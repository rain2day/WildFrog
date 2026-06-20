import CoreLocation
import MapKit
import SwiftUI

// MARK: - CheckInPickerSegment

private enum CheckInPickerSegment: String, CaseIterable {
    case map = "地圖"
    case list = "列表"

    var title: String {
        switch self {
        case .map:
            AppText.value(zh: "地圖", en: "Map")
        case .list:
            AppText.value(zh: "列表", en: "List")
        }
    }
}

// MARK: - CheckInPickerView (replaces plain list in WildFrogRootView)

struct CheckInPickerView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var checkInStore: CheckInStore

    @State private var segment: CheckInPickerSegment = .map

    var body: some View {
        VStack(spacing: 0) {
            // Segment chip bar
            HStack(spacing: 0) {
                ForEach(CheckInPickerSegment.allCases, id: \.self) { seg in
                    Button { withAnimation(.easeInOut(duration: 0.18)) { segment = seg } } label: {
                        Text(seg.title).chipStyle(isSelected: segment == seg)
                    }
                    .buttonStyle(.plain)
                    if seg != CheckInPickerSegment.allCases.last { Spacer(minLength: 8) }
                }
            }
            .padding(.horizontal, FrogSpace.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 10)

            if segment == .map {
                CheckInMapMode()
                    .transition(.opacity)
            } else {
                CheckInListMode()
                    .transition(.opacity)
            }
        }
        .background(FrogTheme.paper.ignoresSafeArea())
        .hiddenNavigationBar()
        .withNativeRoutes()
        .onAppear {
            locationManager.requestAuthorization()
            locationManager.startUpdating()
        }
    }
}

// MARK: - Map mode

/// Full visual identity for a check-in map marker. Including visited/near in
/// `id` forces SwiftUI + MapKit to rebuild the marker when those flip —
/// otherwise the Map caches the annotation by mountain id and the pin stays
/// stale after a check-in until some unrelated change rebuilds the map.
private struct CheckInMapMarker: Identifiable {
    let mountain: Mountain
    let isVisited: Bool
    let isNear: Bool
    let isRecording: Bool
    var id: String { "\(mountain.id)|\(isVisited)|\(isNear)|\(isRecording)" }
}

private struct CheckInMapMode: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var checkInStore: CheckInStore
    @EnvironmentObject private var recorder: TrackRecorder

    @State private var selectedMountainId: String?
    @State private var didFocusNearestCheckIn = false
    @State private var didFocusActiveRecording = false
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.34, longitude: 114.16),
            span: MKCoordinateSpan(latitudeDelta: 0.36, longitudeDelta: 0.54)
        )
    )

    /// At most 40 mountains on the map — closest first, always include featured.
    private var mapMountains: [Mountain] {
        var seen = Set<String>()
        var result: [Mountain] = []

        func append(_ m: Mountain) {
            guard result.count < 40, seen.insert(m.id).inserted else { return }
            result.append(m)
        }

        // Featured always first
        MountainCatalog.featured.forEach(append)
        if let activeRecordingMountain {
            append(activeRecordingMountain)
        }

        // Then nearest by distance
        let sorted = MountainCatalog.mountains.sorted {
            let da = locationManager.distance(to: $0.coordinate)
            let db = locationManager.distance(to: $1.coordinate)
            switch (da, db) {
            case let (.some(x), .some(y)): return x < y
            case (.some, .none): return true
            case (.none, .some): return false
            default: return MountainCatalog.heightRankSortValue(for: $0.id) < MountainCatalog.heightRankSortValue(for: $1.id)
            }
        }
        sorted.forEach(append)
        return result
    }

    /// Nearest 5 get a larger highlight pin
    private var nearestIds: Set<String> {
        let sorted = mapMountains.sorted {
            let da = locationManager.distance(to: $0.coordinate)
            let db = locationManager.distance(to: $1.coordinate)
            switch (da, db) {
            case let (.some(x), .some(y)): return x < y
            case (.some, .none): return true
            case (.none, .some): return false
            default: return false
            }
        }
        return Set(sorted.prefix(5).map(\.id))
    }

    private var selectedMountain: Mountain? {
        guard let id = selectedMountainId else { return nil }
        return mapMountains.first { $0.id == id }
    }

    private var radiusMountain: Mountain? {
        selectedMountain ?? activeRecordingMountain ?? nearestMountain
    }

    private var activeRecordingMountain: Mountain? {
        guard recorder.isRecording,
              let id = recorder.activeMountainId else { return nil }
        return MountainCatalog.mountains.first { $0.id == id }
    }

    private var activeRecordingKey: String {
        recorder.isRecording ? (recorder.activeMountainId ?? "recording") : "none"
    }

    private var hasLocation: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse ||
        locationManager.authorizationStatus == .authorizedAlways
    }

    private var nearestMountain: Mountain? {
        guard locationManager.resolvedLocation != nil else { return nil }
        return MountainCatalog.mountains.min {
            let left = locationManager.distance(to: $0.coordinate) ?? .greatestFiniteMagnitude
            let right = locationManager.distance(to: $1.coordinate) ?? .greatestFiniteMagnitude
            return left < right
        }
    }

    private var locationFocusKey: String {
        guard let coordinate = locationManager.resolvedLocation?.coordinate else { return "none" }
        return String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
    }

    private var mapMarkers: [CheckInMapMarker] {
        let near = nearestIds
        return mapMountains.map {
            CheckInMapMarker(
                mountain: $0,
                isVisited: checkInStore.count(for: $0.id) > 0,
                isNear: near.contains($0.id),
                isRecording: recorder.isRecording && recorder.activeMountainId == $0.id
            )
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $mapPosition, selection: $selectedMountainId) {
                if let radiusMountain {
                    CheckInRadiusMapOverlay.circleWithLabel(center: radiusMountain.coordinate)
                }

                UserAnnotation()

                ForEach(mapMarkers) { pin in
                    Marker(
                        pin.mountain.localizedName,
                        systemImage: pin.isRecording ? "record.circle.fill" : (pin.isVisited ? "checkmark.seal.fill" : (pin.isNear ? "mappin.circle.fill" : "mappin")),
                        coordinate: pin.mountain.coordinate
                    )
                    .tint(pin.isRecording ? FrogTheme.orange : (pin.isVisited ? FrogTheme.moss : (pin.isNear ? FrogTheme.orange : FrogTheme.leaf)))
                    .tag(pin.mountain.id)
                }
            }
            .mapStyle(.standard)
            .mapControlVisibility(.hidden)
            .ignoresSafeArea(edges: .bottom)

            // Count badge (top-right corner)
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Text(AppText.peaks(mapMountains.count))
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.forest)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.88), in: Capsule())

                    Button {
                        refocusMap()
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(FrogTheme.forest)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.92), in: Circle())
                            .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppText.value(zh: "顯示我的位置", en: "Show My Location"))
                }
                .padding(.top, 12)
                .padding(.trailing, 14)
            }

            .overlay(alignment: .topLeading) {
                if let activeRecordingMountain {
                    CheckInActiveRecordingChip(
                        mountain: activeRecordingMountain,
                        elapsedSeconds: recorder.elapsedSeconds,
                        distanceMeters: recorder.distanceMeters,
                        isPaused: recorder.isPaused
                    )
                    .padding(.top, 12)
                    .padding(.leading, 14)
                    .padding(.trailing, 88)
                } else {
                    CheckInMapHint(nearestMountain: nearestMountain, hasLocation: hasLocation)
                        .padding(.top, 12)
                        .padding(.leading, 14)
                        .padding(.trailing, 88)
                }
            }

            // Selected mountain card
            if let mountain = selectedMountain {
                MapPinCard(
                    mountain: mountain,
                    visitCount: checkInStore.count(for: mountain.id),
                    isRecording: recorder.isRecording && recorder.activeMountainId == mountain.id
                ) {
                    selectedMountainId = nil
                }
                .padding(.horizontal, FrogSpace.screenPadding)
                .padding(.bottom, 110) // clear the floating tab bar at the check-in tab root
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.32, dampingFraction: 0.78), value: selectedMountainId)
            }
        }
        .onAppear {
            focusMapIfNeeded()
        }
        .onChange(of: locationFocusKey) { oldValue, _ in
            if oldValue == "none" {
                didFocusActiveRecording = false
                didFocusNearestCheckIn = false
            }
            focusMapIfNeeded()
        }
        .onChange(of: activeRecordingKey) { _, _ in
            didFocusActiveRecording = false
            focusMapIfNeeded()
        }
    }

    @discardableResult
    private func focusActiveRecordingIfNeeded() -> Bool {
        guard let activeRecordingMountain else { return false }

        if selectedMountainId == nil {
            selectedMountainId = activeRecordingMountain.id
        }

        guard !didFocusActiveRecording else { return true }
        didFocusActiveRecording = true

        var coordinates = [activeRecordingMountain.coordinate]
        if let userCoordinate = locationManager.resolvedLocation?.coordinate {
            coordinates.append(userCoordinate)
        }
        coordinates.append(contentsOf: recorder.points.map(\.coordinate))

        withAnimation(.easeInOut(duration: 0.42)) {
            mapPosition = .region(regionIncluding(coordinates, minimumSpan: 0.018))
        }
        return true
    }

    private func focusMapIfNeeded() {
        if focusActiveRecordingIfNeeded() { return }
        focusNearestCheckInLocationIfNeeded()
    }

    private func refocusMap() {
        didFocusActiveRecording = false
        didFocusNearestCheckIn = false
        focusMapIfNeeded()
    }

    private func focusNearestCheckInLocationIfNeeded() {
        guard !didFocusNearestCheckIn,
              let nearestMountain,
              let userCoordinate = locationManager.resolvedLocation?.coordinate else { return }

        didFocusNearestCheckIn = true

        withAnimation(.easeInOut(duration: 0.42)) {
            mapPosition = .region(regionIncluding([userCoordinate, nearestMountain.coordinate], minimumSpan: 0.018))
        }
    }

    private func regionIncluding(
        _ coordinates: [CLLocationCoordinate2D],
        minimumSpan: CLLocationDegrees
    ) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 22.34, longitude: 114.16),
                span: MKCoordinateSpan(latitudeDelta: 0.36, longitudeDelta: 0.54)
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
                latitudeDelta: max((maxLat - minLat) * 1.7, minimumSpan),
                longitudeDelta: max((maxLon - minLon) * 1.7, minimumSpan)
            )
        )
    }
}

private struct CheckInMapHint: View {
    let nearestMountain: Mountain?
    let hasLocation: Bool

    private var detailText: String {
        if let nearestMountain, hasLocation {
            return AppText.value(zh: "已靠近最近位置：\(nearestMountain.nameZh)", en: "Focused near \(nearestMountain.localizedName)")
        }
        return AppText.value(zh: "開啟定位後會靠近最近打卡點", en: "Enable location to focus nearby peaks")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(FrogTheme.orange)
                .frame(width: 26, height: 26)
                .background(FrogTheme.orangeSoft, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(AppText.value(zh: "點選要打卡的山峰", en: "Choose a peak to check in"))
                    .font(.frogCaption.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(detailText)
                    .font(.frogMicro.weight(.semibold))
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FrogTheme.lineSoft, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
    }
}

private struct CheckInActiveRecordingChip: View {
    let mountain: Mountain
    let elapsedSeconds: TimeInterval
    let distanceMeters: Double
    let isPaused: Bool

    var body: some View {
        NavigationLink(value: NativeRoute.checkIn(mountain.id)) {
            HStack(spacing: 9) {
                Image(systemName: isPaused ? "pause.fill" : "record.circle.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(isPaused ? FrogTheme.gold : FrogTheme.orange, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(isPaused ? AppText.value(zh: "行程已暫停", en: "Trip Paused") : AppText.value(zh: "行程記錄中", en: "Recording Trip"))
                        .font(.frogCaption.weight(.black))
                        .foregroundStyle(FrogTheme.ink)
                        .lineLimit(1)
                    Text("\(mountain.localizedName) · \(TrackFormat.distance(distanceMeters)) · \(TrackFormat.duration(elapsedSeconds))")
                        .font(.frogMicro.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FrogTheme.muted)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FrogTheme.orange.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 14, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppText.value(zh: "返回進行中的 \(mountain.localizedName) 記錄", en: "Return to active \(mountain.localizedName) recording"))
    }
}

// MARK: - Map pin card (callout)

private struct MapPinCard: View {
    let mountain: Mountain
    let visitCount: Int
    let isRecording: Bool
    let onDismiss: () -> Void

    var body: some View {
        // The whole card is tappable — tapping anywhere opens check-in.
        NavigationLink(value: NativeRoute.checkIn(mountain.id)) {
            HStack(spacing: 12) {
                MountainPhoto(mountain: mountain, dimming: 0.08)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(mountain.localizedName)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(FrogTheme.ink)
                            .lineLimit(1)
                        if visitCount > 0 {
                            Label(AppText.value(zh: "已打卡", en: "Done"), systemImage: "checkmark.seal.fill")
                                .font(.frogMicro.weight(.black))
                                .foregroundStyle(FrogTheme.moss)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(FrogTheme.leaf.opacity(0.22), in: Capsule())
                                .lineLimit(1)
                        }
                        if isRecording {
                            Label(AppText.value(zh: "記錄中", en: "Recording"), systemImage: "record.circle.fill")
                                .font(.frogMicro.weight(.black))
                                .foregroundStyle(FrogTheme.orange)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(FrogTheme.orange.opacity(0.14), in: Capsule())
                                .lineLimit(1)
                        }
                    }
                    Text(mountain.localizedSecondaryName.isEmpty ? mountain.localizedRegion : mountain.localizedSecondaryName)
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                        .lineLimit(1)
                    Label("\(mountain.height)m · \(mountain.localizedRegion)", systemImage: "triangle.fill")
                        .font(.frogMicro.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Visual CTA only — the entire card is the tap target.
                HStack(spacing: 5) {
                    Text(AppText.value(zh: "打卡", en: "Check In"))
                        .font(.frogCaption.weight(.bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(FrogTheme.orange, in: Capsule())
            }
            .padding(12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(FrogTheme.line, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FrogTheme.muted)
                    .frame(width: 26, height: 26)
                    .background(Color.white, in: Circle())
                    .overlay(Circle().stroke(FrogTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .offset(x: 7, y: -7)
            .accessibilityLabel(AppText.value(zh: "關閉", en: "Close"))
        }
    }
}

// MARK: - List mode

private struct CheckInListMode: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var checkInStore: CheckInStore

    @State private var searchText = ""
    @State private var selectedRegion = "全部"

    private var regions: [String] {
        ["全部"] + Array(Set(MountainCatalog.mountains.map(\.region))).sorted()
    }

    private var filteredMountains: [Mountain] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let preFiltered = MountainCatalog.mountains.filter { mountain in
            let matchesRegion = selectedRegion == "全部" || mountain.region == selectedRegion
            let matchesSearch = query.isEmpty ||
                mountain.nameZh.localizedCaseInsensitiveContains(query) ||
                mountain.nameEn.localizedCaseInsensitiveContains(query)
            return matchesRegion && matchesSearch
        }
        return preFiltered.sorted { a, b in
            let da = locationManager.distance(to: a.coordinate)
            let db = locationManager.distance(to: b.coordinate)
            switch (da, db) {
            case let (.some(x), .some(y)): return x < y
            case (.some, .none): return true
            case (.none, .some): return false
            default: return a.nameZh < b.nameZh
            }
        }
    }

    private var hasLocation: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse ||
        locationManager.authorizationStatus == .authorizedAlways
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(FrogTheme.muted)
                    TextField(AppText.value(zh: "搜尋山峰名稱", en: "Search peak name"), text: $searchText)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .cardStyle()
                .padding(.horizontal, FrogSpace.screenPadding)

                // Region filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(regions, id: \.self) { region in
                            Button { selectedRegion = region } label: {
                                Text(AppText.region(region)).chipStyle(isSelected: selectedRegion == region)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, FrogSpace.screenPadding)
                }

                // Location hint
                if !hasLocation {
                    HStack(spacing: 10) {
                        Image(systemName: "location.slash.fill")
                            .foregroundStyle(FrogTheme.orange)
                        Text(AppText.value(zh: "允許定位可按距離排列", en: "Allow location to sort by distance"))
                            .font(.frogCaption.weight(.semibold))
                            .foregroundStyle(FrogTheme.muted)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FrogTheme.mapWash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, FrogSpace.screenPadding)
                }

                // Result count
                HStack {
                    Text(hasLocation ? AppText.value(zh: "按距離排列", en: "Sorted by distance") : AppText.value(zh: "按名稱排列", en: "Sorted by name"))
                        .font(.frogMicro.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                    Spacer()
                    Text(AppText.peaks(filteredMountains.count))
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.moss)
                }
                .padding(.horizontal, FrogSpace.screenPadding)

                // Mountain rows
                LazyVStack(spacing: 10) {
                    ForEach(filteredMountains) { mountain in
                        NavigationLink(value: NativeRoute.checkIn(mountain.id)) {
                            CheckInPickerRow(
                                mountain: mountain,
                                distance: locationManager.distance(to: mountain.coordinate),
                                visitCount: checkInStore.count(for: mountain.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, FrogSpace.screenPadding)
                .padding(.bottom, 110)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - CheckInPickerRow (moved out of WildFrogRootView, now internal)

struct CheckInPickerRow: View {
    let mountain: Mountain
    let distance: CLLocationDistance?
    let visitCount: Int

    private var distanceText: String {
        guard let d = distance else { return "—" }
        return d < 1000 ? "\(Int(d))m" : String(format: "%.1fkm", d / 1000)
    }

    private var isVisited: Bool { visitCount > 0 }

    var body: some View {
        HStack(spacing: 14) {
            MountainPhoto(mountain: mountain, dimming: 0.08)
                .frame(width: 66, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(mountain.localizedName)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.ink)
                        .lineLimit(1)
                    if isVisited {
                        Text(AppText.value(zh: "已打卡", en: "Done"))
                            .font(.frogMicro.weight(.black))
                            .foregroundStyle(FrogTheme.forest)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(FrogTheme.leaf, in: Capsule())
                    }
                }
                Text(mountain.localizedSecondaryName)
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.forest)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Label("\(mountain.height)m", systemImage: "triangle.fill")
                        .font(.frogMicro.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                    Text("·").foregroundStyle(FrogTheme.muted).font(.frogMicro)
                    Text(mountain.localizedRegion)
                        .font(.frogMicro.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(distanceText)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(distance == nil ? FrogTheme.muted : FrogTheme.ink)
                if isVisited {
                    Text(AppText.checkIns(visitCount))
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.moss)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FrogTheme.muted)
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isVisited ? FrogTheme.moss.opacity(0.35) : FrogTheme.line, lineWidth: 1)
        )
    }
}
