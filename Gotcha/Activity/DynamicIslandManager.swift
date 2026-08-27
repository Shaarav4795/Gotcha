import ActivityKit
import Foundation

@MainActor
final class DynamicIslandManager {
    static let shared = DynamicIslandManager()

    private var activity: Activity<GotchaLiveActivityAttributes>?
    private var successTask: Task<Void, Never>?

    private init() {}

    func start(bufferMinutes: Int) {
        if let activity {
            if activity.attributes.bufferMinutes == bufferMinutes { return }
            endCurrent()
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = GotchaLiveActivityAttributes(bufferMinutes: bufferMinutes)
        let state = GotchaLiveActivityAttributes.ContentState(
            status: "Ready to capture",
            bufferMinutes: bufferMinutes,
            lastCaptureAt: nil
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    func stop() {
        successTask?.cancel()
        successTask = nil
        endCurrent()
    }

    func captureSucceeded(bufferMinutes: Int) {
        guard let activity else { return }
        successTask?.cancel()
        successTask = Task { [weak self] in
            let state = GotchaLiveActivityAttributes.ContentState(
                status: "Captured",
                bufferMinutes: bufferMinutes,
                lastCaptureAt: Date()
            )
            await activity.update(ActivityContent(state: state, staleDate: nil))
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            let readyState = GotchaLiveActivityAttributes.ContentState(
                status: "Ready to capture",
                bufferMinutes: bufferMinutes,
                lastCaptureAt: nil
            )
            await activity.update(ActivityContent(state: readyState, staleDate: nil))
            _ = self
        }
    }

    private func endCurrent() {
        guard let activity else { return }
        self.activity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
