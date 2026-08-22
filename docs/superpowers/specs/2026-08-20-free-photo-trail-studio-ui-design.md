# Free Photo Trail Studio UI Design

Date: 2026-08-20  
Status: Approved visual direction; awaiting written-spec review  
Scope: Free Photo editor and exported Passport/Polaroid frame layout

## Goal

Make the Free Photo flow feel organised and calm after a photo is selected. The framed photo remains the visual focus, while place name, altitude, date, and display coordinates stay editable without appearing as one long settings form. Exported frames must keep all copy visibly away from the canvas edge.

## Product Boundaries

- Preserve the existing Free Photo data and privacy contract.
- Printed coordinate edits change only the exported frame and never move the private-map pin.
- Preserve camera capture metadata, imported Photos metadata, validation, save recovery, Passport/Polaroid switching, and Back navigation.
- Do not change official check-ins, stamps, achievements, leaderboard scores, Firebase data, or App Store metadata.
- Do not add new frame styles, filters, typography choices, or movable elements in this pass.

## Design Direction

Use the approved **Trail Studio A v2** direction: a live framed-photo canvas, a compact frame-style control, one structured metadata summary card, and a persistent primary save action.

The visual hierarchy is fixed:

1. User photo and place name.
2. Date, altitude, and display coordinates.
3. Free Photo branding and seal.

## Editor Layout

### Before photo selection

Keep the current camera and Photos entry choices, privacy boundary, permission handling, and Back navigation. Apply the new page spacing and card styling, but do not show an empty frame editor.

### After photo selection

The editor is ordered as follows:

1. Compact navigation header with Back, title, and a `Replace Photo` menu that reuses the existing camera and Photos choices.
2. Live framed-photo preview.
3. Passport/Polaroid segmented control.
4. Metadata summary card.
5. Sticky save button above the bottom safe area.

Remove the large numbered section headings from the post-selection editor. Do not display latitude, longitude, date picker, explanatory copy, and all toggles simultaneously on the main canvas.

### Metadata summary card

The card contains:

- The editable place name as the primary field.
- Three compact summary items: date, altitude, and coordinates.
- An `Edit` action that opens the metadata editor sheet.

Date and coordinate summary items communicate both value and visibility. Altitude keeps its existing value/source behaviour. Examples:

- `20 AUG · Shown`
- `438 m · GPS approx.`
- `Coordinates · Hidden`

If a value is missing, show `Not set`; do not manufacture a value.

### Metadata editor sheet

Use a native bottom sheet with a visible drag indicator, a concise title, and Done. The sheet edits live state, so it does not present a misleading Cancel action.

The sheet contains three grouped rows:

- Altitude: editable value and GPS-approximate source badge when applicable. As today, a valid value is displayed and clearing the field removes it from the frame.
- Date: date picker and display toggle.
- Coordinates: latitude/longitude fields and display toggle.

The private-map explanation appears once below the coordinate group: printed coordinate edits never move the private-map pin. Validation errors are shown inline beside the relevant group and also prevent export as they do today.

The sheet does not save a separate draft. Done closes the sheet; existing `FreePhotoDraft` state remains the single source of truth, so the live preview updates while editing.

### Save action

The primary save button remains visible above the bottom safe area while editing. It retains the current disabled, saving, completed, failed, and private-map recovery states. The button must not obscure scrollable content; the scroll view receives matching bottom content inset.

## Spacing and Component Rules

Use one spacing system throughout the screen:

| Context | Spacing |
|---|---:|
| Page horizontal inset | 20 pt |
| Major section gap | 24 pt |
| Card internal padding | 16 pt |
| Related element gap | 12 pt |
| Tight label/value gap | 6 pt |
| Minimum control height | 48 pt |
| Card corner radius | 18-20 pt |
| Preview corner radius | 22-24 pt |

Text must not visually touch card boundaries. Labels and values use leading alignment, and no control should rely on the screen edge as its visual padding.

## Exported Frame Layout

### Shared rules

- Reserve at least 8% of canvas width as the outer safe margin for all text and the seal.
- The place name is the only large text block and supports up to two lines.
- Metadata is a maximum of two visual lines.
- Date and altitude share the first metadata line when both are visible.
- Coordinates use the second metadata line.
- Hidden or missing metadata collapses cleanly without leaving placeholder gaps.
- The seal is reduced and inset so it does not crowd the place name or metadata.
- Free Photo branding is tertiary and must not compete with the place name.

### Polaroid

- Preserve the square photo and lower paper area.
- Increase the lower copy area's internal left/right padding.
- Place the name above metadata with a clear minimum gap.
- Keep the seal on the lower-right side, fully inside the safe region, without covering metadata.

### Passport

- Preserve the wide photo and structured lower band.
- Move the place name and metadata inward from the left and bottom edges.
- Reduce the seal and keep it fully inside the right safe region.
- Remove redundant brand/badge copy where it creates a second competing header; one small Free Photo identifier is sufficient.

## Typography and Colour

- Continue using the existing Free Photo mist, pale mist, navy, blue, and white palette.
- Do not introduce a new font family.
- Place name: heavy weight, high contrast.
- Metadata: medium/bold weight, blue, visually secondary.
- Helper and privacy copy: smaller navy at reduced opacity, used only where necessary.
- Avoid all-caps labels except the small existing Free Photo identity mark.

## State and Error Behaviour

- Selecting a new camera or Photos image resets stale save confirmation exactly as today.
- Live preview follows the existing request/fingerprint identity rules.
- Invalid metadata is surfaced in the editor sheet and keeps Save disabled.
- A save failure remains visible on the main screen near the save action.
- Closing the metadata sheet never discards current edits.
- Back remains available and functional after photo upload.

## Accessibility

- Support Dynamic Type without clipping labels or values.
- Every tappable control keeps at least a 44 pt hit target.
- Visibility controls expose explicit accessibility labels such as `Show date on frame`.
- Summary rows announce value plus shown/hidden state.
- Do not encode visible/hidden or error state by colour alone.
- Preserve VoiceOver order: preview, style, place name, metadata summary, Save.

## Verification

Add or update deterministic coverage for:

- Post-selection editor uses the compact summary architecture rather than permanently expanded metadata fields.
- Metadata sheet edits update the same `FreePhotoDraft` and live frame content.
- Save state and Back navigation remain functional after the layout refactor.
- Passport and Polaroid text and seal stay within the new safe-area contracts.
- Maximum-length place names and every metadata visibility combination remain contained.
- Hidden metadata collapses without unexpected gaps.
- Dynamic Type and narrow-device layout do not clip primary controls.

Run the full iOS test target, a generic Simulator build, and Simulator visual acceptance for both frame styles, the metadata sheet, hidden metadata states, Back, and sticky Save behaviour.

## Acceptance Criteria

- After selecting a photo, the initial editor composition prioritises the framed preview, style control, metadata summary, and sticky save action without presenting the full coordinate form. It remains scrollable for Dynamic Type and short screens.
- The main editor no longer uses large numbered section headings.
- Detailed altitude/date/coordinate controls live in one metadata sheet.
- Main-screen spacing follows the defined token table.
- All exported text and the seal remain inside the 8% safe region in both styles.
- No existing Free Photo data, private-map, save, or navigation behaviour regresses.
