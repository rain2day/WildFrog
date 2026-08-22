import MapKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Records stack router
//
// The standalone-trip flow used to be a chain of nested `fullScreenCover`s
// (editor → packing → active → summary sheet). Dismissing any one of them left
// the rest of the chain in an unpredictable state. The whole flow now lives on
// the Records navigation stack; this router is the handle the flow views use to
// push / replace / pop on that stack.
@MainActor
final class RecordsNavigationRouter: ObservableObject {
    @Published var path: NavigationPath

    init(path: NavigationPath = NavigationPath()) {
        self.path = path
    }

    func push(_ route: NativeRoute) {
        path.append(route)
    }

    /// Swap the top of the stack for another screen — used for the linear
    /// editor → packing → active → summary progression so "back" never returns
    /// to a step that is already finished.
    func replaceTop(with route: NativeRoute) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }

    func popToRoot() {
        path = NavigationPath()
    }
}

// MARK: - Error copy

extension TripSessionError {
    var tripFlowMessage: String {
        switch self {
        case .tripNotFound:
            AppText.value(zh: "搵唔到呢個行程，可能已經刪咗。", en: "This trip could not be found — it may have been deleted.")
        case .tripAlreadyActive:
            AppText.value(zh: "已經有行程記錄緊，請先完成或者收起佢。", en: "A trip is already recording. Finish or minimise it first.")
        case .noActiveTrip:
            AppText.value(zh: "而家冇進行中嘅行程。", en: "There is no trip in progress.")
        case .invalidStatus:
            AppText.value(zh: "呢個行程嘅狀態唔做得呢個動作。", en: "This trip's status doesn't allow that action.")
        }
    }
}

enum TripFlowMessage {
    static func text(for error: Error) -> String {
        if let sessionError = error as? TripSessionError { return sessionError.tripFlowMessage }
        if let localized = error as? LocalizedError, let description = localized.errorDescription { return description }
        return error.localizedDescription
    }
}

// MARK: - Status presentation

extension TripStatus {
    var tripBadgeText: String {
        switch self {
        case .planned: AppText.value(zh: "準備中", en: "PLANNED")
        case .active: AppText.value(zh: "記錄中", en: "RECORDING")
        case .paused: AppText.value(zh: "已暫停", en: "PAUSED")
        case .completed: AppText.value(zh: "已完成", en: "DONE")
        case .cancelled: AppText.value(zh: "未完成", en: "INCOMPLETE")
        }
    }

    var tripBadgeColor: Color {
        switch self {
        case .planned: FrogTheme.moss
        case .active, .paused: FrogTheme.orange
        case .completed: FrogTheme.forest
        case .cancelled: FrogTheme.muted
        }
    }
}

// MARK: - Auto naming

enum TripAutoName {
    static func value(activityName: String, date: Date) -> String {
        if AppText.isEnglish {
            let day = date.formatted(.dateTime.month(.abbreviated).day().locale(AppText.locale))
            return "\(day) \(activityName)"
        }
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)月\(day)日 \(activityName)"
    }

    static func value(activity: TripActivityType, date: Date) -> String {
        value(activityName: activity.localizedName, date: date)
    }
}

/// Last activity the hiker actually used, so "Start Now" doesn't always guess 行山.
enum TripPreferences {
    static let lastActivityKey = "wildfrog.trip.lastActivityID"
}

// MARK: - Gear snapshot merge

enum TripGearMerge {
    /// Re-snapshotting a kit must not silently un-tick everything the hiker
    /// already packed — carry `isPacked` across by source gear item id.
    static func preservingPacked(_ new: [TripGearEntry], previous: [TripGearEntry]) -> [TripGearEntry] {
        guard !previous.isEmpty else { return new }
        var packedByItem: [UUID: Bool] = [:]
        for entry in previous {
            guard let source = entry.sourceGearItemID else { continue }
            packedByItem[source] = entry.isPacked
        }
        return new.map { entry in
            var updated = entry
            if let source = entry.sourceGearItemID, let packed = packedByItem[source] {
                updated.isPacked = packed
            }
            return updated
        }
    }
}

// MARK: - Shared "paper form" primitives
//
// Deliberately small: the trip/gear screens just need the app's warm card look
// instead of the stock grey `Form`, not a second design system.

struct TripFormPage<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrogSpace.cardGap) {
                content
            }
            .padding(FrogSpace.screenPadding)
            .padding(.bottom, 40)
        }
        .appPageBackground(FrogTheme.passport)
    }
}

struct TripFormSection<Content: View>: View {
    private let title: String?
    private let footer: String?
    private let content: Content

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.frogEyebrow)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(FrogTheme.moss)
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(FrogSpace.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            if let footer {
                Text(footer)
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Label + trailing control on one hairline-separated line.
struct TripFieldRow<Control: View>: View {
    private let label: String
    private let control: Control
    var showsDivider = true

    init(_ label: String, showsDivider: Bool = true, @ViewBuilder control: () -> Control) {
        self.label = label
        self.showsDivider = showsDivider
        self.control = control()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(FrogTheme.muted)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 8)
                control
                    .font(.frogRow)
                    .foregroundStyle(FrogTheme.ink)
            }
            .frame(minHeight: 44)
            if showsDivider {
                Rectangle().fill(FrogTheme.lineSoft).frame(height: 1)
            }
        }
    }
}

struct TripTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .font(.frogRow)
            .foregroundStyle(FrogTheme.ink)
            .multilineTextAlignment(axis == .horizontal ? .trailing : .leading)
            .textFieldStyle(.plain)
    }
}

struct TripPrimaryButtonStyle: ButtonStyle {
    var isEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.frogRow.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(isEnabled ? FrogTheme.orange : FrogTheme.faint)
            )
            .shadow(color: FrogTheme.orange.opacity(isEnabled ? 0.22 : 0), radius: 9, y: 4)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct TripSecondaryButtonStyle: ButtonStyle {
    var tint: Color = FrogTheme.moss

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.frogRow.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(tint)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

/// Compact stat used inside the active-trip overlay panel where `StatCard`
/// (which draws its own card) would nest a card inside a card.
struct TripStatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.frogNum(21, weight: .heavy))
                .foregroundStyle(FrogTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.frogMicro)
                .foregroundStyle(FrogTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Trip hub

struct TripHubSection: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var session: TripSessionCoordinator
    @EnvironmentObject private var router: RecordsNavigationRouter
    @AppStorage(TripPreferences.lastActivityKey) private var lastActivityID = TripActivityType.hiking.id
    @State private var errorMessage: String?

    private var upcoming: [StandaloneTrip] {
        store.trips.filter { $0.status == .planned }.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    /// Everything that is not "planned" and not the live one — completed AND
    /// cancelled/incomplete, so an abandoned trip never just vanishes.
    private var pastTrips: [StandaloneTrip] {
        store.trips
            .filter { $0.status == .completed || $0.status == .cancelled }
            .prefix(3)
            .map { $0 }
    }

    private var isEmpty: Bool { upcoming.isEmpty && pastTrips.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let active = session.activeTrip {
                Button { router.push(.activeTrip) } label: {
                    TripHubRow(trip: active, status: active.status)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: startNow) {
                    Label(AppText.value(zh: "即刻出發", en: "Start Now"), systemImage: "figure.hiking")
                }
                .buttonStyle(TripPrimaryButtonStyle())
                .accessibilityHint(AppText.value(
                    zh: "用上次嘅活動同預設裝備即刻開始記錄",
                    en: "Starts recording right away using your last activity and its default kit"
                ))
            }

            if isEmpty && session.activeTrip == nil {
                Text(AppText.value(
                    zh: "撳「即刻出發」即刻開始，或者撳 ＋ 慢慢計劃。",
                    en: "Tap Start Now to go, or + to plan one properly."
                ))
                .font(.frogCaption)
                .foregroundStyle(FrogTheme.muted)
            } else {
                ForEach(upcoming.prefix(2)) { trip in
                    Button { router.push(.packingChecklist(trip.id)) } label: {
                        TripHubRow(trip: trip, status: trip.status)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(pastTrips) { trip in
                    Button { router.push(.standaloneTripDetail(trip.id)) } label: {
                        TripHubRow(trip: trip, status: trip.status)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !store.trips.isEmpty {
                Button { router.push(.allStandaloneTrips) } label: {
                    HStack(spacing: 6) {
                        Text(AppText.value(zh: "全部行程", en: "All Trips"))
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                    }
                    .font(.frogCaption.weight(.semibold))
                    .foregroundStyle(FrogTheme.moss)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FrogTheme.line, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FrogSpace.cardPadding)
        .cardStyle()
        .alert(
            AppText.value(zh: "開始唔到行程", en: "Couldn't start the trip"),
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button(AppText.value(zh: "知道喇", en: "OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppText.value(zh: "我的行程", en: "My Trips"))
                    .font(.frogTitle.weight(.black))
                    .foregroundStyle(FrogTheme.ink)
                Text(AppText.value(zh: "唔打卡都可以記錄軌跡", en: "Record a route without checking in"))
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
            }
            Spacer()
            Button { router.push(.gearLibrary) } label: {
                Image(systemName: "backpack.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FrogTheme.moss)
                    .frame(width: 44, height: 44)
                    .background(FrogTheme.moss.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppText.value(zh: "裝備庫", en: "Gear Library"))

            Button { router.push(.tripEditor(nil)) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(FrogTheme.forest)
                    .frame(width: 44, height: 44)
                    .background(FrogTheme.leaf.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppText.value(zh: "制定行程", en: "Plan Trip"))
        }
    }

    /// One tap → a named trip with the last-used activity and its default kit,
    /// straight into packing (or straight into recording when there's no kit).
    private func startNow() {
        let activity = store.activityTypes.first { $0.id == lastActivityID && !$0.isArchived }
            ?? store.activityTypes.first { !$0.isArchived }
            ?? .hiking
        let kit = activity.defaultGearKitID.flatMap { id in store.gearKits.first { $0.id == id && !$0.isArchived } }
            ?? store.gearKits.first { $0.activityTypeIDs.contains(activity.id) && !$0.isArchived }
        let gear = kit?.snapshot(using: store.gearItems) ?? []
        let trip = StandaloneTrip(
            name: TripAutoName.value(activity: activity, date: .now),
            activity: TripActivitySnapshot(activity),
            scheduledAt: .now,
            gear: gear
        )
        do {
            try store.saveTrip(trip)
            lastActivityID = activity.id
            if gear.isEmpty {
                try session.start(tripID: trip.id)
                router.push(.activeTrip)
            } else {
                router.push(.packingChecklist(trip.id))
            }
        } catch {
            errorMessage = TripFlowMessage.text(for: error)
        }
    }
}

struct TripHubRow: View {
    let trip: StandaloneTrip
    let status: TripStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trip.activity.symbolName)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(FrogTheme.moss, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(trip.name)
                    .font(.frogRow.weight(.bold))
                    .foregroundStyle(FrogTheme.ink)
                    .lineLimit(1)
                Text("\(trip.activity.localizedName) · \(trip.scheduledAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(status.tripBadgeText)
                .font(.frogMicro.weight(.black))
                .foregroundStyle(status.tripBadgeColor)
        }
        .padding(12)
        .background(FrogTheme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - All standalone trips

struct AllStandaloneTripsView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var session: TripSessionCoordinator
    @EnvironmentObject private var router: RecordsNavigationRouter
    @State private var errorMessage: String?

    private var trips: [StandaloneTrip] { store.trips }

    var body: some View {
        List {
            if trips.isEmpty {
                Text(AppText.value(zh: "仲未有行程紀錄。", en: "No trips recorded yet."))
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(trips) { trip in
                Button { open(trip) } label: {
                    TripHubRow(trip: trip, status: trip.status)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { delete(trip) } label: {
                        Label(AppText.value(zh: "刪除", en: "Delete"), systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        .contentMargins(.horizontal, FrogSpace.screenPadding, for: .scrollContent)
        .localizedNavigationTitle { AppText.value(zh: "全部行程", en: "All Trips") }
        .nativeInlineTitle()
        .appPageBackground(FrogTheme.passport)
        .alert(
            AppText.value(zh: "做唔到", en: "Couldn't do that"),
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button(AppText.value(zh: "知道喇", en: "OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func open(_ trip: StandaloneTrip) {
        switch trip.status {
        case .planned:
            router.push(.packingChecklist(trip.id))
        case .active, .paused:
            router.push(session.activeTrip?.id == trip.id ? .activeTrip : .standaloneTripDetail(trip.id))
        case .completed, .cancelled:
            router.push(.standaloneTripDetail(trip.id))
        }
    }

    private func delete(_ trip: StandaloneTrip) {
        guard session.activeTrip?.id != trip.id else {
            errorMessage = AppText.value(
                zh: "呢個行程仲記錄緊，請先完成或者放棄佢。",
                en: "This trip is still recording. Finish or discard it first."
            )
            return
        }
        do {
            try store.deleteTrip(trip.id)
        } catch {
            errorMessage = TripFlowMessage.text(for: error)
        }
    }
}

// MARK: - Summary

struct StandaloneTripSummaryView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var checkInStore: CheckInStore
    let tripID: UUID

    private var trip: StandaloneTrip? { store.trips.first { $0.id == tripID } }

    @State private var isReadingHealth = false
    @State private var healthMessage: String?
    @State private var healthHasNoData = false
    @State private var healthUnavailable = false

    var body: some View {
        TripFormPage {
            if let trip {
                if let track = trip.track, track.coordinates.count > 1 {
                    Map { MapPolyline(coordinates: track.coordinates).stroke(FrogTheme.orange, lineWidth: 5) }
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .allowsHitTesting(false)
                }

                HStack(spacing: 10) {
                    StatCard(
                        value: trip.track.map { TrackFormat.distance($0.distanceMeters) } ?? "—",
                        label: AppText.value(zh: "距離", en: "Distance"),
                        systemImage: "ruler"
                    )
                    StatCard(
                        value: trip.track.map { TrackFormat.duration($0.durationSeconds) } ?? "—",
                        label: AppText.value(zh: "時間", en: "Time"),
                        systemImage: "clock"
                    )
                    StatCard(
                        value: "\(Int(TripTotals.intakeCalories(trip.consumables)))",
                        label: "kcal",
                        systemImage: "flame.fill"
                    )
                }

                TripFormSection(AppText.value(zh: "補給", en: "Fuel")) {
                    TripFieldRow(AppText.value(zh: "飲水", en: "Water")) {
                        Text("\(Int(TripTotals.waterMillilitres(trip.consumables))) ml")
                            .font(.frogNum(17, weight: .bold))
                    }
                    TripFieldRow(AppText.value(zh: "攝取", en: "Intake"), showsDivider: false) {
                        Text("\(Int(TripTotals.intakeCalories(trip.consumables))) kcal")
                            .font(.frogNum(17, weight: .bold))
                    }
                }

                healthSection(for: trip)
                officialCheckInSection(for: trip)

                if !trip.gear.isEmpty {
                    TripFormSection(AppText.value(zh: "裝備", en: "Gear")) {
                        ForEach(Array(trip.gear.enumerated()), id: \.element.id) { index, entry in
                            TripFieldRow(entry.name, showsDivider: index < trip.gear.count - 1) {
                                HStack(spacing: 7) {
                                    Text("×\(entry.quantity)")
                                        .font(.frogCaption)
                                        .foregroundStyle(FrogTheme.muted)
                                    Image(systemName: entry.isPacked ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(entry.isPacked ? FrogTheme.moss : FrogTheme.faint)
                                }
                            }
                        }
                    }
                }
            }
        }
        .localizedNavigationTitle { trip?.name ?? AppText.value(zh: "行程", en: "Trip") }
        .nativeInlineTitle()
    }

    // MARK: Apple Health

    @ViewBuilder
    private func healthSection(for trip: StandaloneTrip) -> some View {
        TripFormSection(AppText.value(zh: "APPLE 健康", en: "APPLE HEALTH")) {
            VStack(alignment: .leading, spacing: 10) {
                if let calories = trip.appleHealthActiveCalories {
                    Text(AppText.value(
                        zh: "活動能量估算 \(Int(calories)) kcal",
                        en: "Estimated active energy \(Int(calories)) kcal"
                    ))
                    .font(.frogRow.weight(.bold))
                    .foregroundStyle(FrogTheme.ink)
                } else if healthHasNoData {
                    Text(AppText.value(zh: "冇數據", en: "No data"))
                        .font(.frogRow.weight(.bold))
                        .foregroundStyle(FrogTheme.muted)
                    Text(AppText.value(
                        zh: "Apple 健康喺呢段時間冇活動能量紀錄。戴住 Apple Watch 或者開咗健康權限先會有。",
                        en: "Apple Health has no active-energy samples for this window. Wear an Apple Watch or grant Health access to get them."
                    ))
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if let healthMessage {
                    Text(healthMessage)
                        .font(.frogCaption)
                        .foregroundStyle(FrogTheme.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // The retry button stays put even after a nil / empty read —
                // "no data" is not a terminal state, permissions can change.
                Button { connectHealth(for: trip) } label: {
                    Label(
                        trip.appleHealthActiveCalories == nil && !healthHasNoData
                            ? AppText.value(zh: "連接並讀取今次行程", en: "Connect for This Trip")
                            : AppText.value(zh: "再讀取一次", en: "Read Again"),
                        systemImage: isReadingHealth ? "hourglass" : "heart.text.square"
                    )
                }
                .buttonStyle(TripSecondaryButtonStyle())
                .disabled(isReadingHealth)

                if healthUnavailable {
                    Button(action: openHealthSettings) {
                        Label(AppText.value(zh: "前往設定", en: "Open Settings"), systemImage: "gearshape.fill")
                    }
                    .buttonStyle(TripSecondaryButtonStyle(tint: FrogTheme.muted))
                }

                if let refreshed = trip.healthEnergyRefreshedAt {
                    Text(AppText.value(
                        zh: "上次讀取 \(refreshed.formatted(date: .abbreviated, time: .shortened))",
                        en: "Last read \(refreshed.formatted(date: .abbreviated, time: .shortened))"
                    ))
                    .font(.frogMicro)
                    .foregroundStyle(FrogTheme.faint)
                }
            }
        }
    }

    private func connectHealth(for trip: StandaloneTrip) {
        guard let startedAt = trip.startedAt, let completedAt = trip.completedAt else {
            healthMessage = TripEnergyError.missingTripDates.errorDescription
            return
        }
        isReadingHealth = true
        healthMessage = nil
        healthHasNoData = false
        healthUnavailable = false
        Task { @MainActor in
            do {
                let raw = try await AppleHealthTripEnergyProvider()
                    .requestAccessAndReadActiveEnergy(from: startedAt, to: completedAt)
                // A zero/nil read means "no samples", not "you burned 0 kcal" —
                // never persist it as a result.
                if let calories = TripEnergyReading.usableValue(raw) {
                    var updated = trip
                    updated.appleHealthActiveCalories = calories
                    updated.healthEnergyRefreshedAt = .now
                    try store.saveTrip(updated)
                } else {
                    healthHasNoData = true
                }
            } catch {
                healthMessage = TripFlowMessage.text(for: error)
                healthUnavailable = true
            }
            isReadingHealth = false
        }
    }

    private func openHealthSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    // MARK: Official check-ins

    @ViewBuilder
    private func officialCheckInSection(for trip: StandaloneTrip) -> some View {
        if !trip.officialCheckInIDs.isEmpty {
            TripFormSection(AppText.value(zh: "正式打卡", en: "OFFICIAL CHECK-INS")) {
                ForEach(Array(trip.officialCheckInIDs.enumerated()), id: \.element) { index, checkInID in
                    let isLast = index == trip.officialCheckInIDs.count - 1
                    if let record = checkInStore.records.first(where: { $0.id == checkInID }) {
                        TripFieldRow(
                            MountainCatalog.mountain(id: record.mountainId).localizedName,
                            showsDivider: !isLast
                        ) {
                            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.frogCaption)
                                .foregroundStyle(FrogTheme.muted)
                        }
                    } else {
                        TripFieldRow(
                            AppText.value(zh: "已刪除", en: "Deleted"),
                            showsDivider: !isLast
                        ) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(FrogTheme.faint)
                        }
                    }
                }
            }
        }
    }
}

/// Bridges both shapes of `TripEnergyProviding.requestAccessAndReadActiveEnergy`
/// (`Double` today, `Double?` once the "no data" change lands) onto one
/// optional result, and treats 0 kcal as "no samples".
enum TripEnergyReading {
    static func usableValue(_ raw: Double) -> Double? {
        raw > 0 ? raw : nil
    }

    static func usableValue(_ raw: Double?) -> Double? {
        guard let raw, raw > 0 else { return nil }
        return raw
    }
}
