import MapKit
import SwiftUI

struct HomeMapListView: View {
    @EnvironmentObject private var checkInStore: CheckInStore

    @State private var searchText = ""
    @State private var selectedRegion = "全部"
    @State private var sortMode = SortMode.rank
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
        ScrollView {
            VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                topHeader
                mapOverview
                progressCard
                recommendedCard
                featuredRail
                searchAndFilters
                directoryList
            }
            .padding(FrogSpace.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .nativeInlineTitle()
        .appPageBackground(FrogTheme.warmPaper)
    }

    private var topHeader: some View {
        HStack(spacing: 12) {
            WildFrogBrandMark(size: 46, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text("WildFrog")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(FrogTheme.forest)
                Text("探索香港山峰，完成你的 Peak Passport")
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(FrogTheme.muted)
            }

            Spacer()

            Button {} label: {
                Image(systemName: "bell")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FrogTheme.forest)
                    .frame(width: 44, height: 44)
                    .background(Color.white, in: Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("通知")
        }
    }

    private func hero(topInset: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: MountainCatalog.mountain(id: "tai-mo-shan"), dimming: 0.16)
                .frame(height: 315 + topInset)

            LinearGradient(
                colors: [
                    FrogTheme.forest.opacity(0.18),
                    .clear,
                    FrogTheme.forest.opacity(0.7),
                    FrogTheme.forest
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    brandLockup
                    Spacer()
                    Button {} label: {
                        Image(systemName: "bell")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FrogTheme.ink)
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.92), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("通知")
                }

                Spacer(minLength: 28)

                HStack(spacing: 10) {
                    HeroMetric(value: "\(checkInStore.distinctMountainCount)", label: "Peaks\nChecked In", systemImage: "mountain.2.fill", tint: FrogTheme.leaf)
                    HeroMetric(value: "\(checkInStore.currentStreak)", label: "Day\nStreak", systemImage: "flame.fill", tint: FrogTheme.orange)
                    HeroMetric(value: summitPoints.formatted(), label: "Summit\nPoints", systemImage: "scope", tint: FrogTheme.leaf)
                }
            }
            .padding(.horizontal, FrogSpace.screenPadding)
            .padding(.top, topInset + 8)
            .padding(.bottom, 20)
        }
        .frame(height: 315 + topInset)
    }

    private var brandLockup: some View {
        HStack(spacing: 8) {
            WildFrogBrandMark(size: 34, cornerRadius: 9)

            VStack(alignment: .leading, spacing: 1) {
                Text("WILDFROG")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(FrogTheme.forest)
                Text("EXPLORE · CHECK IN · CONQUER")
                    .font(.system(size: 6.5, weight: .black))
                    .foregroundStyle(FrogTheme.orange)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.9), in: Capsule())
    }

    private var mapOverview: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $mapPosition) {
                ForEach(mapMountains) { mountain in
                    Marker(mountain.nameZh, systemImage: mountain.checkIns > 0 ? "checkmark.circle.fill" : "mappin", coordinate: mountain.coordinate)
                        .tint(mountain.checkIns > 0 ? FrogTheme.orange : FrogTheme.leaf)
                }
            }
            .mapControlVisibility(.hidden)
            .frame(height: 410)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack {
                Label("EXPLORE MAP", systemImage: "location.fill")
                    .font(.frogMicro.weight(.bold))
                    .foregroundStyle(FrogTheme.forest)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.86), in: Capsule())
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
                    Button {} label: {
                        Text("VIEW ALL PEAKS")
                            .font(.frogMicro.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.black.opacity(0.62), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 10) {
                        MapFloatingButton(systemImage: "location.north.fill")
                        MapFloatingButton(systemImage: "square.3.layers.3d")
                    }
                }
                .padding(12)
            }
        }
        .paperCardStyle()
    }

    private var progressCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(FrogTheme.line, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(0.02, Double(checkedMountains.count) / Double(max(1, MountainCatalog.catalogCount))))
                    .stroke(FrogTheme.leaf, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(checkedMountains.count)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                    Text("/\(MountainCatalog.catalogCount)")
                        .font(.frogCaption.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                }
                .foregroundStyle(FrogTheme.forest)
            }
            .frame(width: 96, height: 96)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Label("\(MountainCatalog.catalogCount) Peaks", systemImage: "mountain.2.fill")
                    .font(.frogTitle)
                    .foregroundStyle(FrogTheme.forest)
                Label("\(checkedMountains.count) Completed", systemImage: "checkmark.circle.fill")
                    .font(.frogTitle)
                    .foregroundStyle(FrogTheme.forest)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .paperCardStyle()
    }

    private var recommendedCard: some View {
        NavigationLink(value: NativeRoute.mountainDetail(recommendedMountain.id)) {
            HStack(spacing: 12) {
                MountainPhoto(mountain: recommendedMountain, dimming: 0.08)
                    .frame(width: 96, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("NEXT RECOMMENDED")
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.muted)
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

    private var featuredRail: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("NEARBY HIGHLIGHTS")
                    .font(.frogMicro.weight(.bold))
                    .foregroundStyle(FrogTheme.forest)
                Spacer()
                Text("SEE ALL")
                    .font(.frogMicro.weight(.bold))
                    .foregroundStyle(FrogTheme.orange)
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

            ForEach(filteredMountains.prefix(40)) { mountain in
                NavigationLink(value: NativeRoute.mountainDetail(mountain.id)) {
                    MountainDirectoryRow(mountain: mountain)
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
    }
}

private struct HeroMetric: View {
    let value: String
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
