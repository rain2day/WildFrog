// WildFrog — Track recording Live Activity (Dynamic Island + Lock Screen).
//
// This file is built by the WildFrogLiveActivityWidgetExtension target. The
// app target starts/updates/ends the activity from `TrackRecorder`; this target
// renders the Dynamic Island + Lock Screen UI while recording.

import ActivityKit
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
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        islandStat("距離", distanceString(context.state.distanceMeters))
                        islandStat("上升", "\(Int(context.state.ascentMeters))m")
                        Spacer()
                        Label("記錄中", systemImage: "record.circle")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: "figure.hiking").foregroundStyle(.green)
            } compactTrailing: {
                Text(timeString(context.state.elapsedSeconds))
                    .monospacedDigit()
                    .font(.caption2.weight(.bold))
            } minimal: {
                Image(systemName: "figure.hiking").foregroundStyle(.green)
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

struct LockScreenTrackView: View {
    let context: ActivityViewContext<WildFrogTrackAttributes>

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.hiking")
                .font(.title2.weight(.bold))
                .foregroundStyle(.green)
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
                Text("記錄中")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.orange)
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
