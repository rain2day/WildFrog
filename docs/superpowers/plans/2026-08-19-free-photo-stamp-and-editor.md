# Free Photo Stamp And Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the approved image-generated Free Photo frog stamp to both raster exports and restore reliable altitude editing plus Passport/Polaroid switching after a photo loads.

**Architecture:** Convert the approved third image-generation candidate into a genuine-alpha PNG without changing its generated artwork, then consume it through one `FreePhotoStampSeal` image component. Extend the existing render contract with exact per-style stamp bounds and make the scaled preview explicitly non-interactive so the editor controls retain hit testing. Preserve `FreePhotoDraft` and `FreePhotoExportFingerprint` as the data and save-identity authorities.

**Tech Stack:** SwiftUI, UIKit `ImageRenderer`, Swift Testing, Xcode asset catalog, Pillow only for deterministic alpha extraction of the approved generated raster.

## Global Constraints

- The source artwork is the user-approved third image-generation candidate at `/Users/rainsday/.codex/generated_images/01a012b3-a475-71c1-b9fb-6e1e05f86310/exec-16cb94d8-66a1-48c4-9227-f08cb690124e.png`.
- Final asset format is raster PNG with real alpha. Do not add SVG, PDF vector, SF Symbol, SwiftUI Path, or Canvas artwork.
- Exact stamp text is `WILDFROG` on the upper ring and `FREE PHOTO` on the lower ring.
- Free Photo remains isolated from official check-ins, stamp unlocks, achievements, certificates, and leaderboard scores.
- Ranked Check-In cards and their green/gold mountain seals remain unchanged.
- Do not cancel the active `1.0.3 (11)` App Store submission, increment a build number, archive, upload, deploy, commit, or push.

---

### Task 1: Production Raster Asset

**Files:**
- Create: `ios/WildFrogNative/Sources/WildFrogNative/Assets.xcassets/FreePhotoStampSeal.imageset/Contents.json`
- Create: `ios/WildFrogNative/Sources/WildFrogNative/Assets.xcassets/FreePhotoStampSeal.imageset/free-photo-stamp-seal.png`
- Test: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoFrameContentTests.swift`

**Interfaces:**
- Consumes: approved image-generated PNG named in Global Constraints.
- Produces: asset-catalog image named `FreePhotoStampSeal` with 1,024 by 1,024 pixels and a non-opaque alpha channel.

- [ ] **Step 1: Write the failing asset test**

```swift
import Foundation
import ImageIO
import Testing

@Test func freePhotoStampIsTransparentRasterAndNeverVector() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let imageset = root.appendingPathComponent("Sources/WildFrogNative/Assets.xcassets/FreePhotoStampSeal.imageset")
    let png = imageset.appendingPathComponent("free-photo-stamp-seal.png")

    #expect(FileManager.default.fileExists(atPath: png.path))
    #expect(try FileManager.default.contentsOfDirectory(atPath: imageset.path)
        .allSatisfy { !$0.lowercased().hasSuffix(".svg") })

    let source = try #require(CGImageSourceCreateWithURL(png as CFURL, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(image.width == 1_024)
    #expect(image.height == 1_024)
    #expect(![.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo))
}
```

- [ ] **Step 2: Run the focused test and capture RED**

Run:

```bash
xcodebuild test \
  -project ios/WildFrogNative/WildFrogNative.xcodeproj \
  -scheme WildFrogNative \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath .build/xcode-derived \
  -only-testing:WildFrogNativeTests/FreePhotoFrameContentTests
```

Expected: FAIL because `FreePhotoStampSeal.imageset` or its PNG does not exist.

- [ ] **Step 3: Extract real alpha from the approved image-generated raster**

Use Pillow only as deterministic file preparation: grayscale checkerboard pixels become transparent, blue/navy ink remains, antialiased edges receive proportional alpha, and the artwork is resized to 1,024 square. Do not redraw or reinterpret the generated design.

```python
from pathlib import Path
from PIL import Image

source = Path("/Users/rainsday/.codex/generated_images/01a012b3-a475-71c1-b9fb-6e1e05f86310/exec-16cb94d8-66a1-48c4-9227-f08cb690124e.png")
target = Path("ios/WildFrogNative/Sources/WildFrogNative/Assets.xcassets/FreePhotoStampSeal.imageset/free-photo-stamp-seal.png")
target.parent.mkdir(parents=True, exist_ok=True)

image = Image.open(source).convert("RGBA")
output = Image.new("RGBA", image.size)
pixels = []
for red, green, blue, _ in image.getdata():
    value = max(red, green, blue)
    chroma = value - min(red, green, blue)
    darkness = max(0, 245 - value)
    alpha = min(255, max(chroma * 5, darkness * 4))
    pixels.append((red, green, blue, alpha))
output.putdata(pixels)
output = output.resize((1024, 1024), Image.Resampling.LANCZOS)
output.save(target, format="PNG", optimize=True)
```

Create `Contents.json` with one universal 1x raster filename and no vector-preservation property:

```json
{
  "images" : [
    {
      "filename" : "free-photo-stamp-seal.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 4: Verify the PNG mechanically and visually**

Run the focused test again. Also run:

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha \
  ios/WildFrogNative/Sources/WildFrogNative/Assets.xcassets/FreePhotoStampSeal.imageset/free-photo-stamp-seal.png
```

Expected: focused test PASS; width and height 1,024; `hasAlpha: yes`. Inspect the PNG on both white and navy temporary backgrounds and confirm no checkerboard squares, white halo, spelling drift, clipping, or changed frog silhouette.

### Task 2: Stamp Render Contract And Both Frame Exports

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoFrameViews.swift`
- Modify: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoFrameContentTests.swift`

**Interfaces:**
- Consumes: asset name `FreePhotoStampSeal` from Task 1.
- Produces: `FreePhotoFrameRenderContract.stampBounds`, `FreePhotoStampSeal`, and identical stamp placement in both preview/export card views.

- [ ] **Step 1: Add failing contract and renderer tests**

Add expectations for exact bounds and changed pixels:

```swift
#expect(FreePhotoFrameRenderContract(style: .passport).stampBounds
    == CGRect(x: 694, y: 540, width: 360, height: 360))
#expect(FreePhotoFrameRenderContract(style: .polaroid).stampBounds
    == CGRect(x: 706, y: 876, width: 280, height: 280))

for style in FreePhotoCardStyle.allCases {
    let contract = FreePhotoFrameRenderContract(style: style)
    #expect(CGRect(origin: .zero, size: contract.canvasSize).contains(contract.stampBounds))
    #expect(!contract.nameBounds.intersects(contract.stampBounds))
}
```

Render with and without the stamp through an internal test seam and assert that `changedPixelBounds` is non-nil and contained by `stampBounds`. Keep the existing maximum-name containment test green.

- [ ] **Step 2: Run focused tests and capture RED**

Run the same `xcodebuild test` command with `-only-testing:WildFrogNativeTests/FreePhotoFrameContentTests`.

Expected: compile failure because `stampBounds`, `FreePhotoStampSeal`, or the renderer seam does not exist.

- [ ] **Step 3: Implement exact bounds and bitmap-only component**

Add:

```swift
var stampBounds: CGRect {
    switch style {
    case .polaroid: CGRect(x: 706, y: 876, width: 280, height: 280)
    case .passport: CGRect(x: 694, y: 540, width: 360, height: 360)
    }
}

struct FreePhotoStampSeal: View {
    let size: CGFloat

    var body: some View {
        Image("FreePhotoStampSeal")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .opacity(0.92)
            .rotationEffect(.degrees(-8))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
```

Reserve non-overlapping name bounds in each style and overlay the component at the contract rectangle. Do not expose `stampAssetName` as official metadata and do not touch `MountainStampSeal`.

- [ ] **Step 4: Run focused renderer tests**

Expected: all `FreePhotoFrameContentTests` PASS, including the alpha/format test, both output sizes remain unchanged, and changed seal pixels remain inside exact bounds.

### Task 3: Loaded-Photo Editor Interaction

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoDraft.swift`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoView.swift`
- Modify: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoDraftTests.swift`
- Modify: `ios/WildFrogNative/Tests/WildFrogNativeTests/FreePhotoIsolationTests.swift`

**Interfaces:**
- Consumes: existing `FreePhotoDraft`, `FreePhotoCardStyle`, and `FreePhotoPreviewLayout`.
- Produces: `FreePhotoPreviewInteractionContract.cardAllowsHitTesting == false` and a fixed-bounds preview whose card cannot cover editor controls.

- [ ] **Step 1: Write failing interaction regressions**

Add:

```swift
@Test func loadedPhotoAltitudeCanBeEditedClearedAndEditedAgain() {
    var draft = FreePhotoDraft()
    let started = Date(timeIntervalSince1970: 1_000)
    draft.placeName = "大東山"
    draft.beginLocationPrefillSession(at: started)
    draft.applyLocationSuggestion(altitude: 438, verticalAccuracy: 8, timestamp: started.addingTimeInterval(1))
    draft.setAltitudeText("500")
    #expect(draft.altitudeMetres == 500)
    #expect(draft.altitudeSource == .manual)
    draft.setAltitudeText("")
    #expect(draft.altitudeMetres == nil)
    draft.setAltitudeText("321")
    draft.applyLocationSuggestion(altitude: 900, verticalAccuracy: 8, timestamp: started.addingTimeInterval(2))
    #expect(draft.altitudeMetres == 321)
    #expect(draft.altitudeSource == .manual)
}

@Test func loadedPhotoCanRoundTripPassportAndPolaroidLayouts() {
    let width: CGFloat = 335
    let passportBefore = FreePhotoPreviewLayout(style: .passport).height(forAvailableWidth: width)
    let polaroid = FreePhotoPreviewLayout(style: .polaroid).height(forAvailableWidth: width)
    let passportAfter = FreePhotoPreviewLayout(style: .passport).height(forAvailableWidth: width)
    #expect(passportBefore != polaroid)
    #expect(passportAfter == passportBefore)
    #expect(!FreePhotoPreviewInteractionContract.cardAllowsHitTesting)
}
```

Extend the source isolation assertion to require the production preview card uses `.allowsHitTesting(FreePhotoPreviewInteractionContract.cardAllowsHitTesting)`.

- [ ] **Step 2: Run focused tests and capture RED**

Expected: compile or contract failure because `FreePhotoPreviewInteractionContract` and its production wiring do not exist.

- [ ] **Step 3: Apply the minimal hit-testing and sizing fix**

Add:

```swift
enum FreePhotoPreviewInteractionContract {
    static let cardAllowsHitTesting = false
}
```

In `previewSection`, put the scaled 1,080-point renderer inside a fixed-size container matching `FreePhotoPreviewLayout`, clip that container, and apply:

```swift
.allowsHitTesting(FreePhotoPreviewInteractionContract.cardAllowsHitTesting)
```

only to the rendered card. Keep the segmented Picker outside that modifier. Do not disable the altitude `TextField`, Picker, capture buttons, or save button. Preserve the existing `onChange` invalidation for altitude and style.

- [ ] **Step 4: Run focused Free Photo tests**

Run all four Free Photo test files. Expected: PASS with the altitude, round-trip, source-wiring, renderer, alpha, and save-identity regressions included.

### Task 4: Simulator And Full-Gate Verification

**Files:**
- Modify only if required by a proven QA-route gap: `ios/WildFrogNative/Sources/WildFrogNative/FreePhotoView.swift`
- Update: `/Users/rainsday/Obsidian/RainVault/40_AI_SESSIONS/Shared/Handoffs/20260818-wildfrog-production-rollout.md`

**Interfaces:**
- Consumes: completed Tasks 1-3.
- Produces: screenshot/runtime proof, full test/build evidence, and a resumable delivery boundary.

- [ ] **Step 1: Run deterministic Simulator interaction proof**

Launch with `-qaFreePhoto`, verify the fixture photo is visible, tap the altitude field, replace `438` with `500`, clear it, enter `321`, and switch `Passport -> Polaroid -> Passport`. Capture screenshots for both styles and confirm the stamp stays within the approved position and never covers the name/date/altitude.

- [ ] **Step 2: Compare saved renderers**

Render deterministic blue-photo fixtures for both styles from tests, save temporary PNG evidence under `/tmp`, and inspect them at full size plus app-preview scale. Confirm exact `WILDFROG` and `FREE PHOTO` text, real transparency around the seal, no official green/gold, and preview/export parity.

- [ ] **Step 3: Run the full iOS gates**

```bash
xcodebuild test \
  -project ios/WildFrogNative/WildFrogNative.xcodeproj \
  -scheme WildFrogNative \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath .build/xcode-derived \
  -only-testing:WildFrogNativeTests

xcodebuild \
  -project ios/WildFrogNative/WildFrogNative.xcodeproj \
  -scheme WildFrogNative \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/xcode-derived \
  build

git diff --check
plutil -lint ios/WildFrogNative/Sources/WildFrogNative/Info.plist \
  ios/WildFrogNative/LiveActivityWidget/Info.plist
```

Expected: full Swift Testing count passes, `BUILD SUCCEEDED`, diff check clean, and both plists OK.

- [ ] **Step 4: Update the existing handoff without widening delivery claims**

Record the files changed, RED/GREEN logs, alpha and visual evidence, test/build results, and the fact that `1.0.3 (11)` remains the already-submitted build. Run RainVault strict warnings and Wiki Doctor against the touched handoff.
