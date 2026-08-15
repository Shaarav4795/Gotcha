import SwiftUI

struct CaptureView: View {
    var onSeeAll: () -> Void = {}
    var onOpenClip: (Clip) -> Void = { _ in }
    var onEditClip: (Clip) -> Void = { _ in }

    @EnvironmentObject private var store: ClipStore
    @AppStorage("setting.bufferMinutes") private var bufferMinutes = 2

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 28)
                        .padding(.bottom, 36)

                    captureButton
                        .padding(.bottom, 40)

                    stats
                        .padding(.bottom, 28)

                    recentCaptures
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gotcha")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.ink)

            Text("Instant replay for real life")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var captureButton: some View {
        VStack(spacing: 20) {
            Button {
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.ink)
                        .frame(width: 150, height: 150)
                        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)

                    LiveWaveform(levels: [0.35, 0.62, 0.44, 0.58])
                }
            }
            .buttonStyle(PressableButtonStyle())

            Text("Tap to Capture")
                .font(.headline)
                .foregroundStyle(Theme.ink)
        }
    }

    private var stats: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Recording since",
                icon: "dot.radiowaves.left.and.right",
                value: recordingSinceText
            )
            StatCard(
                title: "Hours recorded",
                icon: "clock",
                value: hoursRecordedText
            )
        }
    }

    private var recordingSinceText: String {
        store.launchedAt.formatted(date: .omitted, time: .shortened)
    }

    private var hoursRecordedText: String {
        let total = Int(store.totalRecordedDuration.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private var recentCaptures: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Captures")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button {
                    onSeeAll()
                } label: {
                    Text("See all")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
            }

            if store.recent.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No captures yet")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Tap Capture when something happens to save the last \(bufferMinutes) minute\(bufferMinutes == 1 ? "" : "s").")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.elevated))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
            } else {
                VStack(spacing: 10) {
                    ForEach(store.recent) { clip in
                        RecentCaptureRow(
                            clip: clip,
                            onOpen: { onOpenClip(clip) },
                            onEdit: { onEditClip(clip) },
                            onDelete: { withAnimation { store.delete(clip) } }
                        )
                    }
                }
            }
        }
    }

}

private struct RecentCaptureRow: View {
    let clip: Clip
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                thumbnail

                VStack(alignment: .leading, spacing: 2) {
                    Text(clip.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)

                    Text(clip.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onOpen() }

            Spacer()

            Button { onEdit() } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surface))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surface))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.elevated))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(Theme.surface)
            Image(systemName: "waveform")
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
        }
        .frame(width: 40, height: 40)
    }
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    CaptureView()
        .environmentObject(ClipStore())
}
