import SwiftUI
import AVFoundation
import UIKit

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var page = 0
    @State private var micDenied = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                OnboardingPage(
                    icon: "waveform",
                    title: "Welcome to Gotcha",
                    message: "Gotcha keeps the last 2 minutes of audio in a rolling buffer. When something happens, tap Capture to save it."
                )
                .tag(0)

                OnboardingPage(
                    icon: "mic.fill",
                    title: "Microphone access",
                    message: "Gotcha needs to access your microphone to record audio."
                )
                .tag(1)

                finalPage
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            bottomButton
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .background(Theme.paper)
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var finalPage: some View {
        if micDenied {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "mic.slash")
                    .font(.system(size: 68, weight: .medium))
                    .foregroundStyle(Theme.ink)

                Text("Microphone access needed")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)

                Text("Gotcha needs your microphone to record audio. Please allow access in Settings, then come back to get started.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 36)

                Button {
                    recheckPermission()
                } label: {
                    Text("I've allowed it. Check again")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)
        } else {
            OnboardingPage(
                icon: "checkmark.circle",
                title: "All set!",
                message: "You're ready to get started!"
            )
        }
    }

    private var bottomButton: some View {
        Button {
            if micDenied {
                openSettings()
            } else if page == 0 {
                withAnimation(.snappy(duration: 0.25)) { page = 1 }
            } else if page == 1 {
                requestMicPermission()
            } else {
                finish()
            }
        } label: {
            Text(buttonTitle)
                .font(.headline)
                .foregroundStyle(Theme.paper)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.ink))
        }
        .buttonStyle(.plain)
    }

    private var buttonTitle: String {
        if micDenied { return "Open Settings" }
        if page < 2 { return "Continue" }
        return "Get Started"
    }

    private func requestMicPermission() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    withAnimation(.snappy(duration: 0.25)) { page = 2 }
                } else {
                    withAnimation(.snappy(duration: 0.25)) { micDenied = true; page = 2 }
                }
            }
        }
    }

    private func finish() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            hasCompletedOnboarding = true
        case .denied:
            withAnimation(.snappy(duration: 0.25)) { micDenied = true; page = 2 }
        case .undetermined:
            requestMicPermission()
        @unknown default:
            withAnimation(.snappy(duration: 0.25)) { micDenied = true; page = 2 }
        }
    }

    private func recheckPermission() {
        if AVAudioApplication.shared.recordPermission == .granted {
            withAnimation(.snappy(duration: 0.25)) {
                micDenied = false
                page = 2
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct OnboardingPage: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 68, weight: .medium))
                .foregroundStyle(Theme.ink)

            Text(title)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink)

            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 36)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    OnboardingView()
}