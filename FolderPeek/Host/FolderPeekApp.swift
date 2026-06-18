import SwiftUI

@main
struct FolderPeekApp: App {
    @NSApplicationDelegateAdaptor(FolderPeekAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
