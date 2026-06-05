# WildFrog App Draft

## Draft Goal

This first app draft turns the P0 brief into a clickable mobile-first prototype. It is a product design draft, not a production Expo or iOS native app.

The core loop is:

1. Pick a mountain.
2. Review personal record and mountain leaderboard.
3. Open GPS check-in.
4. Reach the valid checkpoint area.
5. Add photo proof by taking an on-site photo or uploading a photo.
6. Confirm valid check-in.
7. Return to mountain record.

## Screen Map

- `Home`: mountain list, search, region filter, mountain record cards.
- `Mountain Detail`: mountain hero, my record, check-in CTA, total leaderboard.
- `GPS Check-in`: checkpoint radius, distance, GPS accuracy, locked/unlocked photo proof, safety reminder.
- `Success`: stamp-style feedback, new count, rank movement, next-rank distance.
- `Explore`: map-style regional checkpoint draft.
- `Records`: private check-in history and summary metrics.
- `Profile`: total records, top mountain records, privacy toggle.
- `Language`: Traditional Chinese default UI with English toggle in the prototype shell.

## Visual System

- Tone: refined outdoor field log.
- Palette: daylight field-log neutrals, white/map-paper surfaces, moss green, trail orange, and smaller deep-green anchors.
- Typography: system-native Hong Kong/iOS-friendly stack with strong weights, compact labels, and Traditional Chinese as the default draft language.
- Components: mountain image cards, metric rows, leaderboard rows, GPS info panel, photo proof selector, stamped-photo preview, bottom nav.
- Border radius: compact `8px` panels and controls.
- Motion: subtle screen fade-in only.

## P0 Guardrails

The prototype intentionally excludes:

- Coupons.
- Merchant tools.
- Sponsor campaigns.
- Payment.
- Reward-shop mechanics.
- Friend leaderboard.
- Monthly leaderboard UI.
- Public social feed or chat.

## Check-in Proof Rule

Photo proof is part of the check-in flow, but location is still the gate:

- If the user is outside the valid radius, they cannot submit a leaderboard check-in.
- If the user is inside the valid radius, they can choose `Take photo` or `Upload photo`.
- Uploaded photos are supporting evidence only and must not bypass server-side GPS validation.
- Photo proof stays private by default.
- After validation, the app should generate an official stamped version of the image.
- The stamp treatment should include WildFrog/logo, mountain name, height, region/checkpoint label, user's check-in count for that mountain, and coarse date.
- The stamp treatment should not expose exact GPS coordinates.

## Assets

Generated with built-in image generation and copied into the workspace:

- `design/concepts/wildfrog-mobile-concept.png`: four-screen product concept board.
- `prototype/assets/tai-mo-shan.png`: Tai Mo Shan-inspired banner.
- `prototype/assets/lion-rock.png`: Lion Rock-inspired banner.
- `prototype/assets/lantau-peak.png`: Lantau Peak-inspired banner.

The mountain banners are design assets for the draft only. Production should replace them with verified, licensed real mountain photography or first-party generated assets approved for release.

## Next Product Decisions

- Confirm app name: `WildFrog`, `PeakStamp`, `山印`, or another direction.
- Confirm whether Profile belongs in P0 or P1.
- Replace placeholder checkpoint coordinates before production.
- Decide account deletion and check-in deletion behavior.
- Decide whether private leaderboard rows are hidden or anonymized.
