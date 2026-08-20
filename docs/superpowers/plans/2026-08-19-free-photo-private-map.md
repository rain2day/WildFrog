# Free Photo Private Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record each newly saved Free Photo with an optional contemporaneous/source-photo GPS coordinate and display the user’s local-only memories as Apple-style clustered photo markers on the Explore map.

**Architecture:** A dedicated versioned `FreePhotoStore` owns map records and app thumbnails in Application Support, completely isolated from `CheckInStore` and Firebase. `FreePhotoSaveCoordinator` makes Photos-plus-local persistence idempotent, while a MapKit-backed `FreePhotoMapView` supplies custom photo annotations, clustering, detail, location repair, and deletion. Camera fixes are capture-revision-bound; imported images prefer source metadata and otherwise require an explicit location choice.

**Tech Stack:** Swift 6, SwiftUI, MapKit, CoreLocation, Photos, ImageIO, Swift Testing, iOS 17+

## Global Constraints

- Keep Free Photo out of official check-ins, ranks, routes, streaks, stamps, certificates, achievements, and Firebase by construction.
- Store records only inside this app installation; no Firebase, iCloud, or cross-device sync.
- Never invent a coordinate and never use an imported source asset as a deletion target.
- Preserve the current uncommitted Build 12 version/project changes. Do not bump, archive, upload, submit, commit, push, or deploy.
- Existing Build 12 exports are not scanned or migrated.
- Every async photo, location, save, and map refresh outcome is request/revision gated.

---

### Task 1: Private Record Domain Model

**Files:**
- Create: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoRecord.swift`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoRecordTests.swift`

**Interfaces:**
- Produces: `FreePhotoCoordinate`, `FreePhotoLocationSource`, `FreePhotoRecord`, and `FreePhotoMapProjection`.

- [ ] **Step 1: Write the failing domain tests**

~~~swift
@Test func missingLocationNeverProjectsCoordinate() {
    let record = FreePhotoRecord.fixture(coordinate: nil, locationSource: .missing)
    let projection = FreePhotoMapProjection(records: [record])
    #expect(projection.located.isEmpty)
    #expect(projection.needsLocation == [record])
}

@Test func projectionsAreNewestFirst() {
    let old = FreePhotoRecord.fixture(createdAt: Date(timeIntervalSince1970: 1))
    let new = FreePhotoRecord.fixture(createdAt: Date(timeIntervalSince1970: 2))
    #expect(FreePhotoMapProjection(records: [old, new]).located.map(\.id) == [new.id, old.id])
}
~~~

- [ ] **Step 2: Run RED**

Run:
~~~bash
xcodebuild test -project ios/WildFrogNative/WildFrogNative.xcodeproj -scheme WildFrogNative -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath .build/free-photo-map-red -only-testing:WildFrogNativeTests/FreePhotoRecordTests
~~~
Expected: exit 65 because the record types do not exist.

- [ ] **Step 3: Implement the model**

~~~swift
struct FreePhotoCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

enum FreePhotoLocationSource: String, Codable, Equatable {
    case cameraGPS, sourcePhotoMetadata, currentLocationChoice, manual, missing
}

struct FreePhotoRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let renderedAt: Date
    let placeName: String
    let altitudeMetres: Int?
    let altitudeSource: FreePhotoAltitudeSource
    let cardStyle: FreePhotoCardStyle
    var coordinate: FreePhotoCoordinate?
    var locationSource: FreePhotoLocationSource
    var horizontalAccuracy: Double?
    var locationTimestamp: Date?
    let photosAssetIdentifier: String?
    let thumbnailFilename: String
}
~~~

Make `FreePhotoAltitudeSource` and `FreePhotoCardStyle` raw-string Codable enums. Validate latitude `-90...90` and longitude `-180...180`; invalid decoded values project as unlocated.

- [ ] **Step 4: Run GREEN**

Run the Step 2 command. Expected: the suite executes 2 tests and passes.

---

### Task 2: Versioned Local Store and Thumbnail Ownership

**Files:**
- Create: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoStore.swift`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoStoreTests.swift`

**Interfaces:**
- Consumes: `FreePhotoRecord`.
- Produces: `@MainActor final class FreePhotoStore: ObservableObject`, `FreePhotoStorePaths`, `append(record:thumbnailData:)`, `setManualLocation`, and `removeRecord`.

- [ ] **Step 1: Write failing persistence tests**

~~~swift
@Test @MainActor func persistsVersionedRecordsAndThumbnail() throws {
    let paths = try FreePhotoStorePaths.temporary()
    let store = FreePhotoStore(paths: paths)
    let record = FreePhotoRecord.fixture(thumbnailFilename: "one.jpg")
    try store.append(record: record, thumbnailData: Data([1, 2, 3]))
    let reloaded = FreePhotoStore(paths: paths)
    #expect(reloaded.records == [record])
    #expect(try Data(contentsOf: reloaded.thumbnailURL(for: record)) == Data([1, 2, 3]))
}

@Test @MainActor func corruptEnvelopeFailsSoftAndIsPreserved() throws {
    let paths = try FreePhotoStorePaths.temporary()
    try Data("broken".utf8).write(to: paths.envelopeURL)
    let store = FreePhotoStore(paths: paths)
    #expect(store.records.isEmpty)
    #expect(store.lastCorruptEnvelopeURL != nil)
}
~~~

Also test manual placement changes only the selected UUID, reload preserves it, removal deletes only the selected thumbnail, and a failed envelope write rolls back the newly written thumbnail.

- [ ] **Step 2: Run RED**

Run Task 1’s focused command with `FreePhotoStoreTests`. Expected: missing store contracts.

- [ ] **Step 3: Implement the store**

Use a private Codable envelope with `schemaVersion = 1` and `records`. Store `free-photo-map-v1.json` and `Thumbnails/` under `Application Support/WildFrog/FreePhotoMap`. Encode ISO-8601 dates, write to a same-directory temporary URL with atomic options, then replace/move the envelope. On decode failure, move the original to `free-photo-map-v1.corrupt-<timestamp>.json` and publish an empty array. `append` rolls back its thumbnail if the envelope write fails. `removeRecord` removes only that record and its app-owned thumbnail. `setManualLocation` persists before publishing.

- [ ] **Step 4: Run GREEN**

Run focused store tests. Expected: persistence, corruption, placement, rollback, and deletion pass.

---

### Task 3: Capture-Bound Location and Photos Metadata

**Files:**
- Create: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoLocation.swift`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoLocationTests.swift`

**Interfaces:**
- Produces: `FreePhotoLocationCandidate`, `FreePhotoLocationSelectionState`, `FreePhotoLocationResolver.candidate`, and `FreePhotoMetadataLocationReader.coordinate(from:)`.

- [ ] **Step 1: Write failing location tests**

~~~swift
@Test func cameraFixMustBeCurrentValidAndRevisionBound() {
    let now = Date(timeIntervalSince1970: 100)
    #expect(FreePhotoLocationResolver.candidate(location: .fixture(timestamp: now, accuracy: 8), captureRevision: 3, activeRevision: 3, now: now)?.source == .cameraGPS)
    #expect(FreePhotoLocationResolver.candidate(location: .fixture(timestamp: now.addingTimeInterval(-61), accuracy: 8), captureRevision: 3, activeRevision: 3, now: now) == nil)
    #expect(FreePhotoLocationResolver.candidate(location: .fixture(timestamp: now, accuracy: -1), captureRevision: 3, activeRevision: 3, now: now) == nil)
    #expect(FreePhotoLocationResolver.candidate(location: .fixture(timestamp: now, accuracy: 8), captureRevision: 2, activeRevision: 3, now: now) == nil)
}
~~~

Add tests that embedded GPS beats current location and a missing embedded location remains unresolved until the explicit current/later action.

- [ ] **Step 2: Run RED**

Run `FreePhotoLocationTests`. Expected: missing resolver types.

- [ ] **Step 3: Implement resolver and metadata reader**

Accept camera fixes only when revisions match, `horizontalAccuracy >= 0`, coordinate is valid, timestamp is no older than 60 seconds, and no more than 5 seconds in the future. Read `kCGImagePropertyGPSDictionary` via ImageIO, applying negative values for `S` and `W`. Imported metadata wins; otherwise the state exposes `requiresFallbackChoice` until current or later is selected.

- [ ] **Step 4: Run GREEN**

Expected: freshness, accuracy, revision, metadata precedence, and explicit fallback tests pass.

---

### Task 4: Photos Asset Identity and Safe Deletion

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/PhotoLibrarySaver.swift`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoPhotoLibraryTests.swift`
- Modify: existing `PhotoLibrarySaving` fakes in the test target.

**Interfaces:**
- Changes `PhotoLibrarySaving.save(_:)` to `async throws -> String`.
- Produces `PhotoLibraryAssetDeleting.deleteAsset(localIdentifier:)`.

- [ ] **Step 1: Change test fakes first and add deletion tests**

~~~swift
actor FakePhotoLibrary: PhotoLibrarySaving, PhotoLibraryAssetDeleting {
    var saved = 0
    var deletedIdentifiers: [String] = []
    func save(_ image: UIImage) async throws -> String {
        saved += 1
        return "framed-output-\(saved)"
    }
    func deleteAsset(localIdentifier: String) async throws {
        deletedIdentifiers.append(localIdentifier)
    }
}
~~~

- [ ] **Step 2: Run RED**

Run existing Free Photo tests plus `FreePhotoPhotoLibraryTests`. Expected: protocol conformance/signature failures.

- [ ] **Step 3: Return the Photos placeholder identifier**

Retain `placeholderForCreatedAsset?.localIdentifier` inside `performChanges` and require the exact non-empty identifier after success. Deletion requests `.readWrite` authorization, fetches only the recorded identifier, throws `assetNotFound` if absent, and calls `PHAssetChangeRequest.deleteAssets`. No production API accepts a source-picker identifier.

- [ ] **Step 4: Run GREEN**

Expected: saver/content/deletion tests pass.

---

### Task 5: Idempotent Save Transaction

**Files:**
- Create: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoSaveCoordinator.swift`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoSaveCoordinatorTests.swift`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoDraft.swift`

**Interfaces:**
- Produces `FreePhotoSaveRequest`, `FreePhotoSaveRecovery`, `FreePhotoSaveOutcome`, and `FreePhotoSaveCoordinator.save/retry`.

- [ ] **Step 1: Write failing transaction tests**

~~~swift
@Test @MainActor func retryAfterLocalFailureDoesNotDuplicatePhotosAsset() async {
    let photos = FakePhotoLibrary()
    let store = FailingOnceFreePhotoStore()
    var coordinator = FreePhotoSaveCoordinator()
    let request = FreePhotoSaveRequest.fixture()
    #expect(await coordinator.save(request: request, renderedImage: .fixture(), thumbnailData: Data([1]), photos: photos, store: store) == .photoSavedMapFailed(assetIdentifier: "framed-output-1"))
    #expect(await coordinator.retry(request: request, thumbnailData: Data([1]), store: store) == .completed)
    #expect(await photos.saved == 1)
}
~~~

Also begin request A, replace with B, complete A success/failure, and assert A cannot clear B progress or publish confirmation/error.

- [ ] **Step 2: Run RED**

Run `FreePhotoSaveCoordinatorTests`. Expected: missing coordinator contracts.

- [ ] **Step 3: Implement minimal transaction**

`FreePhotoSaveRequest` contains UUID request ID, capture revision, rendered date, trimmed name, altitude/value source, card style, and selected location. Check the active request before and after each await. Photos success stores its exact identifier in recovery before local append; retry creates the record from recovery and never calls Photos again.

- [ ] **Step 4: Run GREEN**

Expected: idempotent retry and late-outcome tests pass.

---

### Task 6: Integrate the Free Photo UI

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoView.swift`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoDraft.swift`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/WildFrogNativeApp.swift`
- Modify: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoIsolationTests.swift`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoFlowTests.swift`

**Interfaces:**
- Consumes the store, resolver, metadata reader, and save coordinator.
- Produces a complete camera/import/location/save private-map flow.

- [ ] **Step 1: Add failing flow/isolation tests**

Test camera snapshot at its capture revision, Photos metadata precedence, no-metadata explicit choice, location denial saving `.missing`, exact split-result copy, retry without duplicate Photos asset, and spies proving zero official-store/Firebase writes.

- [ ] **Step 2: Run RED**

Run `FreePhotoFlowTests` and `FreePhotoIsolationTests`. Expected: flow assertions fail.

- [ ] **Step 3: Wire production UI**

Inject `FreePhotoStore` at the app root. Maintain a monotonically increasing capture revision; cancel/token-gate Photos loads; snapshot camera location when the picker returns. Parse imported metadata before offering `Use Current Location` / `Add Location Later`. Display `Photo Location`, `Current Location`, or `Needs Location`. Save through the coordinator and show `Saved to Photos and added to your private map` only after local persistence. Preserve the working back button and Passport/Polaroid/altitude editing.

- [ ] **Step 4: Run GREEN**

Run all Free Photo tests. Expected: flow and isolation tests pass.

---

### Task 7: Apple-Style Photo Map, Detail, Repair, and Delete

**Files:**
- Create: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoMapView.swift`
- Create: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoMapDetailView.swift`
- Create: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoManualLocationPicker.swift`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoMapTests.swift`

**Interfaces:**
- Produces `FreePhotoMapView`, `FreePhotoMapClusterProjection`, detail actions, and unrestricted manual placement.

- [ ] **Step 1: Write failing map/deletion tests**

~~~swift
@Test func clusterContentsAreNewestFirstAndThumbnailUsesNewest() {
    let cluster = FreePhotoMapClusterProjection(records: [.fixture(createdAt: .later), .fixture(createdAt: .earlier)])
    #expect(cluster.records.map(\.createdAt) == [.later, .earlier])
    #expect(cluster.representative.id == cluster.records[0].id)
}
~~~

Add record-only deletion (zero Photos calls) and combined deletion (failure preserves record; success removes it) tests.

- [ ] **Step 2: Run RED**

Run `FreePhotoMapTests`. Expected: missing map types.

- [ ] **Step 3: Implement MapKit view and actions**

Wrap `MKMapView` in `UIViewRepresentable`. Use rounded 54×54 thumbnails, 3-point white borders, shadow, pointer, and `clusteringIdentifier = "free-photo"`. A cluster uses the newest member thumbnail and count badge. Fit all records on first load. Selection returns newest-first IDs to a sheet showing thumbnail, place, date, altitude/source, Open in Photos, Edit Location, and Delete. Manual placement has a center pin with no mountain/radius validation. Combined delete calls Photos first and removes local data only on success.

- [ ] **Step 4: Run GREEN**

Expected: projection, placeholder, placement, and deletion tests pass.

---

### Task 8: Explore Layer Integration and Empty/Repair UX

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/HomeMapListView.swift`
- Modify if required: `ios/WildFrogNative/Sources/WildFrogNative/NativeRouting.swift`
- Create: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoMapRoutingTests.swift`

**Interfaces:**
- Produces mutually exclusive `Peaks` / `My Free Photos` map layers, empty start action, and location-repair banner.

- [ ] **Step 1: Write failing layer-state tests**

~~~swift
@Test func layersAreMutuallyExclusive() {
    var state = HomeMapLayerState()
    state.select(.freePhotos)
    #expect(state.layer == .freePhotos)
    #expect(!state.showsPeakMarkers)
    #expect(state.showsFreePhotoMarkers)
}
~~~

Add a three-record projection test proving two missing records render banner count 2.

- [ ] **Step 2: Run RED**

Run `FreePhotoMapRoutingTests`. Expected: missing layer state.

- [ ] **Step 3: Integrate with the existing map card**

Put a two-option compact layer control above the card. Peaks keeps the current SwiftUI map; Free Photos swaps in `FreePhotoMapView` and never overlays peaks. Empty state offers `Start Free Photo`. `X photos need a location` opens a newest-first repair sheet. Add deterministic DEBUG QA records behind `-qaFreePhotoMap` without touching production persistence.

- [ ] **Step 4: Run GREEN**

Expected: exclusive layers, correct repair count, and routing pass.

---

### Task 9: Privacy, Full Verification, Simulator QA, and FyuRa

**Files:**
- Modify only if missing: `ios/WildFrogNative/Sources/WildFrogNative/Info.plist`
- Update: `/Users/rainsday/Obsidian/RainVault/40_AI_SESSIONS/Shared/Handoffs/20260819-wildfrog-free-photo-private-map.md`

- [ ] **Step 1: Verify permissions and copy**

Keep When In Use location copy; ensure Photos read/write copy explains deleting only the framed Free Photo. Preserve bundle versions exactly.

- [ ] **Step 2: Run the full target**

~~~bash
set -o pipefail
xcodebuild test -project ios/WildFrogNative/WildFrogNative.xcodeproj -scheme WildFrogNative -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath .build/free-photo-map-full | tee /tmp/wildfrog-free-photo-map-full.log
~~~
Expected: exit 0 with non-zero Swift Testing count.

- [ ] **Step 3: Generic build and hygiene**

~~~bash
xcodebuild build -project ios/WildFrogNative/WildFrogNative.xcodeproj -scheme WildFrogNative -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/free-photo-map-generic CODE_SIGNING_ALLOWED=NO
git diff --check
plutil -lint ios/WildFrogNative/Sources/WildFrogNative/Info.plist ios/WildFrogNative/LiveActivityWidget/Info.plist
~~~
Expected: `BUILD SUCCEEDED`, clean diff, and both plists `OK`.

- [ ] **Step 4: Simulator QA**

Launch with `-qaFreePhotoMap` and capture screenshots proving layer switching, single thumbnail, cluster count, detail sheet, and Needs Location repair. Confirm white photo border, pointer, readable count, and no simultaneous peak pins.

- [ ] **Step 5: Install exact source on FyuRa**

Use the repo’s signed device build convention and explicit DerivedData outside `/private/tmp`. Identify FyuRa with `xcrun devicectl list devices`, install the built app, launch its bundle identifier, and read back artifact `CFBundleShortVersionString` / `CFBundleVersion`. Do not archive or upload.

- [ ] **Step 6: Close evidence boundaries**

Record tests, build, screenshot paths, device, artifact hash/version, install/readback, and unavailable physical checks in the handoff. Physical camera GPS, source-photo GPS, Photos deletion confirmation, commit/push, ASC upload/submission, and public release remain separate unless actually performed.

## Self-Review

- Spec coverage: local-only architecture, camera/import/manual location, missing-location repair, Photos identity, idempotent save, clustering/detail, both deletion choices, privacy, no migration, isolation, build, Simulator, and FyuRa map to Tasks 1–9.
- Placeholder scan: no `TBD`, `TODO`, “implement later”, “similar to”, or undefined follow-up remains.
- Type consistency: Tasks 2–9 consume the exact record, candidate, Photos protocols, coordinator, and projections introduced earlier.
- Delivery consistency: no step commits, pushes, bumps, archives, uploads, submits, or deploys.
