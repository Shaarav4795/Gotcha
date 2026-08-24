import SwiftUI

struct SubtitleEditorView: View {
    @Binding var subtitles: [Clip.SubtitleLine]

    var body: some View {
        List {
            ForEach($subtitles) { $line in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(line.start.mmss)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                        .frame(width: 44, alignment: .leading)

                    TextField("Subtitle", text: $line.text, axis: .vertical)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in
                var updated = subtitles
                updated.remove(atOffsets: offsets)
                subtitles = updated
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle("Subtitles")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.ink)
    }
}

#Preview {
    NavigationStack {
        SubtitleEditorView(subtitles: .constant([]))
    }
}
