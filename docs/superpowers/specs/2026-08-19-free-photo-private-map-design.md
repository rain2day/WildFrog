# Free Photo Private Map Design

## Goal

Let people see where they created Free Photo memories on an Apple Maps-style private map. Camera captures record the contemporaneous iPhone GPS fix; Photos imports prefer the source photo's embedded location. The feature remains local-only and never becomes an official check-in, public activity, leaderboard input, stamp, achievement, or Firebase record.

## Approved Product Decisions

- Storage is local to this app installation. There is no Firebase, iCloud, or cross-device sync.
- The map lives in Explore as a mutually exclusive map layer: `Peaks` or `My Free Photos`.
- Free Photo markers use framed-photo thumbnails. Nearby markers cluster and display a count.
- Camera capture may finish without GPS. The record becomes `Needs Location` and can be placed manually later.
- Photos import prefers the photo's original GPS metadata. Without it, the user chooses current location or manual placement later; the app never silently substitutes the current location.
- Deleting a record offers `Delete Map Record` or `Delete Map Record and Framed Photo`.
- Deleting a framed output must never delete an imported source photo.
- The map starts with records created after this feature ships. Existing Build 12 exports are not scanned or guessed automatically.

## Isolation Contract

- Do not write or read `CheckInStore` for this feature.
- Do not call `FirestoreService`, create `checkIns`, update `leaderboardProfiles`, or change public-consent state.
- Do not update official counts, routes, streaks, stamps, certificates, achievements, or ranking.
- Do not reuse official check-in radius, checkpoint eligibility, or mountain validation.
- Free Photo copy continues to state that the output is not an official check-in.

## Local Data Model

Add a dedicated `FreePhotoStore` and `FreePhotoRecord` rather than extending official check-in storage.

Each record contains:

- stable UUID;
- created date and framed-output render date;
- trimmed place name;
- optional altitude and altitude source;
- selected Passport or Polaroid style;
- optional latitude and longitude;
- location source: camera GPS, source-photo metadata, current-location choice, manual placement, or missing;
- optional horizontal accuracy and location timestamp;
- Photos local identifier for the app-created framed output;
- app-owned thumbnail filename.

The store persists a versioned Codable envelope in Application Support and thumbnails in a dedicated app-owned subdirectory. It writes through a temporary file followed by replacement. A corrupt envelope fails soft to an empty visible collection while preserving the unreadable file for diagnosis; it must not affect official records.

The Photos local identifier always refers to the app-created framed output. A source photo selected through Photos is never retained as a deletion target.

## Location Capture

### Camera

- Free Photo starts its own scoped `LocationManager` acquisition when the flow opens.
- When the camera returns an image, snapshot the newest resolved location associated with that capture revision.
- Accept only a valid recent fix with non-negative horizontal accuracy. A stale or invalid fix produces a missing-location draft rather than borrowing a later callback.
- Location and photo results share the same capture revision so a late result from an older camera or Photos selection cannot change the current draft.

### Photos Import

- Inspect the selected photo data for GPS metadata and, where available under Photos authorization, resolve its `PHAsset` location.
- Prefer the source photo's location over the current device location.
- If metadata is unavailable, present two explicit choices: `Use Current Location` or `Add Location Later`.
- Current location is captured only after the user chooses it and is labelled accordingly.

### Manual Placement

- A separate unrestricted map picker edits only the private record coordinate.
- It has no official mountain radius, proximity, or checkpoint gate.
- Saving a manual point changes the source to manual and removes the record from `Needs Location`.

## Save Transaction

Saving uses one immutable request identity containing the capture revision, rendered date, frame style, text content, altitude source, and selected location candidate.

1. Validate the Free Photo draft and render the framed output.
2. Save the framed output through Photos and return its placeholder/local identifier.
3. Create and persist the app-owned thumbnail.
4. Append the local `FreePhotoRecord`.
5. Show `Saved to Photos and added to your private map` only after all required local work succeeds for that request.

If Photos succeeds but record persistence fails, retain the returned Photos identifier in the active save-recovery state and show `Photo saved, but it was not added to the map` with Retry. Retry must not create a second Photos asset. A later success or error cannot update a changed draft.

## Explore Map UX

- Add a compact layer control to the current Explore map: `Peaks` and `My Free Photos`.
- Never render both layers together.
- The Peaks layer preserves existing mountain markers and behaviour.
- The Free Photos layer uses a dedicated MapKit-backed view with custom thumbnail annotation views and clustering identifiers.
- A single marker displays the framed thumbnail. A cluster displays the representative/latest thumbnail plus its record count.
- Selecting a marker or cluster opens a bottom sheet containing the represented records, ordered newest first.
- The sheet shows framed photo, place name, date, altitude when present, and location-source label. It offers Open in Photos, Edit Location, and Delete.
- Map entry fits all located private records. A recenter control returns to the live device location.
- An empty map shows a `Start Free Photo` action.
- Unlocated records never receive invented coordinates. A persistent `X photos need a location` banner opens a newest-first repair list.

## Delete Behaviour

The record action sheet offers:

1. `Delete Map Record` — delete the local record and app-owned thumbnail only; preserve the Photos output.
2. `Delete Map Record and Framed Photo` — ask Photos to delete the asset referenced by the record, subject to the system confirmation, then remove the record and thumbnail only after Photos reports success.

If the Photos identifier is missing or the asset no longer exists, explain that the Photos item cannot be found and still allow a separately labelled record-only deletion. Never target or delete an imported source asset.

## Permissions And Privacy

- Continue requesting When In Use location access only while Free Photo or its current-location map action is active.
- Saving an output uses Photos add access. Deleting an output may require read/write Photos authorization and the system deletion confirmation.
- Location denial does not block Free Photo export.
- All map records and thumbnails remain in the app sandbox.
- Update in-app privacy wording and the next App Store review notes to disclose local private location history. Do not claim cross-device recovery.

## Error And Empty States

- Location denied/unavailable: save with `Needs Location` and offer manual placement.
- Source photo has no GPS: require an explicit current-location or later-placement choice.
- Thumbnail missing: display a branded placeholder without losing the record.
- Photos output deleted externally: keep the map record and thumbnail, label the Photos asset unavailable, and allow record deletion.
- Store write failure after Photos success: report the split result and offer idempotent retry.
- Corrupt local store: isolate the corrupt envelope, show no fabricated records, and keep official app surfaces working.

## Verification Contract

### Regression-First Unit Tests

- Codable versioning and corrupt-store fail-soft behaviour.
- Camera location freshness, accuracy, and capture-revision binding.
- Photos GPS precedence and explicit fallback choice.
- Missing-location records do not project map coordinates.
- Save transaction returns and reuses the exact Photos asset identifier on retry.
- Late save/photo/location success and error paths are request-gated.
- Thumbnail projection, newest-first cluster contents, and needs-location counts.
- Manual placement changes only the selected private record.
- Record-only deletion preserves Photos; combined deletion removes only the framed output after Photos success.
- Imported source identifiers are never deletion targets.
- Free Photo operations perform zero official-store and Firebase writes.

### Build And Runtime Proof

- Focused Free Photo private-map tests with observed RED before production code.
- Full `WildFrogNativeTests` with a non-zero executed count.
- Generic iOS Simulator build.
- Simulator QA route showing Peaks/Free Photos switching, thumbnail clusters, detail sheet, and Needs Location repair.
- Exact source build installed, version-read back, and launched on FyuRa.
- Physical acceptance of camera GPS, Photos metadata import, manual placement, and both delete choices remains a separate device proof.

## Migration And Delivery Boundary

- Schema version 1 starts empty on installations with no private-map store.
- Do not scan existing Photos or infer legacy Build 12 exports.
- The existing Build 12 App Store submission/public state is a separate release layer.
- Source, tests, build, FyuRa install/readback, physical acceptance, commit, push, archive/upload, App Store submission, and public release must be reported separately.
- Preserve the existing uncommitted Build 12 plist/project version changes while implementing this feature; do not bump another build, upload, submit, commit, push, or deploy unless separately authorized.
