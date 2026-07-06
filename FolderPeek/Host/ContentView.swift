import AppKit
import SwiftUI

struct ContentView: View {
    let initialTab: HelpTab

    init(initialTab: HelpTab = .guide) {
        self.initialTab = initialTab
    }

    var body: some View {
        FolderPeekHelpView(initialTab: initialTab)
    }
}

enum HelpTab: String, CaseIterable, Identifiable {
    case guide
    case setupCheck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guide: return "Guide"
        case .setupCheck: return "Quick Look Check"
        }
    }

    var symbolName: String {
        switch self {
        case .guide: return "sparkles"
        case .setupCheck: return "checkmark.circle"
        }
    }

    var windowTitle: String {
        switch self {
        case .guide: return "FolderPeek Guide"
        case .setupCheck: return "Quick Look Setup Check"
        }
    }
}

struct FolderPeekHelpView: View {
    @State private var selectedTab: HelpTab

    init(initialTab: HelpTab) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Divider()
                .opacity(0.45)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero

                    switch selectedTab {
                    case .guide:
                        GuidePanel()
                    case .setupCheck:
                        SetupCheckPanel()
                    }
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(DesignColor.canvasParchment)
        .frame(minWidth: 760, minHeight: 620)
    }

    private var topBar: some View {
        HStack(spacing: 18) {
            AppIconImage(size: 42, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text("FolderPeek")
                    .font(DesignTypography.title)
                    .tracking(-0.2)
                    .foregroundStyle(DesignColor.ink)
                Text("Preview folders and archives from Finder Quick Look.")
                    .font(DesignTypography.subheadline)
                    .foregroundStyle(DesignColor.muted)
            }

            Spacer()

            PillTabPicker(selectedTab: $selectedTab)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 22) {
            AppIconImage(size: 76, cornerRadius: 18)

            VStack(alignment: .leading, spacing: 8) {
                Text(selectedTab.windowTitle)
                    .font(DesignTypography.display)
                    .tracking(-0.37)
                    .foregroundStyle(DesignColor.ink)
                Text(heroSubtitle)
                    .font(DesignTypography.body)
                    .tracking(-0.2)
                    .lineSpacing(3)
                    .foregroundStyle(DesignColor.body)
            }
        }
    }

    private var heroSubtitle: String {
        switch selectedTab {
        case .guide:
            return "Use Finder Quick Look to inspect folders and archives before opening them."
        case .setupCheck:
            return "Use this checklist when Finder Quick Look does not show FolderPeek for supported items."
        }
    }
}

private struct PillTabPicker: View {
    @Binding var selectedTab: HelpTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(HelpTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: tab.symbolName)
                            .font(DesignTypography.badge)
                        Text(tab.title)
                            .font(DesignTypography.tab)
                    }
                    .foregroundStyle(selectedTab == tab ? Color.white : DesignColor.primary)
                    .padding(.horizontal, 15)
                    .frame(height: 34)
                    .background(
                        Capsule()
                            .fill(selectedTab == tab ? DesignColor.primary : Color.white.opacity(0.82))
                    )
                    .overlay(
                        Capsule()
                            .stroke(selectedTab == tab ? DesignColor.primary : DesignColor.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.windowTitle)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.68))
        )
        .overlay(
            Capsule()
                .stroke(DesignColor.hairline, lineWidth: 1)
        )
    }
}

private struct GuidePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DesignCard(title: "Start here") {
                NumberedStep(number: 1, title: "Keep FolderPeek running", detail: "The folder icon in the menu bar means FolderPeek is available for Finder Quick Look.")
                NumberedStep(number: 2, title: "Open Finder", detail: "Select a folder, zip archive, or tar archive.")
                NumberedStep(number: 3, title: "Press Space", detail: "Finder opens Quick Look and FolderPeek shows the contents when macOS chooses the FolderPeek extension.")
            }

            HStack(alignment: .top, spacing: 18) {
                DesignCard(title: "What FolderPeek shows") {
                    Bullet("Folder contents without opening the folder")
                    Bullet("Flat zip and tar archive listings without extraction")
                    Bullet("Thumbnails, file names, sizes, and modified dates when available")
                }

                DesignCard(title: "If Quick Look does not use FolderPeek") {
                    Text("Switch to the Quick Look Check tab for extension settings, troubleshooting, privacy, and contact details.")
                        .bodyText()
                }
            }
        }
    }
}

private struct SetupCheckPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DesignCard(title: "Extension settings") {
                Text("FolderPeek does not need Accessibility permission. If macOS requires extension approval, enable it from System Settings, then try Finder Quick Look again.")
                    .bodyText()

                Button("Open Extension Settings") {
                    SystemSettingsOpener.openExtensionsSettings()
                }
                .buttonStyle(PrimaryPillButtonStyle())

                Bullet("Look for Login Items & Extensions, Extensions, or Quick Look. The exact wording can vary by macOS version.")
                Bullet("After changing extension settings, relaunch Finder or reset Quick Look, then press Space again in Finder.")
            }

            HStack(alignment: .top, spacing: 18) {
                DesignCard(title: "Troubleshooting checklist") {
                    Bullet("Make sure the item is selected in Finder, not opened inside another app.")
                    Bullet("Close the Quick Look window and press Space again if macOS shows another extension first.")
                    Bullet("If the app was just replaced, reset Quick Look or restart Finder before testing again.")
                    Bullet("Use supported items: folders, directories, zip archives, and tar archives.")
                }

                VStack(alignment: .leading, spacing: 18) {
                    DesignCard(title: "Privacy and safety") {
                        Bullet("No background indexing or monitoring")
                        Bullet("No history of opened items")
                        Bullet("No archive extraction")
                        Bullet("No extra macOS permissions requested by this app")
                    }

                    DesignCard(title: "Contact") {
                        Link("rovin1273@gmail.com", destination: URL(string: "mailto:rovin1273@gmail.com")!)
                            .font(DesignTypography.body)
                            .foregroundStyle(DesignColor.primary)
                    }
                }
            }
        }
    }
}

private struct DesignCard<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title)
                .font(DesignTypography.bodyStrong)
                .tracking(-0.24)
                .foregroundStyle(DesignColor.ink)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DesignColor.hairline, lineWidth: 1)
        )
    }
}

private struct AppIconImage: View {
    let size: CGFloat
    let cornerRadius: CGFloat

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
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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

private struct NumberedStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(DesignTypography.badge)
                .foregroundStyle(Color.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(DesignColor.primary))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DesignTypography.bodyStrong)
                    .tracking(-0.2)
                    .foregroundStyle(DesignColor.ink)
                Text(detail)
                    .bodyText()
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
        HStack(alignment: .top, spacing: 9) {
            Circle()
                .fill(DesignColor.primary)
                .frame(width: 5, height: 5)
                .padding(.top, 9)
            Text(text)
                .bodyText()
        }
    }
}

private struct PrimaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTypography.body)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 22)
            .frame(height: 44)
            .background(Capsule().fill(DesignColor.primary))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}


private enum DesignTypography {
    // San Francisco is the native macOS system typeface. Using explicit
    // system tokens keeps FolderPeek on SF Pro Display/Text without bundling
    // private font files.
    static let display = Font.system(size: 34, weight: .semibold, design: .default)
    static let title = Font.system(size: 21, weight: .semibold, design: .default)
    static let bodyStrong = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let tab = Font.system(size: 14, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 13, weight: .regular, design: .default)
    static let badge = Font.system(size: 13, weight: .semibold, design: .default)
}

private enum DesignColor {
    static let primary = Color(red: 0.0, green: 0.4, blue: 0.8)
    static let canvasParchment = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let body = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let muted = Color(red: 0.48, green: 0.48, blue: 0.48)
    static let hairline = Color(red: 0.88, green: 0.88, blue: 0.88)
}

private extension Text {
    func bodyText() -> some View {
        self
            .font(DesignTypography.body)
            .tracking(-0.2)
            .lineSpacing(3)
            .foregroundStyle(DesignColor.body)
    }
}
