import CoreLocation
import MapKit
import SwiftUI

// MARK: - Active trip

struct ActiveTripView: View {
    @EnvironmentObject private var session: TripSessionCoordinator
    @EnvironmentObject private var recorder: TrackRecorder
    @EnvironmentObject private var router: RecordsNavigationRouter
    @Environment(\.dismiss) private var dismiss

    @State private var showFinishOptions = false
    @State private var showFuelEntry = false
    @State private var showPeakPicker = false
    @State private var didDismissGapBanner = false
    @State private var errorMessage: String?
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                UserAnnotation()
                if recorder.points.count > 1 {
                    MapPolyline(coordinates: recorder.points.map(\.coordinate))
                        .stroke(FrogTheme.orange, lineWidth: 5)
                }
            }
            .mapControlVisibility(.hidden)
            .ignoresSafeArea(edges: .bottom)

            controlPanel
                .padding(.horizontal, FrogSpace.screenPadding)
                .padding(.bottom, 14)
        }
        .overlay(alignment: .top) { gapBanner }
        .localizedNavigationTitle { session.activeTrip?.name ?? AppText.value(zh: "記錄行程", en: "Recording Trip") }
        .nativeInlineTitle()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                // Non-destructive: the recording keeps running and the global
                // island brings you straight back.
                Button {
                    dismiss()
                } label: {
                    Label(AppText.value(zh: "收起", en: "Minimise"), systemImage: "chevron.down")
                        .labelStyle(.titleAndIcon)
                }
                .foregroundStyle(FrogTheme.moss)
            }
        }
        .sheet(isPresented: $showFuelEntry) { TripFuelEntryView() }
        .sheet(isPresented: $showPeakPicker) {
            ActiveTripPeakPickerView { mountainID in
                showPeakPicker = false
                router.push(.checkIn(mountainID))
            }
        }
        .confirmationDialog(
            AppText.value(zh: "今次記錄點收尾？", en: "How should this recording end?"),
            isPresented: $showFinishOptions,
            titleVisibility: .visible
        ) {
            Button(AppText.value(zh: "完成並儲存", en: "Finish & Save")) { finish() }
            Button(AppText.value(zh: "儲存為未完成", en: "Save as Incomplete")) { cancel(saveIncomplete: true) }
            Button(AppText.value(zh: "放棄記錄", en: "Discard Recording"), role: .destructive) {
                cancel(saveIncomplete: false)
            }
            Button(AppText.value(zh: "繼續", en: "Keep Recording"), role: .cancel) {}
        } message: {
            Text(AppText.value(
                zh: "「放棄記錄」會刪走今次軌跡，行程返返去準備中。",
                en: "Discarding deletes this track and puts the trip back to planned."
            ))
        }
        .alert(
            AppText.value(zh: "做唔到", en: "Couldn't do that"),
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button(AppText.value(zh: "知道喇", en: "OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            while !Task.isCancelled, session.activeTrip != nil {
                try? await Task.sleep(for: .seconds(30))
                if !Task.isCancelled, session.activeTrip != nil { try? session.checkpoint() }
            }
        }
    }

    // MARK: Gap banner (M1)

    @ViewBuilder
    private var gapBanner: some View {
        if let gapDate = session.restoredGapDate, !didDismissGapBanner {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FrogTheme.gold)
                Text(AppText.value(
                    zh: "上次記錄到 \(gapDate.formatted(date: .omitted, time: .shortened))，中間一段未有記錄。",
                    en: "Last recorded at \(gapDate.formatted(date: .omitted, time: .shortened)) — there's a gap since then."
                ))
                .font(.frogCaption.weight(.semibold))
                .foregroundStyle(FrogTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { didDismissGapBanner = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(FrogTheme.muted)
                        .frame(width: 26, height: 26)
                        .background(FrogTheme.ink.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppText.value(zh: "關閉提示", en: "Dismiss notice"))
            }
            .padding(12)
            .background(FrogTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FrogTheme.gold.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: FrogTheme.warmShadow.opacity(0.12), radius: 14, y: 6)
            .padding(.horizontal, FrogSpace.screenPadding)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: Bottom control panel (M12)

    private var controlPanel: some View {
        VStack(spacing: 13) {
            HStack(spacing: 0) {
                TripStatTile(
                    value: TrackFormat.distance(recorder.distanceMeters),
                    label: AppText.value(zh: "距離", en: "Distance")
                )
                divider
                TripStatTile(
                    value: TrackFormat.duration(recorder.elapsedSeconds),
                    label: AppText.value(zh: "時間", en: "Time")
                )
                divider
                TripStatTile(
                    value: "\(Int(recorder.ascentMeters))m",
                    label: AppText.value(zh: "爬升", en: "Ascent")
                )
            }

            HStack(spacing: 11) {
                Button {
                    togglePause()
                } label: {
                    Label(
                        recorder.isPaused ? AppText.value(zh: "繼續", en: "Resume") : AppText.value(zh: "暫停", en: "Pause"),
                        systemImage: recorder.isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .buttonStyle(TripSecondaryButtonStyle())

                Button {
                    showFinishOptions = true
                } label: {
                    Label(AppText.value(zh: "完成", en: "Finish"), systemImage: "flag.checkered")
                }
                .buttonStyle(TripPrimaryButtonStyle())
            }

            HStack(spacing: 11) {
                Button { showFuelEntry = true } label: {
                    Label(AppText.value(zh: "補給", en: "Fuel"), systemImage: "drop.fill")
                        .font(.frogCaption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .foregroundStyle(FrogTheme.forest)
                        .background(FrogTheme.leaf.opacity(0.16), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)

                Button { showPeakPicker = true } label: {
                    Label(AppText.value(zh: "正式打卡", en: "Official Check-in"), systemImage: "checkmark.seal.fill")
                        .font(.frogCaption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .foregroundStyle(FrogTheme.forest)
                        .background(FrogTheme.leaf.opacity(0.16), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityHint(AppText.value(
                    zh: "揀一座山去做排行榜打卡，軌跡照樣記錄",
                    en: "Pick a peak for a ranked check-in; this recording keeps running"
                ))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(FrogTheme.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FrogTheme.line, lineWidth: 1)
        )
        .shadow(color: FrogTheme.warmShadow.opacity(0.14), radius: 20, y: 10)
    }

    private var divider: some View {
        Rectangle().fill(FrogTheme.line).frame(width: 1, height: 30)
    }

    // MARK: Actions

    private func togglePause() {
        do {
            if recorder.isPaused { try session.resume() } else { try session.pause() }
        } catch {
            errorMessage = TripFlowMessage.text(for: error)
        }
    }

    private func finish() {
        do {
            let trip = try session.finish()
            router.replaceTop(with: .standaloneTripDetail(trip.id))
        } catch {
            errorMessage = TripFlowMessage.text(for: error)
        }
    }

    private func cancel(saveIncomplete: Bool) {
        do {
            try session.cancel(saveIncomplete: saveIncomplete)
            dismiss()
        } catch {
            errorMessage = TripFlowMessage.text(for: error)
        }
    }
}

// MARK: - Peak picker for an official check-in mid-trip

struct ActiveTripPeakPickerView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var checkInStore: CheckInStore
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String) -> Void

    @State private var query = ""

    private var mountains: [Mountain] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let pool = trimmed.isEmpty
            ? MountainCatalog.mountains
            : MountainCatalog.mountains.filter {
                $0.nameZh.localizedCaseInsensitiveContains(trimmed)
                    || $0.nameEn.localizedCaseInsensitiveContains(trimmed)
            }
        let sorted = pool.sorted {
            switch (locationManager.distance(to: $0.coordinate), locationManager.distance(to: $1.coordinate)) {
            case let (.some(a), .some(b)): return a < b
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return $0.height > $1.height
            }
        }
        return Array(sorted.prefix(30))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(mountains) { mountain in
                        Button { onSelect(mountain.id) } label: {
                            CheckInPickerRow(
                                mountain: mountain,
                                distance: locationManager.distance(to: mountain.coordinate),
                                visitCount: checkInStore.count(for: mountain.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(FrogSpace.screenPadding)
            }
            .searchable(text: $query, prompt: AppText.value(zh: "搵山", en: "Search peaks"))
            .appPageBackground(FrogTheme.paper)
            .localizedNavigationTitle { AppText.value(zh: "揀山打卡", en: "Pick a Peak") }
            .nativeInlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.value(zh: "取消", en: "Cancel")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Fuel logging (UX11)

private struct TripFuelQuickChip: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let entry: TripConsumableEntry
}

struct TripFuelEntryView: View {
    @EnvironmentObject private var session: TripSessionCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var showsCustom = false
    @State private var kind: ConsumableKind = .water
    @State private var name = ""
    @State private var unit: ConsumableUnit = .millilitres
    @State private var consumed = ""
    @State private var calories = ""
    @State private var errorMessage: String?

    /// Water units only make sense as ml / L (L7).
    private var unitOptions: [ConsumableUnit] {
        kind == .water ? [.millilitres, .litres] : ConsumableUnit.allCases
    }

    private var quickChips: [TripFuelQuickChip] {
        [
            TripFuelQuickChip(
                title: "+250ml",
                systemImage: "drop.fill",
                entry: TripConsumableEntry(
                    kind: .water,
                    name: AppText.value(zh: "水", en: "Water"),
                    unit: .millilitres,
                    consumedQuantity: 250
                )
            ),
            TripFuelQuickChip(
                title: "+500ml",
                systemImage: "drop.fill",
                entry: TripConsumableEntry(
                    kind: .water,
                    name: AppText.value(zh: "水", en: "Water"),
                    unit: .millilitres,
                    consumedQuantity: 500
                )
            ),
            TripFuelQuickChip(
                title: "+1L",
                systemImage: "drop.fill",
                entry: TripConsumableEntry(
                    kind: .water,
                    name: AppText.value(zh: "水", en: "Water"),
                    unit: .litres,
                    consumedQuantity: 1
                )
            ),
            TripFuelQuickChip(
                title: AppText.value(zh: "能量棒 200kcal", en: "Energy bar 200kcal"),
                systemImage: "fork.knife",
                entry: TripConsumableEntry(
                    kind: .food,
                    name: AppText.value(zh: "能量棒", en: "Energy bar"),
                    unit: .items,
                    consumedQuantity: 1,
                    consumedCalories: 200
                )
            ),
            TripFuelQuickChip(
                title: AppText.value(zh: "飯糰 250kcal", en: "Rice ball 250kcal"),
                systemImage: "fork.knife",
                entry: TripConsumableEntry(
                    kind: .food,
                    name: AppText.value(zh: "飯糰", en: "Rice ball"),
                    unit: .items,
                    consumedQuantity: 1,
                    consumedCalories: 250
                )
            )
        ]
    }

    var body: some View {
        NavigationStack {
            TripFormPage {
                TripFormSection(
                    AppText.value(zh: "一撳即記", en: "ONE TAP"),
                    footer: AppText.value(zh: "撳一下就記錄咗，唔使填表。", en: "One tap logs it — no form to fill.")
                ) {
                    VStack(spacing: 10) {
                        ForEach(quickChips) { chip in
                            Button { log(chip.entry) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: chip.systemImage)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 34, height: 34)
                                        .background(
                                            chip.entry.kind == .water ? FrogTheme.moss : FrogTheme.gold,
                                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        )
                                    Text(chip.title)
                                        .font(.frogRow.weight(.bold))
                                        .foregroundStyle(FrogTheme.ink)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(FrogTheme.moss)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { showsCustom.toggle() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(FrogTheme.muted)
                                    .frame(width: 34, height: 34)
                                    .background(FrogTheme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                Text(AppText.value(zh: "自訂", en: "Custom"))
                                    .font(.frogRow.weight(.bold))
                                    .foregroundStyle(FrogTheme.ink)
                                Spacer()
                                Image(systemName: showsCustom ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(FrogTheme.muted)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if showsCustom { customSection }
            }
            .localizedNavigationTitle { AppText.value(zh: "補給記錄", en: "Fuel Log") }
            .nativeInlineTitle()
            .onChange(of: kind) { _, value in
                if value == .water {
                    if !unitOptions.contains(unit) { unit = .millilitres }
                    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        name = AppText.value(zh: "水", en: "Water")
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.value(zh: "關閉", en: "Close")) { dismiss() }
                }
            }
            .alert(
                AppText.value(zh: "記錄唔到", en: "Couldn't log that"),
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button(AppText.value(zh: "知道喇", en: "OK"), role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var customSection: some View {
        // No "planned quantity" here — planning belongs in the editor, not on a
        // mid-hike sheet where you just want to log what you drank.
        TripFormSection(AppText.value(zh: "自訂", en: "CUSTOM")) {
            TripFieldRow(AppText.value(zh: "類型", en: "Type")) {
                Picker("", selection: $kind) {
                    ForEach(ConsumableKind.allCases, id: \.self) { value in
                        Text(value.localizedName).tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(FrogTheme.forest)
            }
            TripFieldRow(AppText.value(zh: "名稱", en: "Name")) {
                TripTextField(placeholder: kind.localizedName, text: $name)
            }
            TripFieldRow(AppText.value(zh: "單位", en: "Unit")) {
                Picker("", selection: $unit) {
                    ForEach(unitOptions, id: \.self) { value in
                        Text(value.localizedName).tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(FrogTheme.forest)
            }
            TripFieldRow(AppText.value(zh: "實際數量", en: "Consumed"), showsDivider: kind != .water) {
                TripTextField(placeholder: "0", text: $consumed)
                    .keyboardType(.decimalPad)
            }
            if kind != .water {
                TripFieldRow(AppText.value(zh: "卡路里 kcal", en: "Calories kcal"), showsDivider: false) {
                    TripTextField(placeholder: "0", text: $calories)
                        .keyboardType(.decimalPad)
                }
            }
        }

        Button(AppText.value(zh: "加入", en: "Add"), action: addCustom)
            .buttonStyle(TripPrimaryButtonStyle())
    }

    private func log(_ entry: TripConsumableEntry) {
        do {
            try session.addConsumable(entry)
            dismiss()
        } catch {
            errorMessage = TripFlowMessage.text(for: error)
        }
    }

    private func addCustom() {
        let resolvedUnit: ConsumableUnit = unitOptions.contains(unit) ? unit : .millilitres
        let entry = TripConsumableEntry(
            kind: kind,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? kind.localizedName : name,
            unit: resolvedUnit,
            consumedQuantity: Double(consumed) ?? 0,
            consumedCalories: Double(calories) ?? 0
        )
        log(entry)
    }
}
