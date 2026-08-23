import Combine
import PhotosUI
import SwiftUI

struct ClipEditorView: View {
    let clip: Clip

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ClipStore
    @EnvironmentObject private var mic: MicrophoneMonitor
    @State private var isPlaying = false
    @State private var playhead: Double = 0
    @State private var selectedTool: EditTool?
    @State private var loop: Bool

    @State private var caption: String
    @State private var captionSize: Double
    @State private var captionPosition: CGPoint
    @State private var captionWeight: CaptionWeight
    @State private var captionAlign: TextAlign
    @State private var captionCase: TextCaseOption

    @State private var subtitlesOn: Bool
    @State private var subtitleSize: Double
    @State private var subtitlePosition: CGPoint

    @State private var aspect: Aspect
    @State private var waveformStyle: WaveformStyle
    @State private var waveformPosition: CGPoint
    @State private var waveformSensitivity: Double
    @State private var volume: Double

    @State private var imageData: Data?

    @State private var trimStart: Double
    @State private var trimEnd: Double
    @State private var draftTrimStart: Double
    @State private var draftTrimEnd: Double

    @State private var waveformPeaks: [Float]?
    @State private var scrubberPeaks: [Float]?

    @State private var pickedItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showCameraUnavailable = false

    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    init(clip: Clip) {
        self.clip = clip
        let e = clip.editor
        _caption = State(initialValue: clip.title)
        _trimStart = State(initialValue: clip.trimStart)
        _trimEnd = State(initialValue: clip.trimEnd)
        _draftTrimStart = State(initialValue: clip.trimStart)
        _draftTrimEnd = State(initialValue: clip.trimEnd)
        _imageData = State(initialValue: clip.imageData)
        _loop = State(initialValue: e.loop)
        _captionSize = State(initialValue: e.captionSize)
        _captionPosition = State(initialValue: e.captionPosition)
        _captionWeight = State(initialValue: e.captionWeight)
        _captionAlign = State(initialValue: e.captionAlign)
        _captionCase = State(initialValue: e.captionCase)
        _subtitlesOn = State(initialValue: e.subtitlesOn)
        _subtitleSize = State(initialValue: e.subtitleSize)
        _subtitlePosition = State(initialValue: e.subtitlePosition)
        _aspect = State(initialValue: e.aspect)
        _waveformStyle = State(initialValue: e.waveformStyle)
        _waveformPosition = State(initialValue: e.waveformPosition)
        _waveformSensitivity = State(initialValue: e.waveformSensitivity)
        _volume = State(initialValue: e.volume)
    }

    var body: some View {
        VStack(spacing: 0) {
            preview
            controlDeck
        }
        .background(Theme.paper)
        .navigationTitle("Edit Clip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { saveAndDismiss() } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .onReceive(timer) { _ in advancePlayhead() }
        .onAppear {
            mic.setPlaybackVolume(volume)
            loadWaveform()
        }
        .onDisappear {
            mic.stopPlayback()
            isPlaying = false
        }
        .onChange(of: volume) { _, newValue in
            mic.setPlaybackVolume(newValue)
        }
        .onChange(of: selectedTool) { oldValue, newValue in
            if oldValue == .trim {
                commitTrim()
            } else if newValue == .trim {
                draftTrimStart = trimStart
                draftTrimEnd = trimEnd
            }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    attachImage(data)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in
                attachImage(data)
            }
        }
        .alert("Camera unavailable", isPresented: $showCameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The camera isn't available here (it requires a real device). Use Photos instead.")
        }
        .animation(.snappy(duration: 0.22), value: selectedTool)
    }

    private var trimmedDuration: Double {
        (trimEnd - trimStart) * clip.duration
    }

    private var playheadFraction: Double {
        guard trimmedDuration > 0 else { return 0 }
        return min(max(playhead / trimmedDuration, 0), 1)
    }

    private func togglePlay() {
        if isPlaying {
            mic.pausePlayback()
            isPlaying = false
        } else {
            if let url = clip.audioURL {
                if playhead >= trimmedDuration { playhead = 0 }
                mic.playClip(url: url,
                             from: trimStart * clip.duration + playhead,
                             to: trimEnd * clip.duration,
                             volume: volume)
            } else if playhead >= trimmedDuration {
                playhead = 0
            }
            isPlaying = true
        }
    }

    private func advancePlayhead() {
        guard isPlaying else { return }

        if let fileTime = mic.currentPlaybackTime() {
            let relative = fileTime - trimStart * clip.duration
            playhead = min(max(relative, 0), trimmedDuration)
        } else {
            playhead += 1.0 / 30.0
        }

        if playhead >= trimmedDuration {
            if loop {
                playhead = 0
                if let url = clip.audioURL {
                    mic.playClip(url: url,
                                 from: trimStart * clip.duration,
                                 to: trimEnd * clip.duration,
                                 volume: volume)
                }
            } else {
                playhead = trimmedDuration
                mic.stopPlayback()
                isPlaying = false
            }
        }
    }

    private func seek(to fraction: Double) {
        let clamped = min(max(fraction, trimStart), trimEnd)
        let span = max(trimEnd - trimStart, 0.001)
        playhead = ((clamped - trimStart) / span) * trimmedDuration
        if let url = clip.audioURL {
            mic.seekPlayback(url: url,
                             to: trimStart * clip.duration + playhead,
                             end: trimEnd * clip.duration)
        }
    }

    private func commitTrim() {
        trimStart = draftTrimStart
        trimEnd = draftTrimEnd
        if playhead > trimmedDuration { playhead = trimmedDuration }
    }

    private var currentSettings: EditorSettings {
        EditorSettings(
            captionSize: captionSize,
            captionPosition: captionPosition,
            captionWeight: captionWeight,
            captionAlign: captionAlign,
            captionCase: captionCase,
            subtitlesOn: subtitlesOn,
            subtitleSize: subtitleSize,
            subtitlePosition: subtitlePosition,
            aspect: aspect,
            waveformStyle: waveformStyle,
            waveformPosition: waveformPosition,
            waveformSensitivity: waveformSensitivity,
            volume: volume,
            loop: loop
        )
    }

    private func saveAndDismiss() {
        if selectedTool == .trim { commitTrim() }

        var updated = clip
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { updated.title = trimmed }
        updated.trimStart = trimStart
        updated.trimEnd = trimEnd
        updated.imageData = imageData
        updated.hasImage = imageData != nil
        updated.editor = currentSettings
        store.update(updated)
        dismiss()
    }

    private func loadWaveform() {
        guard let url = clip.audioURL else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let previewPeaks = WaveformAnalyzer.peaks(for: url, bars: 400)
            let timelinePeaks = WaveformAnalyzer.peaks(for: url, bars: 90)
            DispatchQueue.main.async {
                waveformPeaks = previewPeaks
                scrubberPeaks = timelinePeaks
            }
        }
    }

    private func attachImage(_ data: Data) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = UIImage(data: data),
                  let normalized = ImageProcessor.normalizedJPEG(from: image) else { return }
            DispatchQueue.main.async {
                imageData = normalized
            }
        }
    }

    private var preview: some View {
        GeometryReader { outer in
            let baseWidth: CGFloat = 360
            let baseHeight: CGFloat = baseWidth / aspect.ratio
            let scale = min(outer.size.width / baseWidth, outer.size.height / baseHeight)

            ClipPreview(
                caption: caption,
                editor: currentSettings,
                imageData: imageData,
                waveform: waveformPeaks,
                trimStart: trimStart,
                trimEnd: trimEnd,
                playheadFraction: playheadFraction
            )
            .equatable()
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(width: baseWidth, height: baseHeight)
            .scaleEffect(scale)
            .frame(width: outer.size.width, height: outer.size.height)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var controlDeck: some View {
        VStack(spacing: 0) {
            transport

            if let tool = selectedTool {
                Divider().overlay(Theme.hairline)
                panel(for: tool)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            toolRail
        }
        .background(Theme.elevated)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }

    private var transport: some View {
        HStack(spacing: 14) {
            Button { togglePlay() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.paper)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Theme.ink))
            }
            .buttonStyle(.plain)

            Text(playhead.mmss)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 38, alignment: .leading)

            WaveformScrubber(
                playheadFraction: playheadFraction,
                isTrimming: selectedTool == .trim,
                waveform: scrubberPeaks,
                minGap: trimMinGap,
                sensitivity: waveformSensitivity,
                trimStart: $draftTrimStart,
                trimEnd: $draftTrimEnd,
                onSeek: { seek(to: $0) }
            )
            .frame(height: 42)

            Text(trimmedDuration.mmss)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 38, alignment: .trailing)

            Button { loop.toggle() } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(loop ? Theme.paper : Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(loop ? Theme.ink : .clear))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(loop ? "Loop on" : "Loop off")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func panel(for tool: EditTool) -> some View {
        AdaptivePanel(maxHeight: 240) {
            panelContent(for: tool)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
    }

    @ViewBuilder
    private func panelContent(for tool: EditTool) -> some View {
        switch tool {
        case .caption:
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "textformat")
                        .foregroundStyle(Theme.muted)
                    TextField("Add a caption", text: $caption)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))

                LabeledSection(title: "Size") {
                    Slider(value: $captionSize, in: 12...36)
                        .tint(Theme.ink)
                }

                LabeledSection(title: "Weight") {
                    Picker("Weight", selection: $captionWeight) {
                        ForEach(CaptionWeight.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .tint(Theme.ink)
                }

                LabeledSection(title: "Case") {
                    Picker("Case", selection: $captionCase) {
                        ForEach(TextCaseOption.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .tint(Theme.ink)
                }
            }

        case .image:
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            showCamera = true
                        } else {
                            showCameraUnavailable = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                            Text("Camera")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Photos")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                if let imageData, let thumb = ImageProcessor.croppedImage(for: imageData, ratio: aspect.ratio) {
                    HStack(spacing: 12) {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("Image attached")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.ink)

                        Spacer()

                        Button(role: .destructive) {
                            withAnimation(.snappy(duration: 0.2)) { self.imageData = nil }
                        } label: {
                            Text("Remove")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                }
            }

        case .trim:
            HStack(spacing: 10) {
                nudgeControl(title: "Start", value: $draftTrimStart,
                             lower: 0, upper: draftTrimEnd - trimMinGap)
                nudgeControl(title: "End", value: $draftTrimEnd,
                             lower: draftTrimStart + trimMinGap, upper: 1)

                VStack(alignment: .trailing, spacing: 1) {
                    Text("Kept")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                    Text(trimmedDurationText)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 54)
            }

        case .aspect:
            LabeledSection(title: "Format") {
                Picker("Format", selection: $aspect) {
                    ForEach(Aspect.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .tint(Theme.ink)
            }

        case .waveform:
            VStack(alignment: .leading, spacing: 14) {
                LabeledSection(title: "Style") {
                    Picker("Style", selection: $waveformStyle) {
                        ForEach(WaveformStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .tint(Theme.ink)
                }

                LabeledSection(title: "Sensitivity") {
                    VStack(spacing: 6) {
                        Slider(value: $waveformSensitivity, in: 30...500, step: 10)
                            .tint(Theme.ink)
                        HStack {
                            Text("Boosts the gap between loud and quiet audio")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                            Spacer()
                            Text("\(Int(waveformSensitivity.rounded()))%")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
            }

        case .volume:
            VStack(alignment: .leading, spacing: 12) {
                LabeledSection(title: "Volume") {
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        Slider(value: $volume, in: 0.5...5.0)
                            .tint(Theme.ink)
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }

                HStack {
                    Text("Boost above 100% to amplify quieter audio")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text("\(Int((volume * 100).rounded()))%")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    private var trimmedDurationText: String {
        let start = selectedTool == .trim ? draftTrimStart : trimStart
        let end = selectedTool == .trim ? draftTrimEnd : trimEnd
        let secs = (end - start) * clip.duration
        return secs.mmss
    }

    private var trimMinGap: Double { 0.5 / max(clip.duration, 1) }

    private func nudgeControl(title: String, value: Binding<Double>, lower: Double, upper: Double) -> some View {
        let step = 0.5 / max(clip.duration, 1)
        return HStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 30, alignment: .leading)

            Button {
                value.wrappedValue = min(max(value.wrappedValue - step, lower), upper)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 26, height: 26)
                    .background(Circle().stroke(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Text((value.wrappedValue * clip.duration).mmss)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 34)

            Button {
                value.wrappedValue = min(max(value.wrappedValue + step, lower), upper)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 26, height: 26)
                    .background(Circle().stroke(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var toolRail: some View {
        HStack(spacing: 6) {
            ForEach(EditTool.allCases) { tool in
                let active = selectedTool == tool

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedTool = active ? nil : tool
                    }
                } label: {
                    Image(systemName: tool.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(active ? Theme.paper : Theme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(active ? Theme.ink : .clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tool.title)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }
}

private enum EditTool: String, CaseIterable, Identifiable {
    case caption, image, trim, aspect, waveform, volume

    var id: String { rawValue }

    var title: String {
        switch self {
        case .caption: return "Caption"
        case .image: return "Image"
        case .trim: return "Trim"
        case .aspect: return "Format"
        case .waveform: return "Waveform"
        case .volume: return "Volume"
        }
    }

    var icon: String {
        switch self {
        case .caption: return "textformat"
        case .image: return "photo"
        case .trim: return "scissors"
        case .aspect: return "aspectratio"
        case .waveform: return "waveform"
        case .volume: return "speaker.wave.2"
        }
    }
}

private struct AdaptivePanel<Content: View>: View {
    let maxHeight: CGFloat
    let content: Content
    @State private var contentHeight: CGFloat = 0

    init(maxHeight: CGFloat, @ViewBuilder content: () -> Content) {
        self.maxHeight = maxHeight
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newValue in
                    contentHeight = newValue
                }
        }
        .frame(height: min(contentHeight, maxHeight))
        .animation(.snappy(duration: 0.22), value: contentHeight)
    }
}

private struct LabeledSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.ink)
            content
        }
    }
}

private struct WaveformScrubber: View {
    let playheadFraction: Double
    let isTrimming: Bool
    var waveform: [Float]?
    var minGap: Double = 0.05
    var sensitivity: Double = 100
    @Binding var trimStart: Double
    @Binding var trimEnd: Double
    var onSeek: (Double) -> Void = { _ in }

    private enum DragMode {
        case start, end, shift
    }

    @State private var dragMode: DragMode?
    @State private var dragValue: Double = 0
    @State private var grabOffsetX: CGFloat = 0
    @State private var grabOffset: Double = 0
    @State private var shiftSpan: Double = 0

    private let handleWidth: CGFloat = 14

    private var liveStart: Double {
        switch dragMode {
        case .start, .shift: return dragValue
        default: return trimStart
        }
    }

    private var liveEnd: Double {
        switch dragMode {
        case .end: return dragValue
        case .shift: return min(dragValue + (trimEnd - trimStart), 1)
        default: return trimEnd
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h: CGFloat = 44

            ZStack(alignment: .top) {
                ZStack(alignment: .leading) {
                    Canvas { ctx, size in
                        let peaks = waveform ?? WaveformAnalyzer.fakePeaks(count: max(Int(size.width / 4), 4))
                        let (winStart, winEnd) = isTrimming ? (0.0, 1.0) : (trimStart, trimEnd)
                        let sampled = Self.sample(peaks, start: winStart, end: winEnd,
                                                  bars: max(Int(size.width / 4), 4))
                        let transformed = waveform == nil ? sampled : WaveformAnalyzer.emphasized(sampled, sensitivity: sensitivity)
                        let maxPeak = max(transformed.max() ?? 1, 0.0001)

                        for i in 0..<sampled.count {
                            let x = size.width * CGFloat(i) / CGFloat(max(sampled.count - 1, 1))
                            let barWidth = max(size.width / CGFloat(sampled.count) - 1.5, 1)
                            let peak = transformed[i] / maxPeak
                            let bh = max(3, CGFloat(peak) * size.height)
                            let rect = CGRect(x: x, y: (size.height - bh) / 2, width: barWidth, height: bh)
                            ctx.fill(Path(roundedRect: rect, cornerRadius: 1),
                                     with: .color(Theme.muted.opacity(0.4)))
                        }

                        if isTrimming {
                            let sx = xPos(liveStart, width: size.width)
                            let ex = xPos(liveEnd, width: size.width)
                            ctx.fill(Path(CGRect(x: 0, y: 0, width: sx, height: size.height)),
                                     with: .color(Theme.paper.opacity(0.6)))
                            ctx.fill(Path(CGRect(x: ex, y: 0, width: size.width - ex, height: size.height)),
                                     with: .color(Theme.paper.opacity(0.6)))
                            let sel = CGRect(x: sx, y: 0, width: max(ex - sx, 1), height: size.height)
                            ctx.fill(Path(sel), with: .color(Theme.ink.opacity(0.10)))
                            ctx.stroke(Path(sel), with: .color(Theme.ink), lineWidth: 1.5)
                        } else {
                            let px = min(max(playheadFraction * size.width - 1, 0), size.width - 2)
                            ctx.fill(Path(CGRect(x: px, y: 0, width: 2, height: size.height)),
                                     with: .color(Theme.ink))
                        }
                    }
                    .frame(width: w, height: h)

                    if !isTrimming {
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { g in
                                        let local = Double(min(max(g.location.x / w, 0), 1))
                                        let full = trimStart + local * (trimEnd - trimStart)
                                        onSeek(full)
                                    }
                            )
                    }

                    if isTrimming {
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { g in
                                        if dragMode == nil {
                                            beginDrag(at: g.location, trackWidth: w)
                                        } else {
                                            updateDrag(at: g.location, trackWidth: w)
                                        }
                                    }
                                    .onEnded { _ in endDrag() }
                            )
                    }

                    if isTrimming {
                        let startX = min(max(xPos(liveStart, width: w) - handleWidth / 2, 0), max(w - handleWidth, 0))
                        let endX = min(max(xPos(liveEnd, width: w) - handleWidth / 2, 0), max(w - handleWidth, 0))
                        handle(.start, trackWidth: w)
                            .offset(x: startX)
                        handle(.end, trackWidth: w)
                            .offset(x: endX)
                    }
                }
                .clipped()
            }
        }
        .onChange(of: isTrimming) { _, trimming in
            if trimming { dragMode = nil }
        }
    }

    private func xPos(_ fraction: Double, width: CGFloat) -> CGFloat {
        CGFloat(min(max(fraction, 0), 1)) * width
    }

    private static func sample(_ peaks: [Float], start: Double, end: Double, bars: Int) -> [Float] {
        guard bars > 0, !peaks.isEmpty else { return [] }
        var result = [Float](repeating: 0, count: bars)
        let span = max(end - start, 0.0001)
        for i in 0..<bars {
            let f = start + span * Double(i) / Double(max(bars - 1, 1))
            let idx = min(max(Int(f * Double(peaks.count - 1)), 0), peaks.count - 1)
            result[i] = peaks[idx]
        }
        return result
    }

    private func handle(_ kind: DragMode, trackWidth: CGFloat) -> some View {
        Capsule()
            .fill(Theme.ink)
            .frame(width: handleWidth, height: 44)
            .overlay(
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule().fill(Theme.paper).frame(width: 2, height: 8)
                    }
                }
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if dragMode != kind {
                            dragMode = kind
                            dragValue = kind == .start ? trimStart : trimEnd
                            grabOffsetX = g.location.x - xPos(dragValue, width: trackWidth)
                        }
                        updateDrag(at: g.location, trackWidth: trackWidth)
                    }
                    .onEnded { _ in endDrag() }
            )
    }

    private func beginDrag(at location: CGPoint, trackWidth: CGFloat) {
        let fraction = Double(min(max(location.x / trackWidth, 0), 1))
        if fraction < liveStart {
            dragMode = .start
            dragValue = trimStart
            grabOffsetX = location.x - xPos(trimStart, width: trackWidth)
        } else if fraction > liveEnd {
            dragMode = .end
            dragValue = trimEnd
            grabOffsetX = location.x - xPos(trimEnd, width: trackWidth)
        } else {
            dragMode = .shift
            dragValue = trimStart
            grabOffset = fraction - liveStart
            shiftSpan = trimEnd - trimStart
        }
    }

    private func updateDrag(at location: CGPoint, trackWidth: CGFloat) {
        guard let dragMode else { return }
        switch dragMode {
        case .start:
            let local = Double(min(max((location.x - grabOffsetX) / trackWidth, 0), 1))
            dragValue = min(max(local, 0), trimEnd - minGap)
            trimStart = dragValue
        case .end:
            let local = Double(min(max((location.x - grabOffsetX) / trackWidth, 0), 1))
            dragValue = min(max(local, trimStart + minGap), 1)
            trimEnd = dragValue
        case .shift:
            let fraction = Double(min(max(location.x / trackWidth, 0), 1))
            dragValue = min(max(fraction - grabOffset, 0), 1 - shiftSpan)
            trimStart = dragValue
            trimEnd = dragValue + shiftSpan
        }
    }

    private func endDrag() {
        guard let dragMode else { return }
        switch dragMode {
        case .start:
            trimStart = min(max(dragValue, 0), trimEnd - minGap)
        case .end:
            trimEnd = min(max(dragValue, trimStart + minGap), 1)
        case .shift:
            let newStart = min(max(dragValue, 0), 1 - shiftSpan)
            trimStart = newStart
            trimEnd = newStart + shiftSpan
        }
        self.dragMode = nil
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.85) {
                parent.onImage(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        ClipEditorView(clip: Clip(title: "Sample", duration: 120, capturedAt: Date(), hasImage: false))
            .environmentObject(ClipStore())
            .environmentObject(MicrophoneMonitor())
    }
}
