import SwiftUI

// MARK: - Trip editor

struct TripEditorView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var router: RecordsNavigationRouter
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TripPreferences.lastActivityKey) private var lastActivityID = TripActivityType.hiking.id
    let tripID: UUID?

    @State private var name = ""
    @State private var scheduledAt = Date()
    @State private var activityID = TripActivityType.hiking.id
    @State private var gearKitID: UUID?
    /// Only an explicit pick in the kit picker may re-snapshot the trip's gear.
    /// Merely opening the editor (or switching activity on an existing trip)
    /// must never wipe what the hiker already packed.
    @State private var didChooseKitManually = false
    @State private var notes = ""
    @State private var showAddActivity = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    private var activities: [TripActivityType] { store.activityTypes.filter { !$0.isArchived } }
    private var kits: [GearKit] { store.gearKits.filter { !$0.isArchived } }
    private var existingTrip: StandaloneTrip? { tripID.flatMap { id in store.trips.first { $0.id == id } } }

    private var selectedActivity: TripActivityType? {
        activities.first { $0.id == activityID }
    }

    private var autoName: String {
        TripAutoName.value(
            activityName: selectedActivity?.localizedName ?? TripActivityType.hiking.localizedName,
            date: scheduledAt
        )
    }

    private var resolvedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? autoName : trimmed
    }

    var body: some View {
        TripFormPage {
            TripFormSection(
                AppText.value(zh: "行程", en: "TRIP"),
                footer: AppText.value(
                    zh: "唔改名嘅話會自動叫「\(autoName)」。",
                    en: "Leave the name blank and it becomes “\(autoName)”."
                )
            ) {
                TripFieldRow(AppText.value(zh: "名稱", en: "Name")) {
                    TripTextField(placeholder: autoName, text: $name)
                }
                TripFieldRow(AppText.value(zh: "日期時間", en: "Date & time")) {
                    DatePicker("", selection: $scheduledAt)
                        .labelsHidden()
                        .tint(FrogTheme.moss)
                }
                TripFieldRow(AppText.value(zh: "活動", en: "Activity"), showsDivider: false) {
                    Picker("", selection: $activityID) {
                        ForEach(activities) { activity in
                            Label(activity.localizedName, systemImage: activity.symbolName).tag(activity.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(FrogTheme.forest)
                }
            }

            Button { showAddActivity = true } label: {
                Label(AppText.value(zh: "新增自訂活動", en: "Add Custom Activity"), systemImage: "plus.circle")
            }
            .buttonStyle(TripSecondaryButtonStyle())

            TripFormSection(AppText.value(zh: "準備", en: "PREPARATION")) {
                TripFieldRow(AppText.value(zh: "裝備套裝", en: "Gear kit")) {
                    // Bound by hand so ONLY a real pick flips `didChooseKitManually`
                    // — the activity-driven auto-suggestion below must not count.
                    Picker("", selection: Binding(
                        get: { gearKitID },
                        set: { newValue in
                            gearKitID = newValue
                            didChooseKitManually = true
                        }
                    )) {
                        Text(AppText.value(zh: "不使用套裝", en: "No kit")).tag(UUID?.none)
                        ForEach(kits) { kit in
                            Text(kit.name).tag(Optional(kit.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(FrogTheme.forest)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppText.value(zh: "備註", en: "Notes"))
                        .font(.frogCaption.weight(.semibold))
                        .foregroundStyle(FrogTheme.muted)
                    TripTextField(
                        placeholder: AppText.value(zh: "路線、同行、注意事項…", en: "Route, company, things to watch…"),
                        text: $notes,
                        axis: .vertical
                    )
                    .frame(minHeight: 60, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
            }

            VStack(spacing: 12) {
                Button { save(startNow: true) } label: {
                    Label(AppText.value(zh: "儲存並準備出發", en: "Save & Get Ready"), systemImage: "backpack.fill")
                }
                .buttonStyle(TripPrimaryButtonStyle())

                Button(AppText.value(zh: "淨係儲存", en: "Just Save")) { save(startNow: false) }
                    .buttonStyle(TripSecondaryButtonStyle())
            }

            Text(AppText.value(
                zh: "會先打開裝備清單；必要裝備未剔選只會提醒，唔會阻止你出發。",
                en: "Opens your packing list first. Missing required gear warns but never blocks starting."
            ))
            .font(.frogCaption)
            .foregroundStyle(FrogTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
        .localizedNavigationTitle { AppText.value(zh: "制定行程", en: "Plan Trip") }
        .nativeInlineTitle()
        .onAppear(perform: load)
        .onChange(of: activityID) { _, id in
            // Auto-suggest a kit only while the hiker hasn't picked one.
            guard !didChooseKitManually else { return }
            gearKitID = store.activityTypes.first(where: { $0.id == id })?.defaultGearKitID
                ?? store.gearKits.first(where: { $0.activityTypeIDs.contains(id) && !$0.isArchived })?.id
        }
        .sheet(isPresented: $showAddActivity) { AddTripActivityView(selectedActivityID: $activityID) }
        .alert(
            AppText.value(zh: "儲存唔到", en: "Couldn't save"),
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button(AppText.value(zh: "知道喇", en: "OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() {
        guard !didLoad else { return }
        defer { didLoad = true }
        guard let trip = existingTrip else {
            activityID = activities.contains(where: { $0.id == lastActivityID })
                ? lastActivityID
                : (activities.first?.id ?? TripActivityType.hiking.id)
            return
        }
        name = trip.name
        scheduledAt = trip.scheduledAt
        activityID = trip.activity.id
        notes = trip.notes
        // NOTE: gearKitID is intentionally left as-is (nil). A trip stores a gear
        // *snapshot*, not a kit reference, so there is nothing to restore — and
        // clearing it used to combine with the activity `onChange` to silently
        // re-snapshot (and un-pack) the whole list on every open.
    }

    private func save(startNow: Bool) {
        guard let activity = selectedActivity else {
            errorMessage = AppText.value(zh: "請先揀一個活動。", en: "Pick an activity first.")
            return
        }
        let existing = existingTrip
        let kit = gearKitID.flatMap { id in store.gearKits.first { $0.id == id } }

        let baseGear: [TripGearEntry]
        if didChooseKitManually {
            baseGear = kit?.snapshot(using: store.gearItems) ?? []
        } else if let existing {
            baseGear = existing.gear
        } else {
            baseGear = kit?.snapshot(using: store.gearItems) ?? []
        }

        let trip = StandaloneTrip(
            id: existing?.id ?? UUID(),
            name: resolvedName,
            activity: TripActivitySnapshot(activity),
            scheduledAt: scheduledAt,
            status: existing?.status ?? .planned,
            createdAt: existing?.createdAt ?? .now,
            startedAt: existing?.startedAt,
            completedAt: existing?.completedAt,
            notes: notes,
            gear: TripGearMerge.preservingPacked(baseGear, previous: existing?.gear ?? []),
            consumables: existing?.consumables ?? [],
            track: existing?.track,
            officialCheckInIDs: existing?.officialCheckInIDs ?? [],
            appleHealthActiveCalories: existing?.appleHealthActiveCalories,
            healthEnergyRefreshedAt: existing?.healthEnergyRefreshedAt
        )

        do {
            try store.saveTrip(trip)
            lastActivityID = activity.id
            if startNow {
                router.replaceTop(with: .packingChecklist(trip.id))
            } else {
                dismiss()
            }
        } catch {
            errorMessage = TripFlowMessage.text(for: error)
        }
    }
}

// MARK: - Custom activity

struct AddTripActivityView: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedActivityID: String
    @State private var name = ""
    @State private var errorMessage: String?

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            TripFormPage {
                TripFormSection(AppText.value(zh: "自訂活動", en: "CUSTOM ACTIVITY")) {
                    TripFieldRow(AppText.value(zh: "名稱", en: "Name"), showsDivider: false) {
                        TripTextField(
                            placeholder: AppText.value(zh: "例如：觀鳥", en: "e.g. Birdwatching"),
                            text: $name
                        )
                    }
                }
                Button(AppText.value(zh: "加入", en: "Add"), action: add)
                    .buttonStyle(TripPrimaryButtonStyle(isEnabled: !trimmedName.isEmpty))
                    .disabled(trimmedName.isEmpty)
            }
            .localizedNavigationTitle { AppText.value(zh: "自訂活動", en: "Custom Activity") }
            .nativeInlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.value(zh: "取消", en: "Cancel")) { dismiss() }
                }
            }
            .alert(
                AppText.value(zh: "加唔到", en: "Couldn't add"),
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button(AppText.value(zh: "知道喇", en: "OK"), role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func add() {
        let activity = TripActivityType.custom(name: trimmedName)
        do {
            try store.saveActivityType(activity)
            selectedActivityID = activity.id
            dismiss()
        } catch {
            errorMessage = TripFlowMessage.text(for: error)
        }
    }
}

// MARK: - Packing checklist

struct PackingChecklistView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var session: TripSessionCoordinator
    @EnvironmentObject private var router: RecordsNavigationRouter
    @Environment(\.dismiss) private var dismiss
    let tripID: UUID

    @State private var trip: StandaloneTrip?
    @State private var showMissingWarning = false
    @State private var errorMessage: String?

    private var projection: PackingProjection { PackingProjection(entries: trip?.gear ?? []) }

    var body: some View {
        List {
            if let trip {
                summaryRow(trip)
                gearSection(.required, title: AppText.value(zh: "必要裝備", en: "REQUIRED"))
                gearSection(.optional, title: AppText.value(zh: "選帶裝備", en: "OPTIONAL"))

                if trip.gear.isEmpty {
                    Text(AppText.value(
                        zh: "呢個行程未有裝備清單，可以直接出發。",
                        en: "No packing list for this trip — you can just head out."
                    ))
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Button(action: attemptStart) {
                    Label(AppText.value(zh: "開始記錄行程", en: "Start Recording"), systemImage: "record.circle")
                }
                .buttonStyle(TripPrimaryButtonStyle())
                .listRowInsets(EdgeInsets(top: 14, leading: 0, bottom: 30, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        .contentMargins(.horizontal, FrogSpace.screenPadding, for: .scrollContent)
        .localizedNavigationTitle { AppText.value(zh: "出發前檢查", en: "Packing Check") }
        .nativeInlineTitle()
        .appPageBackground(FrogTheme.passport)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(AppText.value(zh: "關閉", en: "Close")) { dismiss() }
                    .foregroundStyle(FrogTheme.moss)
            }
        }
        .onAppear { trip = store.trips.first { $0.id == tripID } }
        .alert(
            AppText.value(zh: "仲有必要裝備未確認", en: "Required gear unchecked"),
            isPresented: $showMissingWarning
        ) {
            Button(AppText.value(zh: "返去檢查", en: "Review List"), role: .cancel) {}
            Button(AppText.value(zh: "照常開始", en: "Start Anyway"), action: start)
        } message: {
            Text(AppText.value(
                zh: "有 \(projection.missingRequiredCount) 項必要裝備未剔選。",
                en: "\(projection.missingRequiredCount) required items are unchecked."
            ))
        }
        .alert(
            AppText.value(zh: "開始唔到記錄", en: "Couldn't start recording"),
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button(AppText.value(zh: "知道喇", en: "OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func summaryRow(_ trip: StandaloneTrip) -> some View {
        HStack(spacing: 12) {
            Image(systemName: trip.activity.symbolName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(FrogTheme.moss, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.name).font(.frogRow.weight(.bold)).foregroundStyle(FrogTheme.ink).lineLimit(1)
                Text(trip.activity.localizedName).font(.frogCaption).foregroundStyle(FrogTheme.muted)
            }
            Spacer()
            Text("\(projection.packedCount)/\(projection.totalCount)")
                .font(.frogNum(19, weight: .heavy))
                .foregroundStyle(projection.missingRequiredCount == 0 ? FrogTheme.moss : FrogTheme.orange)
        }
        .padding(FrogSpace.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 6, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func gearSection(_ priority: GearPriority, title: String) -> some View {
        let entries = trip?.gear.filter { $0.priority == priority } ?? []
        if !entries.isEmpty {
            Text(title)
                .font(.frogEyebrow)
                .tracking(1.2)
                .foregroundStyle(FrogTheme.moss)
                .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(entries) { entry in
                Button { toggle(entry.id) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: entry.isPacked ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(entry.isPacked ? FrogTheme.moss : FrogTheme.faint)
                        Text(entry.name)
                            .font(.frogRow)
                            .foregroundStyle(FrogTheme.ink)
                        Spacer()
                        Text("×\(entry.quantity)")
                            .font(.frogCaption)
                            .foregroundStyle(FrogTheme.muted)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FrogTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(FrogTheme.line, lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(entry.isPacked ? [.isButton, .isSelected] : [.isButton])
                .accessibilityValue(entry.isPacked
                    ? AppText.value(zh: "已收拾", en: "Packed")
                    : AppText.value(zh: "未收拾", en: "Not packed"))
                .accessibilityHint(AppText.value(zh: "撳一下切換收拾狀態", en: "Double tap to toggle packed"))
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    private func toggle(_ id: UUID) {
        guard var trip, let index = trip.gear.firstIndex(where: { $0.id == id }) else { return }
        trip.gear[index].isPacked.toggle()
        self.trip = trip
        do {
            try store.saveTrip(trip)
        } catch {
            errorMessage = TripFlowMessage.text(for: error)
        }
    }

    private func attemptStart() {
        if projection.shouldWarnBeforeStart {
            showMissingWarning = true
        } else {
            start()
        }
    }

    private func start() {
        guard let trip else {
            errorMessage = TripSessionError.tripNotFound.tripFlowMessage
            return
        }
        do {
            try store.saveTrip(trip)
            try session.start(tripID: trip.id)
            router.replaceTop(with: .activeTrip)
        } catch {
            errorMessage = TripFlowMessage.text(for: error)
        }
    }
}
