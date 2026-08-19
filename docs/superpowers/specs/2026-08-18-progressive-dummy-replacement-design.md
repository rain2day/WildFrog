# Progressive Dummy Replacement Leaderboard Design

## Goal

Restore the existing production dummy leaderboard as a transition layer while real opted-in users gradually replace it one-for-one. A real public user must always appear in the displayed leaderboard, regardless of score.

## Product Contract

- The current production baseline contains 46 visible legacy dummy profiles.
- With zero real public profiles, display all 46 dummy profiles.
- For every real public profile, retain one fewer dummy profile.
- The displayed projection is `all real profiles + max(0, dummy baseline count - real profile count) dummy profiles`.
- When a real profile becomes private or is deleted, restore one dummy profile when available.
- When real public profiles reach or exceed the dummy baseline count, display every real profile and no dummy profiles.
- Rank the final displayed projection together using the existing score, competition-rank, and deterministic tie-order rules.
- Dummy profiles removed first are the lowest-ranked dummy profiles for the selected leaderboard scope. This keeps the strongest transition content while guaranteeing every real profile a slot.

## Data Classification

- A real profile uses the authoritative schema: non-empty `publicAlias`, `totalCheckIns`, `distinctPeaks`, and `monthlyCheckIns`.
- A legacy dummy profile has no `publicAlias` and uses one of the legacy public-name fields (`displayName`, `name`, or `nickname`) plus legacy score fields.
- Documents that match neither schema remain excluded.
- Both profile classes remain read-only public leaderboard data. Client writes to `leaderboardProfiles` stay forbidden.

## Privacy And Detail Boundary

- Real profiles show only backend-derived public aggregates.
- Legacy dummy profiles show only their stored aggregate scores and existing public display metadata.
- Neither server class may generate private-looking mountain visits, exact visit dates, repeat counts, or achievements.
- Existing local-only demo detail generators remain unavailable for server-derived profiles.

## Projection Boundary

- Decode and classify every visible server profile first.
- Apply progressive replacement in one pure projection function before producing leaderboard entries.
- The projection accepts a leaderboard scope so the lowest-ranked dummy profiles for that scope are removed deterministically.
- The UI receives one projected array and keeps its existing main/full-ranking freshness, retry, publication, and exact-own-rank gates.
- A real user's exact displayed rank is computed from the same combined real-plus-retained-dummy projection shown on screen.

## Failure Behaviour

- A failed or in-flight authoritative refresh retains the last projected rows with the existing stale/refreshing disclosure.
- Malformed legacy documents are ignored rather than guessed.
- The dummy baseline derives from the currently decoded legacy dummy set; no new production dummy documents are created.

## Test Contract

- Legacy decoder accepts the current dummy schema but rejects malformed or private rows.
- Authoritative decoder continues to require a valid public alias for real profiles.
- `0 real + 46 dummy` produces 46 dummy rows.
- `1 real + 46 dummy` produces 1 real and the top 45 dummy rows.
- `20 real + 46 dummy` produces 20 real and the top 26 dummy rows.
- `46 real + 46 dummy` produces 46 real and zero dummy rows.
- More than 46 real profiles keeps every real profile and zero dummy rows.
- Removing a real profile restores the next eligible dummy profile.
- A low-scoring real profile remains displayed.
- Both main and full ranking use the same projection and rank values.
- Server-derived dummy detail remains aggregates-only.

## Rollout

- This is an iOS read/projection change; no production dummy-data rebuild or Firestore Rules change is required.
- After full automated verification, increment the iOS build number, install and read back on FyuRa, then upload the replacement build to the existing `1.0.3` App Store Connect train.
- Upload success, TestFlight availability, and App Store release remain separate proof layers.
