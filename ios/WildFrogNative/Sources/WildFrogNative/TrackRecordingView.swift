import MapKit
import SwiftUI

struct TrackRecordingView: View {
    /// Optional mountain to pre-associate the recorded track with.
    let mountainId: String?

    @EnvironmentObject private var trackStore: TrackStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var recorder = TrackRecorder()
    @State private var cameraPosition: MapCameraPosition = .userLocation(
        fallback: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 22.302, longitude: 114.177),
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
        )
    )

    @State private var pendingTrack: Track?
    @State private var showSaveSheet = false

    /// Height reserved at the bottom so the recording card clears the persistent FrogTabBar.
    private let tabBarInset: CGFloat = 96

    var body: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            if recorder.points.count > 1 {
                MapPolyline(coordinates: recorder.points.map(\.coordinate))
                    .stroke(FrogTheme.orange, lineWidth: 5)
            }
        }
        .mapControlVisibility(.hidden)
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) { recordingCard }
        .navigationTitle("軌跡記錄")
        .nativeInlineTitle()
        .background(FrogTheme.paper)
        .sheet(isPresented: $showSaveSheet) {
            if let pendingTrack {
                TrackSaveSheet(
                    track: pendingTrack,
                    defaultMountainId: mountainId,
                    onSave: { name, linkedMountainId in
                        var saved = pendingTrack
                        saved.name = name
                        saved.mountainId = linkedMountainId
                        trackStore.add(saved)
                        self.pendingTrack = nil
                        showSaveSheet = false
                        dismiss()
                    },
                    onDiscard: {
                        self.pendingTrack = nil
                        showSaveSheet = false
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var recordingCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                liveStat(value: TrackFormat.distance(recorder.distanceMeters), label: "距離")
                divider
                liveStat(value: TrackFormat.duration(recorder.elapsedSeconds), label: "時間")
                divider
                liveStat(value: "\(Int(recorder.ascentMeters))m", label: "爬升")
            }

            if recorder.isRecording {
                stopButton
            } else {
                startButton
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 18, y: 6)
        .padding(.horizontal, FrogSpace.screenPadding)
        .padding(.bottom, tabBarInset)
    }

    private var divider: some View {
        Rectangle()
            .fill(FrogTheme.line)
            .frame(width: 1, height: 38)
    }

    private func liveStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.frogDisplay)
                .foregroundStyle(FrogTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.frogCaption.weight(.semibold))
                .foregroundStyle(FrogTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var startButton: some View {
        Button {
            recorder.start()
        } label: {
            Label("開始記錄", systemImage: "record.circle.fill")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var stopButton: some View {
        Button {
            if let track = recorder.stop() {
                pendingTrack = track
                showSaveSheet = true
            } else {
                dismiss()
            }
        } label: {
            Label("停止並儲存", systemImage: "stop.circle.fill")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(FrogTheme.forest, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Save sheet

private struct TrackSaveSheet: View {
    let track: Track
    let defaultMountainId: String?
    let onSave: (String, String?) -> Void
    let onDiscard: () -> Void

    @State private var name: String
    @State private var linkedMountainId: String?

    init(
        track: Track,
        defaultMountainId: String?,
        onSave: @escaping (String, String?) -> Void,
        onDiscard: @escaping () -> Void
    ) {
        self.track = track
        self.defaultMountainId = defaultMountainId
        self.onSave = onSave
        self.onDiscard = onDiscard
        _name = State(initialValue: track.name)
        _linkedMountainId = State(initialValue: defaultMountainId ?? track.mountainId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("軌跡名稱") {
                    TextField("名稱", text: $name)
                }

                Section("數據") {
                    LabeledContent("距離", value: TrackFormat.distance(track.distanceMeters))
                    LabeledContent("時間", value: TrackFormat.duration(track.durationSeconds))
                    LabeledContent("爬升", value: "\(Int(track.ascentMeters))m")
                }

                Section("關聯山峰（可選）") {
                    Picker("山峰", selection: $linkedMountainId) {
                        Text("不關聯").tag(String?.none)
                        ForEach(MountainCatalog.mountains) { mountain in
                            Text(mountain.nameZh).tag(String?.some(mountain.id))
                        }
                    }
                }
            }
            .navigationTitle("儲存軌跡")
            .nativeInlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("捨棄", role: .destructive) { onDiscard() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { onSave(name, linkedMountainId) }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Formatting helpers

enum TrackFormat {
    static func distance(_ meters: Double) -> String {
        meters < 1000
            ? "\(Int(meters))m"
            : String(format: "%.2fkm", meters / 1000)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
