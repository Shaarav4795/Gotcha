import ActivityKit
import SwiftUI
import WidgetKit

struct GotchaLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var bufferMinutes: Int
        var lastCaptureAt: Date?
    }

    var bufferMinutes: Int
}

private func isCaptured(_ context: ActivityViewContext<GotchaLiveActivityAttributes>) -> Bool {
    context.state.status == "Captured"
}

private func bufferLabel(_ minutes: Int) -> String {
    "Last \(minutes) minute\(minutes == 1 ? "" : "s") ready"
}

private func savedLabel(_ date: Date?) -> String {
    guard let date else { return "Captured" }
    return "Saved at \(date.formatted(date: .omitted, time: .shortened))"
}

struct GotchaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GotchaLiveActivityAttributes.self) { context in
            LockScreenPresentation(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: isCaptured(context) ? "checkmark.circle.fill" : "waveform")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(isCaptured(context) ? AnyShapeStyle(.green) : AnyShapeStyle(.white))
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .center, spacing: 2) {
                        Text(isCaptured(context) ? "Captured" : "Gotcha")
                            .font(.headline)
                            .foregroundStyle(isCaptured(context) ? Color.green : Color.white)
                        Group {
                            if isCaptured(context) {
                                Text(savedLabel(context.state.lastCaptureAt))
                            } else {
                                Text(bufferLabel(context.state.bufferMinutes))
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !isCaptured(context) {
                        Button(intent: CaptureFromIslandIntent()) {
                            HStack(spacing: 8) {
                                Image(systemName: "record.circle.fill")
                                    .font(.title3)
                                Text("Capture last recording")
                                    .font(.headline)
                            }
                            .foregroundStyle(Color.white)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity)
                            .background(Color.red, in: Capsule())
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Capture last recording")
                        .padding(.horizontal, 4)
                    }
                }
            } compactLeading: {
                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundStyle(isCaptured(context) ? Color.green : Color.white)
            } compactTrailing: {
                if isCaptured(context) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.green)
                } else {
                    Button(intent: CaptureFromIslandIntent()) {
                        Image(systemName: "record.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.red)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Capture last recording")
                }
            } minimal: {
                if isCaptured(context) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.green)
                } else {
                    Button(intent: CaptureFromIslandIntent()) {
                        Image(systemName: "record.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.red)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Capture last recording")
                }
            }
            .keylineTint(.white)
        }
    }
}

private struct LockScreenPresentation: View {
    let context: ActivityViewContext<GotchaLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCaptured(context) ? "checkmark.circle.fill" : "waveform")
                .font(.title3.weight(.semibold))
                .foregroundStyle(isCaptured(context) ? AnyShapeStyle(.green) : AnyShapeStyle(.primary))

            VStack(alignment: .leading, spacing: 2) {
                Text(isCaptured(context) ? "Captured" : "Gotcha")
                    .font(.headline)
                    .foregroundStyle(isCaptured(context) ? AnyShapeStyle(.green) : AnyShapeStyle(.primary))
                Group {
                    if isCaptured(context) {
                        Text(savedLabel(context.state.lastCaptureAt))
                    } else {
                        Text(bufferLabel(context.state.bufferMinutes))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isCaptured(context) {
                Image(systemName: "checkmark")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.green)
            } else {
                Button(intent: CaptureFromIslandIntent()) {
                    Image(systemName: "record.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.red)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Capture last recording")
            }
        }
        .padding()
        .activityBackgroundTint(nil)
        .activitySystemActionForegroundColor(.primary)
    }
}

@main
struct GotchaLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        GotchaLiveActivity()
    }
}
