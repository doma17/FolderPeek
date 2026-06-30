import AppKit
import SwiftUI

@MainActor
final class FolderPeekAppDelegate: NSObject, NSApplicationDelegate {
    private let menuBarController = FolderPeekMenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController.install()
    }
}

@MainActor
final class FolderPeekMenuBarController: NSObject {
    // FolderPeek is intentionally menu-bar-primary (`LSUIElement`): this status
    // item is the supported management entry point instead of a Dock window.
    private var statusItem: NSStatusItem?
    private var contentWindow: NSWindow?

    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "FolderPeek")
            button.imagePosition = .imageOnly
            button.title = ""
        }
        item.menu = makeMenu()
        statusItem = item
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "FolderPeek")

        let status = NSMenuItem(title: "Finder Quick Look uses FolderPeek", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open FolderPeek Guide…", action: #selector(openSetupGuide), keyEquivalent: ",", target: self))
        menu.addItem(NSMenuItem(title: "Quick Look Setup Check…", action: #selector(openQuickLookSetupCheck), keyEquivalent: "?", target: self))
        menu.addItem(NSMenuItem(title: "About FolderPeek", action: #selector(showAbout), keyEquivalent: "", target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit FolderPeek", action: #selector(quit), keyEquivalent: "q", target: self))

        return menu
    }

    @objc private func openSetupGuide() {
        showContentWindow(title: "FolderPeek Guide", rootView: AnyView(SetupGuideView()))
    }

    @objc private func openQuickLookSetupCheck() {
        showContentWindow(title: "Quick Look Setup Check", rootView: AnyView(QuickLookSetupCheckView()))
    }

    private func showContentWindow(title: String, rootView: AnyView) {
        let window = makeContentWindow()
        window.title = title
        window.contentViewController = NSHostingController(rootView: rootView)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeContentWindow() -> NSWindow {
        if let contentWindow {
            return contentWindow
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FolderPeek"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 620, height: 480)
        window.center()
        contentWindow = window
        return window
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "FolderPeek",
            .applicationVersion: "0.2"
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
