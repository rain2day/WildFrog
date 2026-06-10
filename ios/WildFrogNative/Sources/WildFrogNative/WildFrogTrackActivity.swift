import Foundation
#if canImport(ActivityKit)
@preconcurrency import ActivityKit
#endif

#if canImport(ActivityKit)
/// Live Activity attributes for an in-progress hike recording. Shared between the
/// app (which starts / updates / ends the activity from `TrackRecorder`) and the
/// Widget Extension target that renders the Dynamic Island + Lock Screen UI.
struct WildFrogTrackAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var elapsedSeconds: Int
        public var distanceMeters: Double
        public var ascentMeters: Double
        /// True while the user has paused the recording.
        public var isPaused: Bool
        /// Live distance to the summit checkpoint (nil before the first GPS fix).
        public var distanceToSummitMeters: Double?
        /// 0…1 approach progress toward the summit (nil before the first fix).
        public var summitProgress: Double?

        public init(
            elapsedSeconds: Int,
            distanceMeters: Double,
            ascentMeters: Double,
            isPaused: Bool = false,
            distanceToSummitMeters: Double? = nil,
            summitProgress: Double? = nil
        ) {
            self.elapsedSeconds = elapsedSeconds
            self.distanceMeters = distanceMeters
            self.ascentMeters = ascentMeters
            self.isPaused = isPaused
            self.distanceToSummitMeters = distanceToSummitMeters
            self.summitProgress = summitProgress
        }
    }

    public var mountainName: String

    public init(mountainName: String) {
        self.mountainName = mountainName
    }
}

/// Thin ActivityKit wrapper so `TrackRecorder` stays free of platform/availability
/// guards. Every call is best-effort: if Live Activities are disabled or
/// unsupported, the methods quietly do nothing.
@MainActor
final class TrackLiveActivityController {
    private var activity: Activity<WildFrogTrackAttributes>?

    func start(mountainName: String, state: WildFrogTrackAttributes.ContentState) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = WildFrogTrackAttributes(
            mountainName: mountainName.isEmpty ? "行程記錄中" : mountainName
        )
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil)
        )
    }

    func update(state: WildFrogTrackAttributes.ContentState) {
        guard let activity else { return }
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
