import Cocoa
import QuickLookUI
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    private let folderModelBuilder: PreviewModelBuilder = DefaultPreviewModelBuilder()
    private let archiveModelBuilder = FolderPeekArchivePreviewModelBuilder()
    private let archiveDetector = FolderPeekArchiveTypeDetector()
    private let htmlRenderer = FolderPeekHTMLRenderer()

    func providePreview(for request: QLFilePreviewRequest, completionHandler handler: @escaping (QLPreviewReply?, Error?) -> Void) {
        let url = request.fileURL
        RuntimePreviewEvidence.log("providePreview url=\(url.path)")
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])
        let contentType = values?.contentType

        if isFolder(resourceValues: values) {
            provideFolderPreview(url: url, handler: handler)
            return
        }

        if archiveDetector.detect(url: url, contentType: contentType) != nil {
            provideArchivePreview(url: url, contentType: contentType, handler: handler)
            return
        }

        RuntimePreviewEvidence.log("provided unsupported=\(url.lastPathComponent) type=\(contentType?.identifier ?? "unknown")")
        handler(plainTextReply(title: url.lastPathComponent, text: "FolderPeek supports folders, zip archives, and tar archives."), nil)
    }

    private func isFolder(resourceValues: URLResourceValues?) -> Bool {
        resourceValues?.isDirectory == true
            || resourceValues?.contentType?.conforms(to: .folder) == true
            || resourceValues?.contentType?.conforms(to: .directory) == true
    }

    private func provideFolderPreview(url: URL, handler: @escaping (QLPreviewReply?, Error?) -> Void) {
        let model = folderModelBuilder.buildPreviewModel(folderURL: url, itemLimit: 30, thumbnailLimit: 8)
        let html = htmlRenderer.folderHTML(for: model)
        let reply = htmlReply(title: "FolderPeek — \(model.folderName)", html: html, width: 720, height: 480)
        RuntimePreviewEvidence.log("provided folder=\(model.folderName) state=\(model.state.rawValue) items=\(model.items.count) partial=\(model.isPartial)")
        handler(reply, nil)
    }

    private func provideArchivePreview(url: URL, contentType: UTType?, handler: @escaping (QLPreviewReply?, Error?) -> Void) {
        let model = archiveModelBuilder.buildPreviewModel(archiveURL: url, contentType: contentType, entryLimit: 200)
        let html = htmlRenderer.archiveHTML(for: model)
        let reply = htmlReply(title: "FolderPeek — \(model.archiveName)", html: html, width: 720, height: 480)
        let error = model.errorMessage.map { " error=\($0)" } ?? ""
        RuntimePreviewEvidence.log("provided archive=\(model.archiveName) state=\(model.state.rawValue) entries=\(model.entries.count) partial=\(model.isPartial) type=\(contentType?.identifier ?? model.kind?.contentTypeIdentifier ?? "unknown")\(error)")
        handler(reply, nil)
    }

    private func htmlReply(title: String, html: String, width: CGFloat, height: CGFloat) -> QLPreviewReply {
        QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: width, height: height)) { replyToUpdate in
            replyToUpdate.stringEncoding = .utf8
            replyToUpdate.title = title
            return Data(html.utf8)
        }
    }

    private func plainTextReply(title: String, text: String) -> QLPreviewReply {
        QLPreviewReply(dataOfContentType: .plainText, contentSize: CGSize(width: 720, height: 320)) { replyToUpdate in
            replyToUpdate.stringEncoding = .utf8
            replyToUpdate.title = title
            return Data(text.utf8)
        }
    }
}

enum RuntimePreviewEvidence {
#if FOLDERPEEK_EVIDENCE
    static func log(_ message: String) {
        NSLog("FolderPeekEvidence \(message)")
    }
#else
    static func log(_ message: String) {}
#endif
}
