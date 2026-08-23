import Foundation
import Combine

final class ClipStore: ObservableObject {
    let launchedAt: Date = Date()

    @Published var clips: [Clip] {
        didSet { persist() }
    }

    init() {
        if let data = try? Data(contentsOf: Self.storeURL),
           let saved = try? JSONDecoder().decode([Clip].self, from: data) {
            clips = saved
        } else {
            clips = []
        }
    }

    private static var storeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("clips.json")
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(clips) else { return }
        do {
            try data.write(to: Self.storeURL, options: .atomic)
        } catch {}
    }

    var recent: [Clip] {
        Array(clips.sorted { $0.capturedAt > $1.capturedAt }.prefix(3))
    }

    var totalRecordedDuration: TimeInterval {
        clips.reduce(0) { $0 + $1.duration }
    }

    func delete(_ clip: Clip) {
        clips.removeAll { $0.id == clip.id }
        if let url = clip.audioURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func add(_ clip: Clip) {
        clips.insert(clip, at: 0)
    }

    func update(_ clip: Clip) {
        guard let index = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        clips[index] = clip
    }

    func clip(id: UUID) -> Clip? {
        clips.first { $0.id == id }
    }
}
