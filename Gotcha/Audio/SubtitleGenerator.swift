import AVFoundation
import Foundation
import Speech

enum SubtitleGenerator {
    enum GenerationError: LocalizedError {
        case unavailable
        case denied
        case empty
        case localeNotSupported

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Speech recognition isn't available on this device."
            case .denied:
                return "Speech recognition permission was denied. Enable it in Settings → Gotcha → Speech Recognition."
            case .empty:
                return "No speech was recognised in this clip."
            case .localeNotSupported:
                return "Transcription isn't available for this language on this device."
            }
        }
    }

    struct Token {
        var time: TimeInterval
        var duration: TimeInterval
        var text: String
    }

    static func generate(from url: URL, completion: @escaping (Result<[Clip.SubtitleLine], Error>) -> Void) {
        if #available(iOS 26, *) {
            generateWithSpeechAnalyzer(from: url) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    generateWithLegacyRecognizer(from: url, completion: completion)
                }
            }
        } else {
            generateWithLegacyRecognizer(from: url, completion: completion)
        }
    }

    @available(iOS 26, *)
    private static func generateWithSpeechAnalyzer(from url: URL,
                                                   completion: @escaping (Result<[Clip.SubtitleLine], Error>) -> Void) {
        Task {
            do {
                let lines = try await transcribeWithSpeechTranscriber(url: url)
                if lines.isEmpty {
                    completion(.failure(GenerationError.empty))
                } else {
                    completion(.success(lines))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    @available(iOS 26, *)
    private static func transcribeWithSpeechTranscriber(url: URL) async throws -> [Clip.SubtitleLine] {
        let locale = Locale(identifier: "en_US")

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange]
        )

        let supported = await SpeechTranscriber.supportedLocales
        let supportedIDs = supported.map { $0.identifier(.bcp47) }
        guard supportedIDs.contains(locale.identifier(.bcp47)) else {
            throw GenerationError.localeNotSupported
        }

        let installed = await SpeechTranscriber.installedLocales
        let installedIDs = installed.map { $0.identifier(.bcp47) }
        if !installedIDs.contains(locale.identifier(.bcp47)) {
            if let installer = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await installer.downloadAndInstall()
            }
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        var tokens: [Token] = []

        let collector = Task {
            for try await result in transcriber.results where result.isFinal {
                for run in result.text.runs {
                    let word = String(result.text[run.range].characters)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !word.isEmpty else { continue }
                    if let range = run.audioTimeRange {
                        tokens.append(Token(time: CMTimeGetSeconds(range.start),
                                            duration: CMTimeGetSeconds(range.duration),
                                            text: word))
                    }
                }
            }
        }

        let file = try AVAudioFile(forReading: url)
        if let lastSample = try await analyzer.analyzeSequence(from: file) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        }

        try await collector.value

        return merge(tokens: tokens)
    }

    private static func generateWithLegacyRecognizer(from url: URL,
                                                     completion: @escaping (Result<[Clip.SubtitleLine], Error>) -> Void) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            completion(.failure(GenerationError.unavailable))
            return
        }

        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                completion(.failure(GenerationError.denied))
                return
            }

            attemptLegacy(recognizer: recognizer,
                          url: url,
                          requiresOnDevice: false,
                          completion: completion)
        }
    }

    private static func attemptLegacy(recognizer: SFSpeechRecognizer,
                                      url: URL,
                                      requiresOnDevice: Bool,
                                      completion: @escaping (Result<[Clip.SubtitleLine], Error>) -> Void) {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = requiresOnDevice

        var didFinish = false

        recognizer.recognitionTask(with: request) { result, error in
            guard !didFinish else { return }

            if let result, result.isFinal {
                didFinish = true
                let tokens: [Token] = result.bestTranscription.segments.map {
                    Token(time: $0.timestamp, duration: $0.duration, text: $0.substring)
                }
                let lines = merge(tokens: tokens)
                if lines.isEmpty {
                    if requiresOnDevice {
                        attemptLegacy(recognizer: recognizer, url: url, requiresOnDevice: false, completion: completion)
                    } else {
                        completion(.failure(GenerationError.empty))
                    }
                } else {
                    completion(.success(lines))
                }
            } else if let error {
                didFinish = true
                if requiresOnDevice {
                    attemptLegacy(recognizer: recognizer, url: url, requiresOnDevice: false, completion: completion)
                } else {
                    completion(.failure(error))
                }
            }
        }
    }

    private static func merge(tokens: [Token]) -> [Clip.SubtitleLine] {
        var lines: [Clip.SubtitleLine] = []
        var current = ""
        var currentStart: TimeInterval = 0
        var lastEnd: TimeInterval = 0

        for token in tokens {
            let word = token.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty else { continue }

            if current.isEmpty {
                currentStart = token.time
            }

            let candidate = current.isEmpty ? word : current + " " + word
            let pause = token.time - lastEnd
            let wordCount = candidate.split(separator: " ").count

            if (pause > 1.5 && !current.isEmpty) || wordCount >= 10 {
                lines.append(Clip.SubtitleLine(start: currentStart, text: current))
                current = word
                currentStart = token.time
            } else {
                current = candidate
            }
            lastEnd = token.time + token.duration
        }

        if !current.isEmpty {
            lines.append(Clip.SubtitleLine(start: currentStart, text: current))
        }
        return lines
    }
}
