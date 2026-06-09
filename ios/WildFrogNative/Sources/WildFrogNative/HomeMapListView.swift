import MapKit
import SwiftUI

struct HomeMapListView: View {
    @EnvironmentObject private var checkInStore: CheckInStore

    @State private var searchText = ""
    @State private var selectedRegion = "全部"
    @State private var sortMode = SortMode.rank
    @State private var showNotifications = false
    @State private var mapStyleHybrid = false
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.34, longitude: 114.16),
            span: MKCoordinateSpan(latitudeDelta: 0.36, longitudeDelta: 0.54)
        )
    )

    private enum SortMode: String, CaseIterable, Identifiable {
        case rank = "300峰"
        case height = "高度"
        case checked = "已打卡"
        case open = "未打卡"

        var id: String { rawValue }
    }

    private var regions: [String] {
        ["全部"] + Array(Set(MountainCatalog.mountains.map(\.region))).sorted()
    }

    private var totalCheckIns: Int {
        checkInStore.totalCheckIns
    }

    private var recommendedMountain: Mountain {
        MountainCatalog.featured.first { !checkInStore.hasVisited(mountainId: $0.id) } ?? MountainCatalog.featured.first ?? MountainCatalog.mountain(id: "tai-mo-shan")
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
            return filtered.sorted { ($0.topRank ?? 9999, -$0.height) < ($1.topRank ?? 9999, -$1.height) }
        case .height:
            return filtered.sorted { $0.height > $1.height }
        case .checked:
            return filtered.filter { checkInStore.count(for: $0.id) > 0 }.sorted { checkInStore.count(for: $0.id) > checkInStore.count(for: $1.id) }
        case .open:
            return filtered.filter { !checkInStore.hasVisited(mountainId: $0.id) }.sorted { ($0.topRank ?? 9999) < ($1.topRank ?? 9999) }
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
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
    }

    private func heroBanner(topInset: CGFloat) -> some View {
        let ratio = min(1, Double(conqueredCount) / Double(max(1, MountainCatalog.catalogCount)))
        return ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: MountainCatalog.mountain(id: "tai-mo-shan"), dimming: 0)

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

                    Button { showNotifications = true } label: {
                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.13), in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("通知")
                }
                .padding(.top, topInset + 8)

                Spacer(minLength: 18)

                Text("已征服 · CONQUERED")
                    .font(.frogEyebrow)
                    .tracking(1.8)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.6))

                ZStack(alignment: .bottomLeading) {
                    ConquestMountainBackdrop(progress: ratio)
                        .frame(height: 118)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(conqueredCount)")
                            .font(.frogNum(74, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("/ \(MountainCatalog.catalogCount)")
                            .font(.frogNum(20, weight: .medium))
                            .foregroundStyle(.white.opacity(0.74))
                            .padding(.bottom, 9)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                }
                .padding(.top, 6)

                HStack {
                    Text("仲有 \(max(0, MountainCatalog.catalogCount - conqueredCount)) 座未征服")
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
                    statBandItem(value: totalAscent.formatted(), unit: "m", label: "累計海拔")
                    statBandDivider
                    statBandItem(value: "\(totalCheckIns)", unit: "次", label: "打卡")
                    statBandDivider
                    statBandItem(value: "\(checkInStore.currentStreak)", unit: "日", label: "連續")
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
        ZStack(alignment: .topLeading) {
            Map(position: $mapPosition) {
                ForEach(mapMarkers) { pin in
                    Marker(pin.mountain.nameZh, systemImage: pin.isVisited ? "checkmark.circle.fill" : "mappin", coordinate: pin.mountain.coordinate)
                        .tint(pin.isVisited ? FrogTheme.orange : FrogTheme.moss)
                }
            }
            .mapStyle(mapStyleHybrid ? .hybrid : .standard)
            .mapControlVisibility(.hidden)
            .frame(height: 410)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack {
                Label("山峰地圖", systemImage: "map.fill")
                    .font(.frogCaption.weight(.bold))
                    .foregroundStyle(FrogTheme.forest)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.92), in: Capsule())
                Spacer()
                Text("\(mapMountains.count)")
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
                    Button {
                        withAnimation {
                            scrollProxy.scrollTo("directoryAnchor", anchor: .top)
                        }
                    } label: {
                        Text("睇晒全部山峰")
                            .font(.frogCaption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.62), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 10) {
                        Button {
                            withAnimation {
                                mapPosition = .region(
                                    MKCoordinateRegion(
                                        center: CLLocationCoordinate2D(latitude: 22.34, longitude: 114.16),
                                        span: MKCoordinateSpan(latitudeDelta: 0.36, longitudeDelta: 0.54)
                                    )
                                )
                            }
                        } label: {
                            MapFloatingButton(systemImage: "location.north.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("重置地圖")

                        Button {
                            mapStyleHybrid.toggle()
                        } label: {
                            MapFloatingButton(systemImage: mapStyleHybrid ? "map.fill" : "square.3.layers.3d")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(mapStyleHybrid ? "標準地圖" : "衛星地圖")
                    }
                }
                .padding(12)
            }
        }
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
                    Text("推薦下一座")
                        .font(.frogEyebrow)
                        .tracking(0.5)
                        .foregroundStyle(FrogTheme.orange)
                    Text(recommendedMountain.displayName)
                        .font(.frogRow)
                        .foregroundStyle(FrogTheme.ink)
                        .lineLimit(1)
                    Text("\(recommendedMountain.region) · \(recommendedMountain.height)m · \(recommendedMountain.rankText)")
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
                Text("精選推介")
                    .font(.frogTitle)
                    .foregroundStyle(FrogTheme.ink)
                Spacer()
                Button {
                    withAnimation {
                        scrollProxy.scrollTo("directoryAnchor", anchor: .top)
                    }
                } label: {
                    Text("全部")
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
                TextField("搜尋山峰", text: $searchText)
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
                            Text(region).chipStyle(isSelected: selectedRegion == region)
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
                    Text("山峰列表 \(filteredMountains.count) / \(MountainCatalog.catalogCount)")
                        .font(.frogTitle)
                }

                Spacer()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(SortMode.allCases) { mode in
                            Button { sortMode = mode } label: {
                                Text(mode.rawValue).chipStyle(isSelected: sortMode == mode)
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
                    Text("睇晒全部 \(MountainCatalog.catalogCount) 座")
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
                Text(mountain.nameZh)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Text("\(mountain.height)m · \(mountain.region)")
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
        if let rank = mountain.topRank { return "\(rank)" }
        return "–"
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
                Text(mountain.displayName)
                    .font(.frogRow)
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                Text("\(mountain.region) · \(mountain.height)m")
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
            }

            Spacer()

            if myCheckIns > 0 {
                Text("\(myCheckIns) 次")
                    .font(.frogMicro)
                    .foregroundStyle(FrogTheme.moss)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(FrogTheme.mossSoft, in: Capsule())
            } else {
                Text("未打卡")
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
            .map { (region: $0.key, peaks: $0.value.sorted { ($0.topRank ?? 9999) < ($1.topRank ?? 9999) }) }
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
                            Text(group.region)
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
                    Text("搵唔到符合嘅山峰")
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
                    TextField("搜尋 \(MountainCatalog.catalogCount) 座山峰", text: $searchText)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(FrogTheme.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(FrogTheme.line, lineWidth: 1))

                HStack(spacing: 8) {
                    ForEach(StatusFilter.allCases) { option in
                        Button { status = option } label: {
                            Text(option.rawValue).chipStyle(isSelected: status == option)
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
        .navigationTitle("山峰列表")
        .nativeInlineTitle()
        .background(FrogTheme.warmPaper)
    }
}

// MARK: - Conquest mountain silhouette (real reference art, filled by progress)

/// Conquest as a smooth, natural mountain silhouette that sits BEHIND the headline
/// number (no background box — straight on the photo). Uses the real reference
/// silhouette art (`ConquestRidge`, a soft organic range): a faint full range,
/// with the peaks up to the conquered % filled left-to-right with the leaf→moss
/// gradient. Sized + bottom-anchored by its parent.
private struct ConquestMountainBackdrop: View {
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let fillWidth = CGFloat(max(0, min(1, progress))) * w
            // Stretched to fill the band exactly (full width, parent-controlled
            // height) so the peak hugs the number instead of being pinned to the
            // art's natural aspect — a slightly flatter ridge still reads natural.
            let silhouette = Image("ConquestRidge")
                .renderingMode(.template)
                .resizable()
                .frame(width: w, height: h)

            silhouette
                .foregroundStyle(.white.opacity(0.22))          // faint full range
                .overlay(alignment: .leading) {
                    LinearGradient(
                        colors: [FrogTheme.leaf, FrogTheme.moss],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(width: w, height: h)
                    .mask { silhouette }                        // shaped to the ridge
                    .mask(alignment: .leading) {                // revealed by progress
                        Rectangle().frame(width: fillWidth)
                    }
                }
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.4), value: progress)
    }
}
