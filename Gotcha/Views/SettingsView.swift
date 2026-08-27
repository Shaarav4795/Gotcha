import SwiftUI

struct SettingsView: View {
    @AppStorage("setting.bufferMinutes") private var bufferMinutes = 2
    @AppStorage("setting.dynamicIsland") private var liveActivity = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    bufferSection
                        .padding(.bottom, 28)

                    featuresSection
                        .padding(.bottom, 28)

                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.paper)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .tint(Theme.ink)
        }
    }

    private var bufferSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Buffer")

            VStack(alignment: .leading, spacing: 16) {
                Text("Recording duration")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)

                Picker("Recording duration", selection: $bufferMinutes) {
                    Text("1 min").tag(1)
                    Text("2 min").tag(2)
                    Text("3 min").tag(3)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text("How much audio Gotcha keeps in its rolling recording. Uncaptured audio is discarded automatically.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.elevated))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Features")

            VStack(spacing: 0) {
                toggleRow("Live Activity", systemImage: "livephoto", isOn: $liveActivity)
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.elevated))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
        }
    }

    private func toggleRow(_ title: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(Theme.ink)
        }
        .tint(Theme.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("About")

            VStack(spacing: 0) {
                LabeledContent {
                    Text("1.0")
                        .foregroundStyle(Theme.muted)
                } label: {
                    Label("Version", systemImage: "number")
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.elevated))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))

            Text("Made with love by Shaarav4795")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .kerning(0.5)
            .foregroundStyle(Theme.muted)
    }
}

#Preview {
    SettingsView()
}
