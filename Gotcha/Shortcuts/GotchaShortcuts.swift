import AppIntents
import Foundation

struct GotchaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureClipIntent(),
            phrases: [
                "Capture with \(.applicationName)",
                "Save the last clip with \(.applicationName)",
                "Gotcha capture with \(.applicationName)"
            ],
            shortTitle: "Capture last clip",
            systemImageName: "record.circle"
        )
        AppShortcut(
            intent: OpenCaptureScreenIntent(),
            phrases: [
                "Open capture with \(.applicationName)",
                "Go to capture with \(.applicationName)"
            ],
            shortTitle: "Open capture",
            systemImageName: "viewfinder"
        )
        AppShortcut(
            intent: OpenLibraryIntent(),
            phrases: [
                "Show clips with \(.applicationName)",
                "Open my clips with \(.applicationName)"
            ],
            shortTitle: "Open clips",
            systemImageName: "square.grid.2x2"
        )
        AppShortcut(
            intent: OpenSettingsIntent(),
            phrases: [
                "Open Gotcha settings with \(.applicationName)",
                "Gotcha settings with \(.applicationName)"
            ],
            shortTitle: "Open settings",
            systemImageName: "gearshape"
        )
    }
}

struct CaptureClipIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Last Recording"
    static let description = IntentDescription("Saves the most recent audio buffer as a Gotcha clip.")

    static var openAppWhenRun: Bool = true

    nonisolated func perform() async throws -> some IntentResult {
        let fresh = CaptureClipIntent.isRecordingActive()
        if !fresh {
            throw GotchaShortcutError.appNotRecording
        }
        if let shared = UserDefaults(suiteName: AppGroup.id) {
            shared.set(Date().timeIntervalSince1970, forKey: AppGroup.captureRequestKey)
        }
        return .result()
    }

    private nonisolated static func isRecordingActive() -> Bool {
        guard let shared = UserDefaults(suiteName: AppGroup.id) else { return false }
        let heartbeat = shared.double(forKey: AppGroup.heartbeatKey)
        guard heartbeat > 0 else { return false }
        return Date().timeIntervalSince1970 - heartbeat < 8
    }
}

struct OpenCaptureScreenIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Capture Screen"
    static let description = IntentDescription("Opens the Gotcha capture screen.")

    static var openAppWhenRun: Bool = true

    nonisolated func perform() async throws -> some IntentResult {
        if let shared = UserDefaults(suiteName: AppGroup.id) {
            shared.set(true, forKey: AppGroup.openCaptureKey)
        }
        return .result()
    }
}

struct OpenLibraryIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Clips"
    static let description = IntentDescription("Opens the Gotcha clips library.")

    static var openAppWhenRun: Bool = true

    nonisolated func perform() async throws -> some IntentResult {
        if let shared = UserDefaults(suiteName: AppGroup.id) {
            shared.set(true, forKey: AppGroup.openLibraryKey)
        }
        return .result()
    }
}

struct OpenSettingsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Settings"
    static let description = IntentDescription("Opens the Gotcha settings screen.")

    static var openAppWhenRun: Bool = true

    nonisolated func perform() async throws -> some IntentResult {
        if let shared = UserDefaults(suiteName: AppGroup.id) {
            shared.set(true, forKey: AppGroup.openSettingsKey)
        }
        return .result()
    }
}

enum GotchaShortcutError: LocalizedError {
    case appNotRecording

    var errorDescription: String? {
        "Gotcha isn't recording. Open Gotcha and let it capture audio, then try again."
    }
}
