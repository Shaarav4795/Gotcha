import SwiftUI

struct CaptureSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    let clip: Clip
    var onCustomize: (Clip) -> Void = { _ in }

    init(clip: Clip,
         onCustomize: @escaping (Clip) -> Void = { _ in }) {
        self.clip = clip
        self.onCustomize = onCustomize
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle().fill(Theme.ink).frame(width: 84, height: 84)
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Theme.paper)
                }

                Text("Gotcha!")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 20)

                Text("Saved the last \(clip.durationText)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        dismiss()
                        onCustomize(clip)
                    } label: {
                        Label("Customise", systemImage: "slider.horizontal.3")
                            .font(.headline)
                            .foregroundStyle(Theme.paper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ink))
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.paper)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }
}

#Preview {
    CaptureSuccessView(clip: Clip(title: "Sample", duration: 120, capturedAt: Date(), hasImage: false))
}
