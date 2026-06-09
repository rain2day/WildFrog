import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RecordsCalendarView: View {
    @EnvironmentObject private var checkInStore: CheckInStore

    @State private var selectedDay = Calendar.current.component(.day, from: Date())
    @State private var displayedMonth: Date = {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: components) ?? Date()
    }()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)

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

    /// Map from active day → first matched check-in record for calendar tiles.
    private var activeRecords: [Int: CheckInRecord] {
        var result: [Int: CheckInRecord] = [:]
        for day in activeDays {
            let matchingRecord = checkInStore.records.first { record in
                let cal = Calendar.current
                let comps = cal.dateComponents([.year, .month, .day], from: record.date)
                return comps.year == displayedYear && comps.month == displayedMonthNumber && comps.day == day
            }
            if let matchingRecord {
                result[day] = matchingRecord
            }
        }
        return result
    }

    private var selectedRecord: CheckInRecord? {
        activeRecords[selectedDay]
    }

    private var selectedMountain: Mountain? {
        selectedRecord.map { MountainCatalog.mountain(id: $0.mountainId) }
    }

    private var monthDays: [Int] {
        if let range = Calendar.current.range(of: .day, in: .month, for: displayedMonth) {
            return Array(range)
        }
        return Array(1...30)
    }

    private var calendarCells: [CalendarCellModel] {
        let calendar = Calendar.current
        guard
            let range = calendar.range(of: .day, in: .month, for: displayedMonth),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else {
            return monthDays.map { CalendarCellModel(day: $0, isCurrentMonth: true, id: "current-\($0)") }
        }

        let leadingCount = (calendar.component(.weekday, from: firstDay) - calendar.firstWeekday + 7) % 7
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: firstDay)
        let previousCount = previousMonth.flatMap { calendar.range(of: .day, in: .month, for: $0)?.count } ?? 31

        var cells: [CalendarCellModel] = []
        if leadingCount > 0 {
            for day in (previousCount - leadingCount + 1)...previousCount {
                cells.append(CalendarCellModel(day: day, isCurrentMonth: false, id: "previous-\(day)"))
            }
        }

        for day in range {
            cells.append(CalendarCellModel(day: day, isCurrentMonth: true, id: "current-\(day)"))
        }

        let trailingCount = (7 - (cells.count % 7)) % 7
        if trailingCount > 0 {
            for day in 1...trailingCount {
                cells.append(CalendarCellModel(day: day, isCurrentMonth: false, id: "next-\(day)"))
            }
        }

        return cells
    }

    var body: some View {
        GeometryReader { outer in
            let topInset = outer.safeAreaInsets.top

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    passportCover(topInset: topInset)

                    VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                        TripsSection()
                        calendarPanel
                        selectedRecordCard
                        passportStrip
                    }
                    .padding(FrogSpace.screenPadding)
                    .padding(.top, FrogSpace.cardGap)
                    .padding(.bottom, 110)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .hiddenNavigationBar()
        .appPageBackground(FrogTheme.passport)
    }

    // MARK: - Passport hero (.passport)

    private func passportCover(topInset: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            MountainPhoto(mountain: recentCoverMountain, dimming: 0)

            // Single layered gradient — readable photo top, anchored forest bottom.
            LinearGradient(
                colors: [
                    FrogTheme.forest.opacity(0.30),
                    FrogTheme.forest.opacity(0.55),
                    FrogTheme.forest.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    WildFrogWordmark(markSize: 30)
                        .shadow(color: Color.black.opacity(0.28), radius: 8, y: 3)

                    Spacer()

                    Text(displayedMonth.formatted(.dateTime.year().month(.abbreviated).locale(Locale(identifier: "en_US"))))
                        .font(.frogNum(11, weight: .semibold))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(FrogTheme.forest)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(FrogTheme.leaf, in: Capsule())
                }
                .padding(.top, topInset + 8)

                Spacer(minLength: 24)

                Text("Peak Passport")
                    .font(.frogNum(30, weight: .heavy))
                    .foregroundStyle(.white)

                Text("每一次有效打卡，都變成一本香港山峰護照。")
                    .font(.frogCaption)
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(2)
                    .padding(.top, 7)

                HStack(spacing: 9) {
                    PassportCoverMetric(value: "\(activeDays.count)", label: "月內打卡日")
                    PassportCoverMetric(value: "\(checkInStore.distinctMountainCount)", label: "已到山峰")
                    PassportCoverMetric(value: "\(checkInStore.currentStreak)", label: "連續日")
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, FrogSpace.screenPadding + 4)
            .padding(.bottom, 24)
        }
        .frame(height: topInset + 290)
        .clipped()
    }

    private var recentCoverMountain: Mountain {
        checkInStore.records
            .sorted { $0.date > $1.date }
            .first
            .map { MountainCatalog.mountain(id: $0.mountainId) }
            ?? MountainCatalog.mountain(id: "lion-rock")
    }

    // MARK: - Stamp passport (山峰印章圖鑑)

    private var passportStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            RecordSectionHeader(title: "山峰印章圖鑑 · STAMPS") {
                Text("\(checkInStore.distinctMountainCount) / \(MountainCatalog.catalogCount)")
                    .font(.frogNum(12, weight: .semibold))
                    .foregroundStyle(FrogTheme.moss)
            }

            MountainStampGrid(
                unlockedMountainIds: checkInStore.visitedMountainIds,
                columnsCount: 5,
                limit: 15,
                prioritizesUnlocked: true,
                showsLabels: true
            )
            .padding(FrogSpace.cardPadding)
            .cardStyle()
        }
    }

    // MARK: - Photo calendar (.panel)

    private var calendarPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayedMonthLabel)
                        .font(.frogNum(22, weight: .heavy))
                        .foregroundStyle(FrogTheme.forest)
                    Text("打卡相簿")
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.muted)
                }

                Spacer()

                HStack(spacing: 8) {
                    CalendarNavButton(systemImage: "chevron.left") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                            selectedDay = 1
                        }
                    }
                    CalendarNavButton(systemImage: "chevron.right") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                            selectedDay = 1
                        }
                    }
                }
            }

            HStack(spacing: 7) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.faint)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(calendarCells) { cell in
                    Button {
                        if cell.isCurrentMonth {
                            selectedDay = cell.day
                        }
                    } label: {
                        CalendarTile(
                            day: cell.day,
                            record: cell.isCurrentMonth ? activeRecords[cell.day] : nil,
                            isSelected: cell.isCurrentMonth && selectedDay == cell.day,
                            isCurrentMonth: cell.isCurrentMonth
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!cell.isCurrentMonth)
                }
            }
        }
        .padding(FrogSpace.cardPadding)
        .cardStyle()
    }

    // MARK: - Selected record (.panel)

    private var selectedRecordCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedDay)")
                        .font(.frogNum(42, weight: .heavy))
                        .foregroundStyle(FrogTheme.forest)
                    Text("\(displayedMonthNumber)月")
                        .font(.frogMicro.weight(.bold))
                        .foregroundStyle(FrogTheme.ink)
                }

                if selectedRecord == nil {
                    Rectangle()
                        .fill(FrogTheme.line)
                        .frame(width: 1, height: 52)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("這天未有打卡紀錄")
                            .font(.frogRow)
                            .foregroundStyle(FrogTheme.ink)
                        Text("完成有效打卡後，當天會出現在 passport 日曆。")
                            .font(.frogCaption)
                            .foregroundStyle(FrogTheme.muted)
                            .lineLimit(2)
                    }
                } else {
                    Spacer(minLength: 0)
                }

                if let selectedRecord {
                    NavigationLink(value: NativeRoute.tripDetail(selectedRecord.id)) {
                        Text("查看行程")
                            .font(.frogCaption.weight(.semibold))
                            .foregroundStyle(FrogTheme.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .overlay(
                                Capsule().stroke(FrogTheme.line, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if let selectedRecord, let selectedMountain {
                ZStack(alignment: .bottomLeading) {
                    CheckInRecordPhoto(record: selectedRecord, mountain: selectedMountain, dimming: 0)
                        .frame(height: 172)
                    LinearGradient(
                        colors: [.clear, FrogTheme.forest.opacity(0.8)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedMountain.displayName)
                            .font(.frogTitle)
                        Text("第 \(checkInStore.count(for: selectedMountain.id)) 次登頂 · \(selectedMountain.height)m")
                            .font(.frogNum(13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                }
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
        }
        .padding(FrogSpace.cardPadding)
        .cardStyle()
    }
}

// MARK: - Calendar nav button (.cal-nav .b)

private struct CalendarNavButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(FrogTheme.ink)
                .frame(width: 34, height: 34)
                .background(FrogTheme.warmPaper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(FrogTheme.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendar tile (.cal-cell)

private struct CalendarTile: View {
    let day: Int
    let record: CheckInRecord?
    let isSelected: Bool
    let isCurrentMonth: Bool

    var body: some View {
        ZStack {
            if let record {
                CheckInRecordPhoto(record: record, mountain: MountainCatalog.mountain(id: record.mountainId), dimming: 0)
                Color.black.opacity(0.28)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(FrogTheme.warmPaper)
            }

            Text("\(day)")
                .font(.frogNum(14, weight: .medium))
                .foregroundStyle(record == nil ? FrogTheme.muted : .white)
                .shadow(color: .black.opacity(record == nil ? 0 : 0.5), radius: 3, y: 1)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isSelected ? FrogTheme.orange : (record == nil ? FrogTheme.lineSoft : Color.white.opacity(0.5)),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .opacity(isCurrentMonth ? 1 : 0.4)
    }
}

// MARK: - Passport metric (.ppm .m)

private struct PassportCoverMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.frogNum(22, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.frogMicro.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 4)

            Capsule()
                .fill(FrogTheme.leaf)
                .frame(width: 26, height: 3)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(FrogTheme.forest.opacity(0.42), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct CalendarCellModel: Identifiable {
    let day: Int
    let isCurrentMonth: Bool
    let id: String
}

// MARK: - Section header (.wf-section eyebrow + hairline rule)

private struct RecordSectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.frogEyebrow)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(FrogTheme.moss)
                .fixedSize(horizontal: true, vertical: false)
            Rectangle()
                .fill(FrogTheme.line)
                .frame(height: 1)
            trailing
        }
    }
}

struct MountainStampGrid: View {
    let unlockedMountainIds: Set<String>
    var columnsCount: Int = 5
    var limit: Int?
    var prioritizesUnlocked: Bool = false
    var showsLabels: Bool = true

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: columnsCount)
    }

    private var slots: [MountainStampSlot] {
        let allSlots = (1...MountainCatalog.catalogCount).map { index -> MountainStampSlot in
            let mountain = MountainCatalog.mountains.indices.contains(index - 1) ? MountainCatalog.mountains[index - 1] : nil
            return MountainStampSlot(index: index, mountain: mountain)
        }

        let orderedSlots: [MountainStampSlot]
        if prioritizesUnlocked {
            orderedSlots = allSlots.sorted {
                let lhsUnlocked = $0.mountain.map { unlockedMountainIds.contains($0.id) } ?? false
                let rhsUnlocked = $1.mountain.map { unlockedMountainIds.contains($0.id) } ?? false
                if lhsUnlocked != rhsUnlocked {
                    return lhsUnlocked && !rhsUnlocked
                }
                return $0.index < $1.index
            }
        } else {
            orderedSlots = allSlots
        }

        if let limit {
            return Array(orderedSlots.prefix(limit))
        }
        return orderedSlots
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(slots) { slot in
                MountainStampSlotView(
                    slot: slot,
                    isUnlocked: slot.mountain.map { unlockedMountainIds.contains($0.id) } ?? false,
                    showsLabel: showsLabels
                )
            }
        }
    }
}

private struct MountainStampSlot: Identifiable {
    let index: Int
    let mountain: Mountain?

    var id: Int { index }

    var imageName: String {
        String(format: "WildFrogStamp%03d", index)
    }
}

private struct MountainStampSlotView: View {
    let slot: MountainStampSlot
    let isUnlocked: Bool
    let showsLabel: Bool

    var body: some View {
        Group {
            if let mountain = slot.mountain {
                NavigationLink(value: NativeRoute.mountainDetail(mountain.id)) {
                    content(label: mountain.nameZh)
                }
                .buttonStyle(.plain)
            } else {
                content(label: "待加入")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func content(label: String) -> some View {
        VStack(spacing: showsLabel ? 5 : 0) {
            ZStack(alignment: .topTrailing) {
                Image(slot.imageName)
                    .resizable()
                    .scaledToFit()
                    .saturation(isUnlocked ? 1 : 0)
                    .opacity(isUnlocked ? 1 : 0.32)
                    .overlay {
                        if !isUnlocked {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(FrogTheme.passport.opacity(0.48))
                        }
                    }

                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(FrogTheme.muted)
                        .frame(width: 20, height: 20)
                        .background(FrogTheme.passport, in: Circle())
                        .overlay(Circle().stroke(FrogTheme.forest.opacity(0.12), lineWidth: 1))
                        .padding(2)
                }
            }
            .frame(height: showsLabel ? 64 : 54)
            .frame(maxWidth: .infinity)

            if showsLabel {
                Text(label)
                    .font(.frogMicro.weight(isUnlocked ? .bold : .medium))
                    .foregroundStyle(isUnlocked ? FrogTheme.forest : FrogTheme.muted.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, showsLabel ? 6 : 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isUnlocked ? FrogTheme.warmPaper : FrogTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isUnlocked ? FrogTheme.moss.opacity(0.18) : FrogTheme.lineSoft, lineWidth: 1)
        )
    }

    private var accessibilityLabel: String {
        if let mountain = slot.mountain {
            return isUnlocked ? "\(mountain.nameZh) 印章已解鎖" : "\(mountain.nameZh) 印章未解鎖"
        }
        return "未加入山峰資料的印章槽位"
    }
}

// MARK: - Trips section ("我嘅行程 · TRIPS")

/// Preview of the most recent trips (newest first). Each row is one trip: summit
/// photo, mountain, date, and a track badge (distance/time) or a 打卡 tag.
/// When there are more than `previewLimit`, a "全部行程 →" link opens the full list.
private struct TripsSection: View {
    @EnvironmentObject private var checkInStore: CheckInStore

    private let previewLimit = 4

    private var trips: [CheckInRecord] {
        checkInStore.records.sorted { $0.date > $1.date }
    }

    private var previewTrips: [CheckInRecord] {
        Array(trips.prefix(previewLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RecordSectionHeader(title: "我嘅行程 · TRIPS") {
                Text("\(trips.count)")
                    .font(.frogNum(12, weight: .semibold))
                    .foregroundStyle(FrogTheme.moss)
            }

            if trips.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(previewTrips) { record in
                        NavigationLink(value: NativeRoute.tripDetail(record.id)) {
                            TripRow(record: record)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if trips.count > previewLimit {
                    NavigationLink {
                        AllTripsView(trips: trips)
                    } label: {
                        HStack(spacing: 6) {
                            Text("全部行程")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .font(.frogCaption.weight(.semibold))
                        .foregroundStyle(FrogTheme.moss)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(FrogTheme.line, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "figure.hiking")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(FrogTheme.muted)
            Text("仲未有打卡，去打返座山！")
                .font(.frogRow)
                .foregroundStyle(FrogTheme.ink)
            Text("完成打卡後，每次行程都會收錄喺呢度，有記軌跡仲會顯示路線同距離。")
                .font(.frogCaption)
                .foregroundStyle(FrogTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrogSpace.cardPadding)
        .cardStyle()
    }
}

/// Full chronological list of every completed trip, reached via "全部行程 →".
private struct AllTripsView: View {
    let trips: [CheckInRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                RecordSectionHeader(title: "全部行程 · ALL TRIPS") {
                    Text("\(trips.count)")
                        .font(.frogNum(12, weight: .semibold))
                        .foregroundStyle(FrogTheme.moss)
                }

                VStack(spacing: 10) {
                    ForEach(trips) { record in
                        NavigationLink(value: NativeRoute.tripDetail(record.id)) {
                            TripRow(record: record)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(FrogSpace.screenPadding)
            .padding(.bottom, 110)
        }
        .navigationTitle("我嘅行程")
        .nativeInlineTitle()
        .appPageBackground(FrogTheme.passport)
    }
}

private struct TripRow: View {
    let record: CheckInRecord

    @State private var thumbnail: UIImage?

    private var mountain: Mountain {
        MountainCatalog.mountain(id: record.mountainId)
    }

    var body: some View {
        HStack(spacing: 13) {
            thumbnailView

            VStack(alignment: .leading, spacing: 3) {
                Text(mountain.nameZh)
                    .font(.frogRow)
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.frogNum(12, weight: .medium))
                    .foregroundStyle(FrogTheme.muted)
                badge
                    .padding(.top, 3)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FrogTheme.faint)
        }
        .padding(11)
        .background(FrogTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: 1)
        )
        .onAppear { loadThumbnail() }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        PhotoFallbackView(image: thumbnail, mountain: mountain, dimming: 0.1)
            .scaledToFill()
            .frame(width: 60, height: 60)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var badge: some View {
        if let track = record.track {
            HStack(spacing: 12) {
                Label(TrackFormat.distance(track.distanceMeters), systemImage: "ruler")
                Label(TrackFormat.duration(track.durationSeconds), systemImage: "clock")
            }
            .font(.frogNum(11, weight: .semibold))
            .foregroundStyle(FrogTheme.moss)
        } else {
            Text("打卡")
                .font(.frogMicro.weight(.bold))
                .foregroundStyle(FrogTheme.orange)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(FrogTheme.orangeSoft, in: Capsule())
        }
    }

    private func loadThumbnail() {
        #if os(iOS)
        guard thumbnail == nil, let filename = record.photoFilename, !filename.isEmpty else { return }
        Task {
            let image = await Task.detached(priority: .utility) { () -> UIImage? in
                guard let url = FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)
                    .first?
                    .appendingPathComponent(filename),
                      let data = try? Data(contentsOf: url) else { return nil }
                return UIImage(data: data)
            }.value
            await MainActor.run { thumbnail = image }
        }
        #endif
    }
}

private struct CheckInRecordPhoto: View {
    let record: CheckInRecord
    let mountain: Mountain
    var dimming: Double = 0.1

    @State private var image: UIImage?

    var body: some View {
        PhotoFallbackView(image: image, mountain: mountain, dimming: dimming)
            .onAppear { loadPhoto() }
    }

    private func loadPhoto() {
        #if os(iOS)
        guard image == nil, let filename = record.photoFilename, !filename.isEmpty else { return }
        Task {
            let loaded = await Task.detached(priority: .utility) { () -> UIImage? in
                guard let url = FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)
                    .first?
                    .appendingPathComponent(filename),
                      let data = try? Data(contentsOf: url) else { return nil }
                return UIImage(data: data)
            }.value
            await MainActor.run { image = loaded }
        }
        #endif
    }
}

private struct PhotoFallbackView: View {
    let image: UIImage?
    let mountain: Mountain
    var dimming: Double = 0.1

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                MountainPhoto(mountain: mountain, dimming: dimming)
            }
        }
    }
}
