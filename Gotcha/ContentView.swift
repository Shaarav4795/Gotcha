import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable {
        case clips, capture, settings
    }

    @State private var selection: Tab = .capture
    @StateObject private var store = ClipStore()
    @StateObject private var mic = MicrophoneMonitor.shared
    @AppStorage("setting.bufferMinutes") private var bufferMinutes = 2

    var body: some View {
        TabView(selection: $selection) {
            LibraryView()
                .tabItem { Label("Clips", systemImage: "square.grid.2x2") }
                .tag(Tab.clips)

            CaptureView(
                mic: mic,
                onCustomizeClip: { clip in openInGallery(clip) },
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
        .environmentObject(mic)
        .onAppear { startBuffering() }
        .onChange(of: bufferMinutes) { _, _ in
            mic.stop()
            startBuffering()
        }
    }

    private func startBuffering() {
        mic.start(bufferSeconds: Double(bufferMinutes * 60))
    }

    private func openInGallery(_ clip: Clip) {
        selection = .clips
    }
}

#Preview {
    ContentView()
}
