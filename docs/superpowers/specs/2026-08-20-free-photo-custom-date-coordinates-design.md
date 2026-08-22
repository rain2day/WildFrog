# Free Photo Custom Date And Coordinates Design

## Goal

Let a person customise whether a date and coordinates appear on a Free Photo frame, while preserving sensible capture-derived defaults and keeping the printed metadata independent from the private map location.

## Product Boundary

- This feature changes only the Free Photo editor, preview, exported framed image, and exact local save request.
- Free Photo remains local-only and must not create official check-ins, stamps, achievements, certificates, routes, leaderboard entries, or Firebase writes.
- Editing the coordinates printed on the frame must never move or overwrite the private-map location. Map location continues to come only from captured/source GPS, an explicit current-location choice, or the existing manual map picker.
- No App Store version bump, upload, submission change, Firebase deployment, commit, or push is part of implementation without separate authorization.

## Approved Editor Experience

Add two metadata controls below the existing optional altitude field in `2 · Frame details`.

### Date

- Show a `Display date` toggle and compact date picker.
- Camera captures default to the date at which that accepted camera result was captured.
- Photos imports prefer the source photo's original creation date.
- The user can edit the date without changing the private-map record's actual creation or render timestamps.
- The printed format is `yyyy.MM.dd` using a stable Gregorian/POSIX formatter.
- Date display is enabled by default because every accepted photo has a valid camera, source-photo, or import-time fallback date.
- Turning date display off removes it from both preview and export without discarding the selected editable date.

### Coordinates

- Show a `Display coordinates` toggle plus separate latitude and longitude fields.
- Camera captures prefill from the accepted capture-bound iPhone location when available.
- Photos imports prefer the source photo's embedded/Photos-library coordinate when available.
- If no valid source coordinate exists, leave both fields empty and keep coordinate display off.
- The user can enter or edit decimal coordinates. Editing these fields affects frame presentation only.
- Accept latitude from `-90...90` and longitude from `-180...180`.
- When coordinate display is enabled, both values are required and must be valid. Invalid or incomplete values show a focused validation message and disable export.
- The printed format uses five fractional digits and cardinal directions: `22.40840° N · 114.12010° E`. Negative values render as positive magnitudes with `S` or `W`.
- Turning coordinate display off removes the coordinate line from preview and export while preserving the editable values.

## Metadata Acquisition

### Camera

- Bind the default frame date and coordinate suggestion to the same accepted camera capture revision as the image and private-map candidate.
- Use the camera result time as the default date.
- Reuse the capture-bound valid location candidate for the default printed coordinate, but copy its numeric value into separate display-only draft fields.
- Later location callbacks must not silently change display coordinates after the accepted capture is established.

### Photos Import

- Extend the existing metadata read path so one request returns both the preferred source location and preferred source creation date.
- Prefer `PHAsset.creationDate` when the selected Photos identifier resolves. Fall back to supported ImageIO metadata such as EXIF `DateTimeOriginal` when available.
- If no source date is available, use the time at which the selected import result is accepted.
- Continue preferring source-photo GPS over current device location.
- The existing photo-selection revision/cancellation gate must guard the image, date, display coordinate, and private-map location together so a late older selection cannot overwrite a newer choice.

## Draft And Save Identity

- Extend `FreePhotoDraft` with:
  - editable frame date;
  - date-display flag;
  - editable latitude and longitude text;
  - coordinate-display flag;
  - validation and formatted presentation helpers.
- Preserve the current place-name and altitude validation rules.
- Extend `FreePhotoExportFingerprint` with the exact date, both display flags, and the normalised displayed coordinate values.
- Any date, coordinate, or display-flag change immediately updates the preview and invalidates a prior save confirmation.
- An asynchronous save success or failure may update UI state only if its complete fingerprint still matches the active draft.
- Extend the immutable local save request with the same presentation fields so Photos-success/map-retry recovery cannot reconstruct a different frame.
- Private-map latitude/longitude remain sourced from the existing `FreePhotoLocationCandidate`, never from display-only draft fields.

## Frame Content And Layout

`FreePhotoFrameContent` exposes optional date and coordinate labels rather than assuming date is always present.

### Polaroid

- Keep the place-name region and Free Photo seal bounds unchanged.
- Show date and optional altitude on the first metadata row.
- Show coordinates on a dedicated second metadata row.
- When date or altitude is hidden/absent, remaining metadata closes naturally without placeholder separators.
- When coordinates are hidden, the second row is omitted and the caption spacing closes without leaving an empty line.

### Passport

- Keep the place-name region and Free Photo seal bounds unchanged.
- Keep the optional date in the existing top-trailing header position.
- Put optional altitude and coordinates in the lower metadata region, using a wrapping/stacked arrangement that remains inside the reserved leading text area and does not enter the seal bounds.
- When date or coordinates are hidden, their views are omitted rather than rendered as blank strings.

Preview and export continue to use the same frame content, render contracts, palette, stamp asset, layout constants, and deterministic canvas sizes.

## Validation And Failure Behaviour

- Date selection always remains valid through the system date picker.
- Coordinate validation is inactive while coordinate display is off.
- With coordinate display on, incomplete, non-numeric, non-finite, or out-of-range coordinates prevent export and show a precise error.
- Missing GPS never blocks Free Photo; coordinate display simply begins off and the private-map `Needs Location` behaviour remains unchanged.
- A metadata read failure falls back to an accepted import-time date, no display coordinate, and the existing explicit private-map location choice.
- Changing a photo resets capture-derived defaults to the newly accepted photo while continuing to reject late results from previous selections.

## Verification Contract

### Regression-First Unit Tests

- Camera metadata defaults the frame date to capture time and copies a valid capture-bound coordinate into display-only draft state.
- Photos metadata prefers the source creation date and source GPS; missing source date falls back to accepted import time.
- A late Photos result cannot overwrite a newer image, date, display coordinate, or private-map candidate.
- Date and coordinate switches preserve edited values while removing their labels from `FreePhotoFrameContent`.
- Coordinate formatting covers north, south, east, west, zero, and five fixed fractional digits.
- Coordinate validation covers incomplete, non-numeric, non-finite, boundary, and out-of-range values.
- Editing printed coordinates does not change the `FreePhotoLocationCandidate` used for the private map.
- Date, coordinate, and both display switches participate in save fingerprint equality and late-result rejection.
- Passport and Polaroid render deterministic fixtures with all metadata enabled and keep changed metadata pixels inside approved text bounds and outside the seal bounds.
- Existing Free Photo isolation tests continue proving zero official-store and Firebase writes.

### Build And Runtime Proof

- Capture an expected RED from focused tests before production changes.
- Run focused Free Photo draft, metadata, frame-content, save-identity, and private-map tests to GREEN.
- Run the full `WildFrogNativeTests` target with a non-zero executed count.
- Run a generic iOS Simulator build.
- Use the existing Free Photo QA route to inspect Passport and Polaroid with date/coordinates on and off, edited values, and maximum-length place/altitude combinations.

## Delivery Boundary

- Implementation and verification do not alter the currently submitted App Store version `1.0.5 (13)`.
- A later commit, push, build-number bump, physical-device install, archive, ASC upload, review-submission replacement, or public release requires explicit authorization and separate proof.
