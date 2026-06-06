import MapKit
import SwiftUI

struct HomeMapListView: View {
    @State private var searchText = ""
    @State private var selectedRegion = "全部"
    @State private var sortMode = SortMode.rank
    @State private var mapHeight: CGFloat = 230
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                hero
                stats
                searchAndFilters
                mapOverview
                featuredRail
                directoryList
            }
            .padding(18)
            .padding(.bottom, 110)
        }
        .nativeInlineTitle()
        .background(FrogTheme.paper)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 18, weight: .bold))
                .frame(width: 32, height: 32)
                .foregroundStyle(.white)
                .background(FrogTheme.orange)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("WildFrog")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                Text("香港山峰紀錄")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FrogTheme.muted)
            }

            Spacer()

            Button {} label: {
                Image(systemName: "bell")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(FrogTheme.ink)
            .cardStyle()
            .accessibilityLabel("通知")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text("P0 原型")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(FrogTheme.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FrogTheme.orangeSoft)
                    .clipShape(Capsule())

                Spacer()

                heroPhotoBadge
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("每座山都有自己的打卡紀錄")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(FrogTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Native 版先定好地圖、列表、打卡同紀錄的真互動骨架。")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(FrogTheme.muted)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var heroPhotoBadge: some View {
        ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: MountainCatalog.featured[0], dimming: 0.28)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(MountainCatalog.catalogCount)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.75)
                Text("山峰")
                    .font(.caption.weight(.black))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 6)
            .padding(9)
        }
        .frame(width: 92, height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var stats: some View {
        HStack(spacing: 10) {
            StatCard(value: "86", label: "有效打卡總數", systemImage: "chart.bar")
            StatCard(value: "14", label: "已到訪山峰", systemImage: "mountain.2")
            StatCard(value: "#18", label: "我的排名", systemImage: "trophy")
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
                        Button(region) { selectedRegion = region }
                            .buttonStyle(ChipButtonStyle(isSelected: selectedRegion == region))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var mapOverview: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("山峰地圖")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(FrogTheme.orange)
                    Text("全港山峰概覽")
                        .font(.headline.weight(.black))
                }

                Spacer()

                Picker("地圖大小", selection: $mapHeight) {
                    Text("細").tag(CGFloat(230))
                    Text("大").tag(CGFloat(360))
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }
            .padding(12)

            Capsule()
                .fill(Color.black.opacity(0.18))
                .frame(width: 44, height: 5)
                .padding(.vertical, 10)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            mapHeight = min(420, max(190, mapHeight + value.translation.height / 24))
                        }
                )
                .accessibilityLabel("拉動調整地圖大小")

            Map(position: $mapPosition) {
                ForEach(filteredMountains) { mountain in
                    Marker(mountain.nameZh, systemImage: mountain.checkIns > 0 ? "checkmark.circle.fill" : "mountain.2.fill", coordinate: mountain.coordinate)
                        .tint(mountain.checkIns > 0 ? FrogTheme.orange : FrogTheme.moss)
                }
            }
            .frame(height: mapHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                MapCountPill(value: "\(filteredMountains.count)", label: "列表山峰")
                    .padding(10)
            }
            .animation(.snappy(duration: 0.22), value: mapHeight)
        }
        .cardStyle()
    }

    private var featuredRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("精選山峰")
                    .font(.headline.weight(.black))
                Spacer()
                Text("\(MountainCatalog.featured.count)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(FrogTheme.orange)
                    .clipShape(Circle())
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

    private var directoryList: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("山峰列表")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(FrogTheme.orange)
                    Text("顯示 \(filteredMountains.count) / \(MountainCatalog.catalogCount) 座")
                        .font(.headline.weight(.black))
                }

                Spacer()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(SortMode.allCases) { mode in
                            Button(mode.rawValue) { sortMode = mode }
                                .buttonStyle(ChipButtonStyle(isSelected: sortMode == mode))
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

private struct FeaturedMountainCard: View {
    let mountain: Mountain

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: mountain, dimming: 0.24)

            LinearGradient(
                colors: [.black.opacity(0.02), .black.opacity(0.68)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(mountain.rankText)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(FrogTheme.orange)
                    .clipShape(Capsule())

                Spacer()

                Text(mountain.displayName)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text("\(mountain.height)m · \(mountain.checkIns) 次")
                    .font(.caption.weight(.bold))
            }
            .padding(12)
        }
        .foregroundStyle(.white)
        .frame(width: 156, height: 120, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MountainDirectoryRow: View {
    let mountain: Mountain

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                MountainThumbnail(mountain: mountain, size: 54)

                Text(mountain.rankText)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(FrogTheme.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .padding(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(mountain.displayName)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                Text("\(mountain.region) · \(mountain.height)m · TimHiking 全港300+山峰")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
            }

            Spacer()

            Text(mountain.checkIns > 0 ? "\(mountain.checkIns) 次" : "未打卡")
                .font(.caption2.weight(.black))
                .foregroundStyle(mountain.checkIns > 0 ? .white : FrogTheme.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(mountain.checkIns > 0 ? FrogTheme.moss : Color.black.opacity(0.06))
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.caption.weight(.black))
                .foregroundStyle(FrogTheme.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FrogTheme.line)
                .frame(height: 1)
                .padding(.leading, 70)
        }
    }
}

private struct MapCountPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.black))
            Text(label)
                .font(.caption2.weight(.black))
                .foregroundStyle(FrogTheme.muted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.black))
            .foregroundStyle(isSelected ? .white : FrogTheme.muted)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(isSelected ? FrogTheme.orange : Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(FrogTheme.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
