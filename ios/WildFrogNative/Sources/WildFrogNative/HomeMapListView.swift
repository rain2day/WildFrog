import MapKit
import SwiftUI

struct HomeMapListView: View {
    @EnvironmentObject private var checkInStore: CheckInStore
    @EnvironmentObject private var freePhotoStore: FreePhotoStore

    @State private var searchText = ""
    @State private var selectedRegion = "全部"
    @State private var sortMode = SortMode.rank
    @State private var mapStyleHybrid = false
    @State private var heroMountainId = MountainCatalog.randomCinematicHeroMountainId()
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.34, longitude: 114.16),
            span: MKCoordinateSpan(latitudeDelta: 0.36, longitudeDelta: 0.54)
        )
    )
    @State private var selectedMarkerID: String?
    @State private var homeMapLayerState = HomeMapLayerState()
    @State private var selectedFreePhotoRecords: [FreePhotoRecord] = []
    @State private var editingFreePhotoRecord: FreePhotoRecord?
    @State private var showNeedsLocation = false

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-qaFreePhotoMap") {
            var state = HomeMapLayerState()
            state.select(.freePhotos)
            _homeMapLayerState = State(initialValue: state)
        }
        #endif
    }

    private enum SortMode: String, CaseIterable, Identifiable {
        case rank = "300峰"
        case height = "高度"
        case checked = "已打卡"
        case open = "未打卡"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .rank:
                AppText.value(zh: "300峰", en: "300 Peaks")
            case .height:
                AppText.value(zh: "高度", en: "Height")
            case .checked:
                AppText.value(zh: "已打卡", en: "Checked In")
            case .open:
                AppText.value(zh: "未打卡", en: "Open")
            }
        }
    }

    private var regions: [String] {
        ["全部"] + Array(Set(MountainCatalog.mountains.map(\.region))).sorted()
    }

    private var totalCheckIns: Int {
        checkInStore.totalCheckIns
    }

    private var recommendedMountain: Mountain {
        MountainCatalog.featured.first { !checkInStore.hasVisited(mountainId: $0.id) } ?? MountainCatalog.featured.first ?? MountainCatalog.mountain(id: heroMountainId)
    }

    private var filteredMountains: [Mountain] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = MountainCatalog.mountains.filter { mountain in
            let matchesRegion = selectedRegion == "全部" || mountain.region == selectedRegion
            let matchesSearch = query.isEmpty ||
                mountain.nameZh.localizedCaseInsensitiveContains(query) ||
                mountain.nameEn.localizedCaseInsensitiveContains(query)
            return matchesRegion && matchesSearch
        }

        switch sortMode {
        case .rank:
            return filtered.sorted {
                let r0 = MountainCatalog.heightRank(for: $0.id) ?? Int.max
                let r1 = MountainCatalog.heightRank(for: $1.id) ?? Int.max
                return r0 < r1
            }
        case .height:
            return filtered.sorted { $0.height > $1.height }
        case .checked:
            return filtered.filter { checkInStore.count(for: $0.id) > 0 }.sorted { checkInStore.count(for: $0.id) > checkInStore.count(for: $1.id) }
        case .open:
            return filtered.filter { !checkInStore.hasVisited(mountainId: $0.id) }.sorted {
                MountainCatalog.heightRankSortValue(for: $0.id) < MountainCatalog.heightRankSortValue(for: $1.id)
            }
        }
    }

    private var mapMountains: [Mountain] {
        var seen = Set<String>()
        var result: [Mountain] = []

        func append(_ mountain: Mountain) {
            guard result.count < 36, seen.insert(mountain.id).inserted else { return }
            result.append(mountain)
        }

        MountainCatalog.featured.forEach(append)
        filteredMountains.forEach(append)
        return result
    }

    var body: some View {
        GeometryReader { outer in
            let topInset = outer.safeAreaInsets.top

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroBanner(topInset: topInset)

                        VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                            mapOverview(scrollProxy: proxy)
                            recommendedCard
                            featuredRail(scrollProxy: proxy)
                            searchAndFilters
                            directoryList
                                .id("directoryAnchor")
                        }
                        .padding(FrogSpace.screenPadding)
                        .padding(.top, FrogSpace.cardGap)
                        .padding(.bottom, 110)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .hiddenNavigationBar()
        .appPageBackground(FrogTheme.warmPaper)
        .sheet(isPresented: Binding(
            get: { !selectedFreePhotoRecords.isEmpty },
            set: { if !$0 { selectedFreePhotoRecords = [] } }
        )) {
            FreePhotoMapDetailView(records: selectedFreePhotoRecords) { record in
                selectedFreePhotoRecords = []
                DispatchQueue.main.async { editingFreePhotoRecord = record }
            }
        }
        .sheet(isPresented: $showNeedsLocation) {
            FreePhotoMapDetailView(
                records: FreePhotoMapProjection(records: freePhotoStore.records).needsLocation
            ) { record in
                showNeedsLocation = false
                DispatchQueue.main.async { editingFreePhotoRecord = record }
            }
        }
        .sheet(item: $editingFreePhotoRecord) { record in
            FreePhotoManualLocationPicker(record: record) { coordinate in
                try? freePhotoStore.setManualLocation(recordID: record.id, coordinate: coordinate)
            }
        }
    }

    private func heroBanner(topInset: CGFloat) -> some View {
        let ratio = min(1, Double(conqueredCount) / Double(max(1, MountainCatalog.catalogCount)))
        return ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: MountainCatalog.mountain(id: heroMountainId), dimming: 0)

            // One layered gradient — keep the photo readable top, anchor it bottom.
            LinearGradient(
                colors: [
                    Color.black.opacity(0.36),
                    Color.black.opacity(0.05),
                    FrogTheme.forest.opacity(0.62),
                    Color.black.opacity(0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    WildFrogWordmark(markSize: 30)
                        .shadow(color: Color.black.opacity(0.28), radius: 8, y: 3)

                    Spacer()
                }
                .padding(.top, topInset + 8)

                Spacer(minLength: 18)

                ZStack(alignment: .bottomLeading) {
                    // Height near the art's natural aspect (≈ width / 2.25) so the
                    // massif keeps its real shape instead of stretching into a flat
                    // "cut" mesa; full-width + flush on the bar, peak fully visible.
                    ConquestMountainBackdrop(progress: ratio)
                        .frame(height: 158)

                    // Eyebrow rides right above the number so it reads as a kicker
                    // on the stat instead of floating at the top of the massif.
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppText.value(zh: "已征服 · CONQUERED", en: "CONQUERED"))
                            .font(.frogEyebrow)
                            .tracking(1.8)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.72))

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(conqueredCount)")
                                .font(.frogNum(74, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("/ \(MountainCatalog.catalogCount)")
                                .font(.frogNum(20, weight: .medium))
                                .foregroundStyle(.white.opacity(0.74))
                                .padding(.bottom, 9)
                        }
                    }
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                }
                .padding(.top, 6)

                // Progress bar the mountain's base sits flush on.
                ConquestProgressBar(progress: ratio)
                    .padding(.top, 1)

                HStack {
                    Text(AppText.value(
                        zh: "仲有 \(max(0, MountainCatalog.catalogCount - conqueredCount)) 座未征服",
                        en: "\(max(0, MountainCatalog.catalogCount - conqueredCount)) peaks left"
                    ))
                        .font(.frogCaption)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text("\(Int(ratio * 100))%")
                        .font(.frogNum(14, weight: .semibold))
                        .foregroundStyle(FrogTheme.leaf)
                }
                .padding(.top, 10)

                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 1)
                    .padding(.top, 18)

                HStack(spacing: 0) {
                    statBandItem(value: totalAscent.formatted(), unit: "m", label: AppText.value(zh: "累計海拔", en: "Elevation"))
                    statBandDivider
                    statBandItem(value: "\(totalCheckIns)", unit: AppText.value(zh: "次", en: ""), label: AppText.value(zh: "打卡", en: "Check-ins"))
                    statBandDivider
                    statBandItem(value: "\(checkInStore.currentStreak)", unit: AppText.value(zh: "日", en: "d"), label: AppText.value(zh: "連續", en: "Streak"))
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, FrogSpace.screenPadding + 4)
            .padding(.bottom, 22)
        }
        .frame(height: topInset + 440)
        .clipped()
    }

    /// Marker identity includes visited state so the Map rebuilds the pin when a
    /// mountain is checked in — without this, MapKit caches the annotation by
    /// mountain id and the pin stays stale after returning from check-in.
    private struct HomeMapMarker: Identifiable {
        let mountain: Mountain
        let isVisited: Bool
        var id: String { "\(mountain.id)|\(isVisited)" }
    }

    private var mapMarkers: [HomeMapMarker] {
        mapMountains.map { HomeMapMarker(mountain: $0, isVisited: checkInStore.hasVisited(mountainId: $0.id)) }
    }

    private func mapOverview(scrollProxy: ScrollViewProxy) -> some View {
        let projection = FreePhotoMapProjection(records: freePhotoStore.records)
        return VStack(spacing: 10) {
            Picker(AppText.value(zh: "地圖圖層", en: "Map Layer"), selection: Binding(
                get: { homeMapLayerState.layer },
                set: { homeMapLayerState.select($0) }
            )) {
                ForEach(HomeMapLayer.allCases) { layer in
                    Text(layer.title).tag(layer)
                }
            }
            .pickerStyle(.segmented)

            ZStack(alignment: .topLeading) {
                if homeMapLayerState.showsPeakMarkers {
                    Map(position: $mapPosition, selection: $selectedMarkerID) {
                        ForEach(mapMarkers) { pin in
                            Marker(pin.mountain.localizedName, systemImage: pin.isVisited ? "checkmark.circle.fill" : "mappin", coordinate: pin.mountain.coordinate)
                                .tint(pin.isVisited ? FrogTheme.orange : FrogTheme.moss)
                                .tag(pin.id)
                        }
                    }
                    .mapStyle(mapStyleHybrid ? .hybrid : .standard)
                    .mapControlVisibility(.hidden)
                } else if projection.located.isEmpty {
                    ZStack {
                        LinearGradient(colors: [FreePhotoPalette.mist, .white], startPoint: .top, endPoint: .bottom)
                        VStack(spacing: 12) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundStyle(FreePhotoPalette.blue)
                            Text(AppText.value(zh: "你的自由拍地圖仍然係空白", en: "Your Free Photo map is empty"))
                                .font(.frogTitle)
                                .foregroundStyle(FreePhotoPalette.navy)
                            NavigationLink(value: NativeRoute.freePhoto) {
                                Text(AppText.value(zh: "開始自由拍", en: "Start Free Photo"))
                                    .font(.frogCaption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 11)
                                    .background(FreePhotoPalette.navy, in: Capsule())
                            }
                        }
                    }
                } else {
                    FreePhotoMapView(
                        records: projection.located,
                        thumbnailURL: { freePhotoStore.thumbnailURL(for: $0) },
                        mapType: mapStyleHybrid ? .hybrid : .standard
                    ) { records in
                        selectedFreePhotoRecords = records
                    }
                }

                HStack {
                    Label(
                        homeMapLayerState.showsPeakMarkers
                            ? AppText.value(zh: "山峰地圖", en: "Peak Map")
                            : AppText.value(zh: "我的自由拍", en: "My Free Photos"),
                        systemImage: homeMapLayerState.showsPeakMarkers ? "mountain.2.fill" : "photo.on.rectangle.angled"
                    )
                    .font(.frogCaption.weight(.bold))
                    .foregroundStyle(homeMapLayerState.showsPeakMarkers ? FrogTheme.forest : FreePhotoPalette.navy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.92), in: Capsule())
                    Spacer()
                    Text("\(homeMapLayerState.showsPeakMarkers ? mapMountains.count : projection.located.count)")
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.forest)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.86), in: Capsule())
                }
                .padding(12)

                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        if homeMapLayerState.showsPeakMarkers {
                            Button {
                                withAnimation { scrollProxy.scrollTo("directoryAnchor", anchor: .top) }
                            } label: {
                                Text(AppText.value(zh: "睇晒全部山峰", en: "All Peaks"))
                                    .font(.frogCaption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.62), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        } else if !projection.needsLocation.isEmpty {
                            Button { showNeedsLocation = true } label: {
                                Label(
                                    AppText.value(
                                        zh: "\(projection.needsLocation.count) 張需要位置",
                                        en: "\(projection.needsLocation.count) need a location"
                                    ),
                                    systemImage: "mappin.slash"
                                )
                                .font(.frogCaption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(FreePhotoPalette.navy.opacity(0.9), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()
                        Button { mapStyleHybrid.toggle() } label: {
                            MapFloatingButton(systemImage: mapStyleHybrid ? "map.fill" : "square.3.layers.3d")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                }

                if homeMapLayerState.showsPeakMarkers,
                   let markerID = selectedMarkerID,
                   let mountainID = markerID.split(separator: "|").first.map(String.init),
                   let mountain = MountainCatalog.mountains.first(where: { $0.id == mountainID }) {
                    VStack {
                        Spacer()
                        MapPinCalloutCard(mountain: mountain) { selectedMarkerID = nil }
                            .padding(12)
                    }
                }
            }
            .frame(height: 410)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(10)
        .paperCardStyle()
    }

    private var conqueredCount: Int { checkInStore.distinctMountainCount }

    /// Cumulative summit elevation across distinct conquered peaks — a "Strava-style"
    /// flex stat for the bold sporty hero.
    private var totalAscent: Int {
        Set(checkInStore.records.map(\.mountainId)).reduce(0) { sum, id in
            sum + MountainCatalog.mountain(id: id).height
        }
    }

    /// One stat figure for the in-hero stat row (累計海拔 / 打卡 / 連續).
    private func statBandItem(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.frogNum(27, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(unit)
                    .font(.frogNum(12, weight: .semibold))
                    .foregroundStyle(FrogTheme.leaf)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
    }

    private var statBandDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 32)
    }

    private var recommendedCard: some View {
        NavigationLink(value: NativeRoute.mountainDetail(recommendedMountain.id)) {
            HStack(spacing: 12) {
                MountainPhoto(mountain: recommendedMountain, dimming: 0.08)
                    .frame(width: 96, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(AppText.value(zh: "推薦下一座", en: "Next Recommendation"))
                        .font(.frogEyebrow)
                        .tracking(0.5)
                        .foregroundStyle(FrogTheme.orange)
                    Text(recommendedMountain.localizedName)
                        .font(.frogRow)
                        .foregroundStyle(FrogTheme.ink)
                        .lineLimit(1)
                    Text("\(recommendedMountain.localizedRegion) · \(recommendedMountain.height)m · \(recommendedMountain.localizedRankText)")
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(FrogTheme.moss, in: Circle())
            }
            .padding(11)
            .cardStyle(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    private func featuredRail(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(AppText.value(zh: "精選推介", en: "Featured Peaks"))
                    .font(.frogTitle)
                    .foregroundStyle(FrogTheme.ink)
                Spacer()
                Button {
                    withAnimation {
                        scrollProxy.scrollTo("directoryAnchor", anchor: .top)
                    }
                } label: {
                    Text(AppText.value(zh: "全部", en: "All"))
                        .font(.frogCaption.weight(.bold))
                        .foregroundStyle(FrogTheme.moss)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(MountainCatalog.featured) { mountain in
                        NavigationLink(value: NativeRoute.mountainDetail(mountain.id)) {
                            FeaturedMountainCard(mountain: mountain)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var searchAndFilters: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(FrogTheme.faint)
                TextField(AppText.value(zh: "搜尋山峰", en: "Search peaks"), text: $searchText)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(FrogTheme.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(FrogTheme.line, lineWidth: 1)
            )

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
            }
        }
    }

    private var directoryList: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DIRECTORY")
                        .font(.frogEyebrow)
                        .tracking(1.4)
                        .foregroundStyle(FrogTheme.moss)
                    Text(AppText.value(
                        zh: "山峰列表 \(filteredMountains.count) / \(MountainCatalog.catalogCount)",
                        en: "Peak Directory \(filteredMountains.count) / \(MountainCatalog.catalogCount)"
                    ))
                        .font(.frogTitle)
                }

                Spacer()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(SortMode.allCases) { mode in
                            Button { sortMode = mode } label: {
                                Text(mode.title).chipStyle(isSelected: sortMode == mode)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: 210)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 8)

            ForEach(filteredMountains.prefix(8)) { mountain in
                NavigationLink(value: NativeRoute.mountainDetail(mountain.id)) {
                    MountainDirectoryRow(mountain: mountain)
                }
                .buttonStyle(.plain)
            }

            NavigationLink(value: NativeRoute.allMountains) {
                HStack(spacing: 6) {
                    Text(AppText.value(zh: "睇晒全部 \(MountainCatalog.catalogCount) 座", en: "View all \(MountainCatalog.catalogCount) peaks"))
                        .font(.frogCaption.weight(.bold))
                        .foregroundStyle(FrogTheme.forest)
                    Image(systemName: "arrow.right")
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.moss)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .overlay(alignment: .top) {
                    Rectangle().fill(FrogTheme.lineSoft).frame(height: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct MapFloatingButton: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(FrogTheme.forest)
            .frame(width: 46, height: 46)
            .background(Color.white.opacity(0.92), in: Circle())
            .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
    }
}

private struct FeaturedMountainCard: View {
    let mountain: Mountain

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: mountain, dimming: 0.18)

            LinearGradient(
                colors: [.clear, FrogTheme.forest.opacity(0.84)],
                startPoint: .top,
                endPoint: .bottom
            )

            Text(mountain.rankText)
                .font(.frogMicro.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(FrogTheme.forest.opacity(0.66), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(9)

            VStack(alignment: .leading, spacing: 2) {
                Text(mountain.localizedName)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Text("\(mountain.height)m · \(mountain.localizedRegion)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
            .padding(11)
        }
        .foregroundStyle(.white)
        .frame(width: 122, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: FrogTheme.forest.opacity(0.16), radius: 12, x: 0, y: 7)
    }
}

private struct MountainDirectoryRow: View {
    let mountain: Mountain
    @EnvironmentObject private var checkInStore: CheckInStore

    private var rankLabel: String {
        MountainCatalog.heightRank(for: mountain.id).map(String.init) ?? "–"
    }

    private var myCheckIns: Int { checkInStore.count(for: mountain.id) }

    var body: some View {
        HStack(spacing: 11) {
            Text(rankLabel)
                .font(.frogNum(13, weight: .semibold))
                .foregroundStyle(FrogTheme.faint)
                .frame(width: 24)

            MountainThumbnail(mountain: mountain, size: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(mountain.localizedName)
                    .font(.frogRow)
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                Text("\(mountain.localizedRegion) · \(mountain.height)m")
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
            }

            Spacer()

            if myCheckIns > 0 {
                Text(AppText.checkIns(myCheckIns))
                    .font(.frogMicro)
                    .foregroundStyle(FrogTheme.moss)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(FrogTheme.mossSoft, in: Capsule())
            } else {
                Text(AppText.value(zh: "未打卡", en: "Open"))
                    .font(.frogMicro)
                    .foregroundStyle(FrogTheme.faint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(FrogTheme.ink.opacity(0.05), in: Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FrogTheme.faint)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 11)
        .frame(minHeight: FrogSpace.rowMinHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FrogTheme.lineSoft)
                .frame(height: 1)
        }
    }
}

// MARK: - Map pin callout card

private struct MapPinCalloutCard: View {
    let mountain: Mountain
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            MountainThumbnail(mountain: mountain, size: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(mountain.localizedName)
                    .font(.frogRow.bold())
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                Text("\(mountain.height)m · \(mountain.localizedRegion)")
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            NavigationLink(value: NativeRoute.mountainDetail(mountain.id)) {
                Text(AppText.value(zh: "查看詳情", en: "Details"))
                    .font(.frogCaption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(FrogTheme.orange, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FrogTheme.muted)
                    .frame(width: 26, height: 26)
                    .background(FrogTheme.ink.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(FrogTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
    }
}

/// Full 330-peak directory — the "see all" destination (Preview → full-screen
/// list pattern). Search + status filter pinned on top; rows grouped into
/// region sections with sticky headers so a long list stays navigable.
struct MountainDirectoryView: View {
    @EnvironmentObject private var checkInStore: CheckInStore
    @State private var searchText = ""
    @State private var status: StatusFilter = .all

    private enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "全部", done = "已打卡", open = "未打卡"
        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                AppText.value(zh: "全部", en: "All")
            case .done:
                AppText.value(zh: "已打卡", en: "Done")
            case .open:
                AppText.value(zh: "未打卡", en: "Open")
            }
        }
    }

    private var filtered: [Mountain] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return MountainCatalog.mountains.filter { mountain in
            let matchesStatus: Bool
            switch status {
            case .all: matchesStatus = true
            case .done: matchesStatus = checkInStore.hasVisited(mountainId: mountain.id)
            case .open: matchesStatus = !checkInStore.hasVisited(mountainId: mountain.id)
            }
            let matchesSearch = query.isEmpty ||
                mountain.nameZh.localizedCaseInsensitiveContains(query) ||
                mountain.nameEn.localizedCaseInsensitiveContains(query)
            return matchesStatus && matchesSearch
        }
    }

    private var grouped: [(region: String, peaks: [Mountain])] {
        Dictionary(grouping: filtered, by: { $0.region })
            .map { (region: $0.key, peaks: $0.value.sorted {
                MountainCatalog.heightRankSortValue(for: $0.id) < MountainCatalog.heightRankSortValue(for: $1.id)
            }) }
            .sorted { $0.peaks.count > $1.peaks.count }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(grouped, id: \.region) { group in
                    Section {
                        ForEach(group.peaks) { mountain in
                            NavigationLink(value: NativeRoute.mountainDetail(mountain.id)) {
                                MountainDirectoryRow(mountain: mountain)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text(AppText.region(group.region))
                                .font(.frogEyebrow)
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .foregroundStyle(FrogTheme.moss)
                            Spacer()
                            Text("\(group.peaks.count)")
                                .font(.frogNum(12, weight: .semibold))
                                .foregroundStyle(FrogTheme.faint)
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 9)
                        .background(FrogTheme.warmPaper)
                    }
                }

                if filtered.isEmpty {
                    Text(AppText.value(zh: "搵唔到符合嘅山峰", en: "No matching peaks"))
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, FrogSpace.screenPadding)
            .padding(.bottom, 40)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(FrogTheme.faint)
                    TextField(AppText.value(zh: "搜尋 \(MountainCatalog.catalogCount) 座山峰", en: "Search \(MountainCatalog.catalogCount) peaks"), text: $searchText)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(FrogTheme.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(FrogTheme.line, lineWidth: 1))

                HStack(spacing: 8) {
                    ForEach(StatusFilter.allCases) { option in
                        Button { status = option } label: {
                            Text(option.title).chipStyle(isSelected: status == option)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, FrogSpace.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(FrogTheme.warmPaper)
        }
        .localizedNavigationTitle { AppText.value(zh: "山峰列表", en: "Peak Directory") }
        .nativeInlineTitle()
        .background(FrogTheme.warmPaper)
    }
}

// MARK: - Conquest mountain silhouette (real reference art, filled by progress)

/// Conquest as a *surveyed massif* sitting behind the headline number (no box —
/// straight on the photo). Built in layers for crafted depth, all from the same
/// reference ridge art (`ConquestRidge`):
///   • a faint parallax ridge offset behind for atmosphere,
///   • the full unconquered range as a hairline-crested ghost,
///   • the conquered region revealed left→right with a leaf→moss fill, charted
///     with topographic contour lines, a summit glow on its crest, and a soft
///     mist where the slope meets the survey baseline.
/// Sized + bottom-anchored by its parent. The art's flat base keeps the massif
/// flush on the progress bar; the peak stays fully inside the band.
private struct ConquestMountainBackdrop: View {
    var progress: Double

    private var clamped: CGFloat { CGFloat(max(0, min(1, progress))) }

    private func ridge(_ w: CGFloat, _ h: CGFloat) -> some View {
        Image("ConquestRidge")
            .renderingMode(.template)
            .resizable()
            .frame(width: w, height: h)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let fillWidth = clamped * w
            let silhouette = ridge(w, h)

            ZStack(alignment: .bottomLeading) {
                // 1 — Lit crest: a brighter silhouette nudged up a hair so a
                // thin bright ridgeline peeks above the body drawn over it.
                silhouette
                    .foregroundStyle(.white.opacity(0.5))
                    .offset(y: -1.6)

                // 2 — The full massif as an unsurveyed blueprint: a soft body
                // (lighter toward the crest) plus a contour-line texture. Reads
                // as charted terrain at ANY progress; the conquered swath
                // (layer 3) just lights it up in green.
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [.white.opacity(0.22), .white.opacity(0.11)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(width: w, height: h)
                    FrogContourLines(color: .white.opacity(0.13), lineWidth: 0.8)
                        .frame(width: w, height: h)
                }
                .frame(width: w, height: h, alignment: .bottomLeading)
                .mask { silhouette }

                // 3 — Conquered region, revealed left→right by progress.
                ZStack(alignment: .bottomLeading) {
                    // Saturated leaf→moss→forest body.
                    LinearGradient(
                        colors: [FrogTheme.leaf, FrogTheme.moss, FrogTheme.forest],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(width: w, height: h)

                    // Brighter contour texture on the charted side.
                    FrogContourLines(color: .white.opacity(0.20), lineWidth: 1)
                        .frame(width: w, height: h)

                    // Summit light grazing the upper slopes toward the crest.
                    LinearGradient(
                        colors: [.white.opacity(0.40), .clear],
                        startPoint: .top, endPoint: .center
                    )
                    .frame(width: w, height: h)

                    // Mist where the slope settles onto the survey baseline.
                    LinearGradient(
                        colors: [.clear, FrogTheme.warmPaper.opacity(0.14)],
                        startPoint: .center, endPoint: .bottom
                    )
                    .frame(width: w, height: h)
                }
                .frame(width: w, height: h, alignment: .bottomLeading)
                .mask { silhouette }                            // shaped to the ridge
                .mask(alignment: .leading) {                    // revealed by progress
                    Rectangle().frame(width: max(fillWidth, 1))
                }

                // 4 — Survey frontier: a gold tick marking exactly how far the
                // charted terrain reaches up the slope.
                if clamped > 0.015 && clamped < 0.99 {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, FrogTheme.gold.opacity(0.6), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 1.5, height: h * 0.8)
                        .offset(x: fillWidth - 0.75)
                        .blendMode(.screen)
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.45), value: progress)
    }
}

/// Survey-baseline progress track at the foot of the massif — the explicit
/// "how far to 330". A slim recessed channel with chainage ticks at the thirds
/// (110 / 220 / 330), a leaf→moss fill, and a small gold trig-point seal riding
/// the fill's leading edge like a surveyor's marker planted at the frontier.
private struct ConquestProgressBar: View {
    var progress: Double

    private var clamped: CGFloat { CGFloat(max(0, min(1, progress))) }
    private let barHeight: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fill = max(barHeight, w * clamped)

            ZStack(alignment: .leading) {
                // Recessed channel.
                Capsule()
                    .fill(Color.black.opacity(0.22))
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                    )

                // Chainage ticks at the thirds — survey baseline marks.
                ForEach([1, 2], id: \.self) { i in
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 1.5, height: barHeight - 2)
                        .offset(x: w * CGFloat(i) / 3 - 0.75)
                }

                // Charted fill.
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [FrogTheme.leaf, FrogTheme.moss],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: fill)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1.5)
                            .padding(.horizontal, 2)
                    }

                // Trig-point seal planted at the frontier of progress. Sits ON
                // the bar (below the numeral) so it never collides with "16".
                TrigPointSeal()
                    .frame(width: 13, height: 13)
                    .offset(x: min(fill, w) - 6.5)
            }
        }
        .frame(height: barHeight)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.45), value: progress)
    }
}

/// A surveyor's trig-point marker: a gold-rimmed disc with an inner triangle —
/// the seal motif used across the app, miniaturised to ride the progress edge.
private struct TrigPointSeal: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(FrogTheme.warmPaper)
                .overlay(Circle().stroke(FrogTheme.gold, lineWidth: 1.4))
            WildFrogMark()
                .fill(FrogTheme.forest)
                .padding(2.8)
        }
        .shadow(color: .black.opacity(0.35), radius: 2.5, y: 1)
    }
}
