import AVFoundation
import Combine

enum CaptureError: LocalizedError {
    case notRecording
    case noBuffer
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .notRecording:
            return "Recording isn't active. Grant Gotcha microphone access in Settings → Gotcha → Microphone, then try again."
        case .noBuffer:
            return "There's no audio buffered yet. Wait a moment and try again."
        case .writeFailed:
            return "The capture couldn't be saved. Try again."
        }
    }
}

final class MicrophoneMonitor: ObservableObject {
    static let shared = MicrophoneMonitor()

    @Published var levels: [Float] = Array(repeating: 0, count: 4)
    @Published var isRunning = false
    @Published var totalActiveSeconds: TimeInterval = 0

    private let engine = AVAudioEngine()

    private var ring: [Float] = []
    private var ringIndex = 0
    private var ringCapacity = 0
    private var sampleRate: Double = 48_000
    private var bufferSeconds: TimeInterval = 120

    private var latestLevel: Float = 0
    private var smoothedLevel: Float = 0

    private var accumulatedSeconds: TimeInterval = 0
    private var runStartedAt: Date?
    private var bufferedSeconds: TimeInterval = 0

    private let lock = NSLock()
    private var displayTimer: AnyCancellable?
    private var interruptionObserver: NSObjectProtocol?
    private var tapInstalled = false

    func start(bufferSeconds: TimeInterval) {
        self.bufferSeconds = bufferSeconds

        if isRunning {
            let wanted = Int(bufferSeconds * sampleRate)
            if wanted != ringCapacity {
                stopEngine()
                startEngine()
            }
            return
        }

        requestAuthorization { [weak self] granted in
            guard granted else { return }
            DispatchQueue.main.async { self?.startEngine() }
        }
    }

    func stop() {
        displayTimer?.cancel()
        displayTimer = nil

        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }

        if let runStartedAt {
            accumulatedSeconds += Date().timeIntervalSince(runStartedAt)
            self.runStartedAt = nil
        }

        stopEngine()

        isRunning = false
        smoothedLevel = 0
        levels = Array(repeating: 0, count: levels.count)
        totalActiveSeconds = accumulatedSeconds
    }

    func bufferedDuration() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        guard ringCapacity > 0 else { return 0 }
        return min(bufferedSeconds, bufferSeconds)
    }

    func capture() throws -> URL {
        guard isRunning, ringCapacity > 0 else { throw CaptureError.notRecording }

        let targetRate = 16_000
        let bufferedAudioSeconds = min(bufferedSeconds, bufferSeconds)
        let usableInputSamples = min(ringCapacity, max(Int(bufferedAudioSeconds * sampleRate), 0))
        guard usableInputSamples > 0 else { throw CaptureError.noBuffer }

        let outputCount = max(Int((Double(usableInputSamples) / sampleRate) * Double(targetRate)), 1)
        guard outputCount > 0 else { throw CaptureError.noBuffer }

        var floats = [Float](repeating: 0, count: outputCount)
        lock.lock()
        let ratio = sampleRate / Double(targetRate)
        let startSample = (ringIndex - usableInputSamples + ringCapacity) % ringCapacity
        for j in 0..<outputCount {
            let srcPos = Double(j) * ratio
            let i = min(Int(srcPos), usableInputSamples - 1)
            let frac = Float(srcPos - Double(Int(srcPos)))
            let i0 = (startSample + i) % ringCapacity
            let i1 = (startSample + min(i + 1, usableInputSamples - 1)) % ringCapacity
            let s0 = ring[i0]
            let s1 = ring[i1]
            floats[j] = s0 + (s1 - s0) * frac
        }
        lock.unlock()

        var pcm = [Int16](repeating: 0, count: outputCount)
        for i in 0..<outputCount {
            let v = min(max(floats[i], -1), 1)
            pcm[i] = Int16(v * 32_767)
        }

        let manager = FileManager.default
        guard let documents = manager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CaptureError.writeFailed
        }
        let directory = documents.appendingPathComponent("Captures", isDirectory: true)
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw CaptureError.writeFailed
        }
        let url = directory.appendingPathComponent(UUID().uuidString + ".wav")

        guard let wav = Self.wavData(pcm: pcm, sampleRate: targetRate) else {
            throw CaptureError.writeFailed
        }
        do {
            try wav.write(to: url)
            return url
        } catch {
            throw CaptureError.writeFailed
        }
    }

    private static func wavData(pcm: [Int16], sampleRate: Int) -> Data? {
        let dataSize = pcm.count * 2
        let byteRate = sampleRate * 2

        func le16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8)] }
        func le32(_ v: UInt32) -> [UInt8] {
            [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8(v >> 24)]
        }

        var data = Data(capacity: 44 + dataSize)
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(contentsOf: le32(UInt32(36 + dataSize)))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.append(contentsOf: le32(16))
        data.append(contentsOf: le16(1))
        data.append(contentsOf: le16(1))
        data.append(contentsOf: le32(UInt32(sampleRate)))
        data.append(contentsOf: le32(UInt32(byteRate)))
        data.append(contentsOf: le16(2))
        data.append(contentsOf: le16(16))
        data.append(contentsOf: Array("data".utf8))
        data.append(contentsOf: le32(UInt32(dataSize)))

        pcm.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private func requestAuthorization(completion: @escaping (Bool) -> Void) {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            AVAudioApplication.requestRecordPermission { granted in
                completion(granted)
            }
        @unknown default:
            completion(false)
        }
    }

    private func stopEngine(clearRing: Bool = true) {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if engine.isRunning {
            engine.stop()
        }
        if clearRing {
            lock.lock()
            ring = []
            ringIndex = 0
            ringCapacity = 0
            bufferedSeconds = 0
            lock.unlock()
        }
    }

    private func startEngine() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            return
        }

        #if !targetEnvironment(simulator)
        guard let inputs = session.availableInputs, !inputs.isEmpty else { return }
        #endif

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else { return }

        sampleRate = format.sampleRate
        let capacity = max(Int(bufferSeconds * sampleRate), 1)

        lock.lock()
        ring = Array(repeating: 0, count: capacity)
        ringIndex = 0
        ringCapacity = capacity
        lock.unlock()

        guard !tapInstalled else { return }
        let installed = SafeInstallTap(engine, input, format) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        guard installed else { return }
        tapInstalled = true

        engine.prepare()
        do {
            try engine.start()
        } catch {
            stopEngine()
            return
        }

        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }

        isRunning = true
        runStartedAt = Date()
        startDisplayTimer()
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

        switch type {
        case .began:
            stopEngine(clearRing: false)
            isRunning = false
        case .ended:
            let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            if options.contains(.shouldResume) {
                startEngine()
            }
        @unknown default:
            break
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        let frames = Int(buffer.frameLength)
        guard frames > 0, let channel0 = buffer.floatChannelData?[0] else { return }
        let channel1 = buffer.format.channelCount > 1 ? buffer.floatChannelData?[1] : nil

        var sum: Float = 0

        lock.lock()
        guard ringCapacity > 0 else {
            lock.unlock()
            return
        }
        for i in 0..<frames {
            let sample = channel1.map { (channel0[i] + $0[i]) * 0.5 } ?? channel0[i]
            sum += sample * sample
            ring[ringIndex] = sample
            ringIndex = (ringIndex + 1) % ringCapacity
        }
        bufferedSeconds += Double(frames) / buffer.format.sampleRate
        lock.unlock()

        let rms = sqrt(sum / Float(frames))

        let db = 20 * log10(rms + 1e-8)
        let normalized = Float((Double(db) + 55.0) / 50.0)
        latestLevel = min(max(normalized, 0), 1)
    }

    private func startDisplayTimer() {
        displayTimer = Timer.publish(every: 1.0 / 20.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateLevel()
            }
    }

    private func updateLevel() {
        let factor: Float = latestLevel > smoothedLevel ? 0.6 : 0.15
        smoothedLevel += (latestLevel - smoothedLevel) * factor

        var new = levels
        new.removeFirst()
        new.append(smoothedLevel)
        levels = new

        if let runStartedAt {
            totalActiveSeconds = accumulatedSeconds + Date().timeIntervalSince(runStartedAt)
        }
    }
}
