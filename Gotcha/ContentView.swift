import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable {
        case clips, capture, settings
    }

    @State private var selection: Tab = .capture
    @State private var clipsPath = NavigationPath()
    @StateObject private var store = ClipStore()
    @StateObject private var mic = MicrophoneMonitor.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("setting.bufferMinutes") private var bufferMinutes = 2

    var body: some View {
        ZStack {
            TabView(selection: $selection) {
                LibraryView(path: $clipsPath)
                    .tabItem { Label("Clips", systemImage: "square.grid.2x2") }
                    .tag(Tab.clips)

                CaptureView(
                    mic: mic,
                    onCustomizeClip: { clip in openEditorInGallery(clip) },
                    onSeeAll: { selection = .clips },
                    onOpenClip: { clip in openInGallery(clip) },
                    onEditClip: { clip in openEditorInGallery(clip) }
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

            if scenePhase != .active {
                DoNotCloseOverlay()
            }
        }
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
        var path = NavigationPath()
        path.append(clip)
        clipsPath = path
        selection = .clips
    }

    private func openEditorInGallery(_ clip: Clip) {
        var path = NavigationPath()
        path.append(ClipRoute.edit(clip))
        clipsPath = path
        selection = .clips
    }
}

#Preview {
    ContentView()
}
