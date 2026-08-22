import MapKit
import SwiftUI

struct RouteToCheckpointView: View {
    let mountain: Mountain

    @EnvironmentObject private var locationManager: LocationManager
    @State private var locationConsumerID = UUID()
    @EnvironmentObject private var recorder: TrackRecorder

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
                navigationActions
            }
            .padding(FrogSpace.screenPadding)
            .padding(.bottom, 32)
        }
        .localizedNavigationTitle { AppText.value(zh: "路線導航", en: "Route Navigation") }
        .nativeInlineTitle()
        .background(FrogTheme.paper)
        .onAppear {
            locationManager.requestAuthorization()
            locationManager.startUpdating(for: locationConsumerID)
            recomputeIfNeeded()
        }
        .onDisappear {
            locationManager.stopUpdating(for: locationConsumerID)
        }
        .onChange(of: locationManager.currentLocation) { _, _ in
            recomputeIfNeeded()
        }
    }

    private var mapPanel: some View {
        Map(position: $cameraPosition) {
            CheckInRadiusMapOverlay.circle(center: mountain.coordinate)
            Marker(mountain.localizedName, systemImage: recorder.activeMountainId == mountain.id ? "record.circle.fill" : "flag.checkered", coordinate: mountain.coordinate)
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
                Label(AppText.value(zh: "步行路線", en: "Walking Route"), systemImage: "figure.walk")
                    .font(.headline.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                Spacer()
            }

            HStack(spacing: 10) {
                StatCard(
                    value: routeDistanceText,
                    label: AppText.value(zh: "步行距離", en: "Walking Distance"),
                    systemImage: "ruler",
                    tint: FrogTheme.moss
                )
                StatCard(
                    value: routeETAText,
                    label: AppText.value(zh: "預計時間", en: "ETA"),
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

    private var navigationActions: some View {
        VStack(spacing: 10) {
            Button {
                openInMaps()
            } label: {
                Label(AppText.value(zh: "用地圖導航（步行）", en: "Navigate in Maps (Walking)"), systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                startRecordingAndOpenMaps()
            } label: {
                Label(AppText.value(zh: "用地圖導航及開始記錄", en: "Navigate and Start Recording"), systemImage: "record.circle.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(FrogTheme.moss, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
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
        guard hasLocation, let origin = locationManager.resolvedLocation else {
            statusMessage = hasLocation ? AppText.value(zh: "定位中…", en: "Locating...") : AppText.value(zh: "開啟定位以計算步行路線", en: "Enable location to calculate a walking route")
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
                    fitRouteCamera(origin: origin, route: firstRoute)
                    return
                }
            } catch {
                // Fall through to the straight-line fallback below.
            }
            // No walking route available — fall back to a straight reference line.
            fallbackLine = [origin, destination]
            statusMessage = AppText.value(zh: "未能取得步行路線，顯示直線參考", en: "Could not get a walking route. Showing a straight-line reference.")
            fitFallbackCamera(origin: origin)
        }
    }

    private func fitFallbackCamera(origin: CLLocationCoordinate2D) {
        cameraPosition = .region(regionIncluding([origin, mountain.coordinate], minimumSpan: 0.01))
    }

    private func fitRouteCamera(origin: CLLocationCoordinate2D, route: MKRoute) {
        var coordinates = [origin, mountain.coordinate]
        coordinates.append(contentsOf: route.polyline.coordinates)
        cameraPosition = .region(regionIncluding(coordinates, minimumSpan: 0.01))
    }

    private func regionIncluding(
        _ coordinates: [CLLocationCoordinate2D],
        minimumSpan: CLLocationDegrees
    ) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: mountain.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.55, minimumSpan),
                longitudeDelta: max((maxLon - minLon) * 1.55, minimumSpan)
            )
        )
    }

    private func openInMaps() {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: mountain.coordinate))
        destination.name = mountain.localizedName
        destination.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    private func startRecordingAndOpenMaps() {
        let started = recorder.start(
            mountainId: mountain.id,
            mountainName: mountain.localizedName,
            summitCoordinate: mountain.coordinate
        )
        guard started else {
            statusMessage = AppText.value(
                zh: "已有行程記錄中，請先完成或取消進行中的記錄。",
                en: "A trip is already recording. Finish or cancel it first."
            )
            return
        }
        openInMaps()
    }
}

private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var result = Array(repeating: CLLocationCoordinate2D(), count: pointCount)
        getCoordinates(&result, range: NSRange(location: 0, length: pointCount))
        return result
    }
}
