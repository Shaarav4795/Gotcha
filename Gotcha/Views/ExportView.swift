import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    let clip: Clip

    @State private var mode: Mode = .export
    @State private var isExporting = false
    @State private var progress: Double = 0
    @State private var exportedURL: URL?
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var showPhotosConfirmation = false

    private let composer = ClipComposer()

    private enum Mode: String, CaseIterable, Identifiable {
        case export = "Export"
        case share = "Share"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                modePicker
                summary

                if isExporting {
                    progressView
                } else {
                    options
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Theme.paper)
        .navigationTitle("Export")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy(duration: 0.2), value: mode)
        .animation(.snappy(duration: 0.2), value: isExporting)
        .sheet(isPresented: $showShareSheet, onDismiss: { cleanupExportedFile() }) {
            if let url = exportedURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Saved to Photos", isPresented: $showPhotosConfirmation) {
            Button("OK", role: .cancel) {
                cleanupExportedFile()
            }
        } message: {
            Text("The video has been saved to your Photos library.")
        }
        .alert("Export Failed", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                cleanupExportedFile()
            }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(Mode.allCases) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .tint(Theme.ink)
        .disabled(isExporting)
    }

    private var summary: some View {
        HStack(spacing: 14) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(clip.title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("\(clip.durationText) · \(clip.subtitles.count) subtitles")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.elevated)
            Image(systemName: "waveform")
                .font(.system(size: 24))
                .foregroundStyle(Theme.muted)
        }
        .frame(width: 72, height: 72)
    }

    private var progressView: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress, total: 1.0)
                .tint(Theme.ink)
                .scaleEffect(x: 1, y: 2, anchor: .center)

            Text(progressText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.muted)

            Button(role: .destructive) {
                isExporting = false
                progress = 0
                cleanupExportedFile()
            } label: {
                Text("Cancel")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
    }

    private var progressText: String {
        let pct = Int((progress * 100).rounded())
        if mode == .share {
            return "Preparing for share… \(pct)%"
        }
        return "Exporting… \(pct)%"
    }

    @ViewBuilder
    private var options: some View {
        switch mode {
        case .export:
            VStack(spacing: 12) {
                optionButton(
                    title: "Save as MP4",
                    subtitle: "to Photos · video with audio, subtitles & caption",
                    systemImage: "video",
                    filled: true
                ) {
                    exportVideo(saveToPhotos: true)
                }
                optionButton(
                    title: "Save as M4A",
                    subtitle: "to Files · audio only",
                    systemImage: "doc",
                    filled: false
                ) {
                    exportAudio()
                }
            }

        case .share:
            VStack(spacing: 12) {
                optionButton(
                    title: "Share as MP4",
                    subtitle: "video with audio, subtitles & caption",
                    systemImage: "video",
                    filled: true
                ) {
                    exportVideo(saveToPhotos: false)
                }
                optionButton(
                    title: "Share as M4A",
                    subtitle: "audio only",
                    systemImage: "doc",
                    filled: false
                ) {
                    exportAudio()
                }
            }
        }
    }

    private func optionButton(title: String,
                              subtitle: String,
                              systemImage: String,
                              filled: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(filled ? Theme.paper : Theme.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(filled ? Theme.paper.opacity(0.18) : Theme.surface))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .opacity(0.7)
                }
                .foregroundStyle(filled ? Theme.paper : Theme.ink)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .opacity(0.5)
                    .foregroundStyle(filled ? Theme.paper : Theme.muted)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(filled ? Theme.ink : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(filled ? Color.clear : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func exportVideo(saveToPhotos: Bool) {
        isExporting = true
        progress = 0

        Task {
            do {
                let url = try await composer.exportVideo(clip: clip) { p in
                    Task { @MainActor in
                        guard isExporting else { return }
                        progress = p
                    }
                }
                guard isExporting else { return }
                progress = 1.0

                if saveToPhotos {
                    try await composer.saveToPhotos(url: url)
                    composer.removeTempFile(at: url)
                    showPhotosConfirmation = true
                } else {
                    exportedURL = url
                    showShareSheet = true
                }
                isExporting = false
            } catch {
                guard isExporting else { return }
                isExporting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func exportAudio() {
        isExporting = true
        progress = 0

        Task {
            do {
                let url = try await composer.exportAudio(clip: clip) { p in
                    Task { @MainActor in
                        guard isExporting else { return }
                        progress = p
                    }
                }
                guard isExporting else { return }
                progress = 1.0
                exportedURL = url
                showShareSheet = true
                isExporting = false
            } catch {
                guard isExporting else { return }
                isExporting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func cleanupExportedFile() {
        if let url = exportedURL {
            composer.removeTempFile(at: url)
            exportedURL = nil
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ExportView(clip: Clip(title: "Sample", duration: 120, capturedAt: Date(), hasImage: false, subtitles: []))
    }
}
