# WildFrog App Draft Prototype

This folder contains a static, mobile-first prototype for the WildFrog P0 app draft.

Open `index.html` in a browser to review the first app direction. No backend, auth provider, GPS service, or Supabase project is connected yet.

## Screens In This Draft

- Home mountain list with search and region filter.
- Mountain detail with per-mountain record and total leaderboard.
- GPS check-in state with distance, radius, accuracy, location-gated photo proof, stamped-photo preview, and safety copy.
- Check-in success state.
- Explore map draft.
- Records/history draft.
- Profile and privacy draft.

## Prototype Boundaries

- Sample data only.
- Generated mountain imagery only.
- Server-side check-in validation is represented in UI, not implemented here.
- Take-photo and upload-photo choices are UI-only, and are shown only after the prototype's valid location state.
- The stamped-photo preview demonstrates the intended official overlay: logo, mountain name, height, region/checkpoint label, check-in count, and coarse date.
- Friend leaderboard, monthly leaderboard UI, coupons, merchant tools, payment, and reward-shop mechanics are intentionally absent.

## Design Assets

- `design/concepts/wildfrog-mobile-concept.png`: generated UI concept board.
- `prototype/assets/tai-mo-shan.png`: generated mountain banner.
- `prototype/assets/lion-rock.png`: generated mountain banner.
- `prototype/assets/lantau-peak.png`: generated mountain banner.
