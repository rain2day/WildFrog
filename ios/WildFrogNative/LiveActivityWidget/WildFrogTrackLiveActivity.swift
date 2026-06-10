// WildFrog — Track recording Live Activity (Dynamic Island + Lock Screen).
//
// This file is built by the WildFrogLiveActivityWidgetExtension target. The
// app target starts/updates/ends the activity from `TrackRecorder`; this target
// renders the Dynamic Island + Lock Screen UI while recording. The compact
// island shows the live distance to the summit checkpoint and an approach
// progress ring; expanded + lock screen add a progress bar and a pause/resume
// button (TrackPauseResumeIntent, performed in the app's process).

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct WildFrogTrackLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        WildFrogTrackLiveActivity()
    }
}

struct WildFrogTrackLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WildFrogTrackAttributes.self) { context in
            LockScreenTrackView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.5))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.mountainName, systemImage: "figure.hiking")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timeString(context.state.elapsedSeconds))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(context.state.isPaused ? .orange : .white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 9) {
                        HStack(spacing: 16) {
                            islandStat("距離", distanceString(context.state.distanceMeters))
                            islandStat("上升", "\(Int(context.state.ascentMeters))m")
                            if let toSummit = context.state.distanceToSummitMeters {
                                islandStat("距山頂", distanceString(toSummit))
                            }
                            Spacer()

                            Button(intent: TrackPauseResumeIntent()) {
                                Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(.black)
                                    .frame(width: 36, height: 36)
                                    .background(context.state.isPaused ? Color.green : Color.orange, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }

                        SummitProgressBar(
                            progress: context.state.summitProgress,
                            isPaused: context.state.isPaused
                        )
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                SummitProgressRing(
                    progress: context.state.summitProgress,
                    isPaused: context.state.isPaused
                )
            } compactTrailing: {
                Text(compactStatusText(context.state))
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(context.state.isPaused ? .orange : .green)
            } minimal: {
                SummitProgressRing(
                    progress: context.state.summitProgress,
                    isPaused: context.state.isPaused
                )
            }
            .widgetURL(URL(string: "wildfrog://recording"))
            .keylineTint(.green)
        }
    }

    private func islandStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.7))
            Text(value).font(.caption.weight(.bold)).monospacedDigit().foregroundStyle(.white)
        }
    }
}

/// Collapsed-island status: paused flag, else live distance to the summit,
/// else elapsed time before the first GPS fix.
private func compactStatusText(_ state: WildFrogTrackAttributes.ContentState) -> String {
    if state.isPaused { return "暫停" }
    if let toSummit = state.distanceToSummitMeters { return distanceString(toSummit) }
    return timeString(state.elapsedSeconds)
}

/// Hand-drawn determinate ring (always renders in the island, unlike platform
/// progress styles): approach progress fills clockwise; hiking glyph inside.
struct SummitProgressRing: View {
    let progress: Double?
    let isPaused: Bool

    private var tint: Color { isPaused ? .orange : .green }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 2.4)
            Circle()
                .trim(from: 0, to: max(0.02, progress ?? 0))
                .stroke(tint, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: isPaused ? "pause.fill" : "figure.hiking")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: 21, height: 21)
        .padding(.horizontal, 1)
    }
}

/// Linear approach-progress bar: 行程起點 → 打卡點.
struct SummitProgressBar: View {
    let progress: Double?
    let isPaused: Bool

    private var tint: Color { isPaused ? .orange : .green }

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 5)
                GeometryReader { geo in
                    Capsule()
                        .fill(tint)
                        .frame(width: max(6, geo.size.width * (progress ?? 0)), height: 5)
                }
                .frame(height: 5)
            }
            HStack {
                Text(isPaused ? "已暫停" : "前往打卡點")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
                Text(progress.map { "\(Int($0 * 100))%" } ?? "—")
                    .font(.system(size: 9, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }
}

struct LockScreenTrackView: View {
    let context: ActivityViewContext<WildFrogTrackAttributes>

    private var isPaused: Bool { context.state.isPaused }

    var body: some View {
        VStack(spacing: 11) {
            HStack(spacing: 14) {
                Image(systemName: isPaused ? "pause.fill" : "figure.hiking")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(isPaused ? .orange : .green)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.mountainName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 12) {
                        Label(distanceString(context.state.distanceMeters), systemImage: "ruler")
                        Label("\(Int(context.state.ascentMeters))m", systemImage: "arrow.up.right")
                        if let toSummit = context.state.distanceToSummitMeters {
                            Label(distanceString(toSummit), systemImage: "flag.checkered")
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(timeString(context.state.elapsedSeconds))
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(isPaused ? "已暫停" : "記錄中")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 12) {
                SummitProgressBar(progress: context.state.summitProgress, isPaused: isPaused)

                Button(intent: TrackPauseResumeIntent()) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(isPaused ? Color.green : Color.orange, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }
}

private func timeString(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
}

private func distanceString(_ meters: Double) -> String {
    meters >= 1000 ? String(format: "%.1fkm", meters / 1000) : "\(Int(meters))m"
}
