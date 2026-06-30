import AppKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        SetupGuideView()
    }
}

struct SetupGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderView(
                    title: "FolderPeek Guide",
                    subtitle: "Use Finder Quick Look to inspect folders and archives before opening them."
                )

                HelpSection(title: "Start here") {
                    NumberedStep(number: 1, title: "Keep FolderPeek running", detail: "The folder icon in the menu bar means FolderPeek is available for Finder Quick Look.")
                    NumberedStep(number: 2, title: "Open Finder", detail: "Select a folder, zip archive, or tar archive.")
                    NumberedStep(number: 3, title: "Press Space", detail: "Finder opens Quick Look and FolderPeek shows the contents when macOS chooses the FolderPeek extension.")
                }

                HelpSection(title: "What FolderPeek shows") {
                    Bullet("Folder contents without opening the folder")
                    Bullet("Flat zip and tar archive listings without extraction")
                    Bullet("Thumbnails, file names, sizes, and modified dates when available")
                }

                HelpSection(title: "If Quick Look does not use FolderPeek") {
                    Text("Open Quick Look Setup Check from the menu bar. It contains an extension settings shortcut, troubleshooting checks, privacy notes, and support contact.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 680, minHeight: 560)
    }
}

struct QuickLookSetupCheckView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderView(
                    title: "Quick Look Setup Check",
                    subtitle: "Use this when Finder Quick Look does not show FolderPeek for supported items."
                )

                HelpSection(title: "Extension settings") {
                    Text("FolderPeek does not need Accessibility permission. If macOS requires extension approval, enable it from System Settings, then try Finder Quick Look again.")
                        .foregroundStyle(.secondary)

                    Button("Open Extension Settings") {
                        SystemSettingsOpener.openExtensionsSettings()
                    }

                    Bullet("Look for Login Items & Extensions, Extensions, or Quick Look. The exact wording can vary by macOS version.")
                    Bullet("After changing extension settings, relaunch Finder or reset Quick Look, then press Space again in Finder.")
                }

                HelpSection(title: "Troubleshooting checklist") {
                    Bullet("Make sure the item is selected in Finder, not opened inside another app.")
                    Bullet("Close the Quick Look window and press Space again if macOS shows another extension first.")
                    Bullet("If the app was just replaced, reset Quick Look or restart Finder before testing again.")
                    Bullet("Use supported items: folders, directories, zip archives, and tar archives.")
                }

                HelpSection(title: "Privacy and safety") {
                    Bullet("No background indexing or monitoring")
                    Bullet("No history of opened items")
                    Bullet("No archive extraction")
                    Bullet("No extra macOS permissions requested by this app")
                }

                HelpSection(title: "Contact") {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Link("rovin1273@gmail.com", destination: URL(string: "mailto:rovin1273@gmail.com")!)
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 680, minHeight: 560)
    }
}

private struct HeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            AppIconImage()

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}


private struct AppIconImage: View {
    private var icon: NSImage {
        if let iconURL = Bundle.main.url(forResource: "FolderPeek", withExtension: "icns"),
           let bundledIcon = NSImage(contentsOf: iconURL) {
            return bundledIcon
        }
        return NSApplication.shared.applicationIconImage
    }

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private enum SystemSettingsOpener {
    static func openExtensionsSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",
            "x-apple.systempreferences:com.apple.preference.extensions"
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
        openSystemSettings()
    }

    static func openSystemSettings() {
        let url = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Preferences.app"))
        }
    }
}

private struct HelpSection<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 7) {
                content
            }
        }
    }
}

private struct NumberedStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct Bullet: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}
