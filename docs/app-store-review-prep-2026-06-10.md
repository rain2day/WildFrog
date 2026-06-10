# WildFrog App Store Review Prep - 2026-06-10

## Frozen surface

- App version set to `1.0`; build remains `1`.
- Mountain image library currently has 330 `Mountain*.imageset` folders.
- Seed avatar library currently has 72 `SeedAvatar*.imageset` folders.
- Mountain surfaces now show an illustrative-photo badge when using generated placeholder photos: `示意圖 · 打卡相會取代`.
- The badge copy means: generated mountain photos are temporary illustration only; user-uploaded check-in photos replace them for that user.

## Privacy and permission decisions

- `PrivacyInfo.xcprivacy` is included in app resources.
- Required-reason API declared: UserDefaults, reason `CA92.1`.
- App privacy data to disclose in App Store Connect:
  - Contact Info: Name, Email Address, Phone Number.
  - Identifiers: User ID.
  - Usage Data: Other Usage Data.
  - All are linked to the user.
  - Purpose: App Functionality.
  - Tracking: No.
- Camera permission copy: capture summit check-in photos, watermark cards, and replace illustrative mountain photos with user real photos.
- Location permission copy: confirm proximity to summit checkpoints, calculate route distance, and continue route recording only after the user starts a hike.
- Background location decision: keep background location because live hike recording is a core user-initiated feature. Do not request Always permission at launch.
- Photos permission copy: pick check-in/profile photos and save watermark cards.

## Firebase

- Project used: `wildfrog-hk-prod`.
- Firebase CLI used through `pnpm dlx firebase-tools@latest`.
- CLI version observed: `15.19.1`.
- Logged-in Firebase account observed: `rainsdayjp@gmail.com`.
- Dry run passed for `firestore:rules,storage`.
- Deploy completed for `firestore:rules,storage`.
- Storage rules were already up to date; Firestore rules were uploaded and released.
- Deploy completed for `firestore:indexes`.
- `checkIns` composite index is ready for reviewer/app sync query: `userId ASC`, `createdAt ASC`.

## Build and signing

- Release archive command succeeded for generic iOS device.
- Current archive path: `/tmp/WildFrogNative-1.0-1-20260610.xcarchive`.
- Export options plist: `ios/build/ExportOptions-app-store-connect.plist`.
- Export is blocked until the Mac has App Store distribution signing available:
  - Xcode account is not available to `xcodebuild -exportArchive`.
  - No Apple Distribution / iOS Distribution certificate found in keychain.
  - No App Store provisioning profile found for `com.rainsday.WildFrogNative`.
  - No App Store provisioning profile found for `com.rainsday.WildFrogNative.LiveActivityWidget`.

## QA screenshots

- Screenshot folder: `/tmp/wildfrog-asc-screenshots-20260610`.
- Target simulator: iPhone 16, iOS 18.6.
- QA launch flags used:
  - `-qaDemoData`
  - `-qaScreenshot`
  - `-qaTab home|records|leaderboard|profile`
  - `-qaMountain tai-mo-shan`
  - `-qaCheckIn lion-rock`
  - `-qaSuccess`
- Required recapture rule: screenshots are not acceptable if the iOS location permission alert is visible.

## Reviewer / TestFlight account

- Reviewer account email: `rainsdayjp+wildfrog-asc-20260610@gmail.com`.
- Password is not stored in the repo; keep it only in the final ASC review note / private handoff.
- This email is allowlisted for the in-app reviewer GPS simulator.
- After signing in with this account, open `我的` and tap `測試定位`.
- Pick a mountain to simulate being at that summit, then use `打卡` > `直接打卡` to test the summit proximity flow without physically visiting the mountain.
- Ordinary users do not see the simulator controls in Release/TestFlight builds.
- Account has 4 seeded sample check-ins; ordered Firestore query returned Tai Mo Shan, Lion Rock, Lantau Peak, and Victoria Peak.

## App Store Connect inputs

- Privacy policy URL: required.
- Support URL: required.
- Marketing URL: optional unless the submitted metadata depends on it.
- Review contact: required.
- Demo account: required if reviewers need to see signed-in leaderboard/profile/check-in state.
- Review note should mention:
  - Mountain photos marked as illustrative are placeholders and are replaced by user-uploaded check-in photos.
  - Location is used for summit proximity validation and user-initiated hike recording.
  - Background location is only used during an active hike recording session.
  - The supplied reviewer account has a reviewer-only GPS simulator so App Review can test summit check-in gating.

## Submit gate

- Do not submit until export succeeds with App Store distribution signing and an uploadable `.ipa` exists.
- Do not submit until final ASC screenshots are recaptured without permission/system alerts.
