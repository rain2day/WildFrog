# Free Photo Trail Studio UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the crowded post-selection Free Photo form with the approved Trail Studio layout and move all exported-frame copy and the seal inside an 8% safe region.

**Architecture:** Keep `FreePhotoDraft`, metadata loading, request identity, saving, and private-map location semantics unchanged. Add focused SwiftUI editor components and a small value-type summary/layout contract, then make `FreePhotoView` switch between the existing capture state and the compact post-selection studio. Update the deterministic render contract before changing the two renderers so pixel-containment tests remain authoritative.

**Tech Stack:** SwiftUI, UIKit image rendering, PhotosUI, CoreLocation, Swift Testing, Xcode Simulator.

## Global Constraints

- Preserve camera capture metadata, imported Photos metadata, validation, save recovery, Passport/Polaroid switching, and Back navigation.
- Printed coordinate edits remain display-only and never change `selectedLocation` or the private-map record coordinate.
- Keep altitude behaviour unchanged: a valid value is displayed; clearing it removes it from the frame.
- Page horizontal inset is 20 pt; major gap 24 pt; card padding 16 pt; related gap 12 pt; tight gap 6 pt; controls are at least 48 pt high.
- Every exported text region and the seal must be inside a canvas inset equal to at least 8% of canvas width.
- Do not add dependencies, frame styles, filters, fonts, Firebase writes, version changes, or ASC changes.
- Do not commit or push during this execution unless the user separately authorises it; replace commit steps with scoped diff checkpoints.

---

### Task 1: Trail Studio layout and summary contracts

**Files:**
- Create: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoEditorUI.swift`
- Modify: `ios/WildFrogNative/WildFrogNative.xcodeproj/project.pbxproj`
- Modify: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoDraftTests.swift`

**Interfaces:**
- Consumes: `FreePhotoDraft`, `FreePhotoAltitudeSource`, `AppText`.
- Produces: `FreePhotoEditorMetrics`, `FreePhotoMetadataSummary`, `FreePhotoMetadataSummaryItem`, `FreePhotoMetadataEditorSheet`, and `FreePhotoMetadataSummaryCard`.

- [x] **Step 1: Write failing summary and spacing contract tests**

Add tests that require exact spacing tokens and verify date/coordinate shown/hidden summaries while altitude keeps value/source semantics:

```swift
@Test func trailStudioUsesApprovedSpacingAndMetadataHierarchy() {
    #expect(FreePhotoEditorMetrics.pageInset == 20)
    #expect(FreePhotoEditorMetrics.sectionGap == 24)
    #expect(FreePhotoEditorMetrics.cardPadding == 16)
    #expect(FreePhotoEditorMetrics.relatedGap == 12)
    #expect(FreePhotoEditorMetrics.tightGap == 6)
    #expect(FreePhotoEditorMetrics.minimumControlHeight == 48)

    var draft = FreePhotoDraft()
    draft.placeName = "大東山日落位"
    draft.setAltitudeText("438")
    draft.showsDate = false
    draft.showsCoordinates = true
    draft.setLatitudeText("22.4084")
    draft.setLongitudeText("114.1201")

    let summary = FreePhotoMetadataSummary(draft: draft)
    #expect(summary.altitude.value.contains("438"))
    #expect(summary.date.visibility == .hidden)
    #expect(summary.coordinates.visibility == .shown)
}
```

- [x] **Step 2: Run the focused tests and record RED**

Run:

```bash
xcodebuild test -project ios/WildFrogNative/WildFrogNative.xcodeproj -scheme WildFrogNative -destination 'platform=iOS Simulator,id=B07F718E-943B-4C9B-ABDB-E13FB8FB1EF2' -only-testing:WildFrogNativeTests 2>&1 | tee /tmp/wildfrog-trail-studio-task1-red.log
```

Expected: compile failure because the Trail Studio contracts do not exist.

- [x] **Step 3: Add the value contracts and focused components**

Implement immutable summary values and the approved spacing constants:

```swift
enum FreePhotoEditorMetrics {
    static let pageInset: CGFloat = 20
    static let sectionGap: CGFloat = 24
    static let cardPadding: CGFloat = 16
    static let relatedGap: CGFloat = 12
    static let tightGap: CGFloat = 6
    static let minimumControlHeight: CGFloat = 48
    static let cardRadius: CGFloat = 20
    static let previewRadius: CGFloat = 24
}

enum FreePhotoMetadataVisibility: Equatable {
    case shown
    case hidden
    case notSet
}

struct FreePhotoMetadataSummaryItem: Equatable {
    let title: String
    let value: String
    let visibility: FreePhotoMetadataVisibility
}

struct FreePhotoMetadataSummary: Equatable {
    let altitude: FreePhotoMetadataSummaryItem
    let date: FreePhotoMetadataSummaryItem
    let coordinates: FreePhotoMetadataSummaryItem

    init(draft: FreePhotoDraft) {
        let labels = FreePhotoFrameContent(
            placeName: draft.validatedName,
            altitudeMetres: draft.altitudeMetres,
            altitudeSource: draft.altitudeSource,
            date: draft.frameDate,
            coordinate: draft.displayCoordinate
        )
        let altitudeValue = labels.altitudeLabel
            ?? AppText.value(zh: "未設定", en: "Not set")
        altitude = FreePhotoMetadataSummaryItem(
            title: AppText.value(zh: "海拔", en: "Altitude"),
            value: altitudeValue,
            visibility: draft.altitudeMetres == nil ? .notSet : .shown
        )
        date = FreePhotoMetadataSummaryItem(
            title: AppText.value(zh: "日期", en: "Date"),
            value: labels.dateLabel ?? AppText.value(zh: "未設定", en: "Not set"),
            visibility: draft.showsDate ? .shown : .hidden
        )
        coordinates = FreePhotoMetadataSummaryItem(
            title: AppText.value(zh: "座標", en: "Coordinates"),
            value: labels.coordinateLabel ?? AppText.value(zh: "未設定", en: "Not set"),
            visibility: draft.displayCoordinate == nil
                ? .notSet
                : (draft.showsCoordinates ? .shown : .hidden)
        )
    }
}
```

Add `FreePhotoMetadataSummaryCard` with one editable place-name field, three compact summary cells, and an Edit button. Add `FreePhotoMetadataEditorSheet` with altitude, date, and coordinate groups bound directly to the caller's `FreePhotoDraft`; the sheet has Done, no false-cancel state, inline validation, and one private-map explanation.

- [x] **Step 4: Wire the new source file into the app target**

Add one `PBXFileReference`, one `PBXBuildFile`, one group child, and one Sources build-phase entry for `FreePhotoEditorUI.swift`. Do not reorder unrelated project entries.

- [x] **Step 5: Run the full test target and record GREEN**

Use the Task 1 test command and require all existing tests plus the new contract test to pass.

- [x] **Step 6: Review the scoped diff**

Run `git diff --check` and inspect only the new file, project wiring, and `FreePhotoDraftTests.swift`. Do not commit.

---

### Task 2: Compact post-selection Trail Studio editor

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoView.swift`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoEditorUI.swift`
- Modify: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoDraftTests.swift`

**Interfaces:**
- Consumes: Task 1 editor metrics/components and existing photo/save/location state.
- Produces: a capture state with existing source choices and a post-selection state with live preview, style picker, summary card, metadata sheet, replace-photo menu, and sticky save action.

- [x] **Step 1: Add failing editor-state tests**

Add a value contract that makes the screen state explicit:

```swift
@Test func freePhotoEditorShowsCaptureBeforePhotoAndStudioAfterPhoto() {
    #expect(FreePhotoEditorPresentation(hasPhoto: false).mode == .capture)
    #expect(FreePhotoEditorPresentation(hasPhoto: true).mode == .studio)
    #expect(FreePhotoEditorPresentation(hasPhoto: true).usesStickySave)
    #expect(!FreePhotoEditorPresentation(hasPhoto: true).showsExpandedMetadataOnCanvas)
}
```

Run the full target and record RED in `/tmp/wildfrog-trail-studio-task2-red.log`.

- [x] **Step 2: Split the body into capture and studio compositions**

Keep the existing pre-photo camera/Photos/location UI. When `capturedImage != nil`, render:

```swift
ScrollView {
    VStack(spacing: FreePhotoEditorMetrics.sectionGap) {
        framedPreview
        frameStylePicker
        FreePhotoMetadataSummaryCard(...)
        saveStatusAndPrivacyCopy
    }
    .padding(.horizontal, FreePhotoEditorMetrics.pageInset)
}
.safeAreaInset(edge: .bottom) { stickySaveButton }
```

Remove numbered headings and permanently expanded metadata fields from the studio state. Keep scroll bottom padding equal to the sticky action height plus safe-area spacing.

- [x] **Step 3: Add sheet and replace-photo interactions**

- Add `@State private var showsMetadataEditor = false`.
- Present `FreePhotoMetadataEditorSheet(draft: $draft, ...)` with medium/large detents.
- Put Camera and Photos choices in a compact `Replace Photo` menu/header action.
- Reuse the existing cancellation/revision functions exactly; do not introduce a second selection path.
- Preserve the existing `onChange(of: draft)` save-confirmation reset.

- [x] **Step 4: Keep save/error/recovery behaviour visible**

Extract the existing primary button label/state into the sticky action. Keep `saveError`, retry-private-map action, completion acknowledgement, disabled state, and privacy copy on the studio screen without duplicating them in the sheet.

- [x] **Step 5: Run focused and full tests**

Require the new presentation test and the entire test target to pass; save GREEN output to `/tmp/wildfrog-trail-studio-task2-green.log`.

- [x] **Step 6: Review the scoped diff**

Run `git diff --check`; confirm `selectedLocation` is never assigned from printed-coordinate bindings and Back still calls `dismiss()`. Do not commit.

---

### Task 3: Export-frame safe spacing and information hierarchy

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoFrameViews.swift`
- Modify: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoFrameContentTests.swift`

**Interfaces:**
- Consumes: existing `FreePhotoFrameContent` labels and renderer.
- Produces: `FreePhotoFrameRenderContract.safeBounds`, revised name/metadata/stamp bounds, and Passport/Polaroid layouts whose changed pixels stay inside those bounds.

- [x] **Step 1: Replace exact old stamp expectations with safe-region tests**

Add:

```swift
@MainActor
@Test func bothFramesKeepCopyAndSealInsideEightPercentSafeRegion() throws {
    for style in FreePhotoCardStyle.allCases {
        let contract = FreePhotoFrameRenderContract(style: style)
        let minimumInset = contract.canvasSize.width * 0.08
        #expect(contract.safeBounds.minX >= minimumInset)
        #expect(contract.safeBounds.maxX <= contract.canvasSize.width - minimumInset)
        #expect(contract.safeBounds.contains(contract.nameBounds))
        #expect(contract.safeBounds.contains(contract.metadataBounds))
        #expect(contract.safeBounds.contains(contract.stampBounds))
        #expect(!contract.nameBounds.intersects(contract.stampBounds))
        #expect(!contract.metadataBounds.intersects(contract.stampBounds))
    }
}
```

Keep existing mutation-sensitive image-diff checks for name, metadata, and seal. Run the full target and record RED in `/tmp/wildfrog-trail-studio-task3-red.log`.

- [x] **Step 2: Implement the 8% render contract**

Add `safeBounds` based on an inset of at least `86.4` pixels on the 1080-pixel canvas. Move both `nameBounds` and `metadataBounds` inside it. Reduce and inset `stampBounds`; maintain non-intersection with name and metadata.

- [x] **Step 3: Recompose the Polaroid renderer**

- Increase left/right copy padding to the safe inset.
- Keep name at no more than two lines.
- Render date and altitude on metadata line one; coordinates on line two.
- Collapse missing lines without placeholder spacers.
- Keep only one quiet Free Photo identity line.

- [x] **Step 4: Recompose the Passport renderer**

- Inset lower-band copy and seal to the shared safe bounds.
- Reduce the seal so it cannot crowd the name or metadata.
- Use a single tertiary Free Photo identifier; remove competing redundant copy.
- Preserve the existing wide-photo crop and palette.

- [x] **Step 5: Run renderer tests and mutation sensitivity**

Run the full test target. Temporarily move one tested bound beyond `safeBounds`, verify the new test fails, restore the correct value, and rerun GREEN to `/tmp/wildfrog-trail-studio-task3-green.log`.

- [x] **Step 6: Review the scoped diff**

Run `git diff --check`; confirm canvas sizes, frame styles, content labels, and palette are unchanged. Do not commit.

---

### Task 4: Full verification and visual acceptance

**Files:**
- Modify if a verified issue is found: only files listed in Tasks 1-3.
- Update: `docs/superpowers/plans/2026-08-20-free-photo-trail-studio-ui.md` checkboxes.
- Update: the active RainVault WildFrog handoff with final evidence.

**Interfaces:**
- Consumes: completed Trail Studio editor and render contracts.
- Produces: fresh automated, build, and Simulator evidence without release actions.

- [x] **Step 1: Run the fresh full iOS test target**

Run the exact iPhone 16 Pro Simulator command used above and require all tests to pass with exit 0.

- [x] **Step 2: Run a generic Simulator build in bounded scratch**

```bash
xcodebuild build -project ios/WildFrogNative/WildFrogNative.xcodeproj -scheme WildFrogNative -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/wildfrog-trail-studio-derived CODE_SIGNING_ALLOWED=NO 2>&1 | tee /tmp/wildfrog-trail-studio-generic.log
```

Require `BUILD SUCCEEDED`.

- [x] **Step 3: Run Simulator visual acceptance**

Install the built app on simulator `B07F718E-943B-4C9B-ABDB-E13FB8FB1EF2`, launch with `-qaFreePhoto`, and capture:

- compact studio in Passport;
- compact studio in Polaroid;
- metadata sheet;
- date/coordinates hidden;
- maximum-length place name;
- Back after a selected photo;
- sticky Save on a short viewport.

Inspect every screenshot, not only semantic output.

- [x] **Step 4: Run final hygiene**

- `git diff --check`
- lint both app/widget plists;
- confirm `MARKETING_VERSION = 1.0.5` and `CURRENT_PROJECT_VERSION = 13` remain unchanged;
- confirm only scoped source/test/project/spec/plan files changed, plus pre-existing `.superpowers/` artifacts.

- [x] **Step 5: Update and validate the RainVault handoff**

Record files, decisions, commands, blockers, and next step. Run strict single-note context validation and Wiki Doctor.

- [x] **Step 6: Clean task-owned scratch**

Measure and revalidate `/private/tmp/wildfrog-trail-studio-derived`, verify no open files, preserve logs/screenshots/handoff, remove only that exact rebuildable path, and confirm it is absent.

- [x] **Step 7: Preserve branch and report proof boundaries**

Leave `codex/free-photo-leaderboard` and its worktree intact. Report local implementation, tests, build, Simulator proof, remaining physical-iPhone acceptance, and the fact that no commit, push, version bump, ASC, Firebase, or release action occurred.
