import MapKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct TrackDetailView: View {
    let trackId: UUID

    @EnvironmentObject private var trackStore: TrackStore
    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var shareItems: [Any]?

    private var track: Track? {
        trackStore.tracks.first { $0.id == trackId }
    }

    var body: some View {
        Group {
            if let track {
                content(for: track)
            } else {
                ContentUnavailableView("找不到軌跡", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            }
        }
        .navigationTitle(track?.name ?? "軌跡")
        .nativeInlineTitle()
        .background(FrogTheme.paper)
    }

    @ViewBuilder
    private func content(for track: Track) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                mapPanel(for: track)
                statsPanel(for: track)
                if let mountainId = track.mountainId {
                    linkedMountainRow(mountainId)
                }
                shareButton(for: track)
                actionButtons(for: track)
            }
            .padding(FrogSpace.screenPadding)
            .padding(.bottom, 110)
        }
        .onAppear { fitCamera(to: track) }
        .alert("重新命名", isPresented: $showRename) {
            TextField("名稱", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("儲存") { trackStore.rename(track, to: renameText) }
        }
        .confirmationDialog("刪除軌跡？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("刪除", role: .destructive) {
                trackStore.delete(track)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
        #if os(iOS)
        .sheet(item: Binding(
            get: { shareItems.map { SharePayload(items: $0) } },
            set: { shareItems = $0?.items }
        )) { payload in
            ActivityView(items: payload.items)
        }
        #endif
    }

    private func mapPanel(for track: Track) -> some View {
        Map(position: $cameraPosition) {
            if track.coordinates.count > 1 {
                MapPolyline(coordinates: track.coordinates)
                    .stroke(FrogTheme.orange, lineWidth: 5)
            }
            if let start = track.coordinates.first {
                Marker("起點", systemImage: "flag.fill", coordinate: start)
                    .tint(FrogTheme.moss)
            }
            if let end = track.coordinates.last, track.coordinates.count > 1 {
                Marker("終點", systemImage: "flag.checkered", coordinate: end)
                    .tint(FrogTheme.orange)
            }
        }
        .mapControlVisibility(.hidden)
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statsPanel(for track: Track) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("數據")
                .font(.headline.weight(.black))
                .foregroundStyle(FrogTheme.ink)
            HStack(spacing: 10) {
                StatCard(value: TrackFormat.distance(track.distanceMeters), label: "距離", systemImage: "ruler", tint: FrogTheme.moss)
                StatCard(value: TrackFormat.duration(track.durationSeconds), label: "時間", systemImage: "clock", tint: FrogTheme.orange)
                StatCard(value: "\(Int(track.ascentMeters))m", label: "累積爬升", systemImage: "arrow.up.forward", tint: FrogTheme.gold)
            }
            Label(track.startDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                .font(.frogCaption.weight(.semibold))
                .foregroundStyle(FrogTheme.muted)
        }
        .padding(FrogSpace.cardPadding)
        .cardStyle()
    }

    private func linkedMountainRow(_ mountainId: String) -> some View {
        NavigationLink(value: NativeRoute.mountainDetail(mountainId)) {
            HStack(spacing: 12) {
                let mountain = MountainCatalog.mountain(id: mountainId)
                MountainPhoto(mountain: mountain, dimming: 0.08)
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("關聯山峰")
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.muted)
                    Text(mountain.nameZh)
                        .font(.frogRow)
                        .foregroundStyle(FrogTheme.ink)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FrogTheme.muted)
            }
            .padding(FrogSpace.cardPadding)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func shareButton(for track: Track) -> some View {
        Button {
            prepareShare(for: track)
        } label: {
            Label("分享軌跡（地圖圖 + GPX）", systemImage: "square.and.arrow.up")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func actionButtons(for track: Track) -> some View {
        HStack(spacing: 12) {
            Button {
                renameText = track.name
                showRename = true
            } label: {
                Label("重新命名", systemImage: "pencil")
                    .font(.frogRow)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.bordered)
            .tint(FrogTheme.moss)

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("刪除", systemImage: "trash")
                    .font(.frogRow)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    // MARK: - Camera

    private func fitCamera(to track: Track) {
        let coordinates = track.coordinates
        guard !coordinates.isEmpty else { return }
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }

    // MARK: - Share

    private func prepareShare(for track: Track) {
        var items: [Any] = []
        #if os(iOS)
        if let image = renderTrackImage(for: track) {
            items.append(image)
        }
        #endif
        if let gpxURL = try? GPXExporter.exportToTemporaryFile(track) {
            items.append(gpxURL)
        }
        guard !items.isEmpty else { return }
        shareItems = items
    }

    #if os(iOS)
    @MainActor
    private func renderTrackImage(for track: Track) -> UIImage? {
        let snapshot = TrackShareCard(track: track)
            .frame(width: 600, height: 760)
        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = 2
        return renderer.uiImage
    }
    #endif
}

// MARK: - Share card (rendered for image export)

private struct TrackShareCard: View {
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                WildFrogBrandMark(size: 40, cornerRadius: 11)
                VStack(alignment: .leading, spacing: 1) {
                    Text("WILDFROG")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.ink)
                    Text("TRACK RECORD")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(FrogTheme.orange)
                }
            }

            Text(track.name)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(FrogTheme.ink)
                .lineLimit(2)

            TrackSparkline(coordinates: track.coordinates)
                .stroke(FrogTheme.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .background(FrogTheme.mapWash)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 0) {
                shareStat(value: TrackFormat.distance(track.distanceMeters), label: "距離")
                shareStat(value: TrackFormat.duration(track.durationSeconds), label: "時間")
                shareStat(value: "\(Int(track.ascentMeters))m", label: "爬升")
            }

            Text(track.startDate.formatted(date: .long, time: .shortened))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FrogTheme.muted)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
    }

    private func shareStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(FrogTheme.ink)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FrogTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Normalized polyline shape used for the shareable image (independent of MapKit).
private struct TrackSparkline: Shape {
    let coordinates: [CLLocationCoordinate2D]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard coordinates.count > 1 else { return path }

        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return path }

        let latRange = max(maxLat - minLat, 0.0001)
        let lonRange = max(maxLon - minLon, 0.0001)
        let inset: CGFloat = 28

        func point(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
            let x = inset + (rect.width - inset * 2) * CGFloat((coordinate.longitude - minLon) / lonRange)
            // Flip latitude so north is up.
            let y = inset + (rect.height - inset * 2) * CGFloat(1 - (coordinate.latitude - minLat) / latRange)
            return CGPoint(x: x, y: y)
        }

        path.move(to: point(coordinates[0]))
        for coordinate in coordinates.dropFirst() {
            path.addLine(to: point(coordinate))
        }
        return path
    }
}

// MARK: - Share plumbing

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

#if os(iOS)
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
