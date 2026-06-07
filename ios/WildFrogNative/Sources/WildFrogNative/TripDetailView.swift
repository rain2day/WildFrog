import MapKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// One completed trip viewed in full: the recorded track replay (when present),
/// the summit photo, derived stats, and a certificate entry. Backed by a single
/// `CheckInRecord` looked up from the store so it survives navigation.
struct TripDetailView: View {
    let recordId: UUID

    @EnvironmentObject private var checkInStore: CheckInStore

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var summitPhoto: UIImage?
    @State private var showCertificate = false

    private var record: CheckInRecord? {
        checkInStore.records.first { $0.id == recordId }
    }

    private var mountain: Mountain? {
        record.map { MountainCatalog.mountain(id: $0.mountainId) }
    }

    var body: some View {
        Group {
            if let record, let mountain {
                content(for: record, mountain: mountain)
            } else {
                ContentUnavailableView("找不到行程", systemImage: "mountain.2")
            }
        }
        .navigationTitle(mountain?.nameZh ?? "行程")
        .nativeInlineTitle()
        .background(FrogTheme.paper)
    }

    @ViewBuilder
    private func content(for record: CheckInRecord, mountain: Mountain) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                topMap(for: record, mountain: mountain)
                summitPhotoPanel(for: record, mountain: mountain)
                statsPanel(for: record, mountain: mountain)
                certificateButton
            }
            .padding(FrogSpace.screenPadding)
            .padding(.bottom, 110)
        }
        .onAppear {
            fitCamera(to: record, mountain: mountain)
            loadPhoto(record.photoFilename)
        }
        .sheet(isPresented: $showCertificate) {
            CertificateShareSheet(
                mountainCount: checkInStore.distinctMountainCount,
                onDismiss: { showCertificate = false }
            )
        }
    }

    // MARK: - Top map (track replay or summit location)

    @ViewBuilder
    private func topMap(for record: CheckInRecord, mountain: Mountain) -> some View {
        let coordinates = record.track?.coordinates.map(\.coordinate) ?? []
        Map(position: $cameraPosition) {
            if coordinates.count > 1 {
                MapPolyline(coordinates: coordinates)
                    .stroke(FrogTheme.orange, lineWidth: 5)
                if let start = coordinates.first {
                    Marker("起點", systemImage: "flag.fill", coordinate: start)
                        .tint(FrogTheme.moss)
                }
                if let end = coordinates.last {
                    Marker("山頂打卡", systemImage: "flag.checkered", coordinate: end)
                        .tint(FrogTheme.orange)
                }
            } else {
                Marker(mountain.nameZh, systemImage: "mappin.circle.fill", coordinate: mountain.coordinate)
                    .tint(FrogTheme.orange)
            }
        }
        .mapControlVisibility(.hidden)
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topLeading) {
            Label(record.track != nil ? "軌跡回放" : "山頂位置", systemImage: record.track != nil ? "point.topleft.down.curvedto.point.bottomright.up.fill" : "mappin.and.ellipse")
                .font(.frogMicro.weight(.black))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(FrogTheme.forest.opacity(0.82), in: Capsule())
                .padding(12)
        }
    }

    // MARK: - Summit photo

    @ViewBuilder
    private func summitPhotoPanel(for record: CheckInRecord, mountain: Mountain) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let summitPhoto {
                Image(uiImage: summitPhoto)
                    .resizable()
                    .scaledToFill()
            } else {
                MountainPhoto(mountain: mountain, dimming: 0.18)
            }
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.74)],
                startPoint: .center,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(mountain.displayName)
                    .font(.frogTitle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Text("\(mountain.region) · \(mountain.height)m")
                    .font(.frogCaption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(16)
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: 1)
        )
    }

    // MARK: - Stats

    private func statsPanel(for record: CheckInRecord, mountain: Mountain) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("行程數據")
                .font(.headline.weight(.black))
                .foregroundStyle(FrogTheme.ink)

            if let track = record.track {
                HStack(spacing: 10) {
                    StatCard(value: TrackFormat.distance(track.distanceMeters), label: "距離", systemImage: "ruler", tint: FrogTheme.moss)
                    StatCard(value: TrackFormat.duration(track.durationSeconds), label: "時間", systemImage: "clock", tint: FrogTheme.orange)
                    StatCard(value: "\(Int(track.ascentMeters))m", label: "累積爬升", systemImage: "arrow.up.forward", tint: FrogTheme.gold)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FrogTheme.orange)
                    Text("直接打卡 · 未記錄軌跡")
                        .font(.frogCaption.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(FrogTheme.mapWash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Label(record.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                .font(.frogCaption.weight(.semibold))
                .foregroundStyle(FrogTheme.muted)
        }
        .padding(FrogSpace.cardPadding)
        .cardStyle()
    }

    // MARK: - Certificate

    private var certificateButton: some View {
        Button {
            showCertificate = true
        } label: {
            Label("查看登頂證書", systemImage: "rosette")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Camera

    private func fitCamera(to record: CheckInRecord, mountain: Mountain) {
        let coordinates = record.track?.coordinates.map(\.coordinate) ?? []
        guard coordinates.count > 1 else {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: mountain.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
            return
        }
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

    // MARK: - Photo loading

    private func loadPhoto(_ filename: String?) {
        #if os(iOS)
        guard summitPhoto == nil, let filename, !filename.isEmpty else { return }
        Task {
            let image = await Task.detached(priority: .utility) { () -> UIImage? in
                guard let url = FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)
                    .first?
                    .appendingPathComponent(filename),
                      let data = try? Data(contentsOf: url) else { return nil }
                return UIImage(data: data)
            }.value
            await MainActor.run { summitPhoto = image }
        }
        #endif
    }
}
