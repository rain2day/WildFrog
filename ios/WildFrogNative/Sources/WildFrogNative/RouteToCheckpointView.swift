import MapKit
import SwiftUI

struct RouteToCheckpointView: View {
    let mountain: Mountain

    @EnvironmentObject private var locationManager: LocationManager

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var route: MKRoute?
    @State private var fallbackLine: [CLLocationCoordinate2D] = []
    @State private var statusMessage: String?
    @State private var isLoading = false

    private var hasLocation: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse ||
        locationManager.authorizationStatus == .authorizedAlways
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                mapPanel
                summaryPanel
                navigateButton
            }
            .padding(FrogSpace.screenPadding)
            .padding(.bottom, 110)
        }
        .navigationTitle("路線導航")
        .nativeInlineTitle()
        .background(FrogTheme.paper)
        .onAppear {
            locationManager.requestAuthorization()
            locationManager.startUpdating()
            recomputeIfNeeded()
        }
        .onChange(of: locationManager.currentLocation) { _, _ in
            recomputeIfNeeded()
        }
    }

    private var mapPanel: some View {
        Map(position: $cameraPosition) {
            Marker(mountain.nameZh, systemImage: "flag.checkered", coordinate: mountain.coordinate)
                .tint(FrogTheme.orange)
            UserAnnotation()

            if let route {
                MapPolyline(route.polyline)
                    .stroke(FrogTheme.moss, lineWidth: 6)
            } else if fallbackLine.count > 1 {
                MapPolyline(coordinates: fallbackLine)
                    .stroke(FrogTheme.moss.opacity(0.7), style: StrokeStyle(lineWidth: 4, dash: [8, 6]))
            }
        }
        .mapControlVisibility(.hidden)
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if isLoading {
                ProgressView()
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(10)
            }
        }
    }

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("步行路線", systemImage: "figure.walk")
                    .font(.headline.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                Spacer()
            }

            HStack(spacing: 10) {
                StatCard(
                    value: routeDistanceText,
                    label: "步行距離",
                    systemImage: "ruler",
                    tint: FrogTheme.moss
                )
                StatCard(
                    value: routeETAText,
                    label: "預計時間",
                    systemImage: "clock",
                    tint: FrogTheme.orange
                )
            }

            if let statusMessage {
                Label(statusMessage, systemImage: "info.circle")
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(FrogTheme.muted)
            }
        }
        .padding(FrogSpace.cardPadding)
        .cardStyle()
    }

    private var navigateButton: some View {
        Button {
            openInMaps()
        } label: {
            Label("用地圖導航（步行）", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived text

    private var routeDistanceText: String {
        if let route {
            return TrackFormat.distance(route.distance)
        }
        if let straight = straightLineDistance {
            return TrackFormat.distance(straight)
        }
        return "—"
    }

    private var routeETAText: String {
        if let route {
            return TrackFormat.duration(route.expectedTravelTime)
        }
        return "—"
    }

    private var straightLineDistance: CLLocationDistance? {
        locationManager.distance(to: mountain.coordinate)
    }

    // MARK: - Directions

    private func recomputeIfNeeded() {
        guard route == nil, !isLoading else { return }
        guard hasLocation, let origin = locationManager.currentLocation else {
            statusMessage = hasLocation ? "定位中…" : "開啟定位以計算步行路線"
            return
        }
        requestDirections(from: origin.coordinate)
    }

    private func requestDirections(from origin: CLLocationCoordinate2D) {
        isLoading = true
        statusMessage = nil

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: mountain.coordinate))
        request.transportType = .walking

        let destination = mountain.coordinate
        Task { @MainActor in
            defer { isLoading = false }
            do {
                let response = try await MKDirections(request: request).calculate()
                if let firstRoute = response.routes.first {
                    route = firstRoute
                    statusMessage = nil
                    cameraPosition = .rect(firstRoute.polyline.boundingMapRect)
                    return
                }
            } catch {
                // Fall through to the straight-line fallback below.
            }
            // No walking route available — fall back to a straight reference line.
            fallbackLine = [origin, destination]
            statusMessage = "未能取得步行路線，顯示直線參考"
            fitFallbackCamera(origin: origin)
        }
    }

    private func fitFallbackCamera(origin: CLLocationCoordinate2D) {
        let center = CLLocationCoordinate2D(
            latitude: (origin.latitude + mountain.coordinate.latitude) / 2,
            longitude: (origin.longitude + mountain.coordinate.longitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(abs(origin.latitude - mountain.coordinate.latitude) * 1.6, 0.01),
            longitudeDelta: max(abs(origin.longitude - mountain.coordinate.longitude) * 1.6, 0.01)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }

    private func openInMaps() {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: mountain.coordinate))
        destination.name = mountain.nameZh
        destination.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}

// MARK: - Nearest checkpoint banner

/// Compact banner that surfaces the nearest mountain checkpoint and a route entry point.
struct NearestCheckpointBanner: View {
    @EnvironmentObject private var locationManager: LocationManager

    private var nearest: (mountain: Mountain, distance: CLLocationDistance)? {
        var best: (Mountain, CLLocationDistance)?
        for mountain in MountainCatalog.mountains {
            guard let distance = locationManager.distance(to: mountain.coordinate) else { continue }
            if best == nil || distance < best!.1 {
                best = (mountain, distance)
            }
        }
        return best.map { (mountain: $0.0, distance: $0.1) }
    }

    var body: some View {
        if let nearest {
            NavigationLink(value: NativeRoute.routeToCheckpoint(nearest.mountain.id)) {
                HStack(spacing: 12) {
                    Image(systemName: "location.north.circle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(FrogTheme.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("最近打卡點")
                            .font(.frogMicro.weight(.bold))
                            .foregroundStyle(FrogTheme.muted)
                        Text(nearest.mountain.nameZh)
                            .font(.frogRow)
                            .foregroundStyle(FrogTheme.ink)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TrackFormat.distance(nearest.distance))
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(FrogTheme.ink)
                        Label("導航", systemImage: "chevron.right")
                            .font(.frogMicro.weight(.bold))
                            .foregroundStyle(FrogTheme.orange)
                    }
                }
                .padding(FrogSpace.cardPadding)
                .cardStyle()
            }
            .buttonStyle(.plain)
        }
    }
}
