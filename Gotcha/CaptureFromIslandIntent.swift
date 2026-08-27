import AppIntents
import Foundation

enum AppGroup {
    static let id = "group.com.shaarav4795.Gotcha"
    static let captureRequestKey = "islandCaptureRequestedAt"
    static let openCaptureKey = "shortcutOpenCapture"
    static let openLibraryKey = "shortcutOpenLibrary"
    static let openSettingsKey = "shortcutOpenSettings"
    static let heartbeatKey = "micHeartbeat"
}

struct CaptureFromIslandIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Capture Last Recording"

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        if let shared = UserDefaults(suiteName: AppGroup.id) {
            shared.set(Date().timeIntervalSince1970, forKey: AppGroup.captureRequestKey)
        }
        return .result()
    }
}
