import AppIntents
import Foundation

/// Pause/resume button on the hike-recording Live Activity. `LiveActivityIntent`
/// performs in the APP's process, but the type must also compile in the widget
/// extension (the island button references it) — so it relays via a notification
/// by name instead of touching app-only state like `TrackRecorder` directly.
struct TrackPauseResumeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "暫停／繼續行程記錄"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: Notification.Name("wildfrog.track.togglePause"),
                object: nil
            )
        }
        return .result()
    }
}
