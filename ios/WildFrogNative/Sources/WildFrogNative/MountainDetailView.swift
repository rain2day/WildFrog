import MapKit
import SwiftUI

struct MountainDetailView: View {
    let mountain: Mountain

    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var checkInStore: CheckInStore
    @Environment(\.dismiss) private var dismiss

    @State private var mapCamera: MapCameraPosition = .automatic
    @State private var routeCamera: MapCameraPosition = .automatic
    @State private var showCertShare = false

    /// The signed-in user's own live check-ins for this peak (account-bound),
    /// NOT the static catalog seed `mountain.checkIns`.
    private var myCheckIns: Int { checkInStore.count(for: mountain.id) }

    private var hasCheckedIn: Bool {
        myCheckIns > 0
    }

    @ViewBuilder
    private var certPhoto: some View {
        #if canImport(UIKit)
        let filename = checkInStore.records
            .filter { $0.mountainId == mountain.id }
            .sorted { $0.date > $1.date }
            .first?.photoFilename
        if let name = filename,
           let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let img = UIImage(contentsOfFile: dir.appendingPathComponent(name).path) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            MountainPhoto(mountain: mountain, dimming: 0.02)
        }
        #else
        MountainPhoto(mountain: mountain, dimming: 0.02)
        #endif
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
        GeometryReader { outer in
            let topInset = outer.safeAreaInsets.top

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero(topInset: topInset)

                    VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                        statCards
                        checkInAction
                        trailFactsPanel
                        recordedRoutePanel
                        checkpointMap
                        certificatePreview
                    }
                    .padding(.horizontal, FrogSpace.screenPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .hiddenNavigationBar()
        .background(FrogTheme.paper)
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-qaCert") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showCertShare = true }
            }
        }
        #endif
    }

    private func hero(topInset: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: mountain, dimming: 0, showsSourceBadge: true)

            // One layered gradient (css .dhero .grad) — photo top, forest anchor.
            LinearGradient(
                colors: [
                    .black.opacity(0.34),
                    .black.opacity(0.06),
                    FrogTheme.forest.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.14), in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.26), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("返回")

                    Spacer()

                    MountainStampSeal(
                        mountain: mountain,
                        size: 74,
                        isUnlocked: hasCheckedIn,
                        rotation: .degrees(6)
                    )
                }
                .padding(.top, topInset + 6)

                Spacer(minLength: 28)

                VStack(alignment: .leading, spacing: 10) {
                    Text("\(mountain.rankText) · 300 PEAKS")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(FrogTheme.orange, in: Capsule())

                    (
                        Text(mountain.nameZh)
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(.white)
                        + Text(mountain.nameEn.isEmpty ? "" : "  \(mountain.nameEn)")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.66)
                    .fixedSize(horizontal: false, vertical: true)

                    Label("\(mountain.region) · \(mountain.height)m", systemImage: "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .shadow(color: Color.black.opacity(0.22), radius: 10, y: 4)

                HStack(spacing: 8) {
                    DetailStatusPill(value: mountain.region, label: "地區")
                    DetailStatusPill(value: "\(myCheckIns)", label: "我的紀錄")
                    DetailStatusPill(value: "\(mountain.height)m", label: "海拔")
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
        .frame(height: topInset + 360)
        .clipped()
    }

    /// 3-up stat cards (css .statcards) — hairline on surface, one trail-tinted.
    private var statCards: some View {
        HStack(spacing: 10) {
            DetailStatCard(systemImage: "checkmark.shield.fill", value: "\(myCheckIns)", label: "我的打卡", tint: FrogTheme.moss)
            DetailStatCard(systemImage: "trophy.fill", value: mountain.rankText, label: "300峰排名", tint: FrogTheme.gold)
            DetailStatCard(systemImage: "rosette", value: mountain.unlockTitle, label: "解鎖稱號", tint: FrogTheme.gold)
        }
    }

    private var certificatePreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WILDFROG OFFICIAL RECORD")
                        .font(.frogEyebrow)
                        .tracking(1.1)
                        .foregroundStyle(FrogTheme.gold)
                    Text("登頂紀念證書")
                        .font(.headline.weight(.black))
                }
                Spacer()
                Text(hasCheckedIn ? "山印已解鎖" : "完成打卡後解鎖")
                    .font(.frogMicro.weight(.black))
                    .foregroundStyle(hasCheckedIn ? FrogTheme.forest : FrogTheme.muted)
            }

            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WildFrog 山峰紀錄")
                            .font(.subheadline.weight(.heavy))
                        Text(mountain.nameZh)
                            .font(.system(size: 38, weight: .black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                        Text(mountain.nameEn)
                            .font(.frogCaption.weight(.bold))
                            .foregroundStyle(FrogTheme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer()
                    MountainStampSeal(mountain: mountain, size: 86, isUnlocked: hasCheckedIn, rotation: .degrees(-4))
                }

                // 稱號 unlocked by conquering this peak.
                HStack(spacing: 10) {
                    Image(systemName: hasCheckedIn ? "rosette" : "lock.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(hasCheckedIn ? FrogTheme.gold : FrogTheme.muted)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(hasCheckedIn ? "稱號已解鎖" : "完成打卡解鎖稱號")
                            .font(.frogMicro.weight(.bold))
                            .foregroundStyle(FrogTheme.muted)
                        Text(mountain.unlockTitle)
                            .font(.title3.weight(.black))
                            .foregroundStyle(hasCheckedIn ? FrogTheme.forest : FrogTheme.muted.opacity(0.55))
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    hasCheckedIn ? FrogTheme.gold.opacity(0.12) : FrogTheme.surface2,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                // The mountain's story.
                Text(mountain.blurb)
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.ink.opacity(0.82))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("登頂次數")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FrogTheme.muted)
                        Text(hasCheckedIn ? "第 \(myCheckIns) 次登頂" : "未登頂")
                            .font(.title3.weight(.black))
                            .foregroundStyle(hasCheckedIn ? FrogTheme.ink : FrogTheme.muted)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("山峰海拔")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FrogTheme.muted)
                        Text("\(mountain.height) m")
                            .font(.title3.weight(.black))
                    }
                }

                certPhoto
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(FrogTheme.gold, lineWidth: 4)
                    )

                if hasCheckedIn {
                    Button { showCertShare = true } label: {
                        Label("分享證書", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(FrogTheme.orange, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("愛自然 / 愛運動 / 愛香港")
                        .font(.subheadline.weight(.black))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(FrogTheme.passport.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(FrogTheme.forest.opacity(0.12), lineWidth: 1)
            )
        }
        .padding(14)
        .cardStyle()
        .sheet(isPresented: $showCertShare) {
            MountainCertificateSheet(mountain: mountain, checkInCount: myCheckIns)
        }
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
                    .foregroundStyle(FrogTheme.moss)
            }

            HStack(spacing: 10) {
                DetailFact(value: mountain.rankText, label: "300峰排名", systemImage: "trophy.fill", tint: FrogTheme.gold)
                DetailFact(value: "\(mountain.height)m", label: "山峰海拔", systemImage: "triangle.fill", tint: FrogTheme.moss)
                DetailFact(value: "\(CheckInRules.radiusMeters)m", label: "有效半徑", systemImage: "scope", tint: FrogTheme.moss)
            }
        }
        .padding(FrogSpace.cardPadding)
        .cardStyle()
    }

    @ViewBuilder
    private var recordedRoutePanel: some View {
        let track = checkInStore.records
            .filter { $0.mountainId == mountain.id && $0.track != nil }
            .sorted { $0.date > $1.date }
            .first?.track
        if let track {
            let coords = track.coordinates.map(\.coordinate)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Label("我的路線", systemImage: "point.topleft.down.curvedto.point.bottomright.up.fill")
                        .font(.headline.weight(.black))
                        .foregroundStyle(FrogTheme.ink)
                    Spacer()
                    Text("MY ROUTE")
                        .font(.frogMicro.weight(.black))
                        .foregroundStyle(FrogTheme.moss)
                }

                Map(position: $routeCamera) {
                    if coords.count > 1 {
                        MapPolyline(coordinates: coords)
                            .stroke(FrogTheme.orange, lineWidth: 4)
                        if let start = coords.first {
                            Marker("起點", systemImage: "flag.fill", coordinate: start)
                                .tint(FrogTheme.moss)
                        }
                        if let end = coords.last {
                            Marker("終點", systemImage: "flag.checkered", coordinate: end)
                                .tint(FrogTheme.orange)
                        }
                    } else {
                        Marker(mountain.nameZh, systemImage: "mappin.circle.fill", coordinate: mountain.coordinate)
                            .tint(FrogTheme.orange)
                    }
                }
                .mapControlVisibility(.hidden)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onAppear {
                    guard coords.count > 1 else {
                        routeCamera = .region(MKCoordinateRegion(
                            center: mountain.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        ))
                        return
                    }
                    var minLat = coords[0].latitude, maxLat = coords[0].latitude
                    var minLon = coords[0].longitude, maxLon = coords[0].longitude
                    for c in coords {
                        minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
                        minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
                    }
                    routeCamera = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
                        span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.4, 0.005), longitudeDelta: max((maxLon - minLon) * 1.4, 0.005))
                    ))
                }

                HStack(spacing: 10) {
                    StatCard(value: TrackFormat.distance(track.distanceMeters), label: "距離", systemImage: "ruler", tint: FrogTheme.moss)
                        .frame(maxWidth: .infinity)
                    StatCard(value: TrackFormat.duration(track.durationSeconds), label: "時間", systemImage: "clock", tint: FrogTheme.orange)
                        .frame(maxWidth: .infinity)
                    StatCard(value: "\(Int(track.ascentMeters))m", label: "累積上升", systemImage: "arrow.up.forward", tint: FrogTheme.gold)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(14)
            .cardStyle()
        }
    }

    private var checkpointMap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("檢查點地圖")
                .font(.headline.weight(.black))

            Map(position: $mapCamera) {
                Marker(mountain.nameZh, systemImage: "mappin.circle.fill", coordinate: mountain.coordinate)
                    .tint(FrogTheme.orange)
                UserAnnotation()
            }
            .mapControlVisibility(.hidden)
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onAppear {
                mapCamera = .region(MKCoordinateRegion(
                    center: mountain.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }

            HStack {
                Label("有效半徑 \(CheckInRules.radiusMeters)m", systemImage: "scope")
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
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.frogNum(18, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.frogMicro)
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct DetailStatCard: View {
    let systemImage: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.frogNum(22, weight: .semibold))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(.frogMicro)
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(FrogTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: 1)
        )
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
