import MapKit
import SwiftUI

struct HomeMapListView: View {
    @EnvironmentObject private var checkInStore: CheckInStore

    @State private var searchText = ""
    @State private var selectedRegion = "全部"
    @State private var sortMode = SortMode.rank
    @State private var showNotifications = false
    @State private var mapStyleHybrid = false
    @State private var displayedCount = 40
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

    private var checkedMountains: [Mountain] {
        MountainCatalog.mountains.filter { $0.checkIns > 0 }
    }

    private var totalCheckIns: Int {
        checkInStore.totalCheckIns
    }

    private var summitPoints: Int {
        checkedMountains.reduce(0) { $0 + $1.height }
    }

    private var recommendedMountain: Mountain {
        MountainCatalog.featured.first { $0.checkIns == 0 } ?? MountainCatalog.featured.first ?? MountainCatalog.mountain(id: "tai-mo-shan")
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
            return filtered.filter { $0.checkIns > 0 }.sorted { $0.checkIns > $1.checkIns }
        case .open:
            return filtered.filter { $0.checkIns == 0 }.sorted { ($0.topRank ?? 9999) < ($1.topRank ?? 9999) }
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
                            statsStrip
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
        .nativeInlineTitle()
        .appPageBackground(FrogTheme.warmPaper)
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
    }

    private func heroBanner(topInset: CGFloat) -> some View {
        let ratio = min(1, Double(conqueredCount) / Double(max(1, MountainCatalog.catalogCount)))
        return ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: MountainCatalog.mountain(id: "tai-mo-shan"), dimming: 0)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    WildFrogBrandMark(size: 30, cornerRadius: 8)
                    Text("WILDFROG")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white)

                    Spacer()

                    Button { showNotifications = true } label: {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("通知")
                }
                .padding(.top, topInset + 8)

                Spacer(minLength: 18)

                Text("已征服香港山峰")
                    .font(.frogEyebrow)
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.85))

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(conqueredCount)")
                        .font(.system(size: 86, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ \(MountainCatalog.catalogCount)")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.22))
                        Capsule().fill(FrogTheme.orange)
                            .frame(width: max(10, geo.size.width * ratio))
                    }
                }
                .frame(height: 10)
                .padding(.top, 14)

                HStack {
                    Text("仲有 \(max(0, MountainCatalog.catalogCount - conqueredCount)) 座未征服")
                        .font(.frogCaption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                    Spacer()
                    Text("\(Int(ratio * 100))%")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.orange)
                }
                .padding(.top, 9)
            }
            .padding(.horizontal, FrogSpace.screenPadding)
            .padding(.bottom, 22)
        }
        .frame(height: topInset + 330)
        .clipped()
    }

    private func mapOverview(scrollProxy: ScrollViewProxy) -> some View {
        ZStack(alignment: .topLeading) {
            Map(position: $mapPosition) {
                ForEach(mapMountains) { mountain in
                    Marker(mountain.nameZh, systemImage: mountain.checkIns > 0 ? "checkmark.circle.fill" : "mappin", coordinate: mountain.coordinate)
                        .tint(mountain.checkIns > 0 ? FrogTheme.orange : FrogTheme.leaf)
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

    private var statsStrip: some View {
        HStack(spacing: 0) {
            heroStat(value: totalAscent.formatted(), unit: "m", label: "累計海拔")
            heroStatDivider
            heroStat(value: "\(totalCheckIns)", unit: "次", label: "打卡")
            heroStatDivider
            heroStat(value: "\(checkInStore.currentStreak)", unit: "日", label: "連續")
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(FrogTheme.forest, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: FrogTheme.forest.opacity(0.3), radius: 20, x: 0, y: 12)
    }

    private func heroStat(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(unit)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(FrogTheme.orange)
            }
            Text(label)
                .font(.frogCaption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private var heroStatDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(width: 1, height: 38)
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
                    .frame(width: 42, height: 42)
                    .background(FrogTheme.orange, in: Circle())
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 6)
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
                        .foregroundStyle(FrogTheme.orange)
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
                    .foregroundStyle(FrogTheme.muted)
                TextField("搜尋山峰", text: $searchText)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .cardStyle()

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
                    Text("山峰列表")
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.moss)
                    Text("顯示 \(filteredMountains.count) / \(MountainCatalog.catalogCount) 座")
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
            .padding(12)

            ForEach(filteredMountains.prefix(displayedCount)) { mountain in
                NavigationLink(value: NativeRoute.mountainDetail(mountain.id)) {
                    MountainDirectoryRow(mountain: mountain)
                }
                .buttonStyle(.plain)
            }

            if filteredMountains.count > displayedCount {
                Button {
                    displayedCount += 40
                } label: {
                    HStack(spacing: 6) {
                        Text("顯示更多")
                            .font(.frogCaption.weight(.bold))
                            .foregroundStyle(FrogTheme.forest)
                        Text("(\(filteredMountains.count - displayedCount) 座)")
                            .font(.frogMicro)
                            .foregroundStyle(FrogTheme.muted)
                        Image(systemName: "chevron.down")
                            .font(.frogMicro.weight(.bold))
                            .foregroundStyle(FrogTheme.orange)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
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

            VStack(alignment: .leading, spacing: 3) {
                Spacer()
                Label(mountain.nameZh, systemImage: "location.fill")
                    .font(.frogMicro.weight(.bold))
                    .lineLimit(1)
                Text("\(mountain.height)m")
                    .font(.frogMicro)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(10)
        }
        .foregroundStyle(.white)
        .frame(width: 118, height: 142)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct MountainDirectoryRow: View {
    let mountain: Mountain

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                MountainThumbnail(mountain: mountain, size: 54)

                Text(mountain.rankText)
                    .font(.frogMicro)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(FrogTheme.forest.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .padding(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(mountain.displayName)
                    .font(.frogRow)
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                Text("\(mountain.region) · \(mountain.height)m · WildFrog 山峰目錄")
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
            }

            Spacer()

            Text(mountain.checkIns > 0 ? "\(mountain.checkIns) 次" : "未打卡")
                .font(.frogCaption)
                .foregroundStyle(mountain.checkIns > 0 ? .white : FrogTheme.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(mountain.checkIns > 0 ? FrogTheme.moss : Color.black.opacity(0.06))
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.caption.weight(.medium))
                .foregroundStyle(FrogTheme.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: FrogSpace.rowMinHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FrogTheme.line)
                .frame(height: 1)
                .padding(.leading, 70)
        }
    }
}
