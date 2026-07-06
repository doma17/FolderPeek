import Foundation

public struct FolderPeekHTMLRenderer: Sendable {
    public init() {}

    public func folderHTML(for model: FolderPeekPreviewModel) -> String {
        let groups = model.groupCounts
            .filter { $0.value > 0 }
            .sorted { lhs, rhs in lhs.value == rhs.value ? lhs.key.rawValue < rhs.key.rawValue : lhs.value > rhs.value }
            .map { Self.chip(label: "\($0.value) \($0.key.rawValue)") }
            .joined(separator: "")
        let notice = model.isPartial ? Self.notice("Showing a bounded sample, not a complete inventory.") : ""
        let metadata = Self.metadataRows([
            ("Kind", "Folder preview"),
            ("Items shown", "\(model.items.count)"),
            ("Preview", model.isPartial ? "Bounded sample" : model.state.rawValue.capitalized),
            ("Updated", Self.timestamp(model.generatedAt))
        ])
        let rows = model.items.prefix(30).map { item in
            Self.listRow(name: item.name, detail: item.typeGroup.rawValue, accessory: item.isDirectory ? "Folder" : nil)
        }.joined(separator: "")
        let thumbnails = model.thumbnailCandidates.prefix(8).map { candidate in
            """
            <figure class='thumb'>
              <div class='thumb-icon'>\(Self.escape(Self.iconText(for: candidate.typeGroup)))</div>
              <figcaption>\(Self.escape(candidate.name))</figcaption>
            </figure>
            """
        }.joined(separator: "")
        let thumbnailSection = thumbnails.isEmpty ? "<p class='muted'>No quick visual thumbnails available.</p>" : "<div class='thumbs'>\(thumbnails)</div>"
        let body: String
        if let errorMessage = model.errorMessage {
            body = Self.stateCard(title: "Folder unavailable", message: errorMessage, tone: "warning")
        } else if model.items.isEmpty {
            body = Self.stateCard(title: "Empty folder", message: "There are no visible top-level items to show.", tone: "quiet")
        } else {
            body = """
            <section class='panel'>
              <h2>Quick visual candidates</h2>
              \(thumbnailSection)
            </section>
            <section class='panel'>
              <h2>Sampled contents</h2>
              <ul class='list'>\(rows)</ul>
            </section>
            """
        }
        return page(title: model.folderName, eyebrow: "FolderPeek", summary: model.summary, chips: groups, metadata: metadata, notice: notice, body: body)
    }

    public func archiveHTML(for model: FolderPeekArchivePreviewModel) -> String {
        let chips = [
            model.kind?.rawValue.uppercased(),
            model.isPartial ? "Partial" : nil,
            model.state.rawValue.capitalized
        ].compactMap { $0 }
            .map(Self.chip(label:))
            .joined(separator: "")
        let notice = model.isPartial ? Self.notice("Showing a bounded flat listing, not a complete inventory.") : ""
        let metadata = Self.metadataRows([
            ("Kind", model.kind?.contentTypeIdentifier ?? "Unsupported archive"),
            ("Entries shown", "\(model.entries.count)"),
            ("Listing", "Flat list"),
            ("Safety", "No extraction"),
            ("Updated", Self.timestamp(model.generatedAt))
        ])
        let body: String
        if let errorMessage = model.errorMessage {
            body = Self.stateCard(
                title: "Archive listing unavailable",
                message: "\(errorMessage) FolderPeek did not extract files and will keep the preview read-only.",
                tone: "warning"
            )
        } else if model.entries.isEmpty {
            body = Self.stateCard(title: "Empty archive", message: "No entries were reported by the archive listing step.", tone: "quiet")
        } else {
            let rows = model.entries.prefix(200).map { entry in
                Self.listRow(
                    name: entry.path,
                    detail: entry.kind.rawValue,
                    accessory: entry.uncompressedSize.map(Self.byteCount)
                )
            }.joined(separator: "")
            body = """
            <section class='panel'>
              <h2>Flat archive listing</h2>
              <p class='muted'>Top-level and nested paths are shown as a flat, read-only list.</p>
              <ul class='list'>\(rows)</ul>
            </section>
            """
        }
        return page(title: model.archiveName, eyebrow: "FolderPeek Archive", summary: model.summary, chips: chips, metadata: metadata, notice: notice, body: body)
    }

    private func page(title: String, eyebrow: String, summary: String, chips: String, metadata: String, notice: String, body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            :root {
              color-scheme: light dark;
              --bg: Canvas;
              --text: CanvasText;
              --muted: color-mix(in srgb, CanvasText 54%, transparent);
              --hairline: color-mix(in srgb, CanvasText 14%, transparent);
              --panel: color-mix(in srgb, CanvasText 5%, Canvas);
              --panel-strong: color-mix(in srgb, CanvasText 8%, Canvas);
              --accent: #0a84ff;
              --warning: #b45309;
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
              --font-display: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", system-ui, sans-serif;
              --font-text: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
            }
            * { box-sizing: border-box; }
            body { margin: 0; min-height: 100vh; padding: 22px; background: var(--bg); color: var(--text); font-family: var(--font-text); }
            .shell { max-width: 760px; margin: 0 auto; }
            header { padding: 2px 0 14px; border-bottom: 1px solid var(--hairline); }
            .eyebrow { margin: 0 0 5px; color: var(--muted); font-size: 11px; font-weight: 600; letter-spacing: .08em; text-transform: uppercase; }
            h1 { margin: 0; font-family: var(--font-display); font-size: 26px; line-height: 1.14; font-weight: 650; letter-spacing: -.02em; overflow-wrap: anywhere; }
            .summary { color: var(--muted); margin: 7px 0 0; font-size: 13px; line-height: 1.35; }
            .chips { display: flex; flex-wrap: wrap; gap: 7px; margin: 14px 0 0; }
            .chip { border: 1px solid var(--hairline); border-radius: 999px; background: var(--panel); padding: 4px 9px; font-size: 11px; color: var(--muted); }
            .metadata { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; margin: 14px 0 0; }
            .meta { min-width: 0; border: 1px solid var(--hairline); border-radius: 10px; background: var(--panel); padding: 8px 10px; }
            .meta-label { display: block; color: var(--muted); font-size: 10px; text-transform: uppercase; letter-spacing: .05em; }
            .meta-value { display: block; margin-top: 2px; font-size: 12px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
            .notice { margin: 12px 0 0; border-left: 3px solid var(--warning); padding: 7px 10px; color: var(--warning); background: color-mix(in srgb, var(--warning) 8%, Canvas); border-radius: 8px; font-size: 12px; line-height: 1.35; }
            main { display: grid; gap: 12px; margin-top: 14px; }
            .panel, .state-card { border: 1px solid var(--hairline); border-radius: 14px; background: var(--panel); padding: 14px; }
            h2 { margin: 0 0 10px; font-family: var(--font-display); font-size: 13px; font-weight: 650; }
            .thumbs { display: flex; gap: 10px; overflow: hidden; margin: 0; }
            .thumb { width: 76px; margin: 0; text-align: center; }
            .thumb-icon { width: 54px; height: 54px; margin: 0 auto 6px; border-radius: 13px; display: grid; place-items: center; background: var(--panel-strong); border: 1px solid var(--hairline); font-size: 12px; font-weight: 700; color: var(--accent); }
            figcaption { font-size: 10px; color: var(--muted); overflow: hidden; text-overflow: ellipsis; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow-wrap: anywhere; }
            .list { list-style: none; padding: 0; margin: 0; }
            .row { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 14px; align-items: center; padding: 8px 0; border-bottom: 1px solid var(--hairline); }
            .row:last-child { border-bottom: 0; }
            .name { min-width: 0; overflow-wrap: anywhere; font-size: 13px; }
            .detail { color: var(--muted); font-size: 11px; white-space: nowrap; }
            .accessory { color: var(--muted); font-size: 11px; margin-left: 6px; }
            .state-card { display: grid; gap: 5px; color: var(--muted); }
            .state-card.warning { color: var(--warning); background: color-mix(in srgb, var(--warning) 7%, Canvas); }
            .state-title { margin: 0; color: var(--text); font-size: 14px; font-weight: 650; }
            .state-message { margin: 0; font-size: 12px; line-height: 1.45; }
            .muted { color: var(--muted); font-size: 12px; line-height: 1.4; margin: 0 0 9px; }
            @media (prefers-color-scheme: dark) {
              :root { --accent: #64a9ff; --warning: #f59e0b; }
            }
          </style>
        </head>
        <body>
          <div class="shell">
            <header>
              <p class="eyebrow">\(Self.escape(eyebrow))</p>
              <h1>\(Self.escape(title))</h1>
              <p class="summary">\(Self.escape(summary))</p>
              <div class="chips">\(chips)</div>
              \(metadata)
              \(notice)
            </header>
            <main>\(body)</main>
          </div>
        </body>
        </html>
        """
    }

    private static func chip(label: String) -> String {
        "<span class='chip'>\(escape(label))</span>"
    }

    private static func notice(_ value: String) -> String {
        "<p class='notice'>\(escape(value))</p>"
    }

    private static func metadataRows(_ rows: [(String, String)]) -> String {
        let content = rows.map { label, value in
            """
            <div class='meta'><span class='meta-label'>\(escape(label))</span><span class='meta-value'>\(escape(value))</span></div>
            """
        }.joined(separator: "")
        return "<section class='metadata'>\(content)</section>"
    }

    private static func listRow(name: String, detail: String, accessory: String?) -> String {
        """
        <li class='row'><span class='name'>\(escape(name))</span><span class='detail'>\(escape(detail))\(accessory.map { "<span class='accessory'>\(escape($0))</span>" } ?? "")</span></li>
        """
    }

    private static func stateCard(title: String, message: String, tone: String) -> String {
        """
        <section class='state-card \(escape(tone))'><p class='state-title'>\(escape(title))</p><p class='state-message'>\(escape(message))</p></section>
        """
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter.string(from: date)
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func iconText(for typeGroup: FolderPeekTypeGroup) -> String {
        switch typeGroup {
        case .images: return "IMG"
        case .documents: return "DOC"
        case .videos: return "VID"
        case .audio: return "AUD"
        case .folders: return "DIR"
        case .archives: return "ZIP"
        case .code: return "SRC"
        case .other: return "FILE"
        }
    }

    private static func byteCount(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}
