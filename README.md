# WildFrog Demo

WildFrog is a mobile-first mountain check-in demo focused on hiking records, GPS-gated check-ins, photo proof, and per-mountain leaderboards.

Open the demo from GitHub Pages or run it locally by serving the `prototype/` folder.

## Demo Scope

- Mountain list and detail screens.
- GPS check-in state.
- Location-gated `Take photo` / `Upload photo` proof.
- Branded stamped-photo preview with mountain name, height, region, and check-in count.
- Total leaderboard and personal rank.
- Traditional Chinese default UI with an English toggle.

This is a static web prototype. No iOS native project, backend, real GPS, camera picker, upload service, Supabase project, or server-side stamping is connected yet.

## Local Preview

```bash
python3 -m http.server 4173 --directory prototype
```

Then open `http://localhost:4173/`.
