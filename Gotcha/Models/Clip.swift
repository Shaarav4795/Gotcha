import Foundation

struct Clip: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var duration: TimeInterval
    var capturedAt: Date
    var hasImage: Bool
    var subtitles: [SubtitleLine]

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
         subtitles: [SubtitleLine],
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
        self.subtitles = subtitles
        self.audioURL = audioURL
        self.imageData = imageData
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.editor = editor
    }

    struct SubtitleLine: Identifiable, Hashable, Codable {
        let id: UUID
        let start: TimeInterval
        var text: String

        init(id: UUID = UUID(), start: TimeInterval, text: String) {
            self.id = id
            self.start = start
            self.text = text
        }
    }
}

extension Clip {
    static func recording(title: String, duration: TimeInterval, audioURL: URL) -> Clip {
        Clip(
            title: title,
            duration: duration,
            capturedAt: Date(),
            hasImage: false,
            subtitles: [],
            audioURL: audioURL,
            trimStart: 0,
            trimEnd: 1
        )
    }

    var durationText: String { duration.mmss }
}

extension Array where Element == Clip.SubtitleLine {
    func activeText(at time: TimeInterval) -> String? {
        let sorted = sorted { $0.start < $1.start }
        for (index, line) in sorted.enumerated() {
            guard line.start <= time else { break }
            let nextStart = index + 1 < sorted.count ? sorted[index + 1].start : .infinity
            let readingTime = Swift.max(1.2, Double(line.text.split(separator: " ").count) / 2.8)
            let end = Swift.min(nextStart, line.start + readingTime)
            if time < end { return line.text }
        }
        return nil
    }
}

extension TimeInterval {
    var mmss: String {
        let total = Int(rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

