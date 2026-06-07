import CoreLocation
import MapKit
import SwiftUI

// MARK: - CheckInPickerSegment

private enum CheckInPickerSegment: String, CaseIterable {
    case map = "地圖"
    case list = "列表"
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
                        Text(seg.rawValue).chipStyle(isSelected: segment == seg)
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

private struct CheckInMapMode: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var checkInStore: CheckInStore

    @State private var selectedMountainId: String?
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

        // Then nearest by distance
        let sorted = MountainCatalog.mountains.sorted {
            let da = locationManager.distance(to: $0.coordinate)
            let db = locationManager.distance(to: $1.coordinate)
            switch (da, db) {
            case let (.some(x), .some(y)): return x < y
            case (.some, .none): return true
            case (.none, .some): return false
            default: return ($0.topRank ?? 9999) < ($1.topRank ?? 9999)
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

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $mapPosition, selection: $selectedMountainId) {
                ForEach(mapMountains) { mountain in
                    let isVisited = checkInStore.count(for: mountain.id) > 0
                    let isNear = nearestIds.contains(mountain.id)
                    Marker(
                        mountain.nameZh,
                        systemImage: isVisited ? "checkmark.seal.fill" : (isNear ? "mappin.circle.fill" : "mappin"),
                        coordinate: mountain.coordinate
                    )
                    .tint(isVisited ? FrogTheme.moss : (isNear ? FrogTheme.orange : FrogTheme.leaf))
                    .tag(mountain.id)
                }
            }
            .mapStyle(.standard)
            .mapControlVisibility(.hidden)
            .ignoresSafeArea(edges: .bottom)

            // Count badge (top-right corner)
            .overlay(alignment: .topTrailing) {
                Text("\(mapMountains.count) 座")
                    .font(.frogMicro.weight(.bold))
                    .foregroundStyle(FrogTheme.forest)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.88), in: Capsule())
                    .padding(.top, 12)
                    .padding(.trailing, 14)
            }

            // Selected mountain card
            if let mountain = selectedMountain {
                MapPinCard(mountain: mountain, visitCount: checkInStore.count(for: mountain.id)) {
                    selectedMountainId = nil
                }
                .padding(.horizontal, FrogSpace.screenPadding)
                .padding(.bottom, 110) // clear the floating tab bar at the check-in tab root
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.32, dampingFraction: 0.78), value: selectedMountainId)
            }
        }
    }
}

// MARK: - Map pin card (callout)

private struct MapPinCard: View {
    let mountain: Mountain
    let visitCount: Int
    let onDismiss: () -> Void

    private var distanceText: String {
        // Access via the environment not available in private struct; computed at call site.
        // Use mountain coordinate directly is not enough — caller passes precomputed visitCount.
        // Distance shown only when available (passed via parent state).
        ""
    }

    var body: some View {
        HStack(spacing: 12) {
            MountainPhoto(mountain: mountain, dimming: 0.08)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(mountain.nameZh)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.ink)
                        .lineLimit(1)
                    if visitCount > 0 {
                        Label("已打卡", systemImage: "checkmark.seal.fill")
                            .font(.frogMicro.weight(.black))
                            .foregroundStyle(FrogTheme.moss)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(FrogTheme.leaf.opacity(0.22), in: Capsule())
                            .lineLimit(1)
                    }
                }
                Text(mountain.nameEn.isEmpty ? mountain.region : mountain.nameEn)
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
                Label("\(mountain.height)m · \(mountain.region)", systemImage: "triangle.fill")
                    .font(.frogMicro.weight(.semibold))
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(spacing: 8) {
                NavigationLink(value: NativeRoute.checkIn(mountain.id)) {
                    Text("打卡")
                        .font(.frogCaption.weight(.bold))
                        .primaryCTAStyle(cornerRadius: 12)
                        .frame(width: 56, height: 34)
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FrogTheme.muted)
                        .frame(width: 28, height: 28)
                        .background(FrogTheme.line, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(FrogTheme.line, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 6)
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
                    TextField("搜尋山峰名稱", text: $searchText)
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
                                Text(region).chipStyle(isSelected: selectedRegion == region)
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
                        Text("允許定位可按距離排列")
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
                    Text(hasLocation ? "按距離排列" : "按名稱排列")
                        .font(.frogMicro.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                    Spacer()
                    Text("\(filteredMountains.count) 座")
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
                    Text(mountain.nameZh)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.ink)
                        .lineLimit(1)
                    if isVisited {
                        Text("已打卡")
                            .font(.frogMicro.weight(.black))
                            .foregroundStyle(FrogTheme.forest)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(FrogTheme.leaf, in: Capsule())
                    }
                }
                Text(mountain.nameEn)
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.forest)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Label("\(mountain.height)m", systemImage: "triangle.fill")
                        .font(.frogMicro.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                    Text("·").foregroundStyle(FrogTheme.muted).font(.frogMicro)
                    Text(mountain.region)
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
                    Text("\(visitCount)次")
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
