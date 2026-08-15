import SwiftUI

struct LiveWaveform: View {
    let levels: [Float]

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            ForEach(levels.indices, id: \.self) { i in
                Capsule()
                    .fill(Theme.paper)
                    .frame(width: 8, height: barHeight(levels[i]))
            }
        }
        .frame(height: 46)
    }

    private func barHeight(_ level: Float) -> CGFloat {
        6 + CGFloat(min(max(level, 0), 1)) * 40
    }
}

#Preview {
    ZStack {
        Theme.ink.ignoresSafeArea()
        LiveWaveform(levels: [0.1, 0.4, 0.8, 0.3])
    }
}
