import Foundation

enum WaveformAnalyzer {
    private static var cache: [String: [Float]] = [:]
    private static let lock = NSLock()

    static func peaks(for url: URL?, bars: Int) -> [Float]? {
        guard let url else { return nil }

        let key = "\(url.absoluteString)#\(bars)"
        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let data = try? Data(contentsOf: url), data.count > 44 else { return nil }

        let sampleCount = (data.count - 44) / 2
        guard sampleCount >= bars else { return nil }
        let bucketSize = sampleCount / bars
        guard bucketSize > 0 else { return nil }

        var result = [Float](repeating: 0, count: bars)

        data.withUnsafeBytes { raw in
            guard let baseAddress = raw.baseAddress else { return }
            let samples = baseAddress.assumingMemoryBound(to: Int16.self)
            let offset = 22

            for bucket in 0..<bars {
                var peak: Int16 = 0
                let start = offset + bucket * bucketSize
                for i in 0..<bucketSize {
                    let v = samples[start + i]
                    let magnitude = v > 0 ? v : -v
                    if magnitude > peak { peak = magnitude }
                }
                result[bucket] = max(Float(peak) / 32767.0, 0.04)
            }
        }

        lock.lock()
        cache[key] = result
        lock.unlock()
        return result
    }

    static func emphasized(_ peaks: [Float], sensitivity: Double) -> [Float] {
        let gamma = Float(max(sensitivity / 100.0, 0.05))
        return peaks.map { pow(max($0, 0), gamma) }
    }

    static func fakePeaks(count: Int) -> [Float] {
        (0..<count).map { i in
            Float(0.08 + 0.92 * abs(sin(Double(i) * 0.8)))
        }
    }
}
