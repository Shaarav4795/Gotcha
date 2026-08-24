import SwiftUI

enum ClipDragElement {
    case caption, subtitle, waveform
}

struct ClipPreview: View, Equatable {
    let caption: String
    let editor: EditorSettings
    let subtitles: [Clip.SubtitleLine]
    let activeSubtitle: String?
    let imageData: Data?

    var waveform: [Float]?

    var trimStart: Double = 0
    var trimEnd: Double = 1
    var playheadFraction: Double = 0

    var draggable: Bool = false
    var onPositionChanged: ((ClipDragElement, CGPoint) -> Void)?

    @State private var dragElement: ClipDragElement?
    @State private var dragStartFraction: CGPoint = .zero
    @State private var dragStartPosition: CGPoint = .zero

    private let background = Color(white: 0.07)

    static func == (lhs: ClipPreview, rhs: ClipPreview) -> Bool {
        lhs.caption == rhs.caption &&
        lhs.editor == rhs.editor &&
        lhs.subtitles == rhs.subtitles &&
        lhs.activeSubtitle == rhs.activeSubtitle &&
        lhs.imageData == rhs.imageData &&
        lhs.waveform == rhs.waveform &&
        lhs.trimStart == rhs.trimStart &&
        lhs.trimEnd == rhs.trimEnd &&
        lhs.playheadFraction == rhs.playheadFraction &&
        lhs.draggable == rhs.draggable
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background

                if let imageData, let cropped = ImageProcessor.croppedImage(for: imageData, ratio: editor.aspect.ratio) {
                    Image(uiImage: cropped)
                        .resizable()
                        .scaledToFill()
                        .overlay(Color.black.opacity(0.28))
                }

                let waveformHeight = min(140, geo.size.height * 0.4)
                waveformLayer(height: waveformHeight)
                    .frame(width: geo.size.width, height: waveformHeight)
                    .position(x: geo.size.width * editor.waveformPosition.x,
                              y: geo.size.height * editor.waveformPosition.y)

                if !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: min(editor.captionSize, geo.size.height * 0.22),
                                      weight: editor.captionWeight.weight))
                        .multilineTextAlignment(editor.captionAlign.alignment)
                        .textCase(editor.captionCase.textCase)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            if imageData != nil {
                                RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.4))
                            }
                        }
                        .position(x: geo.size.width * editor.captionPosition.x,
                                  y: geo.size.height * editor.captionPosition.y)
                }

                if let activeSubtitle {
                    Text(activeSubtitle)
                        .font(.system(size: min(editor.subtitleSize, geo.size.height * 0.1), weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.45))
                        }
                        .position(x: geo.size.width * editor.subtitlePosition.x,
                                  y: geo.size.height * editor.subtitlePosition.y)
                }

                if draggable {
                    dragOverlay(size: geo.size)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: activeSubtitle)
        }
        .clipped()
    }

    private func dragOverlay(size: CGSize) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let fraction = CGPoint(x: g.location.x / size.width,
                                               y: g.location.y / size.height)
                        if dragElement == nil {
                            dragElement = nearestElement(to: fraction)
                            dragStartFraction = fraction
                            dragStartPosition = position(of: dragElement!)
                        }
                        guard let element = dragElement else { return }
                        let delta = CGPoint(x: fraction.x - dragStartFraction.x,
                                            y: fraction.y - dragStartFraction.y)
                        let target = CGPoint(x: dragStartPosition.x + delta.x,
                                             y: dragStartPosition.y + delta.y)
                        onPositionChanged?(element, snapped(target))
                    }
                    .onEnded { _ in dragElement = nil }
            )
    }

    private func nearestElement(to fraction: CGPoint) -> ClipDragElement {
        let captionDist = hypot(fraction.x - editor.captionPosition.x,
                                fraction.y - editor.captionPosition.y)
        let subtitleDist = hypot(fraction.x - editor.subtitlePosition.x,
                                 fraction.y - editor.subtitlePosition.y)
        let waveformDist = abs(fraction.y - editor.waveformPosition.y)

        if waveformDist <= captionDist && waveformDist <= subtitleDist {
            return .waveform
        }
        return captionDist <= subtitleDist ? .caption : .subtitle
    }

    private func position(of element: ClipDragElement) -> CGPoint {
        switch element {
        case .caption: return editor.captionPosition
        case .subtitle: return editor.subtitlePosition
        case .waveform: return editor.waveformPosition
        }
    }

    private func snapped(_ point: CGPoint) -> CGPoint {
        let step = 1.0 / 6.0
        func snap(_ v: Double) -> Double {
            let s = (v / step).rounded() * step
            return min(max(s, step), 1 - step)
        }
        return CGPoint(x: snap(point.x), y: snap(point.y))
    }

    @ViewBuilder
    private func waveformLayer(height: CGFloat) -> some View {
        let live = liveWave(barCount: 80)
        let maxPeak = max(live.peaks.max() ?? 0.04, 0.04)

        if imageData == nil {
            switch editor.waveformStyle {
            case .bars:
                let bars = liveWave(barCount: 44)
                let scale: Float = 1.0 / maxPeak
                BarsWaveform(
                    peaks: bars.peaks.map { min($0 * scale, 1) },
                    playedFraction: bars.playedFraction,
                    tint: .white.opacity(0.16),
                    playedTint: .white.opacity(0.55),
                    maxHeight: height
                )
            case .line:
                let minPeak = live.peaks.min() ?? 0
                let span = max(maxPeak - minPeak, 0.0001)
                LineWaveform(
                    peaks: live.peaks.map { ($0 - minPeak) / span },
                    playedFraction: live.playedFraction,
                    tint: .white.opacity(0.20),
                    playedTint: .white.opacity(0.55),
                    height: height
                )
            }
        } else {
            let contentHeight = max(3, CGFloat(maxPeak) * height)

            Group {
                switch editor.waveformStyle {
                case .bars:
                    let bars = liveWave(barCount: 44)
                    let scale: Float = 1.0 / maxPeak
                    BarsWaveform(
                        peaks: bars.peaks.map { min($0 * scale, 1) },
                        playedFraction: bars.playedFraction,
                        tint: .white.opacity(0.16),
                        playedTint: .white.opacity(0.55),
                        maxHeight: contentHeight
                    )
                case .line:
                    let minPeak = live.peaks.min() ?? 0
                    let span = max(maxPeak - minPeak, 0.0001)
                    LineWaveform(
                        peaks: live.peaks.map { ($0 - minPeak) / span },
                        playedFraction: live.playedFraction,
                        tint: .white.opacity(0.20),
                        playedTint: .white.opacity(0.55),
                        height: contentHeight
                    )
                }
            }
            .frame(height: contentHeight)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.30))
            }
        }
    }

    private func liveWave(barCount: Int) -> (peaks: [Float], playedFraction: Double) {
        let hasRealWaveform = waveform != nil
        let full = waveform ?? WaveformAnalyzer.fakePeaks(count: 400)
        let span = max(trimEnd - trimStart, 0.0001)
        let current = trimStart + min(max(playheadFraction, 0), 1) * span
        let window = min(0.05, span)
        let start = min(max(current - window / 2, trimStart), trimEnd - window)

        var result = [Float](repeating: 0, count: barCount)
        for i in 0..<barCount {
            let f = start + window * Double(i) / Double(max(barCount - 1, 1))
            let index = min(max(Int(f * Double(full.count)), 0), full.count - 1)
            result[i] = full[index]
        }
        if hasRealWaveform {
            result = WaveformAnalyzer.emphasized(result, sensitivity: editor.waveformSensitivity)
        }
        let played = min(max((current - start) / window, 0), 1)
        return (result, played)
    }
}

private struct BarsWaveform: View {
    let peaks: [Float]
    let playedFraction: Double
    let tint: Color
    let playedTint: Color
    let maxHeight: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 1.5) {
            ForEach(peaks.indices, id: \.self) { i in
                let h = max(3, CGFloat(peaks[i]) * maxHeight)
                let played = Double(i) < playedFraction * Double(peaks.count)
                Capsule()
                    .fill(played ? playedTint : tint)
                    .frame(width: 2, height: h)
            }
        }
        .frame(height: maxHeight)
    }
}

private struct LineWaveform: View {
    let peaks: [Float]
    let playedFraction: Double
    let tint: Color
    let playedTint: Color
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = max(peaks.count, 2)
            let splitX = w * CGFloat(min(max(playedFraction, 0), 1))

            Path { path in
                var started = false
                for i in 0..<count {
                    let x = w * CGFloat(i) / CGFloat(count - 1)
                    if x > splitX { break }
                    let y = h * (1 - CGFloat(peaks[i]))
                    if !started {
                        path.move(to: CGPoint(x: x, y: y))
                        started = true
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(playedTint, lineWidth: 2.5)

            Path { path in
                var started = false
                for i in 0..<count {
                    let x = w * CGFloat(i) / CGFloat(count - 1)
                    if x < splitX { continue }
                    let y = h * (1 - CGFloat(peaks[i]))
                    if !started {
                        path.move(to: CGPoint(x: x, y: y))
                        started = true
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(tint, lineWidth: 2.5)
        }
        .frame(height: height)
    }
}

#Preview {
    ClipPreview(
        caption: "Gotcha 1",
        editor: EditorSettings(),
        subtitles: [Clip.SubtitleLine(start: 0, text: "Sample subtitle.")],
        activeSubtitle: "Sample subtitle.",
        imageData: nil,
        waveform: nil
    )
    .aspectRatio(9 / 16, contentMode: .fit)
    .frame(width: 250)
    .padding()
}
