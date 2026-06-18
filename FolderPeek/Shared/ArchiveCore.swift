import Foundation
import UniformTypeIdentifiers

public enum FolderPeekArchiveKind: String, Codable, Equatable, Sendable {
    case zip
    case tar

    public var contentTypeIdentifier: String {
        switch self {
        case .zip: return "public.zip-archive"
        case .tar: return "public.tar-archive"
        }
    }
}

public struct FolderPeekArchiveTypeDetector: Sendable {
    public init() {}

    public func detect(url: URL, contentType: UTType? = nil) -> FolderPeekArchiveKind? {
        switch contentType?.identifier {
        case "public.zip-archive":
            return .zip
        case "public.tar-archive":
            return .tar
        default:
            break
        }

        switch url.pathExtension.lowercased() {
        case "zip":
            return .zip
        case "tar":
            return .tar
        default:
            return nil
        }
    }
}

public enum FolderPeekArchiveEntryKind: String, Codable, Equatable, Sendable {
    case file
    case directory
    case symlink
    case other
}

public struct FolderPeekArchiveEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let path: String
    public let kind: FolderPeekArchiveEntryKind
    public let uncompressedSize: Int64?
    public let rawListingLine: String

    public init(path: String, kind: FolderPeekArchiveEntryKind, uncompressedSize: Int64?, rawListingLine: String) {
        self.id = path
        self.path = path
        self.kind = kind
        self.uncompressedSize = uncompressedSize
        self.rawListingLine = rawListingLine
    }
}

public enum FolderPeekArchivePreviewState: String, Codable, Equatable, Sendable {
    case ready
    case empty
    case partial
    case unsupported
    case corrupt
    case timedOut
    case outputLimitExceeded
    case error
}

public struct FolderPeekArchivePreviewModel: Codable, Equatable, Sendable {
    public let archiveName: String
    public let kind: FolderPeekArchiveKind?
    public let generatedAt: Date
    public let state: FolderPeekArchivePreviewState
    public let isPartial: Bool
    public let entries: [FolderPeekArchiveEntry]
    public let errorMessage: String?

    public init(
        archiveName: String,
        kind: FolderPeekArchiveKind?,
        generatedAt: Date,
        state: FolderPeekArchivePreviewState,
        isPartial: Bool,
        entries: [FolderPeekArchiveEntry],
        errorMessage: String?
    ) {
        self.archiveName = archiveName
        self.kind = kind
        self.generatedAt = generatedAt
        self.state = state
        self.isPartial = isPartial
        self.entries = entries
        self.errorMessage = errorMessage
    }

    public var summary: String {
        if let errorMessage { return errorMessage }
        if entries.isEmpty { return "This archive appears empty." }
        let suffix = isPartial ? " · partial preview" : ""
        return "\(entries.count) listed entries\(suffix)"
    }
}

public struct FolderPeekArchiveListingResult: Equatable, Sendable {
    public let entries: [FolderPeekArchiveEntry]
    public let isPartial: Bool

    public init(entries: [FolderPeekArchiveEntry], isPartial: Bool) {
        self.entries = entries
        self.isPartial = isPartial
    }
}

public enum FolderPeekArchiveListingError: Error, Equatable, Sendable {
    case unsupportedArchive
    case commandUnavailable(String)
    case timedOut
    case outputLimitExceeded
    case corruptArchive(String)
    case processFailed(exitCode: Int32, message: String)
    case unreadableOutput
}

public protocol FolderPeekArchiveListingProvider: Sendable {
    func listEntries(in archiveURL: URL, kind: FolderPeekArchiveKind, entryLimit: Int) throws -> FolderPeekArchiveListingResult
}

public protocol FolderPeekCommandRunning: Sendable {
    func run(_ request: FolderPeekCommandRequest) throws -> FolderPeekCommandResult
}

public struct FolderPeekCommandRequest: Equatable, Sendable {
    public let executableURL: URL
    public let arguments: [String]
    public let environment: [String: String]
    public let timeout: TimeInterval
    public let maxOutputBytes: Int

    public init(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval,
        maxOutputBytes: Int
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.timeout = timeout
        self.maxOutputBytes = maxOutputBytes
    }
}

public struct FolderPeekCommandResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: Data
    public let stderr: Data
    public let timedOut: Bool
    public let outputLimitExceeded: Bool

    public init(exitCode: Int32, stdout: Data, stderr: Data, timedOut: Bool, outputLimitExceeded: Bool) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.timedOut = timedOut
        self.outputLimitExceeded = outputLimitExceeded
    }
}

public struct FolderPeekProcessCommandRunner: FolderPeekCommandRunning {
    public init() {}

    public func run(_ request: FolderPeekCommandRequest) throws -> FolderPeekCommandResult {
        let process = Process()
        process.executableURL = request.executableURL
        process.arguments = request.arguments
        process.environment = request.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdout = LockedCommandBuffer(maxBytes: request.maxOutputBytes)
        let stderr = LockedCommandBuffer(maxBytes: request.maxOutputBytes)
        let exceeded = LockedFlag()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            if !stdout.append(data) {
                exceeded.set()
                process.terminate()
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            if !stderr.append(data) {
                exceeded.set()
                process.terminate()
            }
        }

        do {
            try process.run()
        } catch {
            throw FolderPeekArchiveListingError.commandUnavailable("\(request.executableURL.path): \(error.localizedDescription)")
        }
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            finished.signal()
        }

        var timedOut = false
        if finished.wait(timeout: .now() + request.timeout) == .timedOut {
            timedOut = true
            process.terminate()
            _ = finished.wait(timeout: .now() + 1)
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdout.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
        stderr.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

        return FolderPeekCommandResult(
            exitCode: process.terminationStatus,
            stdout: stdout.data,
            stderr: stderr.data,
            timedOut: timedOut,
            outputLimitExceeded: exceeded.value || stdout.didExceedLimit || stderr.didExceedLimit
        )
    }
}

public struct FolderPeekBsdtarArchiveListingProvider: FolderPeekArchiveListingProvider {
    public let bsdtarURL: URL
    public let timeout: TimeInterval
    public let maxOutputBytes: Int
    public let commandRunner: FolderPeekCommandRunning

    public init(
        bsdtarURL: URL = URL(fileURLWithPath: "/usr/bin/bsdtar"),
        timeout: TimeInterval = 5,
        maxOutputBytes: Int = 256 * 1024,
        commandRunner: FolderPeekCommandRunning = FolderPeekProcessCommandRunner()
    ) {
        self.bsdtarURL = bsdtarURL
        self.timeout = timeout
        self.maxOutputBytes = maxOutputBytes
        self.commandRunner = commandRunner
    }

    public func listEntries(in archiveURL: URL, kind: FolderPeekArchiveKind, entryLimit: Int) throws -> FolderPeekArchiveListingResult {
        guard kind == .zip || kind == .tar else {
            throw FolderPeekArchiveListingError.unsupportedArchive
        }

        let request = FolderPeekCommandRequest(
            executableURL: bsdtarURL,
            arguments: ["-tvf", archiveURL.path],
            environment: ["LC_ALL": "C"],
            timeout: timeout,
            maxOutputBytes: maxOutputBytes
        )
        let result = try commandRunner.run(request)

        if result.timedOut {
            throw FolderPeekArchiveListingError.timedOut
        }
        if result.outputLimitExceeded {
            throw FolderPeekArchiveListingError.outputLimitExceeded
        }
        guard result.exitCode == 0 else {
            throw mapProcessFailure(exitCode: result.exitCode, stderr: result.stderr)
        }
        guard let stdout = String(data: result.stdout, encoding: .utf8) else {
            throw FolderPeekArchiveListingError.unreadableOutput
        }
        return FolderPeekBsdtarListingParser().parse(stdout, entryLimit: entryLimit)
    }

    private func mapProcessFailure(exitCode: Int32, stderr: Data) -> FolderPeekArchiveListingError {
        let message = String(data: stderr, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lowercased = message.lowercased()
        if lowercased.contains("unrecognized archive format")
            || lowercased.contains("damaged")
            || lowercased.contains("truncated")
            || lowercased.contains("can't find end of central directory")
            || lowercased.contains("error opening archive") {
            return .corruptArchive(message)
        }
        return .processFailed(exitCode: exitCode, message: message)
    }
}

public struct FolderPeekBsdtarListingParser: Sendable {
    public init() {}

    public func parse(_ output: String, entryLimit: Int) -> FolderPeekArchiveListingResult {
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let entries = lines.prefix(entryLimit).compactMap(parseLine)
        return FolderPeekArchiveListingResult(entries: entries, isPartial: lines.count > entryLimit)
    }

    public func parseLine(_ line: String) -> FolderPeekArchiveEntry? {
        guard let permissions = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first,
              let first = permissions.first else {
            return nil
        }
        let normalized = line.replacingOccurrences(of: "\t", with: " ")
        let pattern = #"^\S+\s+\S+\s+\S+\s+\S+\s+(\d+)\s+\S+\s+\d{1,2}\s+(?:\d{2}:\d{2}|\d{4})\s+(.+)$"#
        guard let match = normalized.range(of: pattern, options: .regularExpression) else {
            return fallbackEntry(line: line, first: first)
        }
        let matched = String(normalized[match])
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let regexMatch = regex.firstMatch(in: matched, range: NSRange(matched.startIndex..., in: matched)),
              regexMatch.numberOfRanges >= 3,
              let sizeRange = Range(regexMatch.range(at: 1), in: matched),
              let pathRange = Range(regexMatch.range(at: 2), in: matched) else {
            return fallbackEntry(line: line, first: first)
        }
        let size = Int64(matched[sizeRange])
        let path = Self.normalizedPath(String(matched[pathRange]))
        return FolderPeekArchiveEntry(path: path, kind: kind(first: first, path: path), uncompressedSize: size, rawListingLine: line)
    }

    private func fallbackEntry(line: String, first: Character) -> FolderPeekArchiveEntry? {
        guard let path = line.split(separator: " ", omittingEmptySubsequences: true).last.map(String.init) else {
            return nil
        }
        let normalizedPath = Self.normalizedPath(path)
        return FolderPeekArchiveEntry(path: normalizedPath, kind: kind(first: first, path: normalizedPath), uncompressedSize: nil, rawListingLine: line)
    }

    private func kind(first: Character, path: String) -> FolderPeekArchiveEntryKind {
        if first == "d" || path.hasSuffix("/") { return .directory }
        if first == "l" { return .symlink }
        if first == "-" { return .file }
        return .other
    }

    private static func normalizedPath(_ path: String) -> String {
        var value = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("./") {
            value.removeFirst(2)
        }
        return value
    }
}

public struct FolderPeekArchivePreviewModelBuilder: Sendable {
    public let detector: FolderPeekArchiveTypeDetector
    public let listingProvider: FolderPeekArchiveListingProvider
    public let now: @Sendable () -> Date

    public init(
        detector: FolderPeekArchiveTypeDetector = FolderPeekArchiveTypeDetector(),
        listingProvider: FolderPeekArchiveListingProvider = FolderPeekBsdtarArchiveListingProvider(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.detector = detector
        self.listingProvider = listingProvider
        self.now = now
    }

    public func buildPreviewModel(archiveURL: URL, contentType: UTType? = nil, entryLimit: Int = 200) -> FolderPeekArchivePreviewModel {
        guard let kind = detector.detect(url: archiveURL, contentType: contentType) else {
            return model(
                archiveURL: archiveURL,
                kind: nil,
                state: .unsupported,
                entries: [],
                isPartial: false,
                errorMessage: "FolderPeek supports zip and tar archive previews."
            )
        }

        do {
            let result = try listingProvider.listEntries(in: archiveURL, kind: kind, entryLimit: entryLimit)
            let state: FolderPeekArchivePreviewState = result.isPartial ? .partial : (result.entries.isEmpty ? .empty : .ready)
            return model(
                archiveURL: archiveURL,
                kind: kind,
                state: state,
                entries: result.entries,
                isPartial: result.isPartial,
                errorMessage: nil
            )
        } catch let error as FolderPeekArchiveListingError {
            return errorModel(archiveURL: archiveURL, kind: kind, error: error)
        } catch {
            return model(
                archiveURL: archiveURL,
                kind: kind,
                state: .error,
                entries: [],
                isPartial: false,
                errorMessage: "Archive contents could not be previewed: \(error.localizedDescription)"
            )
        }
    }

    private func errorModel(archiveURL: URL, kind: FolderPeekArchiveKind, error: FolderPeekArchiveListingError) -> FolderPeekArchivePreviewModel {
        switch error {
        case .unsupportedArchive:
            return model(archiveURL: archiveURL, kind: kind, state: .unsupported, entries: [], isPartial: false, errorMessage: "FolderPeek supports zip and tar archive previews.")
        case .commandUnavailable(let path):
            return model(archiveURL: archiveURL, kind: kind, state: .error, entries: [], isPartial: false, errorMessage: "Archive listing tool is unavailable at \(path).")
        case .timedOut:
            return model(archiveURL: archiveURL, kind: kind, state: .timedOut, entries: [], isPartial: false, errorMessage: "Archive listing timed out before any extraction was attempted.")
        case .outputLimitExceeded:
            return model(archiveURL: archiveURL, kind: kind, state: .outputLimitExceeded, entries: [], isPartial: true, errorMessage: "Archive listing exceeded FolderPeek's safety cap.")
        case .corruptArchive:
            return model(archiveURL: archiveURL, kind: kind, state: .corrupt, entries: [], isPartial: false, errorMessage: "Archive contents could not be listed because the archive appears corrupt or unsupported by bsdtar.")
        case .processFailed(_, let message):
            return model(archiveURL: archiveURL, kind: kind, state: .error, entries: [], isPartial: false, errorMessage: message.isEmpty ? "Archive contents could not be listed." : message)
        case .unreadableOutput:
            return model(archiveURL: archiveURL, kind: kind, state: .error, entries: [], isPartial: false, errorMessage: "Archive listing output could not be decoded.")
        }
    }

    private func model(
        archiveURL: URL,
        kind: FolderPeekArchiveKind?,
        state: FolderPeekArchivePreviewState,
        entries: [FolderPeekArchiveEntry],
        isPartial: Bool,
        errorMessage: String?
    ) -> FolderPeekArchivePreviewModel {
        FolderPeekArchivePreviewModel(
            archiveName: archiveURL.lastPathComponent,
            kind: kind,
            generatedAt: now(),
            state: state,
            isPartial: isPartial,
            entries: entries,
            errorMessage: errorMessage
        )
    }
}

private final class LockedCommandBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let maxBytes: Int
    private var storage = Data()
    private var exceeded = false

    init(maxBytes: Int) {
        self.maxBytes = maxBytes
    }

    @discardableResult
    func append(_ data: Data) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !data.isEmpty else { return !exceeded }
        if storage.count + data.count > maxBytes {
            let remaining = max(0, maxBytes - storage.count)
            if remaining > 0 {
                storage.append(data.prefix(remaining))
            }
            exceeded = true
            return false
        }
        storage.append(data)
        return true
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var didExceedLimit: Bool {
        lock.lock()
        defer { lock.unlock() }
        return exceeded
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = false

    func set() {
        lock.lock()
        storage = true
        lock.unlock()
    }

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
