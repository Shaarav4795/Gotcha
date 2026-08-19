import SwiftUI

struct DoNotCloseOverlay: View {
    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.ink)

                Text("Do not close the app")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.ink)

                Text("Keep Gotcha open so you never miss a moment.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.muted)
            }
            .padding(32)
        }
    }
}

#Preview {
    DoNotCloseOverlay()
}
