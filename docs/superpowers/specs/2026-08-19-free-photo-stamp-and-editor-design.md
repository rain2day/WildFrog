# Free Photo Stamp And Editor Interaction Design

## Goal

Give every Free Photo export a clearly non-ranked WildFrog stamp while keeping altitude editing and bidirectional Passport/Polaroid switching reliable after a camera or Photos image is loaded.

## Product Boundary

- Free Photo remains a photo-only export flow.
- The new seal is a visual mark on the exported image, not a collectible mountain stamp.
- Free Photo must not write `CheckInStore`, Firestore check-ins, routes, certificates, achievements, stamp unlocks, or leaderboard scores.
- The existing official Ranked Check-In cards and their green/gold mountain seals remain unchanged.

## Free Photo Seal

### Visual Language

- Use a circular double-ring pressed-seal treatment derived from the existing mountain-stamp language.
- Put the WildFrog frog-and-mountains mark in the centre.
- Set `WILDFROG` on the upper ring and `FREE PHOTO` on the lower ring, matching the user-approved third image-generation candidate.
- Use only the approved Free Photo colour family:
  - mist blue `#568BA8` for the primary ink;
  - navy `#163044` for secondary ink and contrast;
  - pale mist/white only as translucent backing where the photo needs contrast.
- Generate the seal with OpenAI image generation as a square transparent-background PNG. Do not use SVG, SF Symbols, SwiftUI paths, Canvas drawing, or a runtime-generated vector substitute.
- Preserve the existing WildFrog frog-and-mountains brand mark as the centre subject while converting the complete mark into the Free Photo mist-blue/navy ink treatment.
- Bake the double rings, exact lettering, restrained distressed ink texture, and 92% visual ink density into the PNG. The app must not attempt to reconstruct or typeset the seal at runtime.
- Rotate the seal by `-8°` so it shares the official passport-entry gesture without sharing the official green/gold identity.
- The English seal identity remains unchanged and legible in both Traditional Chinese and English app environments.

### Placement

- Anchor the seal to the trailing edge of the photo/content boundary.
- Passport: match the official Ranked Check-In passport placement and visual weight with a 360-point seal in `CGRect(x: 694, y: 540, width: 360, height: 360)`. This is the top-trailing edge of the lower stub, padded 26 points from the canvas edge and offset 180 points upward over the photo.
- Polaroid: use a 280-point seal in `CGRect(x: 706, y: 876, width: 280, height: 280)`. It crosses the square-photo/caption boundary at `y = 1,016` while remaining inside the 1,080 by 1,400 canvas.
- Reserve the text region to the leading side of each seal wherever their vertical ranges overlap. Maximum-length place text may scale within its existing two-line limit, but cannot render under the seal.
- Preview and export must use the same seal view, layout constants, scale, rotation, and content.
- The seal is decorative and must not intercept taps or accessibility focus.

## Editor Interaction Contract

### Altitude

- A valid fresh iPhone GPS location may prefill the optional altitude once.
- After a user edits the altitude, the source becomes manual and later GPS updates cannot overwrite it.
- The user can clear the altitude completely; the preview and export then omit the altitude line.
- Accept whole metres from `-500` through `9,000`; preserve the existing validation messages outside that range or for non-integers.
- Any altitude change immediately refreshes the preview and invalidates an earlier save confirmation.
- Loading or replacing a photo must not disable or cover the altitude field.

### Frame Style

- Keep a visible segmented control labelled `拍立得 / Polaroid` and `護照 / Passport` above the preview.
- Permit repeated switching in both directions after a photo is loaded.
- Switching style preserves the current photo, place name, altitude value, and altitude source.
- The preview height updates to the selected renderer canvas ratio without creating an oversized interactive layer.
- The saved output always uses the style currently selected when the save request begins.
- A style change invalidates an earlier save confirmation and prevents a late save result from being applied to the changed preview.

## Implementation Boundaries

- Use the user-approved third image-generation candidate as the source, remove only its baked checkerboard into real alpha, store the resulting raster PNG in a dedicated `FreePhotoStampSeal.imageset`, and do not convert it to SVG.
- Add one reusable `FreePhotoStampSeal` SwiftUI component in the Free Photo frame module. It displays only the approved bitmap asset and owns sizing, rotation, opacity, accessibility exclusion, and fallback visibility.
- Add seal placement values to the per-style `FreePhotoFrameRenderContract` so preview, renderer, and tests share one source of truth.
- Keep `FreePhotoFrameContent` free of official mountain, rank, verification, or unlocked-stamp metadata. The decorative Free Photo seal is selected by the renderer, not by an official `stampAssetName`.
- Preserve the existing `FreePhotoDraft` and `FreePhotoExportFingerprint` authority for altitude and save identity.
- Constrain the preview to the selected contract's displayed bounds and disable hit testing on rendered card content. Only the segmented control, altitude field, capture controls, and save button remain interactive.
- Diagnose the current loaded-photo interaction failure before choosing any additional state refactor. Apply only the smallest production change supported by the reproduction.

## Failure Behaviour

- Invalid altitude keeps export disabled and shows the existing validation message; frame switching remains available.
- If a photo load finishes late after a newer camera/Photos choice, the existing request-revision guard continues to reject it.
- If saving finishes after the altitude, style, date, name, or photo changes, the result must not mark the changed preview as saved or show a stale error.
- If the bitmap asset cannot load, export must not crash; the renderer omits the decorative seal rather than substituting an official mountain stamp.

## Verification Contract

### Regression-First Tests

- Prove both frame contracts expose a non-official Free Photo seal placement inside their canvas bounds.
- Validate that `FreePhotoStampSeal.imageset` contains a PNG with a real alpha channel and no SVG/vector payload.
- Prove the Free Photo seal palette is disjoint from the official green/gold Ranked Check-In seal palette.
- Prove maximum-length place name, date, and altitude remain readable and are not covered by the seal in either renderer.
- Prove a loaded-photo editor can change GPS altitude to manual, clear it, and receive further manual input without GPS overwrite.
- Prove `Passport -> Polaroid -> Passport` preserves photo identity and all frame details while changing the preview aspect ratio each time.
- Prove preview card content cannot intercept control hit testing.
- Preserve the existing save-fingerprint tests for style, altitude value, altitude source, photo revision, and exact render date.

### Visual And Runtime Proof

- Render deterministic Passport and Polaroid fixtures and inspect both exported images for placement, contrast, clipping, and metadata overlap.
- Launch the Free Photo QA route on Simulator, load the fixture image, edit and clear altitude, switch styles in both directions, and capture the resulting previews.
- Run the focused Free Photo tests, the full `WildFrogNativeTests` target, and a generic iOS Simulator build.

## Delivery Boundary

- App Store version `1.0.3 (11)` is already waiting for Apple review and cannot contain this later change.
- Source implementation, a new build/archive, device installation, upload, replacing or withdrawing the active App Store submission, and public release are separate gates.
- Do not cancel the current submission, increment a build, upload, commit, push, or deploy without separate authorization.
