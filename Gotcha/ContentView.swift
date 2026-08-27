import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable {
        case clips, capture, settings
    }

    @State private var selection: Tab = .capture
    @State private var clipsPath = NavigationPath()
    @State private var islandCapturedClip: Clip?
    @StateObject private var store = ClipStore()
    @StateObject private var mic = MicrophoneMonitor.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("setting.bufferMinutes") private var bufferMinutes = 2
    @AppStorage("setting.dynamicIsland") private var liveActivity = false

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
        .onAppear {
            startBuffering()
            syncDynamicIsland()
        }
        .onChange(of: bufferMinutes) { _, _ in
            mic.stop()
            startBuffering()
            syncDynamicIsland()
        }
        .onChange(of: liveActivity) { _, _ in
            syncDynamicIsland()
        }
        .onChange(of: mic.isRunning) { _, _ in
            syncDynamicIsland()
        }
        .sheet(item: $islandCapturedClip) { clip in
            CaptureSuccessView(clip: clip, onCustomize: { openEditorInGallery($0) })
        }
        .onOpenURL { url in
            guard url.scheme == "gotcha", url.host == "capture" else { return }
            captureFromDynamicIsland()
        }
    }

    private func startBuffering() {
        mic.start(bufferSeconds: Double(bufferMinutes * 60))
    }

    private func syncDynamicIsland() {
        if liveActivity && mic.isRunning {
            DynamicIslandManager.shared.start(bufferMinutes: bufferMinutes)
        } else if !liveActivity {
            DynamicIslandManager.shared.stop()
        }
    }

    private func captureFromDynamicIsland() {
        guard liveActivity else { return }
        runIslandCapture()
    }

    private func runIslandCapture() {
        Task {
            for _ in 0..<40 {
                if mic.isRunning { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard mic.isRunning else { return }
            do {
                let url = try mic.capture()
                let clip = Clip.recording(
                    title: "Gotcha \(store.clips.count + 1)",
                    duration: max(mic.bufferedDuration(), 0.1),
                    audioURL: url
                )
                store.add(clip)
                DynamicIslandManager.shared.captureSucceeded(bufferMinutes: bufferMinutes)
                islandCapturedClip = clip
            } catch {
                return
            }
        }
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
