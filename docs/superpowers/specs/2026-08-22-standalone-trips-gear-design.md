# Standalone Trips, Gear Kits, and Fuel Design

## Goal

Let people plan and record an outing without completing an official mountain check-in. A trip can start immediately or be scheduled, carries a reusable activity type and gear kit, records a background GPS track, and summarizes packed gear, water, food, calorie intake, and optional Apple Health active-energy data. Official check-ins may be attached during a trip, but only those explicit check-ins affect stamps, summit history, achievements, or rankings.

## Product Decisions

- Support both `Start Now` and `Plan a Trip`.
- Ship built-in activity types for hiking, trail running, running, insect photography, landscape photography, and camping. People can create and rename custom activity types.
- Maintain a personal gear library. Reusable gear kits reference library items and can be assigned as defaults for one or more activity types.
- Starting a trip copies the selected kit into a trip-owned checklist. Later trip edits do not mutate the reusable kit.
- Gear entries support quantity, optional weight, and `Required` or `Optional` priority.
- Starting with unchecked required gear shows one warning, but never blocks the trip.
- Food and water use planned and consumed quantities. Food calories are entered manually; the app totals intake without requiring a food database.
- Apple Health active energy is optional. After explicit permission, a completed trip can compare manually recorded intake with overlapping active-energy data. Denial or unavailable data never blocks planning, recording, or completion.
- A trip may contain zero, one, or multiple official check-ins. The trip remains valid if an attached check-in is deleted.
- All trip planning, gear, fuel, and track data stays on-device for this release.

## Navigation and Information Architecture

Keep WildFrog's existing five-tab structure.

### Records tab

The Records root becomes the trip hub while preserving the existing calendar:

- a compact `Start Now` primary action;
- an upcoming-plan card with date, activity, and packing progress;
- an active-trip card when recording;
- recent completed trips;
- entry points to `All Trips`, `Gear`, and the existing calendar/history.

### Centre action

The existing centre action sheet adds `Record a Trip` alongside `Official Check-in` and `Free Photo`. `Record a Trip` opens a short setup sheet with activity, optional saved plan, and gear kit, then presents the packing checklist before recording begins.

### Trip screens

1. `Trip Editor` — name, date/time, activity, optional notes, gear kit, food, and water.
2. `Packing Check` — required items first, optional items second, packed progress, and a non-blocking missing-item warning.
3. `Active Trip` — map and live route, elapsed time, distance, ascent, pause/resume, add food/water, and an explicit official check-in action.
4. `Trip Summary` — route replay, statistics, attached check-ins, packed gear, consumed food/water, intake calories, and optional active-energy comparison.
5. `Gear Library` — items, kits, total kit weight, activity defaults, add/edit/archive actions.

## Domain Model

### ActivityType

- stable identifier;
- localized/custom name;
- symbol and colour token;
- built-in/custom flag;
- optional default gear-kit identifier.

Built-ins cannot be deleted, but their default kit can change. Custom types can be archived; existing trip snapshots remain readable.

### GearItem

- stable identifier;
- name;
- category;
- optional brand;
- optional unit weight in grams;
- archived flag.

Price and purchase date are deliberately excluded from this version: the goal is reliable trip preparation, not asset accounting.

### GearKit

- stable identifier and name;
- optional activity-type associations;
- ordered kit lines containing a gear-item identifier, default quantity, and required/optional priority.

The displayed total weight is the sum of known item weights times quantities. Missing weights are labelled rather than treated as zero in completeness messaging.

### Trip

- stable identifier;
- name and activity snapshot;
- scheduled date;
- lifecycle status: planned, active, paused, completed, or cancelled;
- created, started, and completed timestamps;
- optional notes;
- gear snapshots;
- consumable entries;
- optional recorded `Track`;
- attached official check-in identifiers;
- optional Apple Health active-energy value and last refresh timestamp.

A trip snapshots names, quantities, priorities, and weights so later library edits cannot rewrite history.

### TripGearEntry

- source gear-item identifier when still available;
- snapshotted name, category, brand, unit weight, and quantity;
- required/optional priority;
- packed flag.

### TripConsumableEntry

- stable identifier;
- kind: water, food, or other drink;
- name;
- unit: millilitres, litres, grams, servings, or items;
- planned quantity;
- consumed quantity;
- manually entered calories for the consumed amount.

Water contributes to hydration totals but defaults to zero calories. Calories remain editable for sports drinks and other beverages.

## Recording Architecture

Reuse `TrackRecorder` as the GPS sampling engine, but stop making a mountain identifier the ownership boundary.

- A new `TripSessionCoordinator` owns the single active trip and starts `TrackRecorder` with an optional mountain/checkpoint.
- `TrackRecorder` continues to own sensor sampling, distance, ascent, pause/resume, background updates, and Live Activity updates.
- The coordinator persists active-session checkpoints on meaningful changes and when the app backgrounds. It restores an interrupted active or paused session after relaunch instead of silently losing the route.
- Finishing returns the existing `Track`, writes it into the trip, and opens the summary. Cancelling offers `Discard Recording` or `Save as Incomplete Trip`.
- Only one trip may record at a time. Starting another routes to the current active trip.
- A planned trip becomes active only when its packing screen completes and recording starts.

The Live Activity uses the trip name when no mountain is selected. Summit distance and progress appear only when the active trip has an attached target mountain.

## Official Check-in Boundary

- The active-trip screen may launch the existing official check-in flow.
- A successful official check-in optionally receives the active trip identifier and the trip stores the check-in identifier.
- The official `CheckInStore` remains the only source for summit records, stamps, achievements, and leaderboard synchronization.
- A standalone trip, GPS point, gear item, food entry, or Health value never creates a Firebase check-in or leaderboard write.
- Deleting or editing a trip never deletes an official check-in without a separate explicit check-in deletion action.
- Deleting an official check-in only removes the link shown in the trip summary; it does not delete the trip or track.

## Local Persistence

Add a dedicated versioned `TripStore` under Application Support rather than extending the Free Photo store or treating `CheckInStore` as the trip database.

The store contains activity types, gear items, gear kits, trips, and at most one active-session checkpoint. Writes use a temporary file followed by atomic replacement. A corrupt envelope is preserved with a timestamp and fails soft to an empty trip surface without affecting official check-ins or Free Photo records.

Schema decoding supplies backward-compatible defaults for future optional fields. Archived items remain resolvable for historic snapshots. Seed built-in activity types only when no store exists; never reinsert a built-in the user has intentionally hidden.

## Apple Health and Privacy

- Add Health access only for reading active-energy data after a contextual explanation on the completed-trip summary.
- Do not request Health access at launch or when merely planning a trip.
- Query only the completed trip's start/end interval and store the resulting aggregate plus refresh timestamp.
- Label the result `Apple Health active energy` and avoid presenting intake-minus-energy as medical or weight-loss advice.
- Manual calorie intake is always available and remains the user's entered estimate.
- Location recording remains explicit, visible, pausable, and stoppable. The existing background-location indicator remains active while recording.
- Trip, gear, fuel, location, and Health aggregates remain local-only. No new Firestore collections or analytics payloads are added.

## Error and Recovery Behaviour

- Location denied: allow planning and checklist use; starting recording explains that a route cannot be captured and offers a timer-only trip.
- Poor GPS: keep recording time, discard inaccurate fixes using the existing threshold, and show `Finding accurate GPS` rather than failing.
- App termination: restore the last persisted active/paused session and explain any unrecorded gap.
- Missing required gear: warn once and allow `Review List` or `Start Anyway`.
- Deleted/archived library item: preserve trip and kit snapshots; offer replacement when editing a kit.
- Health denied/unavailable: hide the comparison row and provide a settings/help action without repeated permission prompts.
- Store write failure: keep the in-memory active session, show a persistent save warning, and retry idempotently.
- No GPS points: save a timer-only completed trip if the user confirms; never invent a route.

## Accessibility and User-Friendly Defaults

- Required state is conveyed by text and symbols, not colour alone.
- Checklist rows have at least 44-point tap targets and support VoiceOver state announcements.
- Default trip names combine activity and date but remain editable.
- The setup flow remembers the most recently used activity and kit without auto-starting location recording.
- Quantities use unit-aware controls; litres and millilitres normalize for totals.
- Destructive actions use explicit labels and preserve reusable kits unless the user separately deletes them.

## Verification Contract

### Model and Store Tests

- built-in/custom activity seeding and archive behaviour;
- gear-kit copying creates independent trip snapshots;
- required/optional packing projection and warning logic;
- known/unknown kit-weight totals;
- water-unit normalization and planned-versus-consumed totals;
- manual calorie totals;
- trip lifecycle transitions and one-active-trip invariant;
- versioned Codable round trips, corrupt-envelope preservation, and idempotent checkpoint recovery.

### Recording and Isolation Tests

- standalone start passes no mountain while preserving distance/ascent tracking;
- pause gaps do not add time or distance;
- active-session checkpoints restore after relaunch;
- timer-only completion contains no fabricated coordinates;
- attached check-ins link to a trip while standalone trips perform zero official-store, Firestore, stamp, achievement, and leaderboard writes;
- deleting either side preserves the other side according to the boundary contract.

### Health Tests

- authorization is contextual and optional;
- denied/unavailable Health data never blocks trip completion;
- the query interval matches the trip interval;
- intake and active-energy labels remain distinct;
- cached Health aggregates retain a refresh timestamp.

### UI and Runtime Proof

- focused tests observe RED before production implementation;
- full `WildFrogNativeTests` executes with a non-zero count;
- generic iOS Simulator build;
- simulator QA routes for trip hub, packing warning, active trip, gear library, and completed summary;
- background/foreground and relaunch recovery test;
- exact source build installed, version-read back, and launched on FyuRa;
- physical-device GPS route, pause/resume, missing-gear warning, trip completion, and Health permission/result acceptance remain separate proof layers.

## Delivery Boundary

- This feature belongs to the release after uploaded Build 15 and must not alter the immutable Build 15 archive.
- Do not upload or submit a feature build until its source, tests, archive, device install, and physical acceptance are separately proven.
- Commit, push, upload, ASC submission, Apple approval, and public release remain independently authorized and verified actions.
