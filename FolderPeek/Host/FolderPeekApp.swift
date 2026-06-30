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
        application.run()
    }
}

@MainActor
private enum FolderPeekApplicationDelegateRetainer {
    static var delegate: FolderPeekAppDelegate?
}
