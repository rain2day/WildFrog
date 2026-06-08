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
        ScrollView {
            VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                passportCover
                TripsSection()
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
                    FrogTheme.forest.opacity(0.16),
                    FrogTheme.forest.opacity(0.42),
                    FrogTheme.forest.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    FrogTheme.orange.opacity(0.18),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
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
                    PassportCoverMetric(value: "\(activeDays.count)", label: "月內打卡日", systemImage: "calendar")
                    PassportCoverMetric(value: "\(checkInStore.distinctMountainCount)", label: "已到山峰", systemImage: "mountain.2")
                    PassportCoverMetric(value: "\(checkInStore.currentStreak)", label: "連續日", systemImage: "flame")
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

    private var recentCoverMountain: Mountain {
        checkedMountains.first ?? MountainCatalog.mountain(id: "lion-rock")
    }

    private var passportStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                RecordSectionTitle(title: "山峰印章圖鑑")
                Spacer()
                Text("\(checkInStore.distinctMountainCount) / \(MountainCatalog.catalogCount)")
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(FrogTheme.orange)
            }
            Divider()
                .background(FrogTheme.forest.opacity(0.12))

            MountainStampGrid(
                unlockedMountainIds: checkInStore.visitedMountainIds,
                columnsCount: 5,
                showsLabels: true
            )
        }
        .padding(FrogSpace.cardPadding)
        .paperCardStyle(cornerRadius: 18)
    }

    private var calendarPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayedMonthLabel)
                        .font(.system(size: 23, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.forest)
                    Text("打卡相簿")
                        .font(.frogCaption.weight(.semibold))
                        .foregroundStyle(FrogTheme.ink)
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
                        .font(.frogMicro.weight(.black))
                        .foregroundStyle(FrogTheme.ink.opacity(0.68))
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
        .paperCardStyle()
    }

    private var selectedRecordCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: selectedRecord == nil ? .center : .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedDay)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(FrogTheme.forest)
                    Text("\(displayedMonthNumber)月")
                        .font(.frogCaption.weight(.black))
                        .foregroundStyle(FrogTheme.ink)
                }

                if selectedRecord == nil {
                    Rectangle()
                        .fill(FrogTheme.forest.opacity(0.12))
                        .frame(width: 1, height: 56)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("這天未有打卡紀錄")
                            .font(.frogRow)
                            .foregroundStyle(FrogTheme.ink)
                        Text("完成有效打卡後，當天會出現在 passport 日曆。")
                            .font(.frogCaption)
                            .foregroundStyle(FrogTheme.muted)
                            .lineLimit(2)
                    }
                } else {
                    Spacer()
                }

                if let selectedRecord {
                    NavigationLink(value: NativeRoute.tripDetail(selectedRecord.id)) {
                        Label("查看行程", systemImage: "chevron.right")
                            .font(.frogCaption)
                    }
                    .buttonStyle(.bordered)
                    .tint(FrogTheme.orange)
                }
            }

            if let selectedRecord, let selectedMountain {
                ZStack(alignment: .bottomLeading) {
                    CheckInRecordPhoto(record: selectedRecord, mountain: selectedMountain, dimming: 0.18)
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

                Text("顯示你打卡時保存的原相；水印版本只用於分享或相簿輸出。")
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
            }
        }
        .padding(FrogSpace.cardPadding)
        .background(alignment: .bottomTrailing) {
            Image(systemName: "mountain.2")
                .font(.system(size: 82, weight: .light))
                .foregroundStyle(FrogTheme.forest.opacity(0.055))
                .padding(.trailing, 18)
                .padding(.bottom, 10)
        }
        .paperCardStyle()
    }
}

private struct CalendarTile: View {
    let day: Int
    let record: CheckInRecord?
    let isSelected: Bool
    let isCurrentMonth: Bool

    var body: some View {
        ZStack {
            if let record {
                CheckInRecordPhoto(record: record, mountain: MountainCatalog.mountain(id: record.mountainId), dimming: 0.24)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isCurrentMonth ? Color.white.opacity(0.74) : FrogTheme.warmPaper.opacity(0.58))
                    .overlay {
                        FrogContourLines(color: FrogTheme.forest.opacity(isCurrentMonth ? 0.025 : 0.015), lineWidth: 0.6)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
            }

            Text("\(day)")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(record == nil ? (isCurrentMonth ? FrogTheme.ink : FrogTheme.muted.opacity(0.72)) : .white)
                .shadow(color: .black.opacity(record == nil ? 0 : 0.25), radius: 3)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isSelected ? FrogTheme.orange : (record == nil ? FrogTheme.forest.opacity(0.07) : Color.white.opacity(0.65)),
                    lineWidth: isSelected ? 2 : 1
                )
        )
    }
}

private struct PassportCoverMetric: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FrogTheme.leaf.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(label)
                    .font(.frogMicro.weight(.bold))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Capsule()
                    .fill(FrogTheme.leaf.opacity(0.84))
                    .frame(width: 28, height: 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct CalendarCellModel: Identifiable {
    let day: Int
    let isCurrentMonth: Bool
    let id: String
}

private struct RecordSectionTitle: View {
    let title: String
    var systemImage: String = "seal.fill"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(FrogTheme.forest)
                .frame(width: 30, height: 30)
                .background(FrogTheme.forest.opacity(0.08), in: Circle())
            Text(title)
                .font(.frogTitle)
                .foregroundStyle(FrogTheme.forest)
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
                    .font(.frogMicro.weight(isUnlocked ? .black : .semibold))
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
                .fill(isUnlocked ? Color.white.opacity(0.68) : Color.white.opacity(0.36))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isUnlocked ? FrogTheme.orange.opacity(0.18) : FrogTheme.forest.opacity(0.05), lineWidth: 1)
        )
    }

    private var accessibilityLabel: String {
        if let mountain = slot.mountain {
            return isUnlocked ? "\(mountain.nameZh) 印章已解鎖" : "\(mountain.nameZh) 印章未解鎖"
        }
        return "未加入山峰資料的印章槽位"
    }
}

// MARK: - Trips section ("我嘅行程")

/// Lists every completed check-in (newest first). Each row is one trip: summit
/// photo, mountain, date, and a track badge (distance/time) or a 打卡 tag.
private struct TripsSection: View {
    @EnvironmentObject private var checkInStore: CheckInStore

    private var trips: [CheckInRecord] {
        checkInStore.records.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RecordSectionTitle(title: "我嘅行程", systemImage: "figure.hiking")
                Spacer()
                Text("\(trips.count)")
                    .font(.frogCaption.weight(.black))
                    .foregroundStyle(FrogTheme.orange)
            }

            if trips.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(trips) { record in
                        NavigationLink(value: NativeRoute.tripDetail(record.id)) {
                            TripRow(record: record)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(FrogSpace.cardPadding)
        .paperCardStyle(cornerRadius: 18)
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
        .padding(.vertical, 10)
    }
}

private struct TripRow: View {
    let record: CheckInRecord

    @State private var thumbnail: UIImage?

    private var mountain: Mountain {
        MountainCatalog.mountain(id: record.mountainId)
    }

    var body: some View {
        HStack(spacing: 14) {
            thumbnailView

            VStack(alignment: .leading, spacing: 5) {
                Text(mountain.nameZh)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(FrogTheme.muted)
                badge
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FrogTheme.muted)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: 1)
        )
        .onAppear { loadThumbnail() }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        PhotoFallbackView(image: thumbnail, mountain: mountain, dimming: 0.1)
        .frame(width: 66, height: 66)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var badge: some View {
        if let track = record.track {
            HStack(spacing: 10) {
                Label(TrackFormat.distance(track.distanceMeters), systemImage: "ruler")
                Label(TrackFormat.duration(track.durationSeconds), systemImage: "clock")
            }
            .font(.frogMicro.weight(.bold))
            .foregroundStyle(FrogTheme.moss)
        } else {
            Text("打卡")
                .font(.frogMicro.weight(.black))
                .foregroundStyle(FrogTheme.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
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
