# Free Photo Custom Date And Coordinates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add editable, independently hideable date and coordinate metadata to both Free Photo frame styles, using capture-derived defaults without changing private-map location.

**Architecture:** `FreePhotoDraft` owns display-only metadata, validation, and formatting. `FreePhotoMetadataReader` returns one revision-bound Photos metadata result containing source date and location; `FreePhotoView` copies accepted defaults into the draft while retaining the existing `selectedLocation` as the sole private-map authority. Frame content and save identity receive immutable presentation values so preview, export, late-result gating, and retry identity stay exact.

**Tech Stack:** Swift 6, SwiftUI, CoreLocation, Photos, ImageIO, Swift Testing, Xcode 26 iOS Simulator.

## Global Constraints

- Printed coordinate format is exactly `22.40840° N · 114.12010° E` with five fixed fractional digits.
- Camera date defaults to accepted capture time; Photos date prefers source creation date and falls back to accepted import time.
- Printed coordinates are editable presentation data only and must never move the private-map location.
- Date display defaults on. Coordinate display defaults on only when valid capture/source GPS exists.
- Latitude is valid only in `-90...90`; longitude is valid only in `-180...180`.
- Free Photo remains local-only and must not write official check-ins, routes, stamps, achievements, certificates, leaderboard state, or Firebase data.
- Do not change version/build numbers, commit, push, deploy Firebase, upload ASC, or alter the active App Review submission.

---

### Task 1: Display Metadata Draft, Validation, Formatting, And Save Fingerprint

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoDraft.swift`
- Modify: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoDraftTests.swift`

**Interfaces:**
- Consumes: existing `FreePhotoCoordinate`, `FreePhotoCardStyle`, and altitude validation.
- Produces: `FreePhotoDraft.applyFrameMetadata(date:coordinate:)`, `setLatitudeText(_:)`, `setLongitudeText(_:)`, `displayCoordinate`, `displayDate`, `coordinateLabel`, and expanded `FreePhotoExportFingerprint`.

- [x] **Step 1: Write failing draft and fingerprint tests**

Add tests proving defaults, independent switches, formatting, validation, and identity:

```swift
@Test func frameMetadataDefaultsAndFormattingAreDisplayOnly() {
    var draft = FreePhotoDraft()
    let date = Date(timeIntervalSince1970: 1_777_777_777)
    let gps = FreePhotoCoordinate(latitude: 22.4084, longitude: 114.1201)
    draft.applyFrameMetadata(date: date, coordinate: gps)

    #expect(draft.showsDate)
    #expect(draft.frameDate == date)
    #expect(draft.showsCoordinates)
    #expect(draft.displayCoordinate == gps)
    #expect(draft.coordinateLabel == "22.40840° N · 114.12010° E")

    draft.setLatitudeText("-22.50000")
    draft.setLongitudeText("-114.25000")
    #expect(draft.coordinateLabel == "22.50000° S · 114.25000° W")

    draft.showsCoordinates = false
    #expect(draft.coordinateLabel == nil)
    #expect(draft.latitudeText == "-22.50000")
    #expect(draft.longitudeText == "-114.25000")
}

@Test func coordinateValidationOnlyBlocksVisibleInvalidCoordinates() {
    var draft = FreePhotoDraft()
    draft.placeName = "獅子山"
    draft.showsCoordinates = true
    draft.setLatitudeText("91")
    draft.setLongitudeText("114")
    #expect(draft.validationError == .coordinatesOutOfRange)
    #expect(!draft.canExport(hasPhoto: true))

    draft.showsCoordinates = false
    #expect(draft.validationError == nil)
    #expect(draft.canExport(hasPhoto: true))
}

@Test func saveFingerprintIncludesEditableDateCoordinatesAndSwitches() {
    let baseline = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        cardStyle: .passport,
        renderedAt: Date(timeIntervalSince1970: 10),
        frameDate: Date(timeIntervalSince1970: 5),
        showsDate: true,
        latitudeText: "22.40840",
        longitudeText: "114.12010",
        showsCoordinates: true
    )
    let dateHidden = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        cardStyle: .passport,
        renderedAt: Date(timeIntervalSince1970: 10),
        frameDate: Date(timeIntervalSince1970: 5),
        showsDate: false,
        latitudeText: "22.40840",
        longitudeText: "114.12010",
        showsCoordinates: true
    )
    let editedLatitude = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        cardStyle: .passport,
        renderedAt: Date(timeIntervalSince1970: 10),
        frameDate: Date(timeIntervalSince1970: 5),
        showsDate: true,
        latitudeText: "22.50000",
        longitudeText: "114.12010",
        showsCoordinates: true
    )
    let coordinatesHidden = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        cardStyle: .passport,
        renderedAt: Date(timeIntervalSince1970: 10),
        frameDate: Date(timeIntervalSince1970: 5),
        showsDate: true,
        latitudeText: "22.40840",
        longitudeText: "114.12010",
        showsCoordinates: false
    )
    #expect(baseline != dateHidden)
    #expect(baseline != editedLatitude)
    #expect(baseline != coordinatesHidden)
}
```

- [x] **Step 2: Run focused tests and capture RED**

Run:

```bash
set -o pipefail
xcodebuild test \
  -project ios/WildFrogNative/WildFrogNative.xcodeproj \
  -scheme WildFrogNative \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath .build/free-photo-metadata-red \
  -only-testing:WildFrogNativeTests/FreePhotoDraftTests \
  | tee /tmp/wildfrog-free-photo-metadata-red.log
```

Expected: non-zero exit because the new draft fields, validation cases, and fingerprint arguments do not exist.

- [x] **Step 3: Implement the minimal draft model**

Extend `FreePhotoValidationError` with `.missingCoordinates`, `.invalidCoordinates`, and `.coordinatesOutOfRange`. Add the following state and helpers to `FreePhotoDraft`:

```swift
var frameDate = Date()
var showsDate = true
private(set) var latitudeText = ""
private(set) var longitudeText = ""
var showsCoordinates = false

mutating func applyFrameMetadata(date: Date, coordinate: FreePhotoCoordinate?) {
    frameDate = date
    if let coordinate, coordinate.isValid {
        latitudeText = Self.editableCoordinateString(coordinate.latitude)
        longitudeText = Self.editableCoordinateString(coordinate.longitude)
        showsCoordinates = true
    } else {
        latitudeText = ""
        longitudeText = ""
        showsCoordinates = false
    }
}

mutating func setLatitudeText(_ value: String) {
    latitudeText = value.trimmingCharacters(in: .whitespacesAndNewlines)
}

mutating func setLongitudeText(_ value: String) {
    longitudeText = value.trimmingCharacters(in: .whitespacesAndNewlines)
}
```

`displayCoordinate` parses both finite doubles and returns a valid `FreePhotoCoordinate`; `coordinateLabel` returns nil when hidden and otherwise formats absolute values to five places with `N/S` and `E/W` under `en_US_POSIX`. Insert coordinate validation after place-name validation and before altitude validation, but only when `showsCoordinates` is true.

Expand `FreePhotoExportFingerprint` with:

```swift
let frameDate: Date
let showsDate: Bool
let latitudeText: String
let longitudeText: String
let showsCoordinates: Bool
```

Keep default initializer arguments for the new properties so existing tests continue compiling, then migrate production call sites in Task 4.

- [x] **Step 4: Run the focused tests to GREEN**

Run the Step 2 command again. Expected: focused Draft tests pass with a non-zero executed count.

---

### Task 2: Source Photo Date And GPS Metadata As One Revision-Bound Result

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoLocation.swift`
- Modify: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoPrivateMapTests.swift`

**Interfaces:**
- Consumes: Photos `PHAsset`, ImageIO GPS/EXIF/TIFF dictionaries, and existing `FreePhotoLocationCandidate`.
- Produces: `FreePhotoImportedMetadata(location:creationDate:)` and `FreePhotoMetadataReader.metadata(from:photosIdentifier:acceptedAt:)`.

- [x] **Step 1: Write failing metadata tests**

Create deterministic in-memory image metadata and assert source priority/fallback:

```swift
@Test func imageMetadataReadsOriginalDateAndGPSTogether() throws {
    let data = try fixtureJPEG(
        latitude: 22.4084,
        latitudeRef: "N",
        longitude: 114.1201,
        longitudeRef: "E",
        dateTimeOriginal: "2026:08:20 09:30:00"
    )
    let fallback = Date(timeIntervalSince1970: 1)
    let metadata = FreePhotoMetadataReader.metadata(
        from: data,
        acceptedAt: fallback,
        timeZone: TimeZone(identifier: "Asia/Hong_Kong")!
    )

    #expect(metadata.location?.coordinate == FreePhotoCoordinate(latitude: 22.4084, longitude: 114.1201))
    #expect(metadata.creationDate != fallback)
}

@Test func missingSourceDateFallsBackToAcceptedImportTime() {
    let acceptedAt = Date(timeIntervalSince1970: 1234)
    let metadata = FreePhotoMetadataReader.metadata(from: Data(), acceptedAt: acceptedAt)
    #expect(metadata.creationDate == acceptedAt)
    #expect(metadata.location == nil)
}
```

Add this fixture helper in the same test file so the metadata test is executable without Photos-library state:

```swift
private func fixtureJPEG(
    latitude: Double,
    latitudeRef: String,
    longitude: Double,
    longitudeRef: String,
    dateTimeOriginal: String
) throws -> Data {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(
        data,
        UTType.jpeg.identifier as CFString,
        1,
        nil
    ))
    let properties: [CFString: Any] = [
        kCGImagePropertyGPSDictionary: [
            kCGImagePropertyGPSLatitude: latitude,
            kCGImagePropertyGPSLatitudeRef: latitudeRef,
            kCGImagePropertyGPSLongitude: longitude,
            kCGImagePropertyGPSLongitudeRef: longitudeRef
        ],
        kCGImagePropertyExifDictionary: [
            kCGImagePropertyExifDateTimeOriginal: dateTimeOriginal
        ]
    ]
    CGImageDestinationAddImage(destination, try #require(image.cgImage), properties as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}
```

Import `UniformTypeIdentifiers` in the test file for `UTType.jpeg`.

- [x] **Step 2: Run the focused metadata tests and verify RED**

Run the Task 1 command with `-only-testing:WildFrogNativeTests/FreePhotoPrivateMapTests`. Expected: compile failure for the missing metadata result/reader.

- [x] **Step 3: Implement one metadata reader**

Add:

```swift
struct FreePhotoImportedMetadata: Equatable {
    let location: FreePhotoLocationCandidate?
    let creationDate: Date
}
```

Replace the UI-facing `FreePhotoMetadataLocationReader.candidate` call with `FreePhotoMetadataReader.metadata`. For Photos identifiers, fetch the asset once and prefer its valid `location` and `creationDate`. For ImageIO fallback, parse GPS as today and parse EXIF `DateTimeOriginal`, then EXIF `DateTimeDigitized`, then TIFF `DateTime`; use format `yyyy:MM:dd HH:mm:ss`, POSIX locale, Gregorian calendar, and injected/current timezone. When all date sources are missing or invalid, use `acceptedAt`.

Keep a compatibility `candidate(from:)` wrapper only if existing focused tests still consume it; production must consume the combined result.

- [x] **Step 4: Run metadata and private-map tests to GREEN**

Run the Task 2 focused command again. Expected: metadata and existing private-map tests pass.

---

### Task 3: Optional Date And Coordinates In Both Frame Renderers

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoFrameViews.swift`
- Modify: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoFrameContentTests.swift`

**Interfaces:**
- Consumes: `FreePhotoDraft.displayDate`, `displayCoordinate`, and the existing seal/name contracts.
- Produces: optional `FreePhotoFrameContent.dateLabel`, optional `coordinateLabel`, and per-style `metadataBounds` used by renderer tests.

- [x] **Step 1: Write failing content and renderer tests**

Add tests for optional labels and both coordinate directions:

```swift
@Test func frameContentCanHideDateAndCoordinatesIndependently() {
    let content = FreePhotoFrameContent(
        placeName: "城門水塘",
        altitudeMetres: 214,
        altitudeSource: .manual,
        date: nil,
        coordinate: nil
    )
    #expect(content.dateLabel == nil)
    #expect(content.coordinateLabel == nil)
    #expect(content.altitudeLabel?.contains("214m") == true)
}

@MainActor
@Test func bothFramesKeepMetadataInsideTextBoundsAndOutsideSeal() throws {
    let full = FreePhotoFrameContent(
        placeName: "大東山日落位",
        altitudeMetres: 869,
        altitudeSource: .gpsApproximate,
        date: Date(timeIntervalSince1970: 0),
        coordinate: FreePhotoCoordinate(latitude: -22.4084, longitude: -114.1201)
    )
    let hidden = FreePhotoFrameContent(
        placeName: full.placeName,
        altitudeMetres: full.altitudeMetres,
        altitudeSource: full.altitudeSource,
        date: nil,
        coordinate: nil
    )
    for style in FreePhotoCardStyle.allCases {
        let contract = FreePhotoFrameRenderContract(style: style)
        #expect(!contract.metadataBounds.intersects(contract.stampBounds))
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1080)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1080, height: 1080))
        }
        let fullRender = try #require(FreePhotoFrameRenderer.render(style: style, content: full, userPhoto: photo))
        let hiddenRender = try #require(FreePhotoFrameRenderer.render(style: style, content: hidden, userPhoto: photo))
        let changed = try #require(fullRender.changedPixelBounds(comparedTo: hiddenRender))
        #expect(contract.metadataBounds.contains(changed))
    }
}
```

- [x] **Step 2: Run frame-content tests and verify RED**

Run the Task 1 command with `-only-testing:WildFrogNativeTests/FreePhotoFrameContentTests`. Expected: compile failure for optional date, coordinate, and metadata bounds.

- [x] **Step 3: Implement optional frame content and layouts**

Change `FreePhotoFrameContent` to:

```swift
let date: Date?
let coordinate: FreePhotoCoordinate?

var dateLabel: String? { date.map(Self.formatDate) }
var coordinateLabel: String? { coordinate.map(Self.formatCoordinate) }
```

Add `metadataBounds` to `FreePhotoFrameRenderContract`, sized to cover only the existing date/altitude and new coordinate text while remaining disjoint from `stampBounds`.

For Polaroid, keep the first `HStack` for optional date plus altitude and add a conditional coordinate `Label(..., systemImage: "location.fill")` beneath it. For Passport, render date conditionally in the top-trailing header and put altitude/coordinate in a leading `VStack` under the divider. Fix the metadata container height/leading width so conditional views do not displace the name or enter the seal bounds.

- [x] **Step 4: Run frame tests to GREEN**

Run the Step 2 command again. Expected: all frame-content tests pass and both renderer sizes remain exact.

---

### Task 4: Editor Wiring, Capture Defaults, And Immutable Save Request

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoView.swift`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoSaveCoordinator.swift`
- Modify: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoDraftTests.swift`
- Modify: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoPrivateMapTests.swift`

**Interfaces:**
- Consumes: Tasks 1-3 draft, metadata, frame-content, and formatting APIs.
- Produces: visible editor controls, exact preview/export content, and expanded `FreePhotoSaveRequest` equality.

- [x] **Step 1: Write failing request identity and separation tests**

Extend the existing retry test so two requests differing only in frame date/coordinate presentation are unequal, while `makeRecord` still uses only `request.location` for the private-map coordinate:

```swift
@Test func printedCoordinateNeverBecomesPrivateMapCoordinate() {
    let printed = FreePhotoCoordinate(latitude: 35, longitude: 139)
    let map = FreePhotoLocationCandidate(
        coordinate: FreePhotoCoordinate(latitude: 22.3, longitude: 114.1),
        source: .cameraGPS,
        horizontalAccuracy: 8,
        timestamp: nil
    )
    let request = FreePhotoSaveRequest(
        id: UUID(),
        captureRevision: 1,
        renderedAt: Date(timeIntervalSince1970: 10),
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .gpsApproximate,
        cardStyle: .passport,
        frameDate: Date(timeIntervalSince1970: 5),
        showsDate: true,
        displayCoordinate: printed,
        showsCoordinates: true,
        location: map
    )
    #expect(request.displayCoordinate == printed)
    #expect(request.location?.coordinate == map.coordinate)
}
```

- [x] **Step 2: Run Draft and private-map tests and verify RED**

Run both focused suites. Expected: compile failure for expanded request fields and view content arguments.

- [x] **Step 3: Wire the editor and metadata defaults**

In `detailsSection`, add:

```swift
Toggle(AppText.value(zh: "顯示日期", en: "Display date"), isOn: $draft.showsDate)
DatePicker(
    AppText.value(zh: "日期", en: "Date"),
    selection: $draft.frameDate,
    displayedComponents: .date
)

Toggle(AppText.value(zh: "顯示座標", en: "Display coordinates"), isOn: $draft.showsCoordinates)
TextField(AppText.value(zh: "緯度", en: "Latitude"), text: latitudeText)
TextField(AppText.value(zh: "經度", en: "Longitude"), text: longitudeText)
```

Use `.numbersAndPunctuation`, the existing white rounded-field styling, and explanatory copy that printed edits do not move the private map.

When Photos load completes, call the combined metadata reader with one `acceptedAt` value, accept the existing request revision, then apply image, `selectedLocation = metadata.location`, and `draft.applyFrameMetadata(date: metadata.creationDate, coordinate: metadata.location?.coordinate)` together.

When camera capture finishes, compute one `capturedAt`, resolve one capture-bound candidate, set `selectedLocation`, and call `draft.applyFrameMetadata(date: capturedAt, coordinate: candidate?.coordinate)`.

Update `frameContent` so `date` is `draft.showsDate ? draft.frameDate : nil` and `coordinate` is `draft.showsCoordinates ? draft.displayCoordinate : nil`. Update validation copy for the three coordinate errors.

Observe changes to date, both coordinate strings, and both switches with `resetSaveConfirmation()`.

- [x] **Step 4: Expand exact fingerprint and save request**

Populate all new fingerprint properties from the draft. Expand `FreePhotoSaveRequest` with:

```swift
let frameDate: Date
let showsDate: Bool
let displayCoordinate: FreePhotoCoordinate?
let showsCoordinates: Bool
```

Pass them when the save begins. Do not add presentation coordinates to `FreePhotoRecord`; `makeRecord` must continue using only `request.location?.coordinate`.

- [x] **Step 5: Run all focused suites to GREEN**

Run focused Draft, frame-content, and private-map suites. Expected: all execute and pass.

---

### Task 5: Full Verification And Runtime Visual Proof

**Files:**
- Verify: all files modified above
- Update: `docs/superpowers/plans/2026-08-20-free-photo-custom-date-coordinates.md` checkboxes only

**Interfaces:**
- Consumes: completed feature.
- Produces: full test/build logs and deterministic visual evidence without changing release state.

- [x] **Step 1: Run the full iOS test target**

```bash
set -o pipefail
xcodebuild test \
  -project ios/WildFrogNative/WildFrogNative.xcodeproj \
  -scheme WildFrogNative \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath .build/free-photo-custom-metadata-full \
  -only-testing:WildFrogNativeTests \
  | tee /tmp/wildfrog-free-photo-custom-metadata-full.log
```

Expected: exit 0, non-zero executed test count, zero failures.

- [x] **Step 2: Run a generic Simulator build**

```bash
set -o pipefail
xcodebuild build \
  -project ios/WildFrogNative/WildFrogNative.xcodeproj \
  -scheme WildFrogNative \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/free-photo-custom-metadata-generic \
  CODE_SIGNING_ALLOWED=NO \
  | tee /tmp/wildfrog-free-photo-custom-metadata-generic.log
```

Expected: exit 0 and `BUILD SUCCEEDED`.

- [x] **Step 3: Inspect both rendered frame styles**

Launch the existing `-qaFreePhoto` route on an iPhone 16 Pro Simulator. Capture Passport and Polaroid previews with date/coordinates enabled, then disable each switch and confirm the corresponding metadata disappears without moving the name under the seal. Retain screenshots under `/tmp/wildfrog-free-photo-custom-metadata-qa/`.

- [x] **Step 4: Run hygiene and scope checks**

```bash
git diff --check
git status --short
plutil -lint ios/WildFrogNative/Sources/WildFrogNative/Info.plist
plutil -lint ios/WildFrogNative/LiveActivityWidget/Info.plist
```

Expected: no diff whitespace errors; both plists report `OK`; only scoped source/tests/spec/plan plus pre-existing `.superpowers/` scratch are present. Confirm version/build remain `1.0.5 (13)` and no Git/ASC/Firebase delivery action occurred.
