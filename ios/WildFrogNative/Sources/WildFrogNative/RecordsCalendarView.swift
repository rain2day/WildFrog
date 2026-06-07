import SwiftUI

struct RecordsCalendarView: View {
    @EnvironmentObject private var checkInStore: CheckInStore

    @State private var selectedDay = Calendar.current.component(.day, from: Date())
    @State private var displayedMonth: Date = {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: components) ?? Date()
    }()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)

    private var checkedMountains: [Mountain] {
        MountainCatalog.mountains.filter { $0.checkIns > 0 }
    }

    private var displayedYear: Int {
        Calendar.current.component(.year, from: displayedMonth)
    }

    private var displayedMonthNumber: Int {
        Calendar.current.component(.month, from: displayedMonth)
    }

    private var displayedMonthLabel: String {
        "\(displayedYear)年\(displayedMonthNumber)月"
    }

    /// Days in the displayed month that have at least one check-in.
    private var activeDays: Set<Int> {
        checkInStore.days(year: displayedYear, month: displayedMonthNumber)
    }

    /// Map from active day → first matched Mountain (for calendar tiles and stamp timeline).
    private var activeRecords: [Int: Mountain] {
        var result: [Int: Mountain] = [:]
        for day in activeDays {
            // Find a mountain checked in on this day in the displayed month
            let matchingRecord = checkInStore.records.first { record in
                let cal = Calendar.current
                let comps = cal.dateComponents([.year, .month, .day], from: record.date)
                return comps.year == displayedYear && comps.month == displayedMonthNumber && comps.day == day
            }
            if let mountainId = matchingRecord?.mountainId,
               let mountain = MountainCatalog.mountains.first(where: { $0.id == mountainId }) {
                result[day] = mountain
            }
        }
        return result
    }

    private var selectedMountain: Mountain? {
        activeRecords[selectedDay]
    }

    private var monthDays: [Int] {
        if let range = Calendar.current.range(of: .day, in: .month, for: displayedMonth) {
            return Array(range)
        }
        return Array(1...30)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                passportCover
                stampTimeline
                passportStrip
                calendarPanel
                selectedRecordCard
            }
            .padding(FrogSpace.screenPadding)
            .padding(.bottom, 110)
        }
        .hiddenNavigationBar()
        .background(FrogTheme.passport)
    }

    private var passportCover: some View {
        ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: recentCoverMountain, dimming: 0.24)

            LinearGradient(
                colors: [
                    FrogTheme.forest.opacity(0.08),
                    FrogTheme.forest.opacity(0.36),
                    FrogTheme.forest.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    HStack(spacing: 9) {
                        WildFrogBrandMark(size: 40, cornerRadius: 11)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("WILDFROG")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                            Text("PEAK PASSPORT")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(FrogTheme.orange)
                        }
                    }
                    .foregroundStyle(.white)

                    Spacer()

                    Text(displayedMonth.formatted(.dateTime.year().month(.abbreviated).locale(Locale(identifier: "en_US"))))
                        .font(.frogMicro.weight(.black))
                        .foregroundStyle(FrogTheme.forest)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(FrogTheme.leaf, in: Capsule())
                }

                Spacer(minLength: 40)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Peak Passport")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("每一次有效打卡，都變成一本香港山峰護照。")
                        .font(.frogCaption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    PassportCoverMetric(value: "\(activeDays.count)", label: "月內打卡日")
                    PassportCoverMetric(value: "\(checkInStore.distinctMountainCount)", label: "已到山峰")
                    PassportCoverMetric(value: "\(checkInStore.currentStreak)", label: "連續日")
                }
            }
            .padding(18)
        }
        .frame(height: 286)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: FrogTheme.forest.opacity(0.2), radius: 16, y: 8)
    }

    private var stampTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("本月印章", systemImage: "seal.fill")
                    .font(.frogTitle)
                    .foregroundStyle(FrogTheme.forest)
                Spacer()
                Text("\(activeDays.count) DAYS")
                    .font(.frogMicro.weight(.black))
                    .foregroundStyle(FrogTheme.orange)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(activeRecords.keys.sorted().prefix(8), id: \.self) { day in
                        if let mountain = activeRecords[day] {
                            StampTimelineCard(day: day, mountain: mountain, isSelected: selectedDay == day)
                                .onTapGesture {
                                    selectedDay = day
                                }
                        }
                    }
                }
            }
        }
        .padding(FrogSpace.cardPadding)
        .background(Color.white.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FrogTheme.forest.opacity(0.1), lineWidth: 1)
        )
    }

    private var recentCoverMountain: Mountain {
        checkedMountains.first ?? MountainCatalog.mountain(id: "lion-rock")
    }

    private var passportStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Passport Stamps", systemImage: "seal.fill")
                    .font(.frogTitle)
                    .foregroundStyle(FrogTheme.forest)
                Spacer()
                Text("\(checkInStore.distinctMountainCount) / \(MountainCatalog.catalogCount)")
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(FrogTheme.orange)
            }

            Image("WildFrogStampSheet")
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(FrogSpace.cardPadding)
        .background(Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FrogTheme.forest.opacity(0.12), lineWidth: 1)
        )
    }

    private var calendarPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayedMonthLabel)
                        .font(.frogTitle)
                    Text("打卡相簿")
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                        selectedDay = 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.ink)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .controlStyle()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                        selectedDay = 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.ink)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .controlStyle()
            }

            HStack {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(.frogCaption)
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
                            mountain: activeRecords[day],
                            isSelected: selectedDay == day
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(FrogSpace.cardPadding)
        .cardStyle()
    }

    private var selectedRecordCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedDay)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                    Text("\(displayedMonthNumber)月")
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                }

                Spacer()

                if let selectedMountain {
                    NavigationLink(value: NativeRoute.mountainDetail(selectedMountain.id)) {
                        Label("查看山峰", systemImage: "chevron.right")
                            .font(.frogCaption)
                    }
                    .buttonStyle(.bordered)
                    .tint(FrogTheme.orange)
                }
            }

            if let selectedMountain {
                ZStack(alignment: .bottomLeading) {
                    MountainPhoto(mountain: selectedMountain, dimming: 0.18)
                        .frame(height: 210)
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.76)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedMountain.displayName)
                            .font(.frogTitle)
                        Text("第 \(max(1, selectedMountain.checkIns)) 次登頂 · \(selectedMountain.height)m")
                            .font(.frogBody)
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("官方有效紀錄已保存。相片會生成白色水印版本，可用於分享或之後輸出證書。")
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "mountain.2")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(FrogTheme.muted)
                    Text("這天未有打卡紀錄")
                        .font(.frogRow)
                        .foregroundStyle(FrogTheme.ink)
                    Text("完成有效打卡後，當天會出現在 passport 日曆。")
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 18)
            }
        }
        .padding(FrogSpace.cardPadding)
        .cardStyle()
    }
}

private struct CalendarTile: View {
    let day: Int
    let mountain: Mountain?
    let isSelected: Bool

    var body: some View {
        ZStack {
            if let mountain {
                MountainPhoto(mountain: mountain, dimming: 0.24)
            } else {
                Color.white.opacity(0.46)
            }

            Text("\(day)")
                .font(.frogTitle)
                .foregroundStyle(mountain == nil ? FrogTheme.muted : .white)
                .shadow(color: .black.opacity(mountain == nil ? 0 : 0.25), radius: 3)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? FrogTheme.orange : Color.white.opacity(mountain == nil ? 0 : 0.65), lineWidth: isSelected ? 3 : 1)
        )
    }
}

private struct PassportCoverMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(label)
                .font(.frogMicro)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct StampTimelineCard: View {
    let day: Int
    let mountain: Mountain
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                MountainPhoto(mountain: mountain, dimming: 0.14)
                    .frame(width: 98, height: 82)

                Text("\(day)")
                    .font(.frogCaption.weight(.black))
                    .foregroundStyle(FrogTheme.forest)
                    .frame(width: 30, height: 30)
                    .background(FrogTheme.passport.opacity(0.92), in: Circle())
                    .padding(7)
            }
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(mountain.nameZh)
                    .font(.frogCaption.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                Text("\(mountain.height)m")
                    .font(.frogMicro)
                    .foregroundStyle(FrogTheme.muted)
            }
        }
        .frame(width: 98, alignment: .leading)
        .padding(8)
        .background(isSelected ? FrogTheme.orangeSoft : Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(isSelected ? FrogTheme.orange : FrogTheme.line, lineWidth: isSelected ? 2 : 1)
        )
    }
}
