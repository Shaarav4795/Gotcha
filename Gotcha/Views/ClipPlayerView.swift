import Combine
import SwiftUI

struct ClipPlayerView: View {
    let clip: Clip
    var onDelete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ClipStore
    @EnvironmentObject private var mic: MicrophoneMonitor

    @State private var isPlaying = false
    @State private var playhead: Double = 0
    @State private var waveformPeaks: [Float]?

    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    private var liveClip: Clip {
        store.clip(id: clip.id) ?? clip
    }

    var body: some View {
        VStack(spacing: 0) {
            videoFrame(liveClip)
                .aspectRatio(liveClip.editor.aspect.ratio, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            controls
                .padding(.horizontal, 16)
                .padding(.top, 16)

            info
                .padding(.top, 16)
                .padding(.bottom, 16)
        }
        .background(Theme.paper)
        .navigationTitle("Clip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ClipEditorView(clip: liveClip)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .onReceive(timer) { _ in advancePlayhead() }
        .onAppear {
            mic.setPlaybackVolume(liveClip.editor.volume)
            loadWaveform()
            clampPlayhead()
        }
        .onDisappear {
            mic.stopPlayback()
            isPlaying = false
        }
        .onChange(of: liveClip.trimStart) { _, _ in clampPlayhead() }
        .onChange(of: liveClip.trimEnd) { _, _ in clampPlayhead() }
        .onChange(of: liveClip.editor.volume) { _, newValue in
            mic.setPlaybackVolume(newValue)
        }
    }

    private func clampPlayhead() {
        if playhead > trimmedDuration { playhead = trimmedDuration }
    }

    private func loadWaveform() {
        guard let url = liveClip.audioURL else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let peaks = WaveformAnalyzer.peaks(for: url, bars: 400)
            DispatchQueue.main.async { waveformPeaks = peaks }
        }
    }

    private func videoFrame(_ clip: Clip) -> some View {
        ZStack {
            ClipPreview(
                caption: clip.title,
                editor: clip.editor,
                subtitles: clip.subtitles,
                activeSubtitle: currentSubtitleText,
                imageData: clip.imageData,
                waveform: waveformPeaks,
                trimStart: clip.trimStart,
                trimEnd: clip.trimEnd,
                playheadFraction: playheadFraction
            )
            .equatable()

            Button { togglePlay() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(Circle().fill(.black.opacity(0.45)))
            }
            .buttonStyle(.plain)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var currentSubtitleText: String? {
        let fileTime = liveClip.trimStart * liveClip.duration + playhead
        return liveClip.subtitles.activeText(at: fileTime)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface).frame(height: 4)
                    Capsule()
                        .fill(Theme.ink)
                        .frame(width: max(geo.size.width * progress, 0), height: 4)
                }
                .frame(height: 4)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            seek(to: g.location.x / geo.size.width)
                        }
                )
            }
            .frame(height: 4)

            HStack {
                Text(playhead.mmss)
                Spacer()
                Text(trimmedDuration.mmss)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Theme.muted)
        }
    }

    private var trimmedDuration: TimeInterval {
        liveClip.duration * (liveClip.trimEnd - liveClip.trimStart)
    }

    private var playheadFraction: Double {
        guard trimmedDuration > 0 else { return 0 }
        return min(max(playhead / trimmedDuration, 0), 1)
    }

    private var progress: Double {
        trimmedDuration > 0 ? playhead / trimmedDuration : 0
    }

    private var info: some View {
        Text("Captured \(liveClip.capturedAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.footnote)
            .foregroundStyle(Theme.muted)
    }

    private func togglePlay() {
        if isPlaying {
            mic.pausePlayback()
            isPlaying = false
        } else {
            if let url = liveClip.audioURL {
                if playhead >= trimmedDuration { playhead = 0 }
                mic.playClip(url: url,
                             from: liveClip.trimStart * liveClip.duration + playhead,
                             to: liveClip.trimEnd * liveClip.duration,
                             volume: liveClip.editor.volume)
            } else if playhead >= trimmedDuration {
                playhead = 0
            }
            isPlaying = true
        }
    }

    private func advancePlayhead() {
        guard isPlaying else { return }

        if let fileTime = mic.currentPlaybackTime() {
            let relative = fileTime - liveClip.trimStart * liveClip.duration
            playhead = min(max(relative, 0), trimmedDuration)
        } else {
            playhead += 1.0 / 30.0
        }

        if playhead >= trimmedDuration {
            if liveClip.editor.loop {
                playhead = 0
                if let url = liveClip.audioURL {
                    mic.playClip(url: url,
                                 from: liveClip.trimStart * liveClip.duration,
                                 to: liveClip.trimEnd * liveClip.duration,
                                 volume: liveClip.editor.volume)
                }
            } else {
                playhead = trimmedDuration
                mic.stopPlayback()
                isPlaying = false
            }
        }
    }

    private func seek(to fraction: Double) {
        let clamped = min(max(fraction, 0), 1)
        playhead = clamped * trimmedDuration
        if let url = liveClip.audioURL {
            mic.seekPlayback(url: url,
                             to: liveClip.trimStart * liveClip.duration + playhead,
                             end: liveClip.trimEnd * liveClip.duration)
        }
    }
}

#Preview {
    NavigationStack {
        ClipPlayerView(clip: Clip(title: "Sample", duration: 120, capturedAt: Date(), hasImage: false, subtitles: []))
            .environmentObject(ClipStore())
            .environmentObject(MicrophoneMonitor())
    }
}
