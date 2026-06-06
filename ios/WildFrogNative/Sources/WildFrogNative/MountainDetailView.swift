import MapKit
import SwiftUI

struct MountainDetailView: View {
    let mountain: Mountain

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                recordPanel
                certificatePreview
                checkInAction
                checkpointMap
            }
            .padding(18)
            .padding(.bottom, 110)
        }
        .navigationTitle(mountain.nameZh)
        .nativeInlineTitle()
        .background(FrogTheme.paper)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
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

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .bottomLeading)
        .padding(18)
        .background(
            ZStack {
                MountainPhoto(mountain: mountain, dimming: 0.22)
                LinearGradient(
                    colors: [.black.opacity(0.02), .black.opacity(0.74)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
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
            Label("立即打卡", systemImage: "location.circle.fill")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(FrogTheme.orange)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
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
                Label("有效半徑 60m", systemImage: "scope")
                Spacer()
                Label("GPS 良好", systemImage: "location.fill")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(FrogTheme.muted)
        }
        .padding(14)
        .cardStyle()
    }
}
