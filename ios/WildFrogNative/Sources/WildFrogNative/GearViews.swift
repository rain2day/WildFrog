import SwiftUI

enum GearText {
    static var defaultCategory: String { AppText.value(zh: "其他", en: "Other") }
}

// MARK: - Gear library

struct GearLibraryView: View {
    @EnvironmentObject private var store: TripStore

    @State private var editingKit: GearKit?
    @State private var editingItem: GearItem?
    @State private var showAddItem = false
    @State private var showAddKit = false
    @State private var errorMessage: String?

    private var kits: [GearKit] { store.gearKits.filter { !$0.isArchived } }
    private var items: [GearItem] { store.gearItems.filter { !$0.isArchived } }

    var body: some View {
        List {
            sectionHeader(AppText.value(zh: "裝備套裝", en: "GEAR KITS"))

            if kits.isEmpty {
                emptyRow(AppText.value(zh: "仲未有套裝。", en: "No kits yet."))
            }
            ForEach(kits) { kit in
                Button { editingKit = kit } label: { kitRow(kit) }
                    .buttonStyle(.plain)
                    .cardRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button { archive(kit) } label: {
                            Label(AppText.value(zh: "封存", en: "Archive"), systemImage: "archivebox")
                        }
                        .tint(FrogTheme.gold)
                    }
            }

            Button { showAddKit = true } label: {
                Label(AppText.value(zh: "新增套裝", en: "Add Kit"), systemImage: "plus")
            }
            .buttonStyle(TripSecondaryButtonStyle())
            .cardRow(top: 10, bottom: 4)

            sectionHeader(AppText.value(zh: "所有裝備", en: "ALL GEAR"))

            if items.isEmpty {
                emptyRow(AppText.value(zh: "仲未有裝備。", en: "No gear yet."))
            }
            ForEach(items) { item in
                Button { editingItem = item } label: { itemRow(item) }
                    .buttonStyle(.plain)
                    .cardRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button { archive(item) } label: {
                            Label(AppText.value(zh: "封存", en: "Archive"), systemImage: "archivebox")
                        }
                        .tint(FrogTheme.gold)
                    }
            }

            Button { showAddItem = true } label: {
                Label(AppText.value(zh: "新增裝備", en: "Add Gear"), systemImage: "plus")
            }
            .buttonStyle(TripSecondaryButtonStyle())
            .cardRow(top: 10, bottom: 40)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        .contentMargins(.horizontal, FrogSpace.screenPadding, for: .scrollContent)
        .localizedNavigationTitle { AppText.value(zh: "裝備庫", en: "Gear Library") }
        .nativeInlineTitle()
        .appPageBackground(FrogTheme.passport)
        .sheet(isPresented: $showAddItem) { GearItemEditorView(item: nil) }
        .sheet(isPresented: $showAddKit) { GearKitEditorView(kit: nil) }
        .sheet(item: $editingItem) { item in GearItemEditorView(item: item) }
        .sheet(item: $editingKit) { kit in GearKitEditorView(kit: kit) }
        .alert(
            AppText.value(zh: "做唔到", en: "Couldn't do that"),
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button(AppText.value(zh: "知道喇", en: "OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.frogEyebrow)
            .tracking(1.2)
            .foregroundStyle(FrogTheme.moss)
            .cardRow(top: 18, bottom: 4)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.frogCaption)
            .foregroundStyle(FrogTheme.muted)
            .cardRow()
    }

    private func kitRow(_ kit: GearKit) -> some View {
        let weight = TripTotals.gearWeight(kit.snapshot(using: store.gearItems))
        return HStack(spacing: 12) {
            Image(systemName: "backpack.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(FrogTheme.moss, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(kit.name).font(.frogRow.weight(.bold)).foregroundStyle(FrogTheme.ink).lineLimit(1)
                Text(AppText.value(
                    zh: "\(kit.lines.count) 件 · \(Int(weight.knownGrams)) g",
                    en: "\(kit.lines.count) items · \(Int(weight.knownGrams)) g"
                ))
                .font(.frogCaption)
                .foregroundStyle(FrogTheme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FrogTheme.faint)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrogTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(FrogTheme.line, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func itemRow(_ item: GearItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.frogRow).foregroundStyle(FrogTheme.ink).lineLimit(1)
                Text(item.brand.map { "\(item.category) · \($0)" } ?? item.category)
                    .font(.frogCaption)
                    .foregroundStyle(FrogTheme.muted)
                    .lineLimit(1)
            }
            Spacer()
            if let weight = item.unitWeightGrams {
                Text("\(Int(weight)) g")
                    .font(.frogNum(13, weight: .semibold))
                    .foregroundStyle(FrogTheme.muted)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FrogTheme.faint)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrogTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(FrogTheme.line, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func archive(_ kit: GearKit) {
        var updated = kit
        updated.isArchived = true
        do { try store.saveGearKit(updated) } catch { errorMessage = TripFlowMessage.text(for: error) }
    }

    private func archive(_ item: GearItem) {
        var updated = item
        updated.isArchived = true
        do { try store.saveGearItem(updated) } catch { errorMessage = TripFlowMessage.text(for: error) }
    }
}

private extension View {
    /// Strip the stock grey list chrome so rows read as paper cards.
    func cardRow(top: CGFloat = 5, bottom: CGFloat = 5) -> some View {
        self
            .listRowInsets(EdgeInsets(top: top, leading: 0, bottom: bottom, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

// MARK: - Gear item editor

struct GearItemEditorView: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    let item: GearItem?
    /// Called after a successful save so a parent (e.g. the kit editor) can
    /// pull the new/edited item straight into its own selection.
    var onSaved: ((GearItem) -> Void)? = nil

    @State private var name = ""
    @State private var category = ""
    @State private var brand = ""
    @State private var weight = ""
    @State private var errorMessage: String?
    @State private var didLoad = false

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            TripFormPage {
                TripFormSection(AppText.value(zh: "裝備", en: "GEAR")) {
                    TripFieldRow(AppText.value(zh: "名稱", en: "Name")) {
                        TripTextField(placeholder: AppText.value(zh: "例如：頭燈", en: "e.g. Headlamp"), text: $name)
                    }
                    TripFieldRow(AppText.value(zh: "分類", en: "Category")) {
                        TripTextField(placeholder: GearText.defaultCategory, text: $category)
                    }
                    TripFieldRow(AppText.value(zh: "品牌", en: "Brand")) {
                        TripTextField(placeholder: AppText.value(zh: "選填", en: "Optional"), text: $brand)
                    }
                    TripFieldRow(AppText.value(zh: "重量 g", en: "Weight g"), showsDivider: false) {
                        TripTextField(placeholder: AppText.value(zh: "選填", en: "Optional"), text: $weight)
                            .keyboardType(.decimalPad)
                    }
                }

                Button(AppText.value(zh: "儲存", en: "Save"), action: save)
                    .buttonStyle(TripPrimaryButtonStyle(isEnabled: isValid))
                    .disabled(!isValid)

                if item != nil {
                    Button(AppText.value(zh: "封存呢件裝備", en: "Archive This Item"), action: archive)
                        .buttonStyle(TripSecondaryButtonStyle(tint: FrogTheme.muted))
                }
            }
            .localizedNavigationTitle {
                item == nil ? AppText.value(zh: "新增裝備", en: "Add Gear") : AppText.value(zh: "編輯裝備", en: "Edit Gear")
            }
            .nativeInlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.value(zh: "取消", en: "Cancel")) { dismiss() }
                }
            }
            .onAppear(perform: load)
            .alert(
                AppText.value(zh: "儲存唔到", en: "Couldn't save"),
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button(AppText.value(zh: "知道喇", en: "OK"), role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func load() {
        guard !didLoad, let item else { didLoad = true; return }
        didLoad = true
        name = item.name
        category = item.category
        brand = item.brand ?? ""
        weight = item.unitWeightGrams.map { String(Int($0)) } ?? ""
    }

    private func save() {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = GearItem(
            id: item?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: trimmedCategory.isEmpty ? GearText.defaultCategory : trimmedCategory,
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : brand,
            unitWeightGrams: Double(weight),
            isArchived: item?.isArchived ?? false
        )
        do {
            try store.saveGearItem(updated)
            onSaved?(updated)
            dismiss()
        } catch {
            errorMessage = TripFlowMessage.text(for: error)
        }
    }

    private func archive() {
        guard var updated = item else { return }
        updated.isArchived = true
        do {
            try store.saveGearItem(updated)
            dismiss()
        } catch {
            errorMessage = TripFlowMessage.text(for: error)
        }
    }
}

// MARK: - Gear kit editor

struct GearKitEditorView: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    let kit: GearKit?

    @State private var name = ""
    /// Selection *and* priority in one map — the old `Set<UUID> optional`
    /// inverted flag meant an unselected item silently read as "required".
    @State private var selection: [UUID: KitLineDraft] = [:]
    @State private var activityIDs = Set<String>()
    @State private var errorMessage: String?
    @State private var didLoad = false
    @State private var editingItem: GearItem?
    @State private var showAddItem = false

    struct KitLineDraft: Equatable {
        var priority: GearPriority
        var quantity: Int
    }

    private var items: [GearItem] { store.gearItems.filter { !$0.isArchived } }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var selectedEntries: [TripGearEntry] {
        items.compactMap { item in
            guard let draft = selection[item.id] else { return nil }
            return TripGearEntry(
                sourceGearItemID: item.id,
                name: item.name,
                category: item.category,
                unitWeightGrams: item.unitWeightGrams,
                quantity: draft.quantity,
                priority: draft.priority
            )
        }
    }

    private var weightSummary: String {
        let weight = TripTotals.gearWeight(selectedEntries)
        let grams = Int(weight.knownGrams)
        let base = grams >= 1000
            ? String(format: "%.2f kg", weight.knownGrams / 1000)
            : "\(grams) g"
        if weight.unknownLineCount > 0 {
            return AppText.value(
                zh: "合共 \(base) · \(weight.unknownLineCount) 件未設重量",
                en: "Total \(base) · \(weight.unknownLineCount) without weight"
            )
        }
        return AppText.value(zh: "合共 \(base)", en: "Total \(base)")
    }

    var body: some View {
        NavigationStack {
            TripFormPage {
                TripFormSection(AppText.value(zh: "套裝", en: "KIT")) {
                    TripFieldRow(AppText.value(zh: "名稱", en: "Name"), showsDivider: false) {
                        TripTextField(
                            placeholder: AppText.value(zh: "例如：日行輕裝", en: "e.g. Day-hike light"),
                            text: $name
                        )
                    }
                }

                TripFormSection(AppText.value(zh: "包括裝備", en: "INCLUDED GEAR")) {
                    if items.isEmpty {
                        Text(AppText.value(zh: "裝備庫仲係空嘅，撳下面新增第一件。", en: "Your gear library is empty — add your first item below."))
                            .font(.frogCaption)
                            .foregroundStyle(FrogTheme.muted)
                    } else {
                        Text(AppText.value(zh: "撳名稱可改重量／分類", en: "Tap a name to edit its weight or category"))
                            .font(.frogMicro)
                            .foregroundStyle(FrogTheme.muted)
                            .padding(.bottom, 4)
                    }
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        gearLine(item, showsDivider: true)
                    }
                    Button { showAddItem = true } label: {
                        Label(AppText.value(zh: "新增裝備並加入套裝", en: "Add New Gear to Kit"), systemImage: "plus.circle")
                            .font(.frogRow.weight(.semibold))
                            .foregroundStyle(FrogTheme.moss)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if !selection.isEmpty {
                        Text(weightSummary)
                            .font(.frogCaption.weight(.semibold))
                            .foregroundStyle(FrogTheme.forest)
                            .padding(.top, 4)
                    }
                }

                TripFormSection(AppText.value(zh: "適用活動", en: "ACTIVITIES")) {
                    ForEach(Array(store.activityTypes.filter { !$0.isArchived }.enumerated()), id: \.element.id) { index, activity in
                        let all = store.activityTypes.filter { !$0.isArchived }
                        Button {
                            activityIDs.formSymmetricDifference([activity.id])
                        } label: {
                            TripFieldRow(activity.localizedName, showsDivider: index < all.count - 1) {
                                Image(systemName: activityIDs.contains(activity.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(activityIDs.contains(activity.id) ? FrogTheme.moss : FrogTheme.faint)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(activityIDs.contains(activity.id) ? [.isButton, .isSelected] : [.isButton])
                    }
                }

                Button(AppText.value(zh: "儲存", en: "Save"), action: save)
                    .buttonStyle(TripPrimaryButtonStyle(isEnabled: isValid))
                    .disabled(!isValid)

                if kit != nil {
                    Button(AppText.value(zh: "封存呢個套裝", en: "Archive This Kit"), action: archive)
                        .buttonStyle(TripSecondaryButtonStyle(tint: FrogTheme.muted))
                }
            }
            .localizedNavigationTitle {
                kit == nil ? AppText.value(zh: "新增套裝", en: "Add Kit") : AppText.value(zh: "編輯套裝", en: "Edit Kit")
            }
            .sheet(isPresented: $showAddItem) {
                GearItemEditorView(item: nil) { saved in
                    selection[saved.id] = KitLineDraft(priority: .required, quantity: 1)
                }
            }
            .sheet(item: $editingItem) { item in
                GearItemEditorView(item: item)
            }
            .nativeInlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.value(zh: "取消", en: "Cancel")) { dismiss() }
                }
            }
            .onAppear(perform: load)
            .alert(
                AppText.value(zh: "儲存唔到", en: "Couldn't save"),
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button(AppText.value(zh: "知道喇", en: "OK"), role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func gearLine(_ item: GearItem, showsDivider: Bool) -> some View {
        let isSelected = selection[item.id] != nil
        let weightText = item.unitWeightGrams.map { "\(Int($0)) g" }
            ?? AppText.value(zh: "未設重量", en: "No weight")
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    if isSelected { selection[item.id] = nil } else { selection[item.id] = KitLineDraft(priority: .required, quantity: 1) }
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? FrogTheme.moss : FrogTheme.faint)
                        .frame(width: 32, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.name)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])

                Button { editingItem = item } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.frogRow)
                            .foregroundStyle(FrogTheme.ink)
                            .lineLimit(1)
                        Text("\(item.category) · \(weightText)")
                            .font(.frogMicro)
                            .foregroundStyle(item.unitWeightGrams == nil ? FrogTheme.orange : FrogTheme.muted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(AppText.value(zh: "編輯重量及分類", en: "Edit weight and category"))

                if isSelected {
                    HStack(spacing: 6) {
                        Stepper(
                            value: Binding(
                                get: { selection[item.id]?.quantity ?? 1 },
                                set: { selection[item.id]?.quantity = max(1, min(99, $0)) }
                            ),
                            in: 1...99
                        ) {
                            Text("×\(selection[item.id]?.quantity ?? 1)")
                                .font(.frogCaption.weight(.bold).monospacedDigit())
                                .foregroundStyle(FrogTheme.ink)
                        }
                        .labelsHidden()
                        .fixedSize()
                        Text("×\(selection[item.id]?.quantity ?? 1)")
                            .font(.frogCaption.weight(.bold).monospacedDigit())
                            .foregroundStyle(FrogTheme.ink)
                            .frame(minWidth: 28, alignment: .trailing)
                        Picker("", selection: Binding(
                            get: { selection[item.id]?.priority ?? .required },
                            set: { selection[item.id]?.priority = $0 }
                        )) {
                            ForEach(GearPriority.allCases, id: \.self) { priority in
                                Text(priority.localizedName).tag(priority)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(FrogTheme.forest)
                    }
                }
            }
            .frame(minHeight: 52)
            if showsDivider {
                Rectangle().fill(FrogTheme.lineSoft).frame(height: 1)
            }
        }
    }

    private func load() {
        guard !didLoad, let kit else { didLoad = true; return }
        didLoad = true
        name = kit.name
        activityIDs = kit.activityTypeIDs
        selection = Dictionary(
            kit.lines.map { ($0.gearItemID, KitLineDraft(priority: $0.priority, quantity: max(1, $0.quantity))) },
            uniquingKeysWith: { _, last in last }
        )
    }

    private func save() {
        // Preserve the original line ids/quantities where the item is still in.
        let existingLines = Dictionary(
            (kit?.lines ?? []).map { ($0.gearItemID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let lines = items.compactMap { item -> GearKitLine? in
            guard let draft = selection[item.id] else { return nil }
            let existing = existingLines[item.id]
            return GearKitLine(
                id: existing?.id ?? UUID(),
                gearItemID: item.id,
                quantity: draft.quantity,
                priority: draft.priority
            )
        }
        let updated = GearKit(
            id: kit?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            activityTypeIDs: activityIDs,
            lines: lines,
            isArchived: kit?.isArchived ?? false
        )
        do {
            try store.saveGearKit(updated)
            dismiss()
        } catch {
            errorMessage = TripFlowMessage.text(for: error)
        }
    }

    private func archive() {
        guard var updated = kit else { return }
        updated.isArchived = true
        do {
            try store.saveGearKit(updated)
            dismiss()
        } catch {
            errorMessage = TripFlowMessage.text(for: error)
        }
    }
}
