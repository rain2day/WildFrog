# WildFrog P0 Build Brief

## Product Intent

Build a non-commercial mountain check-in app for hiking records and mountain-specific leaderboards.

Core principle:

> Do not build coupon, merchant, sponsor, shopping, payment, reward-shop, or campaign features. Build only mountain check-in, per-mountain records, and per-mountain leaderboards.

The first version should feel like a hiking achievement log:

- Record that a user reached a mountain checkpoint.
- Count valid check-ins per mountain.
- Show each mountain's independent leaderboard.
- Show the user's own record and rank for that mountain.

Working name: `WildFrog`

Optional product name direction: `PeakStamp` / `山印`.

## P0 Scope

P0 must ship a small, working loop:

1. User signs in.
2. User sees a list of mountains.
3. User opens a mountain detail page.
4. User requests a GPS check-in.
5. Server validates that the user is inside the mountain check-in area.
6. If the user is inside the valid area, the app unlocks photo proof.
7. User takes an on-site photo or uploads a photo.
8. Server creates the check-in attempt.
9. A valid check-in increases that user's count for that mountain.
10. User sees the mountain's total leaderboard and their own rank.

## P0 Must Have

- Authenticated user account.
- Mountain list.
- Mountain detail page.
- GPS permission and current location request.
- Server-side distance validation for check-ins.
- Photo proof after location validation:
  - take an on-site photo,
  - or upload a photo.
- One valid leaderboard check-in per user per mountain per HKT day.
- Storage of valid and invalid check-in attempts.
- Total leaderboard per mountain.
- User's own rank and count, even when outside the visible top 10.
- Basic safety and privacy copy.

## P0 Explicitly Deferred

Do not build these in P0:

- Friend system.
- Friend leaderboard.
- Monthly leaderboard UI.
- Public social feed.
- Public chat.
- Merchant dashboard.
- Coupons or commercial rewards.
- Sponsor campaigns.
- Payment or e-commerce.
- Full hiking route navigation.
- AR, NFT, gamified prize mechanics, or reward shop.
- Complex moderation console.
- Weather API integration.

These may be added later only if they still support the mountain-record product loop.

## Recommended Stack

Use one simple, coherent stack:

- Mobile app: Expo, React Native, TypeScript.
- Backend/database: Supabase Auth, PostgreSQL, PostGIS.
- Data access: Supabase client or a small API layer.
- Storage: Supabase Storage only if cover images are needed.

Avoid adding a separate NestJS or custom JWT backend in P0 unless the repo later proves it needs that complexity.

## Main Screens

### 1. Mountain List

Purpose: help the user choose a mountain and see their current record.

Show:

- Search.
- Region filter.
- Mountain cards.

Each mountain card shows:

- Chinese and English mountain name.
- Region.
- Height.
- User's valid check-in count.
- User's current total rank.
- Total app-wide valid check-ins for that mountain.

### 2. Mountain Detail

Purpose: the core screen.

Show:

- Mountain name.
- Region and height.
- Static safety reminder.
- User record:
  - total valid check-ins,
  - last valid check-in summary,
  - current rank,
  - distance to next rank.
- `Check In` action.
- Total leaderboard.

Leaderboard behavior:

- Show top 10.
- Always show the user's own rank row if they are not in top 10.
- Rank by valid check-ins for this mountain only.

### 3. Check-in Flow

States:

- GPS permission needed.
- GPS loading.
- Location valid.
- Location too far.
- GPS accuracy too poor.
- Already checked in today.
- Photo proof needed.
- On-site photo selected.
- Uploaded photo selected.
- Suspicious or invalid attempt stored but not counted.

Photo proof behavior:

- The photo controls are locked until server-side location validation says the user is inside the valid radius.
- On-site camera and upload are both allowed after the user has reached the valid area.
- Upload cannot bypass GPS validation.
- Photo proof is not public by default.
- The app should turn the proof image into a branded mountain stamp image, not just store a plain photo.
- The branded image should include WildFrog/logo, mountain name, height, region/checkpoint label, valid check-in count for that mountain, and coarse date.
- Do not print exact GPS coordinates onto the public/shareable image.

Success screen shows:

- Mountain name.
- Check-in successful message.
- New total valid check-in count.
- Previous rank and new rank when changed.
- Distance to next rank.

### 4. Profile

P0 can keep this simple.

Show:

- Total valid check-ins.
- Unique mountains visited.
- Top 5 mountain records.
- Recent valid check-ins.

If this delays the first check-in loop, defer profile to P1.

## Data Model

Use relational tables and keep leaderboard math server-side.

### `profiles`

Extends auth users.

- `id` UUID primary key, references auth user id.
- `display_name` text not null.
- `avatar_url` text nullable.
- `is_private` boolean default false.
- `created_at` timestamptz not null.
- `updated_at` timestamptz not null.

### `mountains`

- `id` text primary key.
- `name_en` text not null.
- `name_zh` text not null.
- `region` text not null.
- `height_meters` integer not null.
- `checkpoint` geography(Point, 4326) not null.
- `checkin_radius_meters` integer not null.
- `difficulty_level` text nullable.
- `cover_image_url` text nullable.
- `is_active` boolean default true.
- `created_at` timestamptz not null.
- `updated_at` timestamptz not null.

### `mountain_checkins`

Stores every check-in attempt.

- `id` UUID primary key.
- `user_id` UUID not null.
- `mountain_id` text not null.
- `location` geography(Point, 4326) nullable.
- `gps_accuracy_meters` numeric not null.
- `distance_from_checkpoint_meters` numeric nullable.
- `is_valid_for_leaderboard` boolean not null.
- `invalid_reason` text nullable.
- `risk_score` integer default 0.
- `created_at` timestamptz not null.
- `created_date_hkt` date not null.
- `device_id` text nullable.
- `client_platform` text nullable.
- `photo_url` text nullable.
- `photo_source` text nullable, either `camera` or `upload`.
- `photo_captured_at` timestamptz nullable.
- `photo_uploaded_at` timestamptz nullable.
- `stamped_photo_url` text nullable.
- `stamp_payload` jsonb nullable, stores the server-rendered watermark text such as mountain name, height, region, check-in count, and coarse date.

Important:

- Never trust client-side distance validation.
- Server calculates distance from `mountains.checkpoint`.
- Server requires valid current location before accepting photo proof for leaderboard counting.
- Uploaded photos are supporting evidence only; they cannot make an out-of-area check-in valid.
- Server should generate the stamped photo output after validation, so clients cannot fake the official WildFrog stamp.
- Invalid attempts are stored but do not affect leaderboard counts.

### `mountain_user_stats`

Aggregated total stats per user per mountain.

- `id` UUID primary key.
- `user_id` UUID not null.
- `mountain_id` text not null.
- `total_valid_checkins` integer not null default 0.
- `first_valid_checkin_at` timestamptz nullable.
- `last_valid_checkin_at` timestamptz nullable.
- `updated_at` timestamptz not null.

Unique constraint:

- `(user_id, mountain_id)`.

Do not store `monthly_valid_checkins` in this table for P0. Monthly stats should be calculated from `mountain_checkins` or added later as a separate period table.

### `anti_cheat_flags`

P0 stores simple flags only.

- `id` UUID primary key.
- `user_id` UUID not null.
- `mountain_id` text not null.
- `checkin_id` UUID not null.
- `flag_type` text not null.
- `description` text nullable.
- `severity` text not null.
- `created_at` timestamptz not null.
- `resolved_at` timestamptz nullable.

## Check-in Validation Rules

A check-in counts for leaderboard only when all conditions pass:

1. User is authenticated.
2. Mountain exists and is active.
3. Server-calculated distance is inside `checkin_radius_meters`.
4. GPS accuracy is acceptable.
5. User has no valid leaderboard check-in for the same mountain on the same HKT date.
6. User has attached photo proof after reaching the valid area.
7. Attempt is not flagged as suspicious enough to block counting.

Recommended P0 thresholds:

- `gps_accuracy_meters <= 50`.
- Check-in radius from mountain row, usually `120-200m`.
- HKT date boundary for daily limit.

Invalid reasons:

- `TOO_FAR_FROM_CHECKPOINT`.
- `GPS_ACCURACY_TOO_POOR`.
- `ALREADY_CHECKED_IN_TODAY`.
- `PHOTO_PROOF_REQUIRED`.
- `MOUNTAIN_INACTIVE`.
- `SUSPICIOUS_LOCATION`.

## Leaderboard Rules

Total leaderboard per mountain:

```sql
ORDER BY
  total_valid_checkins DESC,
  last_valid_checkin_at ASC,
  first_valid_checkin_at ASC
```

Tie breakers:

1. Higher valid check-in count wins.
2. If tied, earlier latest valid check-in wins.
3. If still tied, earlier first valid check-in wins.

P0 can calculate rank on demand with SQL window functions. Avoid snapshot tables until performance requires caching.

## API Shape

Use Supabase RPC/functions or a small server API. The behavior matters more than the exact transport.

### `GET /mountains`

Returns active mountains with current user's count and rank summary.

### `GET /mountains/:id`

Returns mountain detail, current user's stats, and total leaderboard preview.

### `POST /mountains/:id/checkins`

Request:

```json
{
  "latitude": 22.411,
  "longitude": 114.123,
  "gpsAccuracyMeters": 20,
  "deviceId": "abc123",
  "clientTimestamp": "2026-06-05T10:30:00+08:00"
}
```

Success response:

```json
{
  "success": true,
  "isValidForLeaderboard": true,
  "mountainId": "tai-mo-shan",
  "newTotalValidCheckins": 13,
  "previousRank": 18,
  "newRank": 17,
  "distanceToNextRank": 1
}
```

Invalid response:

```json
{
  "success": false,
  "isValidForLeaderboard": false,
  "reason": "TOO_FAR_FROM_CHECKPOINT",
  "distanceFromCheckpointMeters": 482,
  "requiredRadiusMeters": 150
}
```

### `GET /mountains/:id/leaderboard?type=total`

Returns top rows plus current user's own row.

P0 only supports `type=total`.

## Seed Data

Use placeholder coordinates only for local testing. Replace with verified checkpoint coordinates before production.

Initial mountains:

- `tai-mo-shan`: 大帽山 / Tai Mo Shan, New Territories, 957m.
- `lion-rock`: 獅子山 / Lion Rock, Kowloon, 495m.
- `lantau-peak`: 鳳凰山 / Lantau Peak, Lantau Island, 934m.

Each seed row must include:

- `id`.
- `name_zh`.
- `name_en`.
- `region`.
- `height_meters`.
- `checkpoint`.
- `checkin_radius_meters`.
- `is_active`.

## Privacy Requirements

P0 must avoid exposing sensitive location data:

- Public leaderboard shows display name and count only.
- Exact historical coordinates are never public.
- Check-in photos are private by default and should not appear publicly without explicit sharing.
- Shareable stamped photos can show the official mountain stamp, but must avoid exact coordinates and overly precise timestamps.
- Public check-in recency should be coarse, such as today, yesterday, or this week.
- No real-time location sharing.
- Private profiles should be hidden or anonymized in public leaderboard views.

Deletion policy to decide before production:

- Whether deleting check-in history removes leaderboard stats.
- Whether coordinates are hard-deleted or anonymized.
- Whether anti-cheat records are retained after user deletion.

## Safety Requirements

The app must not reward unsafe hiking.

Do not add achievements or streaks for:

- Typhoon hiking.
- Thunderstorm hiking.
- Night hiking.
- Restricted areas.
- Dangerous weather.

P0 should include a static safety reminder on check-in-related screens:

- Check weather before hiking.
- Bring enough water.
- Respect restricted areas and private land.
- Do not check in while moving through unsafe terrain.

## P0 Build Order

1. Scaffold Expo TypeScript app and Supabase config.
2. Create database schema and seed mountains.
3. Build auth session handling.
4. Build mountain list.
5. Build mountain detail.
6. Implement GPS permission and current location request.
7. Implement server-side check-in validation.
8. Unlock camera/upload photo proof only when current location is valid.
9. Store check-in attempts with photo proof metadata.
10. Update total stats after valid check-in.
11. Build total leaderboard and current user rank.
12. Add basic empty, loading, and error states.
13. Add minimal safety and privacy copy.

## Acceptance Criteria

P0 is done when:

- A signed-in user can open a mountain detail screen.
- The app can request GPS permission and read current location.
- Photo proof controls are locked until the user is inside the valid checkpoint area.
- A user inside the valid area can take an on-site photo or upload a photo before submitting.
- A valid nearby check-in is stored and counted.
- An invalid far-away check-in is stored but not counted.
- A second valid check-in on the same mountain in the same HKT day is rejected for leaderboard counting.
- The mountain leaderboard updates from server-side data.
- The user can see their own rank and count.
- Public leaderboard does not expose exact coordinates or exact private timestamps.
- No coupon, merchant, sponsor, shopping, payment, or reward-shop feature exists.

## Open Decisions Before Production

- Verified mountain checkpoint coordinates.
- Exact GPS accuracy threshold.
- Exact check-in radius per mountain.
- Account deletion and check-in deletion policy.
- Whether private users appear as anonymous rows or are removed from public leaderboards.
- Whether monthly leaderboard belongs in P1 or P2.
- Whether the product name is `WildFrog`, `PeakStamp`, `山印`, or another name.
