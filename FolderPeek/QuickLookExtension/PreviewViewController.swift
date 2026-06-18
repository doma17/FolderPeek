import Cocoa
import QuickLookUI
import UniformTypeIdentifiers

final class PreviewViewController: NSViewController, QLPreviewingController {
    private let modelBuilder: PreviewModelBuilder = DefaultPreviewModelBuilder()
    private let rootStack = NSStackView()
    private let itemListStack = NSStackView()
    private let typeSummaryStack = NSStackView()
    private let thumbnailStack = NSStackView()
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        configureRootStack()
        addStateCard(title: "FolderPeek", message: "Preparing folder contents preview…", symbol: "folder")
        RuntimePreviewLogger.log("loadView")
    }

    func preparePreviewOfFile(at url: URL) async throws {
        await MainActor.run {
            renderPreview(at: url)
        }
    }

    private func renderPreview(at url: URL) {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])
        let isFolder = values?.isDirectory == true || values?.contentType?.conforms(to: .folder) == true || values?.contentType?.conforms(to: .directory) == true
        RuntimePreviewLogger.log("preparePreviewOfFile url=\(url.path) isFolder=\(isFolder)")
        guard isFolder else {
            renderMessage(title: url.lastPathComponent, message: "FolderPeek MVP only previews user-browsable folders.", state: .error)
            RuntimePreviewLogger.log("unsupported url=\(url.path)")
            return
        }

        let model = modelBuilder.buildPreviewModel(folderURL: url, itemLimit: 30, thumbnailLimit: 8)
        render(model: model)
        RuntimePreviewLogger.log("rendered folder=\(model.folderName) state=\(model.state.rawValue) items=\(model.items.count) partial=\(model.isPartial) thumbnails=\(model.thumbnailCandidates.count)")
    }

    private func configureRootStack() {
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 14
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 22, right: 24)
        view.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor),
            rootStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor)
        ])
    }

    private func render(model: FolderPeekPreviewModel) {
        clearRoot()
        rootStack.addArrangedSubview(headerView(for: model))

        if model.state == .empty {
            addStateCard(title: "Empty folder", message: "This folder appears empty.", symbol: "folder")
            return
        }

        if let errorMessage = model.errorMessage {
            addStateCard(title: "Preview unavailable", message: errorMessage, symbol: "exclamationmark.triangle")
            return
        }

        if model.isPartial {
            addInlineNotice("Showing a bounded sample, not a complete inventory.")
        }

        rootStack.addArrangedSubview(typeSummaryView(groupCounts: model.groupCounts))
        rootStack.addArrangedSubview(thumbnailStrip(for: model))
        rootStack.addArrangedSubview(itemList(for: model))
    }

    private func renderMessage(title: String, message: String, state: FolderPeekPreviewState) {
        clearRoot()
        let model = FolderPeekPreviewModel(
            folderName: title,
            generatedAt: Date(),
            state: state,
            isPartial: false,
            items: [],
            groupCounts: [:],
            thumbnailCandidates: [],
            errorMessage: message
        )
        rootStack.addArrangedSubview(headerView(for: model))
        addStateCard(title: "Unsupported item", message: message, symbol: "questionmark.folder")
    }

    private func headerView(for model: FolderPeekPreviewModel) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

        let title = label(model.folderName, font: .boldSystemFont(ofSize: 24), color: .labelColor)
        let subtitle = label(model.summary, font: .systemFont(ofSize: 13), color: .secondaryLabelColor)
        let freshness = label("Snapshot preview · generated at \(dateFormatter.string(from: model.generatedAt))", font: .systemFont(ofSize: 11), color: .tertiaryLabelColor)

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(freshness)
        return stack
    }

    private func typeSummaryView(groupCounts: [FolderPeekTypeGroup: Int]) -> NSView {
        typeSummaryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        typeSummaryStack.orientation = .horizontal
        typeSummaryStack.alignment = .centerY
        typeSummaryStack.spacing = 6

        let sortedGroups = groupCounts
            .filter { $0.value > 0 }
            .sorted { lhs, rhs in lhs.value == rhs.value ? lhs.key.rawValue < rhs.key.rawValue : lhs.value > rhs.value }

        if sortedGroups.isEmpty {
            typeSummaryStack.addArrangedSubview(chip("No sampled items"))
        } else {
            sortedGroups.forEach { group, count in
                typeSummaryStack.addArrangedSubview(chip("\(count) \(group.rawValue)"))
            }
        }
        return typeSummaryStack
    }

    private func thumbnailStrip(for model: FolderPeekPreviewModel) -> NSView {
        thumbnailStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        thumbnailStack.orientation = .horizontal
        thumbnailStack.alignment = .centerY
        thumbnailStack.spacing = 8

        let candidates = model.thumbnailCandidates.prefix(8)
        if candidates.isEmpty {
            thumbnailStack.addArrangedSubview(label("No quick visual thumbnails available.", font: .systemFont(ofSize: 12), color: .tertiaryLabelColor))
        } else {
            candidates.forEach { candidate in
                thumbnailStack.addArrangedSubview(thumbnailPlaceholder(for: candidate))
            }
        }
        return thumbnailStack
    }

    private func itemList(for model: FolderPeekPreviewModel) -> NSView {
        itemListStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        itemListStack.orientation = .vertical
        itemListStack.alignment = .leading
        itemListStack.spacing = 5

        itemListStack.addArrangedSubview(label("Sampled contents", font: .boldSystemFont(ofSize: 13), color: .labelColor))
        model.items.prefix(14).forEach { item in
            itemListStack.addArrangedSubview(itemRow(item))
        }
        return itemListStack
    }

    private func itemRow(_ item: FolderPeekItem) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 7

        let icon = NSImageView(image: icon(for: item))
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setFrameSize(NSSize(width: 18, height: 18))
        stack.addArrangedSubview(icon)

        let name = label(item.name, font: .systemFont(ofSize: 13), color: .labelColor)
        name.lineBreakMode = .byTruncatingMiddle
        stack.addArrangedSubview(name)
        stack.addArrangedSubview(label(item.typeGroup.rawValue, font: .systemFont(ofSize: 11), color: .secondaryLabelColor))
        return stack
    }

    private func thumbnailPlaceholder(for candidate: FolderPeekThumbnailCandidate) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.widthAnchor.constraint(equalToConstant: 74).isActive = true

        let imageView = NSImageView(image: icon(forFileName: candidate.name))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.widthAnchor.constraint(equalToConstant: 52).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let caption = label(candidate.name, font: .systemFont(ofSize: 10), color: .secondaryLabelColor)
        caption.maximumNumberOfLines = 2
        caption.alignment = .center
        caption.lineBreakMode = .byTruncatingMiddle

        stack.addArrangedSubview(imageView)
        stack.addArrangedSubview(caption)
        return stack
    }

    private func icon(for item: FolderPeekItem) -> NSImage {
        item.isDirectory ? NSWorkspace.shared.icon(for: .folder) : icon(forFileName: item.name)
    }

    private func icon(forFileName fileName: String) -> NSImage {
        let ext = fileName.pathExtensionOrFallback
        if let type = UTType(filenameExtension: ext) {
            return NSWorkspace.shared.icon(for: type)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    private func addInlineNotice(_ text: String) {
        let notice = label(text, font: .systemFont(ofSize: 12), color: .systemOrange)
        rootStack.addArrangedSubview(notice)
    }

    private func addStateCard(title: String, message: String, symbol: String) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.addArrangedSubview(label(title, font: .boldSystemFont(ofSize: 15), color: .labelColor))
        stack.addArrangedSubview(label(message, font: .systemFont(ofSize: 13), color: .secondaryLabelColor))
        rootStack.addArrangedSubview(stack)
    }

    private func chip(_ text: String) -> NSView {
        let field = label(text, font: .systemFont(ofSize: 11, weight: .medium), color: .secondaryLabelColor)
        field.wantsLayer = true
        field.layer?.cornerRadius = 8
        field.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        field.setContentHuggingPriority(.required, for: .horizontal)
        return field
    }

    private func label(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private func clearRoot() {
        rootStack.arrangedSubviews.forEach { view in
            rootStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
}

private extension String {
    var pathExtensionOrFallback: String {
        let ext = (self as NSString).pathExtension
        return ext.isEmpty ? "txt" : ext
    }
}

private enum RuntimePreviewLogger {
    static func log(_ message: String) {
        let tempLog = URL(fileURLWithPath: "/tmp/FolderPeek-preview.log")
        if write(message, to: tempLog) {
            return
        }

        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("FolderPeek", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            _ = write(message, to: directory.appendingPathComponent("preview.log"))
        } catch {
            // Runtime evidence logging must never prevent Quick Look rendering.
        }
    }

    private static func write(_ message: String, to file: URL) -> Bool {
        do {
            let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
            guard let data = line.data(using: .utf8) else { return false }
            if FileManager.default.fileExists(atPath: file.path),
               let handle = try? FileHandle(forWritingTo: file) {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: file, options: .atomic)
            }
            return true
        } catch {
            return false
        }
    }
}
