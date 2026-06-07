import MapKit
import SwiftUI

struct MountainDetailView: View {
    let mountain: Mountain

    @EnvironmentObject private var locationManager: LocationManager

    private var hasCheckedIn: Bool {
        mountain.checkIns > 0
    }

    private var distanceCaption: String {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            return "開啟定位睇距離"
        }
        guard let d = locationManager.distance(to: mountain.coordinate) else {
            return "定位中…"
        }
        if d < 1000 {
            return "距離 \(Int(d))m"
        } else {
            return String(format: "距離 %.1fkm", d / 1000)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                hero
                recordPanel
                checkInAction
                trailFactsPanel
                checkpointMap
                certificatePreview
            }
            .padding(FrogSpace.screenPadding)
            .padding(.bottom, 124)
        }
        .navigationTitle(mountain.nameZh)
        .nativeInlineTitle()
        .background(FrogTheme.paper)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: mountain, dimming: 0.1)

            LinearGradient(
                colors: [
                    .black.opacity(0.08),
                    .black.opacity(0.22),
                    FrogTheme.forest.opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    WildFrogBrandMark(size: 38, cornerRadius: 10)

                    Spacer()

                    Text(hasCheckedIn ? "已完成" : "未打卡")
                        .font(.frogMicro.weight(.black))
                        .foregroundStyle(hasCheckedIn ? FrogTheme.forest : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(hasCheckedIn ? FrogTheme.leaf : Color.black.opacity(0.48), in: Capsule())
                }

                Spacer(minLength: 44)

                VStack(alignment: .leading, spacing: 8) {
                    Text(mountain.rankText)
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(FrogTheme.orange)
                        .clipShape(Capsule())

                    Text(mountain.displayName)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .fixedSize(horizontal: false, vertical: true)

                    Label("\(mountain.region) · \(mountain.height)m", systemImage: "mappin.and.ellipse")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                HStack(spacing: 8) {
                    DetailStatusPill(value: "\(mountain.totalCheckIns)", label: "全站打卡")
                    DetailStatusPill(value: mountain.checkIns > 0 ? "\(mountain.checkIns)" : "0", label: "我的紀錄")
                    DetailStatusPill(value: "\(mountain.height)m", label: "海拔")
                }
            }
            .padding(18)
        }
        .frame(height: 330)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var recordPanel: some View {
        HStack(spacing: 10) {
            StatCard(value: "\(mountain.checkIns)", label: "我的打卡", systemImage: "checkmark.seal")
            StatCard(value: mountain.rankText, label: "300峰排名", systemImage: "trophy")
            StatCard(value: "\(mountain.totalCheckIns)", label: "總打卡", systemImage: "person.2")
        }
    }

    private var certificatePreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("登頂紀念證書")
                .font(.headline.weight(.black))

            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text("WildFrog 山峰紀錄")
                        .font(.subheadline.weight(.heavy))
                    Text(mountain.nameZh)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                    Text("登頂紀念證書")
                        .font(.title2.weight(.heavy))
                }

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("登頂次數")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FrogTheme.muted)
                        Text("第 \(max(1, mountain.checkIns)) 次登頂")
                            .font(.title3.weight(.black))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("山峰海拔")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FrogTheme.muted)
                        Text("\(mountain.height).0 m")
                            .font(.title3.weight(.black))
                    }
                }

                MountainPhoto(mountain: mountain, dimming: 0.02)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(FrogTheme.orange, lineWidth: 5)
                    )

                Text("愛自然 / 愛運動 / 愛香港")
                    .font(.subheadline.weight(.black))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.white.opacity(0.74))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(14)
        .cardStyle()
    }

    private var checkInAction: some View {
        NavigationLink(value: NativeRoute.checkIn(mountain.id)) {
            Label(hasCheckedIn ? "再次打卡" : "開始有效打卡", systemImage: "location.circle.fill")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(FrogTheme.orange)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var trailFactsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("路線摘要", systemImage: "figure.hiking")
                    .font(.headline.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                Spacer()
                Text(hasCheckedIn ? "PASSPORT SAVED" : "READY")
                    .font(.frogMicro.weight(.black))
                    .foregroundStyle(FrogTheme.orange)
            }

            HStack(spacing: 10) {
                DetailFact(value: mountain.rankText, label: "300峰排名", systemImage: "trophy.fill", tint: FrogTheme.gold)
                DetailFact(value: "\(mountain.height)m", label: "山峰海拔", systemImage: "triangle.fill", tint: FrogTheme.moss)
                DetailFact(value: "60m", label: "有效半徑", systemImage: "scope", tint: FrogTheme.orange)
            }
        }
        .padding(FrogSpace.cardPadding)
        .cardStyle()
    }

    private var checkpointMap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("檢查點地圖")
                .font(.headline.weight(.black))

            Map {
                Marker(mountain.nameZh, systemImage: "mappin.circle.fill", coordinate: mountain.coordinate)
                    .tint(FrogTheme.orange)
                UserAnnotation()
            }
            .mapControlVisibility(.hidden)
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                Label("有效半徑 500m", systemImage: "scope")
                Spacer()
                Label(distanceCaption, systemImage: "location.fill")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(FrogTheme.muted)

            NavigationLink(value: NativeRoute.routeToCheckpoint(mountain.id)) {
                Label("路線 / 導航去呢度", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(FrogTheme.moss, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .cardStyle()
    }
}

private struct DetailStatusPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.frogCaption.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(label)
                .font(.frogMicro)
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct DetailFact: View {
    let value: String
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.frogTitle)
                .foregroundStyle(FrogTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.frogMicro)
                .foregroundStyle(FrogTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(FrogTheme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: 1)
        )
    }
}
