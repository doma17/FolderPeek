import Foundation
import UniformTypeIdentifiers

public enum FolderPeekTypeGroup: String, CaseIterable, Codable, Equatable, Sendable {
    case images = "Images"
    case documents = "Documents"
    case videos = "Videos"
    case audio = "Audio"
    case folders = "Folders"
    case archives = "Archives"
    case code = "Code"
    case other = "Other"
}

public enum FolderPeekPreviewState: String, Codable, Equatable, Sendable {
    case ready
    case empty
    case partial
    case inaccessible
    case error
}

public struct FolderPeekItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let typeGroup: FolderPeekTypeGroup
    public let isDirectory: Bool

    public init(url: URL, typeGroup: FolderPeekTypeGroup, isDirectory: Bool) {
        self.id = url.path
        self.name = url.lastPathComponent
        self.typeGroup = typeGroup
        self.isDirectory = isDirectory
    }
}

public struct FolderPeekThumbnailCandidate: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let url: URL
    public let name: String
    public let typeGroup: FolderPeekTypeGroup

    public init(url: URL, typeGroup: FolderPeekTypeGroup) {
        self.id = url.path
        self.url = url
        self.name = url.lastPathComponent
        self.typeGroup = typeGroup
    }
}

public struct FolderPeekPreviewModel: Codable, Equatable, Sendable {
    public let folderName: String
    public let generatedAt: Date
    public let state: FolderPeekPreviewState
    public let isPartial: Bool
    public let items: [FolderPeekItem]
    public let groupCounts: [FolderPeekTypeGroup: Int]
    public let thumbnailCandidates: [FolderPeekThumbnailCandidate]
    public let errorMessage: String?

    public init(
        folderName: String,
        generatedAt: Date,
        state: FolderPeekPreviewState,
        isPartial: Bool,
        items: [FolderPeekItem],
        groupCounts: [FolderPeekTypeGroup: Int],
        thumbnailCandidates: [FolderPeekThumbnailCandidate],
        errorMessage: String?
    ) {
        self.folderName = folderName
        self.generatedAt = generatedAt
        self.state = state
        self.isPartial = isPartial
        self.items = items
        self.groupCounts = groupCounts
        self.thumbnailCandidates = thumbnailCandidates
        self.errorMessage = errorMessage
    }

    public var summary: String {
        if let errorMessage { return errorMessage }
        if items.isEmpty { return "This folder appears empty." }
        let leading = groupCounts
            .sorted { lhs, rhs in lhs.value == rhs.value ? lhs.key.rawValue < rhs.key.rawValue : lhs.value > rhs.value }
            .prefix(2)
            .map { "\($0.value) \($0.key.rawValue.lowercased())" }
            .joined(separator: ", ")
        let suffix = isPartial ? " · partial preview" : ""
        return "\(items.count) sampled items" + (leading.isEmpty ? suffix : " · \(leading)\(suffix)")
    }
}

public struct FolderEnumerationResult: Equatable, Sendable {
    public let itemURLs: [URL]
    public let isPartial: Bool

    public init(itemURLs: [URL], isPartial: Bool) {
        self.itemURLs = itemURLs
        self.isPartial = isPartial
    }
}

public protocol FolderEnumerator: Sendable {
    func topLevelItems(in folderURL: URL, limit: Int) throws -> FolderEnumerationResult
}

public protocol TypeClassifier: Sendable {
    func classify(url: URL, resourceValues: URLResourceValues?) -> FolderPeekTypeGroup
}

public protocol ThumbnailProvider: Sendable {
    func thumbnailCandidates(from itemURLs: [URL], classifiedItems: [FolderPeekItem], maxCount: Int) -> [FolderPeekThumbnailCandidate]
}

public protocol PreviewModelBuilder: Sendable {
    func buildPreviewModel(folderURL: URL, itemLimit: Int, thumbnailLimit: Int) -> FolderPeekPreviewModel
}

public struct FileSystemFolderEnumerator: FolderEnumerator {
    public init() {}

    public func topLevelItems(in folderURL: URL, limit: Int) throws -> FolderEnumerationResult {
        let urls = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentTypeKey],
            options: [.skipsHiddenFiles]
        )
        let sorted = urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        return FolderEnumerationResult(itemURLs: Array(sorted.prefix(limit)), isPartial: sorted.count > limit)
    }
}

public struct UTTypeClassifier: TypeClassifier {
    public init() {}

    public func classify(url: URL, resourceValues: URLResourceValues?) -> FolderPeekTypeGroup {
        if resourceValues?.isDirectory == true { return .folders }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return .folders
        }

        let ext = url.pathExtension.lowercased()
        if Self.archiveExtensions.contains(ext) { return .archives }
        if Self.codeExtensions.contains(ext) { return .code }
        if Self.imageExtensions.contains(ext) { return .images }
        if Self.videoExtensions.contains(ext) { return .videos }
        if Self.audioExtensions.contains(ext) { return .audio }
        if Self.documentExtensions.contains(ext) { return .documents }

        guard let type = resourceValues?.contentType ?? UTType(filenameExtension: ext) else { return .other }
        if type.conforms(to: .image) { return .images }
        if type.conforms(to: .movie) { return .videos }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .pdf) || type.conforms(to: .text) || type.conforms(to: .rtf) { return .documents }
        return .other
    }

    private static let archiveExtensions: Set<String> = ["zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar"]
    private static let codeExtensions: Set<String> = ["swift", "js", "ts", "tsx", "jsx", "py", "rb", "go", "rs", "java", "c", "cc", "cpp", "h", "hpp", "html", "css", "json", "yaml", "yml", "toml"]
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tiff", "tif", "bmp", "svg"]
    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]
    private static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "flac"]
    private static let documentExtensions: Set<String> = ["txt", "md", "markdown", "pdf", "rtf", "doc", "docx", "pages", "key", "numbers", "csv", "tsv"]
}

public struct CandidateThumbnailProvider: ThumbnailProvider {
    public init() {}

    public func thumbnailCandidates(from itemURLs: [URL], classifiedItems: [FolderPeekItem], maxCount: Int) -> [FolderPeekThumbnailCandidate] {
        let itemByID = Dictionary(uniqueKeysWithValues: classifiedItems.map { ($0.id, $0) })
        return itemURLs.compactMap { url in
            guard let item = itemByID[url.path], Self.visualGroups.contains(item.typeGroup), !item.isDirectory else {
                return nil
            }
            return FolderPeekThumbnailCandidate(url: url, typeGroup: item.typeGroup)
        }
        .prefix(maxCount)
        .map { $0 }
    }

    private static let visualGroups: Set<FolderPeekTypeGroup> = [.images, .documents, .videos]
}

public struct DefaultPreviewModelBuilder: PreviewModelBuilder {
    private let enumerator: FolderEnumerator
    private let classifier: TypeClassifier
    private let thumbnailProvider: ThumbnailProvider
    private let now: @Sendable () -> Date

    public init(
        enumerator: FolderEnumerator = FileSystemFolderEnumerator(),
        classifier: TypeClassifier = UTTypeClassifier(),
        thumbnailProvider: ThumbnailProvider = CandidateThumbnailProvider(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.enumerator = enumerator
        self.classifier = classifier
        self.thumbnailProvider = thumbnailProvider
        self.now = now
    }

    public func buildPreviewModel(folderURL: URL, itemLimit: Int = 30, thumbnailLimit: Int = 8) -> FolderPeekPreviewModel {
        do {
            var groupCounts: [FolderPeekTypeGroup: Int] = [:]
            let result = try enumerator.topLevelItems(in: folderURL, limit: itemLimit)
            let items = result.itemURLs.map { url in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])
                let group = classifier.classify(url: url, resourceValues: values)
                groupCounts[group, default: 0] += 1
                return FolderPeekItem(url: url, typeGroup: group, isDirectory: values?.isDirectory == true)
            }
            let candidates = thumbnailProvider.thumbnailCandidates(
                from: result.itemURLs,
                classifiedItems: items,
                maxCount: thumbnailLimit
            )
            let state: FolderPeekPreviewState
            if result.isPartial {
                state = .partial
            } else if items.isEmpty {
                state = .empty
            } else {
                state = .ready
            }
            return FolderPeekPreviewModel(
                folderName: folderURL.lastPathComponent,
                generatedAt: now(),
                state: state,
                isPartial: result.isPartial,
                items: items,
                groupCounts: groupCounts,
                thumbnailCandidates: candidates,
                errorMessage: nil
            )
        } catch CocoaError.fileReadNoPermission {
            return errorModel(folderURL: folderURL, state: .inaccessible, message: "Folder contents could not be previewed because access was denied.")
        } catch {
            return errorModel(folderURL: folderURL, state: .error, message: "Folder contents could not be previewed: \(error.localizedDescription)")
        }
    }

    private func errorModel(folderURL: URL, state: FolderPeekPreviewState, message: String) -> FolderPeekPreviewModel {
        FolderPeekPreviewModel(
            folderName: folderURL.lastPathComponent,
            generatedAt: now(),
            state: state,
            isPartial: false,
            items: [],
            groupCounts: [:],
            thumbnailCandidates: [],
            errorMessage: message
        )
    }
}
