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
            button.image = makeStatusBarIcon()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.title = ""
        }
        item.menu = makeMenu()
        statusItem = item
    }


    private func makeStatusBarIcon() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        let icon = NSImage(
            systemSymbolName: "folder",
            accessibilityDescription: "FolderPeek"
        )?.withSymbolConfiguration(configuration)
        icon?.size = NSSize(width: 18, height: 18)
        icon?.isTemplate = true
        return icon
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
        showContentWindow(title: "FolderPeek", rootView: AnyView(ContentView(initialTab: .guide)))
    }

    @objc private func openQuickLookSetupCheck() {
        showContentWindow(title: "FolderPeek", rootView: AnyView(ContentView(initialTab: .setupCheck)))
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
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FolderPeek"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 700, height: 560)
        window.center()
        contentWindow = window
        return window
    }

    @objc private func closeContentWindow() {
        contentWindow?.performClose(nil)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "FolderPeek",
            .applicationVersion: "0.3"
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
