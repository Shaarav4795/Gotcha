import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable {
        case clips, capture, settings
    }

    @State private var selection: Tab = .capture
    @StateObject private var store = ClipStore()

    var body: some View {
        TabView(selection: $selection) {
            LibraryView()
                .tabItem { Label("Clips", systemImage: "square.grid.2x2") }
                .tag(Tab.clips)

            CaptureView(
                onSeeAll: { selection = .clips },
                onOpenClip: { clip in openInGallery(clip) },
                onEditClip: { clip in openInGallery(clip) }
            )
                .tabItem { Label("Capture", systemImage: "record.circle") }
                .tag(Tab.capture)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(Theme.ink)
        .environmentObject(store)
    }

    private func openInGallery(_ clip: Clip) {
        selection = .clips
    }
}

#Preview {
    ContentView()
}
