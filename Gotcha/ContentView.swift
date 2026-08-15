import SwiftUI

struct ContentView: View {
    @StateObject private var store = ClipStore()

    var body: some View {
        CaptureView()
            .tint(Theme.ink)
            .environmentObject(store)
    }
}

#Preview {
    ContentView()
}
