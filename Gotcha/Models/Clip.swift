import Foundation

struct Clip: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var duration: TimeInterval
    var capturedAt: Date
    var hasImage: Bool

    var audioURL: URL?

    var imageData: Data?

    var trimStart: Double
    var trimEnd: Double

    var editor: EditorSettings

    init(id: UUID = UUID(),
         title: String,
         duration: TimeInterval,
         capturedAt: Date,
         hasImage: Bool,
         audioURL: URL? = nil,
         imageData: Data? = nil,
         trimStart: Double = 0,
         trimEnd: Double = 1,
         editor: EditorSettings = EditorSettings()) {
        self.id = id
        self.title = title
        self.duration = duration
        self.capturedAt = capturedAt
        self.hasImage = hasImage
        self.audioURL = audioURL
        self.imageData = imageData
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.editor = editor
    }
}

extension Clip {
    static func recording(title: String, duration: TimeInterval, audioURL: URL) -> Clip {
        Clip(
            title: title,
            duration: duration,
            capturedAt: Date(),
            hasImage: false,
            audioURL: audioURL,
            trimStart: 0,
            trimEnd: 1
        )
    }

    var durationText: String { duration.mmss }
}

extension TimeInterval {
    var mmss: String {
        let total = Int(rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
