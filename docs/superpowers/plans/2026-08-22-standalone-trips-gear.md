# Standalone Trips, Gear Kits, and Fuel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add local-first planned and immediate trips with independent GPS recording, reusable gear kits, packing checks, manual food/water intake, and optional Apple Health active-energy comparison without changing official ranking semantics.

**Architecture:** A versioned `TripStore` owns activity, gear, kit, trip, and active-checkpoint data. `TripSessionCoordinator` composes that store with the existing `TrackRecorder`; feature views consume those two boundaries and never write ranking data. A protocol-backed Health adapter is invoked only from a completed-trip summary after contextual permission.

**Tech Stack:** Swift 6, SwiftUI, MapKit, CoreLocation, ActivityKit, HealthKit, Swift Testing, local versioned Codable JSON.

## Global Constraints

- Keep the existing five-tab structure and make Records the trip hub.
- Standalone trips remain local-only and perform zero Firestore or leaderboard writes.
- Only explicit official check-ins affect stamps, summit history, achievements, and rankings.
- Manual food calories always work; Apple Health active energy is optional and contextual.
- Preserve and migrate all existing `CheckInRecord` and Free Photo data.
- Do not mutate the already uploaded Build 15 archive.
- Do not commit, push, upload, or submit this feature without separate explicit authorization.

---

### Task 1: Trip, gear, and fuel domain model

**Files:**
- Create: `ios/WildFrogNative/Sources/WildFrogNative/TripModels.swift`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/TripModelsTests.swift`

**Interfaces:**
- Produces: `TripActivityType`, `GearItem`, `GearKit`, `GearKitLine`, `TripGearEntry`, `TripConsumableEntry`, `StandaloneTrip`, `TripStatus`, `TripTotals`.

- [ ] **Step 1: Write failing model tests**

```swift
@Test func gearKitSnapshotIsIndependentAndTotalsKnownWeight() {
    let camera = GearItem(name: "相機", category: "攝影", unitWeightGrams: 355)
    let kit = GearKit(name: "昆蟲攝影", activityTypeIDs: [TripActivityType.insectPhotography.id], lines: [
        GearKitLine(gearItemID: camera.id, quantity: 1, priority: .required)
    ])
    let entries = kit.snapshot(using: [camera])
    #expect(entries.first?.name == "相機")
    #expect(TripTotals.gearWeight(entries).knownGrams == 355)
    #expect(TripTotals.gearWeight(entries).unknownLineCount == 0)
}

@Test func fuelTotalsNormalizeWaterAndCalories() {
    let water = TripConsumableEntry(kind: .water, name: "水", unit: .litres, plannedQuantity: 2, consumedQuantity: 1.25, consumedCalories: 0)
    let gel = TripConsumableEntry(kind: .food, name: "能量啫喱", unit: .items, plannedQuantity: 3, consumedQuantity: 2, consumedCalories: 180)
    #expect(TripTotals.waterMillilitres([water, gel]) == 1_250)
    #expect(TripTotals.intakeCalories([water, gel]) == 180)
}
```

- [ ] **Step 2: Run the focused tests and observe RED**

```bash
xcodebuild test -project ios/WildFrogNative/WildFrogNative.xcodeproj -scheme WildFrogNative -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath /private/tmp/wildfrog-trips-task1-red -only-testing:WildFrogNativeTests/TripModelsTests
```

Expected: non-zero exit with missing `GearItem`, `GearKit`, and `TripTotals` symbols.

- [ ] **Step 3: Implement value types and deterministic helpers**

```swift
enum TripStatus: String, Codable { case planned, active, paused, completed, cancelled }
enum GearPriority: String, Codable { case required, optional }
enum ConsumableKind: String, Codable { case water, food, otherDrink }
enum ConsumableUnit: String, Codable { case millilitres, litres, grams, servings, items }

struct TripTotals {
    static func waterMillilitres(_ entries: [TripConsumableEntry]) -> Double {
        entries.filter { $0.kind == .water }.reduce(0) { total, entry in
            switch entry.unit {
            case .litres: total + entry.consumedQuantity * 1_000
            case .millilitres: total + entry.consumedQuantity
            default: total
            }
        }
    }
    static func intakeCalories(_ entries: [TripConsumableEntry]) -> Double { entries.reduce(0) { $0 + $1.consumedCalories } }
    static func gearWeight(_ entries: [TripGearEntry]) -> (knownGrams: Double, unknownLineCount: Int) {
        entries.reduce(into: (knownGrams: 0.0, unknownLineCount: 0)) { result, entry in
            if let weight = entry.unitWeightGrams {
                result.knownGrams += weight * Double(entry.quantity)
            } else {
                result.unknownLineCount += 1
            }
        }
    }
}
```

Define six stable built-ins on `TripActivityType`: hiking, trailRunning, running, insectPhotography, landscapePhotography, and camping. All entities are `Codable`, `Identifiable`, and `Equatable`; trip snapshots store display fields rather than relying on future library resolution.

- [ ] **Step 4: Run `TripModelsTests` and expect PASS**

---

### Task 2: Versioned local TripStore and active checkpoint

**Files:**
- Create: `ios/WildFrogNative/Sources/WildFrogNative/TripStore.swift`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/TripStoreTests.swift`

**Interfaces:**
- Consumes: all Task 1 models.
- Produces: `TripStorePaths`, `TripStore`, `TripStoreSnapshot`, and CRUD methods `saveActivityType`, `saveGearItem`, `saveGearKit`, `saveTrip`, `setActiveCheckpoint`, `clearActiveCheckpoint`.

- [ ] **Step 1: Write failing persistence tests**

```swift
@Test @MainActor func tripStoreSeedsBuiltInsOnlyOnce() throws {
    let paths = TripStorePaths(rootDirectory: temporaryDirectory())
    let first = TripStore(paths: paths)
    #expect(first.activityTypes.filter(\.isBuiltIn).count == 6)
    first.archiveActivityType(TripActivityType.camping.id)
    let relaunched = TripStore(paths: paths)
    #expect(relaunched.activityTypes.first { $0.id == TripActivityType.camping.id }?.isArchived == true)
}

@Test @MainActor func corruptEnvelopeIsPreservedAndFailsSoft() throws {
    let paths = TripStorePaths(rootDirectory: temporaryDirectory())
    try Data("broken".utf8).write(to: paths.envelopeURL)
    let store = TripStore(paths: paths)
    #expect(store.trips.isEmpty)
    #expect(store.lastCorruptEnvelopeURL != nil)
}
```

- [ ] **Step 2: Run `TripStoreTests` and observe RED**

- [ ] **Step 3: Implement schema version 1 and atomic persistence**

```swift
private struct Envelope: Codable {
    let schemaVersion: Int
    var activityTypes: [TripActivityType]
    var gearItems: [GearItem]
    var gearKits: [GearKit]
    var trips: [StandaloneTrip]
    var activeCheckpoint: TripSessionCheckpoint?
}
```

Use `Application Support/WildFrog/Trips/trips-v1.json`, write a unique temporary file, then replace/move atomically. Preserve corrupt input as `trips-v1.corrupt-<timestamp>.json`. Seed built-ins only when the envelope has never existed.

- [ ] **Step 4: Run `TripStoreTests` and expect PASS**

---

### Task 3: Independent recording coordinator and crash recovery

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/TrackRecorder.swift`
- Create: `ios/WildFrogNative/Sources/WildFrogNative/TripSessionCoordinator.swift`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/TripSessionCoordinatorTests.swift`

**Interfaces:**
- Consumes: `TrackRecorder.start(mountainId:mountainName:summitCoordinate:)`, `pause`, `resume`, `stop`, `cancel`; `TripStore` checkpoint methods.
- Produces: `start(tripID:)`, `pause()`, `resume()`, `finish() -> StandaloneTrip?`, `cancel(saveIncomplete:)`, `restoreCheckpointIfNeeded()`.

- [ ] **Step 1: Write failing lifecycle tests with a recorder protocol fake**

```swift
@Test @MainActor func standaloneTripStartsWithoutMountainAndFinishesWithTrack() throws {
    let recorder = RecordingFake(finishedTrack: sampleTrack())
    let coordinator = TripSessionCoordinator(store: seededStore(), recorder: recorder)
    try coordinator.start(tripID: plannedTripID)
    #expect(recorder.startMountainID == nil)
    let finished = coordinator.finish()
    #expect(finished?.status == .completed)
    #expect(finished?.track?.points.isEmpty == false)
}

@Test @MainActor func onlyOneTripCanBeActive() throws {
    let coordinator = makeCoordinatorWithTwoPlans()
    try coordinator.start(tripID: firstID)
    #expect(throws: TripSessionError.tripAlreadyActive) { try coordinator.start(tripID: secondID) }
}
```

- [ ] **Step 2: Run focused tests and observe RED**

- [ ] **Step 3: Extract `TrackRecording` protocol and implement coordinator**

```swift
@MainActor protocol TrackRecording: AnyObject {
    var isRecording: Bool { get }
    var isPaused: Bool { get }
    var elapsedSeconds: TimeInterval { get }
    var distanceMeters: Double { get }
    var ascentMeters: Double { get }
    var points: [TrackPoint] { get }
    func start(mountainId: String?, mountainName: String, summitCoordinate: CLLocationCoordinate2D?)
    func pause()
    func resume()
    func stop() -> Track?
    func cancel()
}
```

Make `TrackRecorder` conform without changing its GPS math. The coordinator checkpoints lifecycle changes immediately and coalesces live progress at a bounded interval; foreground/background hooks force a checkpoint. A restored active session becomes paused and reports the timestamp gap instead of pretending background samples exist.

- [ ] **Step 4: Run coordinator plus existing track-related tests and expect PASS**

---

### Task 4: Gear library, kit editor, and packing checklist

**Files:**
- Create: `ios/WildFrogNative/Sources/WildFrogNative/GearLibraryView.swift`
- Create: `ios/WildFrogNative/Sources/WildFrogNative/GearKitEditorView.swift`
- Create: `ios/WildFrogNative/Sources/WildFrogNative/PackingChecklistView.swift`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/PackingChecklistTests.swift`

**Interfaces:**
- Consumes: `TripStore`, `GearItem`, `GearKit`, `TripGearEntry`.
- Produces: `PackingProjection` with required/optional sections, packed count, missing-required count, and start-warning decision.

- [ ] **Step 1: Write failing projection tests**

```swift
@Test func requiredItemsSortFirstAndWarningDoesNotBlock() {
    let projection = PackingProjection(entries: sampleEntries)
    #expect(projection.sections.map(\.priority) == [.required, .optional])
    #expect(projection.missingRequiredCount == 1)
    #expect(projection.canStart == true)
    #expect(projection.shouldWarnBeforeStart == true)
}
```

- [ ] **Step 2: Run `PackingChecklistTests` and observe RED**

- [ ] **Step 3: Implement library, kit, and checklist views**

Use existing `FrogTheme`, `FrogSpace.screenPadding`, `.cardStyle()`, and 44-point controls. Gear items edit name/category/brand/weight; kits edit name, activity associations, ordered lines, quantity, and priority. The checklist snapshots a kit, allows trip-only edits, displays packed progress and known total weight, and uses `Review List` / `Start Anyway` for missing required items.

- [ ] **Step 4: Run focused tests and a generic iOS Simulator build; expect PASS**

---

### Task 5: Trip hub, editor, active recording, and summary

**Files:**
- Create: `ios/WildFrogNative/Sources/WildFrogNative/TripHubView.swift`
- Create: `ios/WildFrogNative/Sources/WildFrogNative/TripEditorView.swift`
- Create: `ios/WildFrogNative/Sources/WildFrogNative/ActiveTripView.swift`
- Create: `ios/WildFrogNative/Sources/WildFrogNative/StandaloneTripSummaryView.swift`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/RecordsCalendarView.swift`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/WildFrogRootView.swift`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/CheckInTypeChooserView.swift`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/WildFrogNativeApp.swift`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/TripRoutingTests.swift`

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces routes `tripHub`, `tripEditor(UUID?)`, `packingChecklist(UUID)`, `activeTrip`, `standaloneTripDetail(UUID)`, `gearLibrary`.

- [ ] **Step 1: Write failing source/routing tests**

```swift
@Test func centreChooserOffersIndependentTripWithoutOfficialWrite() throws {
    let source = try sourceText("CheckInTypeChooserView.swift")
    #expect(source.contains("Record a Trip"))
    #expect(source.contains("NativeRoute.tripEditor(nil)"))
}
```

- [ ] **Step 2: Run routing tests and observe RED**

- [ ] **Step 3: Inject store/coordinator and add routes**

```swift
@StateObject private var tripStore: TripStore
@StateObject private var tripSession: TripSessionCoordinator

// Inject both with environmentObject and call restoreCheckpointIfNeeded() once.
```

Construct both in `WildFrogNativeApp.init` so the coordinator receives the same app-owned `TrackRecorder` and `TripStore` instances. Add debug QA arguments for hub, packing, active, and completed-summary states without auto-starting real GPS.

- [ ] **Step 4: Implement the four trip surfaces**

Records leads with `TripHubView` and keeps the existing passport/calendar below a clear `Check-in History` section. The active surface displays a Map polyline, elapsed/distance/ascent cards, pause/resume, quick water/food logging, official check-in entry, and finish. Summary displays route, stats, links, packed gear, hydration, calories, and optional Health row.

- [ ] **Step 5: Run routing tests and generic Simulator build; expect PASS**

---

### Task 6: Fuel entry and optional Apple Health energy

**Files:**
- Create: `ios/WildFrogNative/Sources/WildFrogNative/TripFuelViews.swift`
- Create: `ios/WildFrogNative/Sources/WildFrogNative/TripEnergyProvider.swift`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/Info.plist`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/WildFrogNative.entitlements`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/TripEnergyProviderTests.swift`

**Interfaces:**
- Produces: `TripEnergyProviding`, `HealthTripEnergyProvider`, `authorizationStatus()`, `requestAuthorization() async throws`, `activeEnergy(start:end:) async throws -> Double?`.

- [ ] **Step 1: Write failing interval and denial tests against a fake provider**

```swift
@Test @MainActor func healthDenialLeavesTripCompletionUsable() async {
    let provider = EnergyProviderFake(result: .denied)
    let model = TripEnergySummaryModel(provider: provider)
    await model.refresh(for: completedTrip)
    #expect(model.activeCalories == nil)
    #expect(model.canDisplayManualIntake == true)
}
```

- [ ] **Step 2: Run focused tests and observe RED**

- [ ] **Step 3: Implement manual fuel controls and Health adapter**

```swift
protocol TripEnergyProviding {
    func authorizationStatus() -> TripEnergyAuthorization
    func requestAuthorization() async throws
    func activeEnergy(start: Date, end: Date) async throws -> Double?
}
```

Use `HKHealthStore`, `HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)`, and a strict start/end predicate. Convert the cumulative sum to kilocalories. Request read permission only after the completed-summary explanation and user action. Add the Health share usage description and HealthKit entitlement; do not write workouts or Health samples.

- [ ] **Step 4: Run focused tests, plist lint, entitlement readback, and generic Simulator build; expect PASS**

---

### Task 7: Optional official check-in linking without ranking drift

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/CheckInStore.swift`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/CheckInCameraView.swift`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/TripSessionCoordinator.swift`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/StandaloneTripIsolationTests.swift`

**Interfaces:**
- Adds optional `tripID: UUID?` to local `CheckInRecord` with a backward-compatible decode default.
- Produces `TripSessionCoordinator.attachCheckIn(_ recordID: UUID)`.

- [ ] **Step 1: Write failing backward-compatibility and isolation tests**

```swift
@Test func legacyCheckInDecodesWithoutTripID() throws {
    let record = try decodeLegacyCheckInFixture()
    #expect(record.tripID == nil)
}

@Test @MainActor func standaloneTripNeverEnqueuesCloudCheckIn() throws {
    let spies = OfficialWriteSpies()
    try makeStandaloneCoordinator(spies: spies).completeTimerOnlyTrip()
    #expect(spies.checkInWrites == 0)
    #expect(spies.leaderboardWrites == 0)
}
```

- [ ] **Step 2: Run focused tests and observe RED**

- [ ] **Step 3: Add optional linkage only at explicit check-in success**

Pass the active trip identifier into the existing check-in save call; keep every official validation, consent, outbox, and server aggregation rule unchanged. Trip deletion only removes the local trip. Check-in deletion causes the summary projection to omit the missing link.

- [ ] **Step 4: Run isolation, leaderboard, check-in, and migration tests; expect PASS**

---

### Task 8: Full verification and physical-device handoff

**Files:**
- Modify only tests or production files proven necessary by failures from Tasks 1–7.
- Update: `docs/superpowers/specs/2026-08-22-standalone-trips-gear-design.md` only if live implementation exposes a genuine contradiction.

- [ ] **Step 1: Run all `WildFrogNativeTests` and record the executed count**

- [ ] **Step 2: Build a clean generic iOS Simulator target**

- [ ] **Step 3: Exercise QA routes and visually inspect trip hub, packing, active route, gear library, and summary**

- [ ] **Step 4: Build and install the exact source on FyuRa; read back bundle/version and launch**

- [ ] **Step 5: Physically verify GPS recording, pause/resume, background/foreground, restore, finish, manual fuel totals, and Health permission/energy**

- [ ] **Step 6: Re-scan crash logs after the complete interaction and separate automated proof from user acceptance**

- [ ] **Step 7: Review `git diff --check`, scoped diff/stat, status, and confirm Build 15 archive hash remains unchanged**

- [ ] **Step 8: Clean only exact task-owned rebuildable scratch after evidence capture; retain source, test results, and release evidence**
