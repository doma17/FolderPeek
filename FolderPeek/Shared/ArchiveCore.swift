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
    case unsupportedArchiveFeature(String)
    case outputLimitExceeded
    case corruptArchive(String)
}

public protocol FolderPeekArchiveListingProvider: Sendable {
    func listEntries(in archiveURL: URL, kind: FolderPeekArchiveKind, entryLimit: Int) throws -> FolderPeekArchiveListingResult
}

public struct FolderPeekInProcessArchiveListingProvider: FolderPeekArchiveListingProvider {
    public let maxCentralDirectoryBytes: Int
    public let maxPAXDataBytes: Int

    public init(maxCentralDirectoryBytes: Int = 8 * 1024 * 1024, maxPAXDataBytes: Int = 256 * 1024) {
        self.maxCentralDirectoryBytes = maxCentralDirectoryBytes
        self.maxPAXDataBytes = maxPAXDataBytes
    }

    public func listEntries(in archiveURL: URL, kind: FolderPeekArchiveKind, entryLimit: Int) throws -> FolderPeekArchiveListingResult {
        switch kind {
        case .zip:
            return try FolderPeekZIPCentralDirectoryListingParser(
                maxCentralDirectoryBytes: maxCentralDirectoryBytes
            ).listEntries(in: archiveURL, entryLimit: entryLimit)
        case .tar:
            return try FolderPeekTARListingParser(
                maxPAXDataBytes: maxPAXDataBytes
            ).listEntries(in: archiveURL, entryLimit: entryLimit)
        }
    }
}

public struct FolderPeekZIPCentralDirectoryListingParser: Sendable {
    private let maxEOCDSearchBytes = 22 + 65_535
    private let maxCentralDirectoryBytes: Int

    public init(maxCentralDirectoryBytes: Int = 8 * 1024 * 1024) {
        self.maxCentralDirectoryBytes = maxCentralDirectoryBytes
    }

    public func listEntries(in archiveURL: URL, entryLimit: Int) throws -> FolderPeekArchiveListingResult {
        let fileSize = try archiveFileSize(archiveURL)
        guard fileSize >= 22 else {
            throw FolderPeekArchiveListingError.corruptArchive("ZIP archive is too small to contain an end-of-central-directory record.")
        }

        let searchLength = min(Int(fileSize), maxEOCDSearchBytes)
        let searchOffset = fileSize - UInt64(searchLength)
        let tail = try readData(from: archiveURL, offset: searchOffset, length: searchLength)
        guard let eocdOffsetInTail = findEOCD(in: tail) else {
            throw FolderPeekArchiveListingError.corruptArchive("ZIP end-of-central-directory record was not found.")
        }
        guard eocdOffsetInTail + 22 <= tail.count else {
            throw FolderPeekArchiveListingError.corruptArchive("ZIP end-of-central-directory record is truncated.")
        }

        let eocd = tail
        let diskNumber = eocd.littleEndianUInt16(at: eocdOffsetInTail + 4)
        let centralDirectoryDisk = eocd.littleEndianUInt16(at: eocdOffsetInTail + 6)
        let entriesOnDisk = eocd.littleEndianUInt16(at: eocdOffsetInTail + 8)
        let totalEntries = eocd.littleEndianUInt16(at: eocdOffsetInTail + 10)
        let centralDirectorySize32 = eocd.littleEndianUInt32(at: eocdOffsetInTail + 12)
        let centralDirectoryOffset32 = eocd.littleEndianUInt32(at: eocdOffsetInTail + 16)
        let commentLength = Int(eocd.littleEndianUInt16(at: eocdOffsetInTail + 20))

        guard eocdOffsetInTail + 22 + commentLength <= tail.count else {
            throw FolderPeekArchiveListingError.corruptArchive("ZIP end-of-central-directory comment is truncated.")
        }
        guard diskNumber == 0, centralDirectoryDisk == 0, entriesOnDisk == totalEntries else {
            throw FolderPeekArchiveListingError.unsupportedArchiveFeature("Multi-disk ZIP archives are not supported.")
        }
        guard totalEntries != UInt16.max,
              centralDirectorySize32 != UInt32.max,
              centralDirectoryOffset32 != UInt32.max else {
            throw FolderPeekArchiveListingError.unsupportedArchiveFeature("ZIP64 metadata is not supported in this preview build.")
        }

        let centralDirectorySize = UInt64(centralDirectorySize32)
        let centralDirectoryOffset = UInt64(centralDirectoryOffset32)
        guard centralDirectoryOffset <= fileSize,
              centralDirectorySize <= fileSize - centralDirectoryOffset else {
            throw FolderPeekArchiveListingError.corruptArchive("ZIP central directory points outside the archive.")
        }
        if centralDirectorySize > UInt64(maxCentralDirectoryBytes) {
            throw FolderPeekArchiveListingError.outputLimitExceeded
        }

        let centralDirectory = try readData(
            from: archiveURL,
            offset: centralDirectoryOffset,
            length: Int(centralDirectorySize)
        )
        return try parseCentralDirectory(
            centralDirectory,
            expectedEntries: Int(totalEntries),
            entryLimit: entryLimit
        )
    }

    public func parseCentralDirectory(_ centralDirectory: Data, expectedEntries: Int, entryLimit: Int) throws -> FolderPeekArchiveListingResult {
        var offset = 0
        var entries: [FolderPeekArchiveEntry] = []
        var parsedCount = 0

        while offset < centralDirectory.count && parsedCount < expectedEntries {
            guard offset + 46 <= centralDirectory.count else {
                throw FolderPeekArchiveListingError.corruptArchive("ZIP central directory header is truncated.")
            }
            guard centralDirectory.littleEndianUInt32(at: offset) == 0x0201_4b50 else {
                throw FolderPeekArchiveListingError.corruptArchive("ZIP central directory header signature is invalid.")
            }

            let flags = centralDirectory.littleEndianUInt16(at: offset + 8)
            let uncompressedSize32 = centralDirectory.littleEndianUInt32(at: offset + 24)
            let fileNameLength = Int(centralDirectory.littleEndianUInt16(at: offset + 28))
            let extraFieldLength = Int(centralDirectory.littleEndianUInt16(at: offset + 30))
            let commentLength = Int(centralDirectory.littleEndianUInt16(at: offset + 32))
            let externalAttributes = centralDirectory.littleEndianUInt32(at: offset + 38)
            let nextOffset = offset + 46 + fileNameLength + extraFieldLength + commentLength

            guard nextOffset <= centralDirectory.count else {
                throw FolderPeekArchiveListingError.corruptArchive("ZIP central directory variable fields are truncated.")
            }
            guard Self.supports(flags: flags) else {
                throw FolderPeekArchiveListingError.unsupportedArchiveFeature("Encrypted ZIP entries are not supported in this preview build.")
            }
            guard uncompressedSize32 != UInt32.max else {
                throw FolderPeekArchiveListingError.unsupportedArchiveFeature("ZIP64 entry sizes are not supported in this preview build.")
            }

            let nameData = centralDirectory.subdata(in: (offset + 46)..<(offset + 46 + fileNameLength))
            let path = Self.normalizedPath(Self.decodePath(nameData, flags: flags))
            if entries.count < entryLimit, !path.isEmpty {
                entries.append(
                    FolderPeekArchiveEntry(
                        path: path,
                        kind: Self.kind(path: path, externalAttributes: externalAttributes),
                        uncompressedSize: Int64(uncompressedSize32),
                        rawListingLine: path
                    )
                )
            }
            parsedCount += 1
            offset = nextOffset
        }

        guard parsedCount == expectedEntries else {
            throw FolderPeekArchiveListingError.corruptArchive("ZIP central directory ended before all expected entries were parsed.")
        }
        let isPartial = expectedEntries > entries.count
        return FolderPeekArchiveListingResult(entries: entries, isPartial: isPartial)
    }

    private func archiveFileSize(_ archiveURL: URL) throws -> UInt64 {
        let values = try archiveURL.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize, fileSize >= 0 {
            return UInt64(fileSize)
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: archiveURL.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw FolderPeekArchiveListingError.corruptArchive("ZIP archive size could not be read.")
        }
        return size.uint64Value
    }

    private func readData(from url: URL, offset: UInt64, length: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: offset)
        return handle.readData(ofLength: length)
    }

    private func findEOCD(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        var index = data.count - 22
        while index >= 0 {
            if data.littleEndianUInt32(at: index) == 0x0605_4b50 {
                return index
            }
            if index == 0 { break }
            index -= 1
        }
        return nil
    }

    private static func decodePath(_ data: Data, flags: UInt16) -> String {
        let usesUTF8 = (flags & (1 << 11)) != 0
        if usesUTF8, let value = String(data: data, encoding: .utf8) {
            return value
        }
        if let value = String(data: data, encoding: .utf8) {
            return value
        }
        if let value = String(data: data, encoding: .isoLatin1) {
            return value
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func supports(flags: UInt16) -> Bool {
        let encrypted = (flags & (1 << 0)) != 0
        let strongEncrypted = (flags & (1 << 6)) != 0
        let centralDirectoryEncrypted = (flags & (1 << 13)) != 0
        return !encrypted && !strongEncrypted && !centralDirectoryEncrypted
    }

    private static func normalizedPath(_ path: String) -> String {
        var value = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("./") {
            value.removeFirst(2)
        }
        while value.hasPrefix("/") {
            value.removeFirst()
        }
        return value
    }

    private static func kind(path: String, externalAttributes: UInt32) -> FolderPeekArchiveEntryKind {
        if path.hasSuffix("/") { return .directory }
        let unixMode = (externalAttributes >> 16) & 0o170000
        if unixMode == 0o040000 { return .directory }
        if unixMode == 0o120000 { return .symlink }
        if unixMode == 0o100000 || unixMode == 0 { return .file }
        return .other
    }
}

public struct FolderPeekTARListingParser: Sendable {
    private let blockSize = 512
    private let maxPAXDataBytes: Int

    public init(maxPAXDataBytes: Int = 256 * 1024) {
        self.maxPAXDataBytes = maxPAXDataBytes
    }

    public func listEntries(in archiveURL: URL, entryLimit: Int) throws -> FolderPeekArchiveListingResult {
        let handle = try FileHandle(forReadingFrom: archiveURL)
        defer { try? handle.close() }

        var position: UInt64 = 0
        var zeroBlockCount = 0
        var entries: [FolderPeekArchiveEntry] = []
        var pendingPAX: [String: String] = [:]
        var globalPAX: [String: String] = [:]

        while true {
            let header = try readExactBlock(from: handle, position: &position)
            if header.allSatisfy({ $0 == 0 }) {
                zeroBlockCount += 1
                if zeroBlockCount == 2 {
                    return FolderPeekArchiveListingResult(entries: entries, isPartial: false)
                }
                continue
            }
            zeroBlockCount = 0

            guard checksumIsValid(header) else {
                let headerOffset = position - UInt64(blockSize)
                throw FolderPeekArchiveListingError.corruptArchive("TAR header checksum is invalid at offset \(headerOffset) for \(Self.ustarPath(header)).")
            }

            let rawSize = try Self.parseOctal(header, range: 124..<136, fieldName: "size")
            guard rawSize >= 0 else {
                throw FolderPeekArchiveListingError.corruptArchive("TAR entry size is negative.")
            }
            let typeflag = header[156]

            if typeflag == Self.typeflag("x") || typeflag == Self.typeflag("g") {
                guard rawSize <= Int64(maxPAXDataBytes) else {
                    throw FolderPeekArchiveListingError.outputLimitExceeded
                }
                let paxData = try readExact(from: handle, byteCount: Int(rawSize), position: &position)
                try skipPadding(afterPayloadSize: UInt64(rawSize), handle: handle, position: &position)
                let parsed = Self.parsePAXRecords(paxData)
                if typeflag == Self.typeflag("g") {
                    globalPAX.merge(parsed) { _, new in new }
                } else {
                    pendingPAX = parsed
                }
                continue
            }

            let mergedPAX = globalPAX.merging(pendingPAX) { _, local in local }
            pendingPAX.removeAll(keepingCapacity: true)
            let entryPath = Self.normalizedPath(
                mergedPAX["path"] ?? Self.ustarPath(header)
            )
            let size = try Self.entrySize(rawSize: rawSize, pax: mergedPAX)
            let kind = Self.kind(typeflag: typeflag, path: entryPath)

            if !entryPath.isEmpty {
                if entries.count >= entryLimit {
                    return FolderPeekArchiveListingResult(entries: entries, isPartial: true)
                }
                entries.append(
                    FolderPeekArchiveEntry(
                        path: entryPath,
                        kind: kind,
                        uncompressedSize: kind == .directory ? 0 : size,
                        rawListingLine: entryPath
                    )
                )
            }

            try skipPayload(payloadSize: UInt64(size), handle: handle, position: &position)
        }
    }

    private func readExactBlock(from handle: FileHandle, position: inout UInt64) throws -> Data {
        let data = try readExact(from: handle, byteCount: blockSize, position: &position)
        guard data.count == blockSize else {
            throw FolderPeekArchiveListingError.corruptArchive("TAR header block is truncated.")
        }
        return data
    }

    private func readExact(from handle: FileHandle, byteCount: Int, position: inout UInt64) throws -> Data {
        let data = handle.readData(ofLength: byteCount)
        position += UInt64(data.count)
        guard data.count == byteCount else {
            throw FolderPeekArchiveListingError.corruptArchive("TAR payload is truncated.")
        }
        return data
    }

    private func skipPadding(afterPayloadSize payloadSize: UInt64, handle: FileHandle, position: inout UInt64) throws {
        let remainder = payloadSize % UInt64(blockSize)
        guard remainder != 0 else { return }
        let padding = UInt64(blockSize) - remainder
        try handle.seek(toOffset: position + padding)
        position += padding
    }

    private func skipPayload(payloadSize: UInt64, handle: FileHandle, position: inout UInt64) throws {
        let remainder = payloadSize % UInt64(blockSize)
        let padding = remainder == 0 ? 0 : UInt64(blockSize) - remainder
        let distance = payloadSize + padding
        try handle.seek(toOffset: position + distance)
        position += distance
    }

    private func checksumIsValid(_ header: Data) -> Bool {
        guard let stored = try? Self.parseOctal(header, range: 148..<156, fieldName: "checksum") else {
            return false
        }
        var sum: Int64 = 0
        for index in 0..<header.count {
            if (148..<156).contains(index) {
                sum += 32
            } else {
                sum += Int64(header[index])
            }
        }
        return stored == sum
    }

    private static func entrySize(rawSize: Int64, pax: [String: String]) throws -> Int64 {
        guard let paxSize = pax["size"] else { return rawSize }
        guard let size = Int64(paxSize), size >= 0 else {
            throw FolderPeekArchiveListingError.corruptArchive("TAR PAX size is invalid.")
        }
        return size
    }

    private static func ustarPath(_ header: Data) -> String {
        let name = nullTerminatedString(header, range: 0..<100)
        let prefix = nullTerminatedString(header, range: 345..<500)
        if prefix.isEmpty { return name }
        if name.isEmpty { return prefix }
        return "\(prefix)/\(name)"
    }

    private static func nullTerminatedString(_ data: Data, range: Range<Int>) -> String {
        let bytes = data[range].prefix { $0 != 0 }
        return String(data: Data(bytes), encoding: .utf8) ?? String(decoding: bytes, as: UTF8.self)
    }

    private static func parseOctal(_ data: Data, range: Range<Int>, fieldName: String) throws -> Int64 {
        let raw = data[range]
            .filter { $0 != 0 && $0 != 32 }
        guard !raw.isEmpty else { return 0 }
        var value: Int64 = 0
        for byte in raw {
            guard byte >= 48 && byte <= 55 else {
                throw FolderPeekArchiveListingError.corruptArchive("TAR \(fieldName) field is not octal.")
            }
            value = (value * 8) + Int64(byte - 48)
        }
        return value
    }

    private static func parsePAXRecords(_ data: Data) -> [String: String] {
        guard let text = String(data: data, encoding: .utf8) else { return [:] }
        var result: [String: String] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let space = line.firstIndex(of: " ") else { continue }
            let payload = line[line.index(after: space)...]
            guard let equals = payload.firstIndex(of: "=") else { continue }
            let key = String(payload[..<equals])
            let value = String(payload[payload.index(after: equals)...])
            result[key] = value
        }
        return result
    }

    private static func normalizedPath(_ path: String) -> String {
        var value = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("./") {
            value.removeFirst(2)
        }
        while value.hasPrefix("/") {
            value.removeFirst()
        }
        return value
    }

    private static func kind(typeflag: UInt8, path: String) -> FolderPeekArchiveEntryKind {
        if typeflag == Self.typeflag("5") || path.hasSuffix("/") { return .directory }
        if typeflag == Self.typeflag("2") { return .symlink }
        if typeflag == 0 || typeflag == Self.typeflag("0") { return .file }
        return .other
    }

    private static func typeflag(_ value: Character) -> UInt8 {
        value.asciiValue ?? 0
    }
}

public struct FolderPeekArchivePreviewModelBuilder: Sendable {
    public let detector: FolderPeekArchiveTypeDetector
    public let listingProvider: FolderPeekArchiveListingProvider
    public let now: @Sendable () -> Date

    public init(
        detector: FolderPeekArchiveTypeDetector = FolderPeekArchiveTypeDetector(),
        listingProvider: FolderPeekArchiveListingProvider = FolderPeekInProcessArchiveListingProvider(),
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
                errorMessage: "FolderPeek supports zip and tar archives."
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
            return model(archiveURL: archiveURL, kind: kind, state: .unsupported, entries: [], isPartial: false, errorMessage: "FolderPeek supports zip and tar archives.")
        case .unsupportedArchiveFeature(let message):
            return model(archiveURL: archiveURL, kind: kind, state: .unsupported, entries: [], isPartial: false, errorMessage: message)
        case .outputLimitExceeded:
            return model(archiveURL: archiveURL, kind: kind, state: .outputLimitExceeded, entries: [], isPartial: true, errorMessage: "Archive listing exceeded FolderPeek's safety cap.")
        case .corruptArchive:
            return model(archiveURL: archiveURL, kind: kind, state: .corrupt, entries: [], isPartial: false, errorMessage: "Archive contents could not be listed because the archive appears corrupt or uses unsupported metadata.")
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

private extension Data {
    func littleEndianUInt16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func littleEndianUInt32(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }
}
