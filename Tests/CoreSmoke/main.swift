import Foundation
import AppKit

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        Foundation.exit(1)
    }
}

let fixedClock: @Sendable () -> Date = { Date(timeIntervalSince1970: 1_800_000_000) }

func makeTemporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("FolderPeekCoreSmoke")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func writeFile(_ name: String, in folder: URL) throws {
    try "fixture".write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
}

func writePNG(_ name: String, in folder: URL) throws {
    let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
    let data = Data(base64Encoded: base64)!
    try data.write(to: folder.appendingPathComponent(name), options: .atomic)
}

let mixed = try makeTemporaryFolder()
defer { try? FileManager.default.removeItem(at: mixed) }
try writePNG("photo.png", in: mixed)
try writeFile("notes.txt", in: mixed)
try writeFile("archive.zip", in: mixed)
try FileManager.default.createDirectory(at: mixed.appendingPathComponent("Nested"), withIntermediateDirectories: true)

let ready = DefaultPreviewModelBuilder(now: fixedClock).buildPreviewModel(folderURL: mixed, itemLimit: 30, thumbnailLimit: 8)
require(ready.state == .ready, "mixed folder should be ready")
require(!ready.isPartial, "mixed folder should not be partial")
require(ready.items.count == 4, "mixed folder item count")
require(ready.groupCounts[.images] == 1, "image classification")
require(ready.groupCounts[.documents] == 1, "document classification")
require(ready.groupCounts[.archives] == 1, "archive classification")
require(ready.groupCounts[.folders] == 1, "folder classification")
require(Set(ready.thumbnailCandidates.map(\.name)) == Set(["photo.png", "notes.txt"]), "thumbnail candidates should be bounded visual docs/images")
require(ready.generatedAt == fixedClock(), "snapshot generatedAt should use injected clock")

let large = try makeTemporaryFolder()
defer { try? FileManager.default.removeItem(at: large) }
for index in 0..<40 {
    try writeFile(String(format: "item-%02d.txt", index), in: large)
}
let partial = DefaultPreviewModelBuilder(now: fixedClock).buildPreviewModel(folderURL: large, itemLimit: 10, thumbnailLimit: 3)
require(partial.state == .partial, "large folder should be partial")
require(partial.isPartial, "large folder partial flag")
require(partial.items.count == 10, "large folder should be bounded")
require(partial.thumbnailCandidates.count == 3, "thumbnail candidate cap")
require(partial.summary.contains("partial preview"), "partial summary disclosure")

let empty = try makeTemporaryFolder()
defer { try? FileManager.default.removeItem(at: empty) }
let emptyModel = DefaultPreviewModelBuilder(now: fixedClock).buildPreviewModel(folderURL: empty, itemLimit: 30, thumbnailLimit: 8)
require(emptyModel.state == .empty, "empty folder state")
require(emptyModel.items.isEmpty, "empty folder items")
require(emptyModel.thumbnailCandidates.isEmpty, "empty folder thumbnail candidates")
require(emptyModel.summary == "This folder appears empty.", "empty folder summary")

struct DeniedEnumerator: FolderEnumerator {
    func topLevelItems(in folderURL: URL, limit: Int) throws -> FolderEnumerationResult {
        throw CocoaError(.fileReadNoPermission)
    }
}
let denied = DefaultPreviewModelBuilder(enumerator: DeniedEnumerator(), now: fixedClock)
    .buildPreviewModel(folderURL: URL(fileURLWithPath: "/private"), itemLimit: 30, thumbnailLimit: 8)
require(denied.state == .inaccessible, "permission error state")
require(denied.summary.contains("access was denied"), "permission error copy")



let classification = try makeTemporaryFolder()
defer { try? FileManager.default.removeItem(at: classification) }
try writePNG("image.png", in: classification)
try writeFile("movie.mp4", in: classification)
try writeFile("sound.mp3", in: classification)
try writeFile("readme.md", in: classification)
try writeFile("package.json", in: classification)
try writeFile("bundle.zip", in: classification)
try writeFile("unknown.customfolderpeek", in: classification)
try "hidden".write(to: classification.appendingPathComponent(".hidden.txt"), atomically: true, encoding: .utf8)
let classified = DefaultPreviewModelBuilder(now: fixedClock).buildPreviewModel(folderURL: classification, itemLimit: 30, thumbnailLimit: 8)
require(classified.items.count == 7, "hidden files should be skipped during top-level enumeration")
require(classified.groupCounts[.images] == 1, "png should classify as image")
require(classified.groupCounts[.videos] == 1, "mp4 should classify as video")
require(classified.groupCounts[.audio] == 1, "mp3 should classify as audio")
require(classified.groupCounts[.documents] == 1, "md should classify as document")
require(classified.groupCounts[.code] == 1, "package.json should classify as code without project analysis")
require(classified.groupCounts[.archives] == 1, "zip should classify as archive without expansion")
require(classified.groupCounts[.other] == 1, "unknown extension should classify as other")

let devLooking = try makeTemporaryFolder()
defer { try? FileManager.default.removeItem(at: devLooking) }
try writeFile("README.md", in: devLooking)
try writeFile("package.json", in: devLooking)
try writeFile("Dockerfile", in: devLooking)
try FileManager.default.createDirectory(at: devLooking.appendingPathComponent("src"), withIntermediateDirectories: true)
let devModel = DefaultPreviewModelBuilder(now: fixedClock).buildPreviewModel(folderURL: devLooking, itemLimit: 30, thumbnailLimit: 8)
require(devModel.items.map(\.name).contains("package.json"), "dev-looking package file should remain an ordinary listed item")
require(devModel.groupCounts[.folders] == 1, "src should remain an ordinary folder")
require(devModel.summary.lowercased().contains("project") == false, "dev-looking folder should not generate a project summary")

let classifier = UTTypeClassifier()
require(classifier.classify(url: URL(fileURLWithPath: "package.json"), resourceValues: nil) == .code, "code classification")
require(classifier.classify(url: URL(fileURLWithPath: "bundle.tar"), resourceValues: nil) == .archives, "archive classification")

let archiveDetector = FolderPeekArchiveTypeDetector()
require(archiveDetector.detect(url: URL(fileURLWithPath: "/tmp/sample.zip")) == .zip, "zip archive detection by extension")
require(archiveDetector.detect(url: URL(fileURLWithPath: "/tmp/sample.tar")) == .tar, "tar archive detection by extension")
require(archiveDetector.detect(url: URL(fileURLWithPath: "/tmp/sample.txt")) == nil, "unsupported archive detection")

let archiveFixtureRoot = try makeTemporaryFolder()
defer { try? FileManager.default.removeItem(at: archiveFixtureRoot) }
let archiveSource = archiveFixtureRoot.appendingPathComponent("source")
try FileManager.default.createDirectory(at: archiveSource.appendingPathComponent("nested"), withIntermediateDirectories: true)
try "space".write(to: archiveSource.appendingPathComponent("nested/file with spaces.txt"), atomically: true, encoding: .utf8)
try "unicode".write(to: archiveSource.appendingPathComponent("유니코드.txt"), atomically: true, encoding: .utf8)
try FileManager.default.createSymbolicLink(
    atPath: archiveSource.appendingPathComponent("link-to-space.txt").path,
    withDestinationPath: "nested/file with spaces.txt"
)
let zipURL = archiveFixtureRoot.appendingPathComponent("fixture.zip")
let tarURL = archiveFixtureRoot.appendingPathComponent("fixture.tar")

func runProcess(_ executable: String, _ arguments: [String], currentDirectoryURL: URL? = nil) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectoryURL
    try process.run()
    process.waitUntilExit()
    require(process.terminationStatus == 0, "process \(executable) \(arguments.joined(separator: " ")) should succeed")
}

try runProcess("/usr/bin/zip", ["-qry", zipURL.path, "."], currentDirectoryURL: archiveSource)
try runProcess("/usr/bin/bsdtar", ["-cf", tarURL.path, "."], currentDirectoryURL: archiveSource)
let realArchiveBuilder = FolderPeekArchivePreviewModelBuilder(now: fixedClock)
let zipModel = realArchiveBuilder.buildPreviewModel(archiveURL: zipURL, entryLimit: 20)
let tarModel = realArchiveBuilder.buildPreviewModel(archiveURL: tarURL, entryLimit: 20)
require(zipModel.state == .ready, "real zip archive should list successfully")
require(zipModel.entries.map(\.path).contains("nested/file with spaces.txt"), "real zip listing should preserve nested path with spaces")
require(zipModel.entries.map(\.path).contains("유니코드.txt"), "real zip listing should preserve Unicode paths")
let partialZipModel = realArchiveBuilder.buildPreviewModel(archiveURL: zipURL, entryLimit: 1)
require(partialZipModel.state == .partial, "real zip archive should disclose partial listing when entry-limited")
require(partialZipModel.entries.count == 1, "zip entry cap should limit listed entries")
require(tarModel.state == .ready, "real tar archive should list successfully")
require(tarModel.entries.map(\.path).contains("nested/file with spaces.txt"), "real tar listing should preserve nested path with spaces")
require(tarModel.entries.map(\.path).contains("유니코드.txt"), "real tar listing should preserve Unicode paths")
require(tarModel.entries.contains { $0.path == "link-to-space.txt" && $0.kind == .symlink }, "real tar listing should preserve symlink metadata without following it")
let partialTarModel = realArchiveBuilder.buildPreviewModel(archiveURL: tarURL, entryLimit: 1)
require(partialTarModel.state == .partial, "real tar archive should disclose partial listing when entry-limited")
require(partialTarModel.entries.count == 1, "tar entry cap should limit listed entries")

let corruptURL = archiveFixtureRoot.appendingPathComponent("corrupt.zip")
try "not an archive".write(to: corruptURL, atomically: true, encoding: .utf8)
let corruptModel = realArchiveBuilder.buildPreviewModel(archiveURL: corruptURL, entryLimit: 20)
require(corruptModel.state == .corrupt, "corrupt zip archive should map to corrupt state")
let corruptTarURL = archiveFixtureRoot.appendingPathComponent("corrupt.tar")
try "not an archive".write(to: corruptTarURL, atomically: true, encoding: .utf8)
let corruptTarModel = realArchiveBuilder.buildPreviewModel(archiveURL: corruptTarURL, entryLimit: 20)
require(corruptTarModel.state == .corrupt, "corrupt tar archive should map to corrupt state")

var zip64SentinelCentralDirectory = Data()
func appendLE16(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(value & 0x00ff))
    data.append(UInt8((value >> 8) & 0x00ff))
}
func appendLE32(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(value & 0x000000ff))
    data.append(UInt8((value >> 8) & 0x000000ff))
    data.append(UInt8((value >> 16) & 0x000000ff))
    data.append(UInt8((value >> 24) & 0x000000ff))
}
func zipCentralDirectoryEntry(path: String, flags: UInt16 = 1 << 11, uncompressedSize: UInt32 = 0) -> Data {
    var data = Data()
    let name = Data(path.utf8)
    appendLE32(0x0201_4b50, to: &data)
    appendLE16(20, to: &data)
    appendLE16(20, to: &data)
    appendLE16(flags, to: &data)
    appendLE16(0, to: &data)
    appendLE16(0, to: &data)
    appendLE16(0, to: &data)
    appendLE32(0, to: &data)
    appendLE32(0, to: &data)
    appendLE32(uncompressedSize, to: &data)
    appendLE16(UInt16(name.count), to: &data)
    appendLE16(0, to: &data)
    appendLE16(0, to: &data)
    appendLE16(0, to: &data)
    appendLE16(0, to: &data)
    appendLE32(0, to: &data)
    appendLE32(0, to: &data)
    data.append(name)
    return data
}
zip64SentinelCentralDirectory = zipCentralDirectoryEntry(path: "big.bin", uncompressedSize: UInt32.max)
do {
    _ = try FolderPeekZIPCentralDirectoryListingParser().parseCentralDirectory(
        zip64SentinelCentralDirectory,
        expectedEntries: 1,
        entryLimit: 20
    )
    require(false, "zip64 sentinel entry should be unsupported")
} catch FolderPeekArchiveListingError.unsupportedArchiveFeature {
    // Expected: ZIP64 policy is explicit for this story.
}
do {
    _ = try FolderPeekZIPCentralDirectoryListingParser().parseCentralDirectory(
        zipCentralDirectoryEntry(path: "secret.txt", flags: (1 << 11) | 1),
        expectedEntries: 1,
        entryLimit: 20
    )
    require(false, "encrypted zip entries should be unsupported")
} catch FolderPeekArchiveListingError.unsupportedArchiveFeature {
    // Expected: encrypted ZIP entries are outside the metadata-only preview support matrix.
}
do {
    _ = try FolderPeekZIPCentralDirectoryListingParser().parseCentralDirectory(
        zipCentralDirectoryEntry(path: "one.txt"),
        expectedEntries: 2,
        entryLimit: 20
    )
    require(false, "truncated zip central directory entry counts should be corrupt")
} catch FolderPeekArchiveListingError.corruptArchive {
    // Expected: EOCD/header count mismatch is malformed metadata, not a partial preview.
}

let renderer = FolderPeekHTMLRenderer()
let folderHTML = renderer.folderHTML(for: ready)
require(folderHTML.contains("Quick visual candidates"), "shared renderer should render folder visual section")
require(folderHTML.contains("Sampled contents"), "shared renderer should render folder contents")
let archiveHTML = renderer.archiveHTML(for: zipModel)
require(archiveHTML.contains("Flat archive listing"), "shared renderer should render flat archive listing")
require(archiveHTML.contains("nested/file with spaces.txt"), "shared renderer should include archive entries")
require(!archiveHTML.lowercased().contains("tree"), "archive renderer should not introduce tree UI copy")

final class FakeThumbnailCancellation: CancellableThumbnailRequest {
    private(set) var isCancelled = false
    func cancel() { isCancelled = true }
}

final class FakeThumbnailProvider: ThumbnailImageProvider {
    enum Mode {
        case success
        case failure
        case neverCompletes
    }

    let mode: Mode
    private(set) var requestedURLs: [URL] = []
    private(set) var cancellations: [FakeThumbnailCancellation] = []

    init(mode: Mode) {
        self.mode = mode
    }

    func generateThumbnail(
        for url: URL,
        size: CGSize,
        scale: CGFloat,
        completion: @escaping (Result<NSImage, Error>) -> Void
    ) -> CancellableThumbnailRequest? {
        requestedURLs.append(url)
        let cancellation = FakeThumbnailCancellation()
        cancellations.append(cancellation)
        switch mode {
        case .success:
            completion(.success(NSImage(size: size)))
        case .failure:
            completion(.failure(CocoaError(.fileNoSuchFile)))
        case .neverCompletes:
            break
        }
        return cancellation
    }
}

final class RenderedThumbnailBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [FolderPeekRenderedThumbnail] = []

    func set(_ value: [FolderPeekRenderedThumbnail]) {
        lock.lock()
        storage = value
        lock.unlock()
    }

    var value: [FolderPeekRenderedThumbnail] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

func renderSynchronously(provider: FakeThumbnailProvider, candidates: [FolderPeekThumbnailCandidate], maxCount: Int, timeout: TimeInterval = 0.05) -> [FolderPeekRenderedThumbnail] {
    let semaphore = DispatchSemaphore(value: 0)
    let rendered = RenderedThumbnailBox()
    ThumbnailPipeline(provider: provider).render(candidates: candidates, maxCount: maxCount, timeout: timeout) { results in
        rendered.set(results)
        semaphore.signal()
    }
    if semaphore.wait(timeout: .now() + 2) != .success {
        FileHandle.standardError.write(Data("FAILED: thumbnail pipeline timed out in smoke test\n".utf8))
        Foundation.exit(1)
    }
    return rendered.value
}

let thumbnailFolder = try makeTemporaryFolder()
defer { try? FileManager.default.removeItem(at: thumbnailFolder) }
let thumbnailURLs = (0..<5).map { thumbnailFolder.appendingPathComponent("thumb-\($0).jpg") }
for url in thumbnailURLs { try "image".write(to: url, atomically: true, encoding: .utf8) }
let thumbnailCandidates = thumbnailURLs.map { FolderPeekThumbnailCandidate(url: $0, typeGroup: .images) }

let successProvider = FakeThumbnailProvider(mode: .success)
let successResults = renderSynchronously(provider: successProvider, candidates: thumbnailCandidates, maxCount: 3)
require(successProvider.requestedURLs.count == 3, "thumbnail pipeline should enforce maxCount")
require(successResults.count == 3, "thumbnail pipeline should return bounded results")
require(successResults.allSatisfy { $0.state == .rendered && $0.image != nil }, "successful thumbnails should render images")

let failureProvider = FakeThumbnailProvider(mode: .failure)
let failureResults = renderSynchronously(provider: failureProvider, candidates: thumbnailCandidates, maxCount: 2)
require(failureResults.count == 2, "failure results should preserve bounded count")
require(failureResults.allSatisfy { $0.state == .placeholder && $0.image == nil }, "failed thumbnails should use placeholders")

let timeoutProvider = FakeThumbnailProvider(mode: .neverCompletes)
let timeoutResults = renderSynchronously(provider: timeoutProvider, candidates: thumbnailCandidates, maxCount: 1, timeout: 0.01)
require(timeoutResults.count == 1, "timeout result count")
require(timeoutResults[0].state == .cancelled, "timeout should cancel thumbnail request")
require(timeoutProvider.cancellations.first?.isCancelled == true, "timeout should call cancellation")

print("FolderPeekCore smoke tests passed")
