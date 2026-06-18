import AppKit

@MainActor
final class FolderPeekAppDelegate: NSObject, NSApplicationDelegate {
    private let menuBarController = FolderPeekMenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController.install()
    }
}

@MainActor
final class FolderPeekMenuBarController: NSObject {
    private var statusItem: NSStatusItem?

    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "FolderPeek")
            button.imagePosition = .imageLeading
            button.title = "FolderPeek"
        }
        item.menu = makeMenu()
        statusItem = item
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "FolderPeek")

        let status = NSMenuItem(title: "Quick Look previews are managed by Finder", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open FolderPeek", action: #selector(openMainWindow), keyEquivalent: ",", target: self))
        menu.addItem(NSMenuItem(title: "Quick Look Help", action: #selector(showQuickLookHelp), keyEquivalent: "?", target: self))
        menu.addItem(NSMenuItem(title: "About FolderPeek", action: #selector(showAbout), keyEquivalent: "", target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit FolderPeek", action: #selector(quit), keyEquivalent: "q", target: self))

        return menu
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func showQuickLookHelp() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Using FolderPeek"
        alert.informativeText = "Select a folder, zip archive, or tar archive in Finder and press Space. FolderPeek only previews selected items; it does not index folders in the background or extract archives."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "FolderPeek",
            .applicationVersion: "0.1"
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private extension NSMenuItem {
    convenience init(title: String, action: Selector?, keyEquivalent: String, target: AnyObject?) {
        self.init(title: title, action: action, keyEquivalent: keyEquivalent)
        self.target = target
    }
}
