import SwiftUI

struct ClipEditorView: View {
    let clip: Clip
    @Binding var settings: EditorSettings
    @Environment(\.dismiss) private var dismiss

    @State private var activeTool: EditorTool = .layout

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            stage
            toolRail
            toolPanel
        }
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var editorHeader: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
            }

            Spacer()

            Text("Edit")
                .font(.headline)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var stage: some View {
        EditorStage(settings: settings)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
    }

    private var toolRail: some View {
        HStack(spacing: 0) {
            ForEach(EditorTool.allCases) { tool in
                Button {
                    activeTool = tool
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 19))
                            .frame(height: 22)
                        Text(tool.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(activeTool == tool ? Theme.ink : Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }

    @ViewBuilder
    private var toolPanel: some View {
        switch activeTool {
        case .layout:
            LayoutPanel(settings: $settings)
        case .caption:
            CaptionPanel(settings: $settings)
        case .waveform:
            WaveformPanel(settings: $settings)
        case .audio:
            AudioPanel(settings: $settings)
        }
    }
}

enum EditorTool: CaseIterable, Identifiable {
    case layout, caption, waveform, audio

    var id: Self { self }

    var title: String {
        switch self {
        case .layout: return "Layout"
        case .caption: return "Caption"
        case .waveform: return "Wave"
        case .audio: return "Audio"
        }
    }

    var icon: String {
        switch self {
        case .layout: return "rectangle.portrait.rotate"
        case .caption: return "textformat"
        case .waveform: return "waveform"
        case .audio: return "speaker.wave.2"
        }
    }
}

private struct EditorStage: View {
    let settings: EditorSettings

    var body: some View {
        GeometryReader { geo in
            let aspect = settings.aspect.ratio
            let maxWidth = geo.size.width
            let maxHeight = geo.size.height
            let width = min(maxWidth, maxHeight * aspect)
            let height = width / aspect

            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Theme.hairline, lineWidth: 1)
                    )

                VStack {
                    captionText
                        .padding(.horizontal, 18)
                        .offset(
                            x: (settings.captionPosition.x - 0.5) * width,
                            y: (settings.captionPosition.y - 0.82) * height
                        )

                    Spacer()

                    waveform
                        .offset(
                            x: (settings.waveformPosition.x - 0.5) * width,
                            y: (settings.waveformPosition.y - 0.5) * height
                        )
                        .padding(.bottom, 14)
                }
                .frame(width: width, height: height)
            }
            .frame(width: width, height: height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 360)
    }

    private var captionText: some View {
        Text(clipCaption)
            .font(.system(size: settings.captionSize, weight: settings.captionWeight.weight))
            .multilineTextAlignment(settings.captionAlign.alignment)
            .textCase(settings.captionCase.textCase)
            .frame(
                maxWidth: .infinity,
                alignment: Alignment(
                    horizontal: settings.captionAlign.horizontal,
                    vertical: .center
                )
            )
            .foregroundStyle(Theme.ink)
    }

    private var clipCaption: String {
        "The part where the plan actually worked"
    }

    @ViewBuilder
    private var waveform: some View {
        switch settings.waveformStyle {
        case .bars:
            EditorWaveformBars(sensitivity: settings.waveformSensitivity)
        case .line:
            EditorWaveformLine(sensitivity: settings.waveformSensitivity)
        }
    }
}

private struct EditorWaveformBars: View {
    let sensitivity: Double

    private let levels: [Float] = [0.16, 0.32, 0.5, 0.72, 0.44, 0.86, 0.6, 0.38, 0.66, 0.3, 0.52, 0.24, 0.44, 0.7]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(levels.indices, id: \.self) { i in
                Capsule()
                    .fill(Theme.ink)
                    .frame(width: 4, height: barHeight(levels[i]))
            }
        }
    }

    private func barHeight(_ level: Float) -> CGFloat {
        4 + CGFloat(min(max(level, 0), 1)) * (sensitivity / 100) * 34
    }
}

private struct EditorWaveformLine: View {
    let sensitivity: Double

    var body: some View {
        WaveformLineShape(sensitivity: sensitivity)
            .stroke(Theme.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 170, height: 42)
    }
}

private struct WaveformLineShape: Shape {
    let sensitivity: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = 24
        let step = rect.width / CGFloat(points - 1)
        let amplitude = rect.height * 0.42 * (sensitivity / 100)

        for i in 0..<points {
            let x = CGFloat(i) * step
            let wave = sin(Double(i) * 0.9) * 0.55 + sin(Double(i) * 0.31) * 0.45
            let y = rect.midY - CGFloat(wave) * amplitude
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

private struct LayoutPanel: View {
    @Binding var settings: EditorSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            panelLabel("Aspect")

            HStack(spacing: 8) {
                ForEach(Aspect.allCases) { aspect in
                    Button {
                        settings.aspect = aspect
                    } label: {
                        Text(aspect.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(settings.aspect == aspect ? Theme.paper : Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(settings.aspect == aspect ? Theme.ink : Theme.elevated)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}

private struct CaptionPanel: View {
    @Binding var settings: EditorSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    panelLabel("Size")
                    slider(value: $settings.captionSize, range: 12...40)
                }

                VStack(alignment: .leading, spacing: 8) {
                    panelLabel("Weight")
                    Picker("Weight", selection: $settings.captionWeight) {
                        ForEach(CaptionWeight.allCases) { weight in
                            Text(weight.title).tag(weight)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                panelLabel("Alignment")
                Picker("Alignment", selection: $settings.captionAlign) {
                    ForEach(TextAlign.allCases) { align in
                        Text(align.title).tag(align)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                panelLabel("Case")
                Picker("Case", selection: $settings.captionCase) {
                    ForEach(TextCaseOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}

private struct WaveformPanel: View {
    @Binding var settings: EditorSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    panelLabel("Style")
                    Picker("Style", selection: $settings.waveformStyle) {
                        ForEach(WaveformStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                VStack(alignment: .leading, spacing: 8) {
                    panelLabel("Sensitivity")
                    slider(value: $settings.waveformSensitivity, range: 20...200)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}

private struct AudioPanel: View {
    @Binding var settings: EditorSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                panelLabel("Volume")
                slider(value: $settings.volume, range: 0...1)
            }

            Toggle(isOn: $settings.loop) {
                panelLabel("Loop playback")
            }
            .tint(Theme.ink)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}

private func panelLabel(_ text: String) -> some View {
    Text(text.uppercased())
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Theme.muted)
}

private func slider(value: Binding<Double>, range: ClosedRange<Double>) -> some View {
    Slider(value: value, in: range)
        .tint(Theme.ink)
}

#Preview {
    NavigationStack {
        ClipEditorView(
            clip: Clip(title: "Sample", duration: 120, capturedAt: Date()),
            settings: .constant(EditorSettings())
        )
    }
}
