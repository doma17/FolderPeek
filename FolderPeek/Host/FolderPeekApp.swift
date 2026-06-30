import AppKit

@main
enum FolderPeekApplication {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = FolderPeekAppDelegate()
        FolderPeekApplicationDelegateRetainer.delegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.mainMenu = FolderPeekMainMenu.make()
        application.run()
    }
}

@MainActor
private enum FolderPeekApplicationDelegateRetainer {
    static var delegate: FolderPeekAppDelegate?
}


@MainActor
enum FolderPeekMainMenu {
    static func make() -> NSMenu {
        let mainMenu = NSMenu(title: "FolderPeek")

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "FolderPeek")
        appMenu.addItem(NSMenuItem(title: "Quit FolderPeek", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        return mainMenu
    }
}
