import Combine
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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("setting.bufferMinutes") private var bufferMinutes = 2
    @AppStorage("setting.dynamicIsland") private var liveActivity = false
    private let heartbeatTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            TabView(selection: $selection) {
                LibraryView(path: $clipsPath)
                    .tabItem { Label("Clips", systemImage: "square.grid.2x2") }
                    .tag(Tab.clips)

                CaptureView(
                    mic: mic,
                    onCustomizeClip: { openInGallery($0) },
                    onSeeAll: { selection = .clips },
                    onOpenClip: { openInGallery($0) },
                    onEditClip: { openEditorInGallery($0) }
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
        .fullScreenCover(isPresented: showOnboarding) {
            OnboardingView()
        }
        .sheet(item: $islandCapturedClip) { clip in
            CaptureSuccessView(clip: clip, onCustomize: { openEditorInGallery($0) })
        }
        .onAppear {
            updateMic()
            syncDynamicIsland()
            checkShortcutRequests()
        }
        .onOpenURL { url in
            guard url.scheme == "gotcha", url.host == "capture" else { return }
            captureFromDynamicIsland()
        }
        .onChange(of: hasCompletedOnboarding) { _, _ in
            updateMic()
            syncDynamicIsland()
        }
        .onChange(of: bufferMinutes) { _, _ in
            mic.stop()
            updateMic()
            syncDynamicIsland()
        }
        .onChange(of: liveActivity) { _, _ in
            syncDynamicIsland()
        }
        .onChange(of: mic.isRunning) { _, _ in
            syncDynamicIsland()
        }
        .onReceive(heartbeatTimer) { _ in
            writeHeartbeat()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                checkShortcutRequests()
            }
        }
    }

    private func updateMic() {
        if hasCompletedOnboarding {
            mic.start(bufferSeconds: Double(bufferMinutes * 60))
        } else {
            mic.stop()
        }
    }

    private func writeHeartbeat() {
        guard mic.isRunning else { return }
        if let shared = UserDefaults(suiteName: AppGroup.id) {
            shared.set(Date().timeIntervalSince1970, forKey: AppGroup.heartbeatKey)
        }
    }

    private func syncDynamicIsland() {
        if liveActivity && hasCompletedOnboarding && mic.isRunning {
            DynamicIslandManager.shared.start(bufferMinutes: bufferMinutes)
        } else if !liveActivity || !hasCompletedOnboarding {
            DynamicIslandManager.shared.stop()
        }
    }

    private func captureFromDynamicIsland() {
        guard liveActivity else { return }
        runIslandCapture()
    }

    private func checkShortcutRequests() {
        guard let shared = UserDefaults(suiteName: AppGroup.id) else { return }

        if shared.bool(forKey: AppGroup.openCaptureKey) {
            shared.removeObject(forKey: AppGroup.openCaptureKey)
            selection = .capture
        }
        if shared.bool(forKey: AppGroup.openLibraryKey) {
            shared.removeObject(forKey: AppGroup.openLibraryKey)
            selection = .clips
        }
        if shared.bool(forKey: AppGroup.openSettingsKey) {
            shared.removeObject(forKey: AppGroup.openSettingsKey)
            selection = .settings
        }

        if liveActivity {
            Task {
                for _ in 0..<20 {
                    let capKey = AppGroup.captureRequestKey
                    let requestedAt = shared.double(forKey: capKey)
                    if requestedAt > 0 {
                        shared.removeObject(forKey: capKey)
                        if Date().timeIntervalSince1970 - requestedAt < 30 {
                            runIslandCapture()
                        }
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(150))
                }
            }
        }
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

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )
    }
}

#Preview {
    ContentView()
}
