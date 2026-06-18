import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FolderPeek")
                .font(.title)
            Text("Use Finder Quick Look to preview folders, zip archives, and tar archives before opening them.")
                .foregroundStyle(.secondary)
            Text("The menu bar item provides quick status, help, about, and quit actions. FolderPeek does not index folders in the background or extract archives.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 180)
    }
}
