# WildFrog UI System And Function Map

Last reviewed: 2026-06-07

## Design Direction

WildFrog should use one visual language: **Warm Topographic Passport**.

The app is a Hong Kong mountain check-in and peak passport app. It should feel like a useful hiking logbook with map, photo, stamp, and route context, not a dark adventure dashboard and not a collection of unrelated concept screens.

## Core Visual Rules

- Use warm paper backgrounds as the default page surface.
- Use subtle topographic/passport texture through color, cards, stamps, and map/photo content, not decorative blobs.
- Use deep forest green for text, icons, borders, and small badges.
- Avoid deep green as a full-page background except for tiny overlays on photos or highly focused proof states.
- Use trail orange only for primary actions: start check-in, complete check-in, view route.
- Use mountain photos where they explain real content: mountain cards, selected records, check-in preview, and detail hero.
- Keep cards at 14-20px radius; avoid nested-card stacks.
- Keep copy short and Traditional Chinese by default.

## Palette

- Paper: warm off-white for most screens.
- Passport: pale cream for Records/Profile surfaces.
- Forest: primary text and icon color.
- Moss/Leaf: positive completion and secondary accents.
- Orange: primary CTA only.
- Line: light separators and card borders.

## Typography

- Use rounded heavy display only for page titles and important mountain names.
- Use compact semibold text for metadata.
- Avoid tiny all-caps English labels unless they are decorative brand microcopy.
- Primary user-facing text should be Traditional Chinese.

## Navigation Model

Tabs:

- 探索: map-first discovery and mountain list.
- 紀錄: personal peak passport, calendar, stamps, and check-in history.
- 打卡: proof/check-in flow for one mountain.
- 排行: ranks, friends, and hot peaks.
- 我的: account, profile, passport summary, and achievements.

The center 打卡 button may be visually prominent, but it should not imply GPS/camera capabilities that are not wired.

## Functional Map

### 探索

Current real/mostly real content:

- Mountain catalog.
- Region filters.
- Search.
- Mountain map markers.
- Mountain rows and detail navigation.
- Completion counts from local mock/catalog check-in values.

Allowed UI:

- Map.
- 329 peaks / completed count.
- Next mountain recommendation.
- Mountain quick list.
- CTA: 查看路線 or 查看山峰.

Avoid for now:

- Fake route planning details.
- Excessive dashboard metrics.
- Large dark-green background.

### 紀錄

Current real/mostly real content:

- Local/mock checked mountain records.
- Calendar day selection.
- Selected mountain detail navigation.
- Stamp sheet asset.

Allowed UI:

- Peak Passport title.
- Month calendar with photo/stamp days.
- Selected date record.
- Stamp progress.

Avoid for now:

- Treating every decorative stamp as a real achievement if not backed by data.
- Duplicating the full Profile passport summary.

### 打卡

Current real/mostly real content:

- Current target mountain.
- Mountain photo preview.
- Upload picker surface.
- Watermark image generation/save based on target mountain.
- Check-in/detail navigation shell.

Not wired yet:

- Live camera capture.
- CoreLocation summit distance.
- Weather.
- Real check-in persistence.

Allowed UI:

- Proof preview.
- Target mountain facts.
- Watermark preview.
- Upload photo / save watermark.
- Primary CTA can be shown, but copy should not overclaim final GPS validation until persistence/location are wired.

Avoid for now:

- Weather chips.
- Flash/camera controls that do nothing.
- "GPS Excellent" or exact summit distance as if live if CoreLocation is not wired.

### 山峰詳情

Current real/mostly real content:

- Mountain photo/name/height/region/rank.
- Local/mock check-in counts.
- Map marker.
- Navigation to check-in.

Allowed UI:

- Photo hero.
- Route facts when they are honest catalog fields or clearly generic.
- CTA: 開始打卡.
- Recent record previews only when backed by local/mock data.

Avoid for now:

- Over-specific route duration/difficulty if not in the catalog.

### 排行

Current real/mostly real content:

- Static/mock users.
- Hot peaks from catalog.

Allowed UI:

- "示範排行榜" or neutral leaderboard copy until backend/social ranking is wired.
- Current user rank card.
- Top climbers podium.
- Friend list.
- Hot peaks.

Avoid for now:

- Large dark-green page background.
- Copy that implies live social backend if it is mock data.

### 我的

Current real/mostly real content:

- Auth service state.
- Avatar picker/storage.
- Passport summary.
- Recent mountain.
- Account status.

Allowed UI:

- Profile card.
- Passport summary.
- Sign-in providers.
- Achievements if framed as local/demo until backed by data.

Avoid for now:

- Duplicating Records calendar.
- Large dark hero if the rest of the app is paper/passport.

## Implementation Rules

- Put shared visual primitives in `Theme.swift`.
- Reuse a single card style and a single primary button style.
- Page backgrounds should default to `FrogTheme.paper` or `FrogTheme.passport`.
- If a screen needs immersive photo, use a contained hero/card instead of a full dark page.
- Any UI label implying live data must either be wired or written as local/demo/status copy.
- Build and inspect at least Explore, Records, Check-in, Leaderboard after a major visual pass.
