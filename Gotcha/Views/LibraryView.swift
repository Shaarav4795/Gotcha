import SwiftUI

enum ClipRoute: Hashable {
    case edit(Clip)
}

struct LibraryView: View {
    @EnvironmentObject private var store: ClipStore
    @AppStorage("setting.bufferMinutes") private var bufferMinutes = 2
    @Binding var path: NavigationPath

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.clips.isEmpty {
                    emptyState
                } else {
                    clipScroll
                }
            }
            .background(Theme.paper)
            .navigationTitle("Clips")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Clip.self) { clip in
                ClipPlayerView(clip: clip) { store.delete(clip) }
            }
            .navigationDestination(for: ClipRoute.self) { route in
                switch route {
                case .edit(let clip):
                    ClipEditorView(clip: clip)
                }
            }
            .tint(Theme.ink)
        }
    }

    private var clipScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                summary
                    .padding(.top, 4)
                    .padding(.bottom, 28)

                VStack(spacing: 10) {
                    ForEach(sortedClips) { clip in
                        NavigationLink(value: clip) {
                            ClipCard(clip: clip)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { store.delete(clip) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var sortedClips: [Clip] {
        store.clips.sorted { $0.capturedAt > $1.capturedAt }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Saved clips",
                icon: "square.grid.2x2",
                value: "\(store.clips.count)"
            )
            StatCard(
                title: "Total saved",
                icon: "clock",
                value: totalDurationText
            )
        }
    }

    private var totalDurationText: String {
        let total = Int(store.totalRecordedDuration.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m \(seconds)s"
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 44))
                .foregroundStyle(Theme.muted)

            Text("No clips yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)

            Text("Tap Capture when something happens to save the last \(bufferMinutes) minute\(bufferMinutes == 1 ? "" : "s").")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipCard: View {
    let clip: Clip

    var body: some View {
        HStack(spacing: 14) {
            poster

            VStack(alignment: .leading, spacing: 4) {
                Text(clip.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)

                Text(clip.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                Text(clip.durationText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.ink)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.elevated))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
    }

    private var poster: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.surface)

            Image(systemName: clip.hasImage ? "photo.fill" : "waveform")
                .font(.system(size: 20))
                .foregroundStyle(Theme.ink)
        }
        .frame(width: 46, height: 62)
    }
}

#Preview {
    LibraryView(path: .constant(NavigationPath()))
        .environmentObject(ClipStore())
}
