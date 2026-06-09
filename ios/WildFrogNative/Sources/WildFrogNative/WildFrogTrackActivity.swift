import Foundation
#if canImport(ActivityKit)
@preconcurrency import ActivityKit
#endif

#if canImport(ActivityKit)
/// Live Activity attributes for an in-progress hike recording. Shared between the
/// app (which starts / updates / ends the activity from `TrackRecorder`) and the
/// future Widget Extension target that renders the Dynamic Island + Lock Screen UI
/// (see `ios/WildFrogNative/LiveActivityWidget/`).
///
/// To activate end-to-end you still need to: (1) add a Widget Extension target,
/// (2) move/include the LiveActivityWidget UI + this file in that target, and
/// (3) set `NSSupportsLiveActivities = YES` in the app's Info.plist. Until then
/// `TrackLiveActivityController` simply no-ops.
struct WildFrogTrackAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var elapsedSeconds: Int
        public var distanceMeters: Double
        public var ascentMeters: Double

        public init(elapsedSeconds: Int, distanceMeters: Double, ascentMeters: Double) {
            self.elapsedSeconds = elapsedSeconds
            self.distanceMeters = distanceMeters
            self.ascentMeters = ascentMeters
        }
    }

    public var mountainName: String

    public init(mountainName: String) {
        self.mountainName = mountainName
    }
}

/// Thin ActivityKit wrapper so `TrackRecorder` stays free of platform/availability
/// guards. Every call is best-effort: if Live Activities are disabled, unsupported,
/// or the widget target isn't wired yet, the methods quietly do nothing.
@MainActor
final class TrackLiveActivityController {
    private var activity: Activity<WildFrogTrackAttributes>?

    func start(mountainName: String, elapsedSeconds: Int, distanceMeters: Double, ascentMeters: Double) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = WildFrogTrackAttributes(
            mountainName: mountainName.isEmpty ? "行程記錄中" : mountainName
        )
        let state = WildFrogTrackAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            distanceMeters: distanceMeters,
            ascentMeters: ascentMeters
        )
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil)
        )
    }

    func update(elapsedSeconds: Int, distanceMeters: Double, ascentMeters: Double) {
        guard let activity else { return }
        let state = WildFrogTrackAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            distanceMeters: distanceMeters,
            ascentMeters: ascentMeters
        )
        Task { @MainActor in
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end() {
        guard let current = activity else { return }
        let finalState = current.content.state
        Task { @MainActor in
            await current.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        activity = nil
    }
}
#endif
