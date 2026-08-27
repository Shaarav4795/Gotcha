import ActivityKit

struct GotchaLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var bufferMinutes: Int
        var lastCaptureAt: Date?
    }

    var bufferMinutes: Int
}
