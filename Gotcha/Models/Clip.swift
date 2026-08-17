import Foundation

struct Clip: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var duration: TimeInterval
    var capturedAt: Date

    var audioURL: URL?
    var editor: EditorSettings

    init(id: UUID = UUID(),
         title: String,
         duration: TimeInterval,
         capturedAt: Date,
         audioURL: URL? = nil,
         editor: EditorSettings = EditorSettings()) {
        self.id = id
        self.title = title
        self.duration = duration
        self.capturedAt = capturedAt
        self.audioURL = audioURL
        self.editor = editor
    }
}

extension Clip {
    static func recording(title: String, duration: TimeInterval, audioURL: URL) -> Clip {
        Clip(
            title: title,
            duration: duration,
            capturedAt: Date(),
            audioURL: audioURL
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
