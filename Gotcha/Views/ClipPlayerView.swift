import AVFoundation
import Combine
import SwiftUI

struct ClipPlayerView: View {
    let clip: Clip
    var onDelete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ClipStore

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playhead: Double = 0

    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.surface)
                    .frame(height: 280)

                VStack(spacing: 14) {
                    Image(systemName: "waveform")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.ink)

                    Text(clip.title)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            controls
                .padding(.horizontal, 16)

            info
                .padding(.bottom, 16)
        }
        .background(Theme.paper)
        .navigationTitle("Clip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
        .onDisappear { stopPlayback() }
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
                Text(clip.durationText)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Theme.muted)

            Button {
                togglePlay()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.paper)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Theme.ink))
            }
            .buttonStyle(.plain)
        }
    }

    private var progress: Double {
        clip.duration > 0 ? playhead / clip.duration : 0
    }

    private var info: some View {
        Text("Captured \(clip.capturedAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.footnote)
            .foregroundStyle(Theme.muted)
    }

    private func togglePlay() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard let url = clip.audioURL else { return }
        do {
            if player == nil {
                player = try AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
            }
            player?.play()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    private func pausePlayback() {
        player?.pause()
        isPlaying = false
    }

    private func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    private func advancePlayhead() {
        guard isPlaying, let player else { return }
        playhead = player.currentTime
        if !player.isPlaying {
            isPlaying = false
            playhead = 0
            player.currentTime = 0
        }
    }

    private func seek(to fraction: Double) {
        let clamped = min(max(fraction, 0), 1)
        playhead = clamped * clip.duration
        player?.currentTime = playhead
    }
}

#Preview {
    NavigationStack {
        ClipPlayerView(clip: Clip(title: "Sample", duration: 120, capturedAt: Date()))
            .environmentObject(ClipStore())
    }
}
