import SwiftUI

struct RecordsCalendarView: View {
    @State private var selectedDay = 5

    private let monthDays = Array(1...30)
    private let activeDays: Set<Int> = [1, 2, 4, 5, 7, 9, 12, 16, 18, 20, 21, 24, 27, 29]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)

    private var selectedMountain: Mountain {
        MountainCatalog.mountains[selectedDay % MountainCatalog.mountains.count]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summaryStrip
                calendarPanel
                selectedRecordCard
            }
            .padding(18)
            .padding(.bottom, 110)
        }
        .navigationTitle("紀錄")
        .nativeInlineTitle()
        .background(FrogTheme.paper)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日曆紀錄")
                .font(.system(size: 34, weight: .black, design: .rounded))
            Text("用相片格睇返每次有效打卡")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FrogTheme.muted)
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 10) {
            StatCard(value: "\(activeDays.count)", label: "月內打卡", systemImage: "calendar")
            StatCard(value: "7", label: "連續日數", systemImage: "flame")
            StatCard(value: "14", label: "山峰數", systemImage: "mountain.2")
        }
    }

    private var calendarPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("2026年6月")
                        .font(.title2.weight(.black))
                    Text("WildFrog Photo Calendar")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FrogTheme.muted)
                }

                Spacer()

                Button {} label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .cardStyle()

                Button {} label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .cardStyle()
            }

            HStack {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.black))
                        .foregroundStyle(FrogTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(monthDays, id: \.self) { day in
                    Button {
                        selectedDay = day
                    } label: {
                        CalendarTile(
                            day: day,
                            mountain: MountainCatalog.mountains[day % MountainCatalog.mountains.count],
                            isActive: activeDays.contains(day),
                            isSelected: selectedDay == day
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var selectedRecordCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedDay)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                    Text("6月 / 周五")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FrogTheme.muted)
                }

                Spacer()

                NavigationLink(value: NativeRoute.mountainDetail(selectedMountain.id)) {
                    Label("查看山峰", systemImage: "chevron.right")
                        .font(.caption.weight(.black))
                }
                .buttonStyle(.bordered)
                .tint(FrogTheme.orange)
            }

            ZStack(alignment: .bottomLeading) {
                MountainPhoto(mountain: selectedMountain, dimming: 0.2)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                LinearGradient(
                    colors: [.black.opacity(0.02), .black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedMountain.displayName)
                        .font(.title2.weight(.black))
                    Text("第 \(max(1, selectedMountain.checkIns)) 次登頂 · \(selectedMountain.height)m")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(16)
            }

            Text("官方有效紀錄已保存。相片會生成白色水印版本，可用於分享或之後輸出證書。")
                .font(.footnote.weight(.medium))
                .foregroundStyle(FrogTheme.muted)
        }
        .padding(14)
        .cardStyle()
    }
}

private struct CalendarTile: View {
    let day: Int
    let mountain: Mountain
    let isActive: Bool
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isActive {
                MountainPhoto(mountain: mountain, dimming: 0.22)
            } else {
                Color.black.opacity(0.05)
            }

            Text("\(day)")
                .font(.headline.weight(.black))
                .foregroundStyle(isActive ? .white : FrogTheme.muted)
                .shadow(color: .black.opacity(isActive ? 0.25 : 0), radius: 3)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isSelected ? FrogTheme.orange : Color.clear, lineWidth: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(isActive ? 0.7 : 0), lineWidth: 1)
            )
    }
}
