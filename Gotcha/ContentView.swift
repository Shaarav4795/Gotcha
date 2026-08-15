import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(Theme.ink)

            Text("Gotcha")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.ink)

            Text("Instant replay for real life")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
    }
}

#Preview {
    ContentView()
}
