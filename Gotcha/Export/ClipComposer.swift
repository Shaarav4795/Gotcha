import SwiftUI
import AVFoundation
import Photos

@MainActor
final class ClipComposer {
    struct ExportError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }


    private func outputSize(for aspect: Aspect) -> CGSize {
        let base: CGFloat = 1080
        func even(_ value: CGFloat) -> CGFloat {
            let rounded = value.rounded(.down)
            return rounded.truncatingRemainder(dividingBy: 2) == 0 ? rounded : rounded - 1
        }
        switch aspect {
        case .portrait:  return CGSize(width: even(base * 9 / 16), height: base)
        case .square:    return CGSize(width: base, height: base)
        case .landscape: return CGSize(width: base, height: even(base * 9 / 16))
        }
    }


    func exportVideo(clip: Clip, progress: @escaping (Double) -> Void) async throws -> URL {
        let size = outputSize(for: clip.editor.aspect)
        let fps = 30
        let trimmedDuration = clip.duration * (clip.trimEnd - clip.trimStart)
        let totalFrames = max(Int(trimmedDuration * Double(fps)), 1)

        let videoURL = try await renderVideo(
            clip: clip,
            size: size,
            fps: fps,
            totalFrames: totalFrames,
            progress: { p in progress(p * 0.85) }
        )
        defer { removeTempFile(at: videoURL) }

        return try await finalizeVideo(
            videoURL: videoURL,
            clip: clip,
            progress: { p in progress(0.85 + p * 0.15) }
        )
    }


    func exportAudio(clip: Clip, progress: @escaping (Double) -> Void) async throws -> URL {
        guard let audioURL = clip.audioURL else {
            throw ExportError(message: "No audio available")
        }
        let outputURL = try tempURL(ext: "m4a")
        let composition = AVMutableComposition()

        let audioAsset = AVURLAsset(url: audioURL)
        let audioTracks: [AVAssetTrack]
        do { audioTracks = try await audioAsset.loadTracks(withMediaType: .audio) }
        catch { throw ExportError(message: "Couldn't read audio track: \(Self.describe(error))") }
        guard let audioTrack = audioTracks.first,
              let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportError(message: "No audio track found")
        }

        let start = clip.trimStart * clip.duration
        let duration = max((clip.trimEnd - clip.trimStart) * clip.duration, 0.001)
        do {
            try compAudio.insertTimeRange(
                CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                            duration: CMTime(seconds: duration, preferredTimescale: 600)),
                of: audioTrack,
                at: .zero
            )
        } catch {
            throw ExportError(message: "Couldn't trim audio: \(Self.describe(error))")
        }

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw ExportError(message: "Cannot create export session")
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a
        exporter.exportAsynchronously(completionHandler: {})

        while exporter.status == .waiting || exporter.status == .exporting {
            progress(Double(exporter.progress))
            try await Task.sleep(for: .milliseconds(50))
        }
        if exporter.status == .failed {
            throw ExportError(message: "Audio export failed: \(Self.describe(exporter.error))")
        }
        return outputURL
    }


    private func renderVideo(clip: Clip,
                             size: CGSize,
                             fps: Int,
                             totalFrames: Int,
                             progress: @escaping (Double) -> Void) async throws -> URL {
        let outputURL = try tempURL(ext: "mp4")
        let writer = try AVAssetWriter(url: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 12_000_000,
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false

        let pbAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pbAttrs
        )

        guard writer.canAdd(videoInput) else { throw ExportError(message: "Cannot add video input") }
        writer.add(videoInput)

        guard writer.startWriting() else {
            throw ExportError(message: "Failed to start writing: \(Self.describe(writer.error))")
        }
        writer.startSession(atSourceTime: .zero)

        let exportWaveform = await loadWaveform(clip: clip)

        let frameDuration = CMTime(value: 1, timescale: Int32(fps))
        for i in 0..<totalFrames {
            try await waitUntilReady(videoInput, writer: writer)
            let fraction = Double(i) / Double(max(totalFrames - 1, 1))
            let image = renderFrame(
                clip: clip,
                playheadFraction: fraction,
                size: size,
                waveform: exportWaveform
            )
            guard let buffer = Self.pixelBuffer(from: image, size: size, pool: adaptor.pixelBufferPool) else {
                throw ExportError(message: "Failed to create pixel buffer")
            }
            guard adaptor.append(buffer, withPresentationTime: CMTimeMultiply(frameDuration, multiplier: Int32(i))) else {
                throw ExportError(message: writer.error?.localizedDescription ?? "Failed to append frame")
            }
            progress(Double(i) / Double(totalFrames))
            if i % 3 == 0 { await Task.yield() }
        }
        videoInput.markAsFinished()

        await writer.finishWriting()
        if writer.status == .failed {
            throw ExportError(message: "Video render failed: \(Self.describe(writer.error))")
        }
        return outputURL
    }


    private func finalizeVideo(videoURL: URL,
                               clip: Clip,
                               progress: @escaping (Double) -> Void) async throws -> URL {
        let outputURL = try tempURL(ext: "mp4")
        let composition = AVMutableComposition()

        let videoAsset = AVURLAsset(url: videoURL)
        let videoTracks: [AVAssetTrack]
        do { videoTracks = try await videoAsset.loadTracks(withMediaType: .video) }
        catch { throw ExportError(message: "Couldn't read rendered video: \(Self.describe(error))") }
        guard let videoTrack = videoTracks.first,
              let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportError(message: "Rendered video has no track")
        }
        let videoDuration: CMTime
        do { videoDuration = try await videoAsset.load(.duration) }
        catch { throw ExportError(message: "Couldn't read rendered video duration: \(Self.describe(error))") }
        do {
            try compVideo.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: videoTrack, at: .zero)
        } catch {
            throw ExportError(message: "Couldn't add video track: \(Self.describe(error))")
        }

        if let audioURL = clip.audioURL {
            do {
                let audioAsset = AVURLAsset(url: audioURL)
                let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
                if let audioTrack = audioTracks.first,
                   let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    let start = clip.trimStart * clip.duration
                    let duration = max((clip.trimEnd - clip.trimStart) * clip.duration, 0.001)
                    try compAudio.insertTimeRange(
                        CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                    duration: CMTime(seconds: duration, preferredTimescale: 600)),
                        of: audioTrack,
                        at: .zero
                    )
                }
            } catch {
                print("[ClipComposer] audio track skipped: \(Self.describe(error))")
            }
        }

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError(message: "Cannot create export session")
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4

        exporter.exportAsynchronously(completionHandler: {})

        while exporter.status == .waiting || exporter.status == .exporting {
            progress(Double(exporter.progress))
            try await Task.sleep(for: .milliseconds(50))
        }
        if exporter.status == .failed {
            let detail = Self.describe(exporter.error)
            print("[ClipComposer] final export failed: \(detail)")
            throw ExportError(message: "Muxing failed: \(detail)")
        }

        let resultAsset = AVURLAsset(url: outputURL)
        let resultDuration: CMTime
        let resultTracks: [AVAssetTrack]
        do {
            resultDuration = try await resultAsset.load(.duration)
            resultTracks = try await resultAsset.loadTracks(withMediaType: .video)
        } catch {
            throw ExportError(message: "Muxed video couldn't be read: \(Self.describe(error))")
        }
        guard resultDuration.seconds > 0, !resultTracks.isEmpty else {
            throw ExportError(message: "Muxed video is invalid")
        }
        return outputURL
    }


    private func renderFrame(clip: Clip,
                             playheadFraction: Double,
                             size: CGSize,
                             waveform: [Float]?) -> UIImage {
        let trimmedDuration = clip.duration * (clip.trimEnd - clip.trimStart)
        let fileTime = clip.trimStart * clip.duration + playheadFraction * trimmedDuration
        let activeSubtitle = clip.subtitles.activeText(at: fileTime)

        let preview = ClipPreview(
            caption: clip.title,
            editor: clip.editor,
            subtitles: clip.subtitles,
            activeSubtitle: activeSubtitle,
            imageData: clip.imageData,
            waveform: waveform,
            trimStart: clip.trimStart,
            trimEnd: clip.trimEnd,
            playheadFraction: playheadFraction
        )
        .equatable()
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: preview)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = 1.0

        return renderer.uiImage ?? UIImage()
    }


    private func loadWaveform(clip: Clip) async -> [Float]? {
        guard let url = clip.audioURL else { return nil }
        return await Task.detached(priority: .userInitiated) {
            WaveformAnalyzer.peaks(for: url, bars: 400)
        }.value
    }

    private func tempURL(ext: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent(UUID().uuidString + "." + ext)
    }

    private static func pixelBuffer(from image: UIImage,
                                    size: CGSize,
                                    pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        if let pool {
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer) == kCVReturnSuccess,
                  let buffer else { return nil }
        } else {
            let attrs: [String: Any] = [
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ]
            guard CVPixelBufferCreate(kCFAllocatorDefault,
                                      Int(size.width), Int(size.height),
                                      kCVPixelFormatType_32BGRA,
                                      attrs as CFDictionary,
                                      &buffer) == kCVReturnSuccess,
                  let buffer else { return nil }
        }

        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        let rect = CGRect(origin: .zero, size: size)
        context.clear(rect)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        image.draw(in: rect)
        UIGraphicsPopContext()

        return buffer
    }

    private func waitUntilReady(_ input: AVAssetWriterInput,
                                writer: AVAssetWriter) async throws {
        var stalled: TimeInterval = 0
        while !input.isReadyForMoreMediaData {
            if writer.status == .failed {
                throw ExportError(message: writer.error?.localizedDescription ?? "Export failed")
            }
            try await Task.sleep(for: .milliseconds(10))
            stalled += 0.01
            if stalled > 30 {
                throw ExportError(message: "Export stalled: the encoder stopped accepting data (writer status \(writer.status.rawValue), \(writer.error?.localizedDescription ?? "no error")). Try a shorter clip.")
            }
        }
    }

    func saveToPhotos(url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            throw ExportError(
                message: "Photos access was denied. Allow it in Settings → Gotcha → Photos, then export again."
            )
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
        } catch {
            throw ExportError(message: "Couldn't save to Photos: \(Self.describe(error))")
        }
    }


    private static func describe(_ error: Error?) -> String {
        guard let error else { return "unknown error" }
        var detail = "\(error.localizedDescription) (\((error as NSError).domain) \((error as NSError).code))"
        var underlying = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError
        var depth = 0
        while let u = underlying, depth < 3 {
            detail += " → \(u.localizedDescription) (\(u.domain) \(u.code))"
            underlying = u.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }
        return detail
    }


    nonisolated func removeTempFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
