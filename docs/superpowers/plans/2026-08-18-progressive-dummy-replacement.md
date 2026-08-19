# Progressive Dummy Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the 46 production dummy profiles while guaranteeing that every real public user replaces one lowest-ranked dummy until the leaderboard contains only real users.

**Architecture:** Decode authoritative real and legacy dummy Firestore rows into one server-derived profile model with an explicit dummy marker. Apply a pure scope-aware one-for-one projection inside `SeedLeaderboard` before the existing competition-rank calculation so the main and full ranking automatically share identical rows and ranks.

**Tech Stack:** Swift 6, SwiftUI, Firebase Firestore iOS SDK, Swift Testing, Xcode 17.

## Global Constraints

- Start with all currently decoded legacy dummy profiles; production currently has 46.
- Display all real profiles plus `max(0, dummy count - real count)` highest-ranked dummy profiles.
- Every real public profile remains displayed regardless of score.
- Removing a real public profile restores one eligible dummy.
- Real and legacy dummy server profiles remain aggregate-only and never fabricate visits, dates, repeats, mountains, or achievements.
- Do not change Firebase Functions, Firestore Rules, the approved honor-system boundary, or production dummy documents.
- Do not commit or push; this plan overrides the generic commit steps because the user has not authorized Git publication.

---

### Task 1: Decode And Classify Legacy Dummy Profiles

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/SeedLeaderboard.swift`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/FirestoreService.swift`
- Test: `ios/WildFrogNative/Tests/WildFrogNativeTests/LeaderboardFlowContractTests.swift`

**Interfaces:**
- Produces: `SeedHikerProfile.isLegacyDummy: Bool` with initializer default `false`.
- Produces: `LeaderboardProfileDecoder.decode(documentID:data:index:)` accepting either authoritative real rows or the exact legacy dummy envelope.
- Preserves: `isServerDerived == true` for both real and legacy dummy rows.

- [ ] **Step 1: Write failing decoder and privacy-boundary tests**

Add tests that decode production's legacy fields and reject malformed legacy rows:

```swift
@Test func legacyDummyDecoderUsesStoredAggregatesWithoutPrivateDetail() throws {
    let profile = try #require(LeaderboardProfileDecoder.decode(
        documentID: "seed-profile-001",
        data: [
            "isVisible": true,
            "displayName": "山友一號",
            "monthScore": 8,
            "totalScore": 21,
            "distinctPeaks": 6,
            "homeRegion": "新界",
            "style": "週末山友",
            "heroMountainId": "lion-rock"
        ],
        index: 0
    ))

    #expect(profile.isLegacyDummy)
    #expect(profile.isServerDerived)
    #expect(profile.baseMonthCheckIns == 8)
    #expect(profile.baseTotalCheckIns == 21)
    #expect(profile.baseDistinctPeaks == 6)
    #expect(SeedLeaderboard.recentVisits(for: profile, asOf: .now).isEmpty)
    #expect(SeedLeaderboard.unlockedAchievements(for: profile, asOf: .now).isEmpty)
}

@Test func malformedLegacyDummyRowsRemainExcluded() {
    #expect(LeaderboardProfileDecoder.decode(
        documentID: "missing-score",
        data: ["isVisible": true, "displayName": "Incomplete"],
        index: 0
    ) == nil)
    #expect(LeaderboardProfileDecoder.decode(
        documentID: "private-dummy",
        data: ["isVisible": false, "displayName": "Hidden", "totalScore": 10],
        index: 1
    ) == nil)
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
xcodebuild test \
  -project ios/WildFrogNative/WildFrogNative.xcodeproj \
  -scheme WildFrogNative \
  -destination 'platform=iOS Simulator,id=B07F718E-943B-4C9B-ABDB-E13FB8FB1EF2' \
  -derivedDataPath .build/xcode-derived \
  -only-testing:WildFrogNativeTests/LeaderboardFlowContractTests
```

Expected: compile/test failure because `isLegacyDummy` and legacy decoding do not exist.

- [ ] **Step 3: Add the minimal profile marker**

Extend `SeedHikerProfile`:

```swift
let isLegacyDummy: Bool

init(
    // existing parameters
    isServerDerived: Bool = false,
    isLegacyDummy: Bool = false
) {
    // existing assignments
    self.isServerDerived = isServerDerived
    self.isLegacyDummy = isLegacyDummy
}
```

- [ ] **Step 4: Add strict dual-schema decoding**

Refactor the decoder into real and legacy branches. The legacy branch must require a non-empty public name and both month/total stored scores:

```swift
static func decode(documentID: String, data: [String: Any], index: Int) -> SeedHikerProfile? {
    guard (data["isVisible"] as? Bool) == true else { return nil }
    if let publicAlias = nonEmptyString(data["publicAlias"]) {
        return realProfile(documentID: documentID, alias: publicAlias, data: data, index: index)
    }
    guard let name = nonEmptyString(data["displayName"])
            ?? nonEmptyString(data["name"])
            ?? nonEmptyString(data["nickname"]),
          let monthScore = numericValue(data["monthScore"]),
          let totalScore = numericValue(data["totalScore"]),
          let distinctPeaks = numericValue(data["distinctPeaks"]) else { return nil }
    return SeedHikerProfile(
        id: documentID,
        name: name,
        homeRegion: nonEmptyString(data["homeRegion"]) ?? "香港",
        style: nonEmptyString(data["style"]) ?? "山友",
        titleMountainId: validMountainID(data["titleMountainId"]),
        heroMountainId: validMountainID(data["heroMountainId"]) ?? "lantau-peak",
        progressSeed: 10_000 + index,
        baseMonthCheckIns: max(0, monthScore),
        baseTotalCheckIns: max(0, totalScore),
        baseDistinctPeaks: max(0, distinctPeaks),
        cadenceDays: 999_999,
        weekendCycle: 999_999,
        isServerDerived: true,
        isLegacyDummy: true
    )
}
```

Keep the real branch's existing `publicAlias`, `monthlyCheckIns`, `totalCheckIns`, and `distinctPeaks` contract unchanged. Add private `nonEmptyString` and `validMountainID` helpers inside the decoder.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run the Step 2 command.

Expected: all `LeaderboardFlowContractTests` pass.

---

### Task 2: Project One-For-One Dummy Replacement Before Ranking

**Files:**
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/SeedLeaderboard.swift`
- Test: `ios/WildFrogNative/Tests/WildFrogNativeTests/LeaderboardFlowContractTests.swift`

**Interfaces:**
- Consumes: `SeedHikerProfile.isLegacyDummy` from Task 1.
- Produces: `SeedLeaderboard.projectedProfiles(_:scope:asOf:) -> [SeedHikerProfile]`.
- Changes: `SeedLeaderboard.entries` and `SeedLeaderboard.rank` use the same projection.

- [ ] **Step 1: Write failing projection tests**

Add helpers for real/dummy server profiles and these contracts:

```swift
@Test func eachRealProfileReplacesOneLowestRankedDummyAndAlwaysAppears() throws {
    let dummies = (1...46).map { transitionProfile(id: "dummy-\($0)", score: $0, isDummy: true) }
    let lowScoringReal = transitionProfile(id: "real-low", score: 0, isDummy: false)
    let entries = SeedLeaderboard.entries(
        profiles: dummies + [lowScoringReal],
        scope: .all,
        asOf: Date(timeIntervalSince1970: 0)
    )

    #expect(entries.count == 46)
    #expect(entries.contains { $0.profile.id == "real-low" })
    #expect(!entries.contains { $0.profile.id == "dummy-1" })
    #expect(entries.filter(\.profile.isLegacyDummy).count == 45)
}

@Test func realProfilesFullyReplaceAndThenRestoreDummySlots() {
    let dummies = (1...46).map { transitionProfile(id: "dummy-\($0)", score: $0, isDummy: true) }
    let reals = (1...46).map { transitionProfile(id: "real-\($0)", score: $0, isDummy: false) }

    let fullReal = SeedLeaderboard.entries(profiles: dummies + reals, scope: .all, asOf: .now)
    #expect(fullReal.count == 46)
    #expect(fullReal.allSatisfy { !$0.profile.isLegacyDummy })

    let afterOptOut = SeedLeaderboard.entries(profiles: dummies + reals.dropLast(), scope: .all, asOf: .now)
    #expect(afterOptOut.count == 46)
    #expect(afterOptOut.filter(\.profile.isLegacyDummy).count == 1)
}

private func transitionProfile(id: String, score: Int, isDummy: Bool) -> SeedHikerProfile {
    SeedHikerProfile(
        id: id,
        name: id,
        homeRegion: "香港",
        style: "山友",
        titleMountainId: nil,
        heroMountainId: "lion-rock",
        progressSeed: 0,
        baseMonthCheckIns: score,
        baseTotalCheckIns: score,
        baseDistinctPeaks: min(score, 10),
        cadenceDays: 999_999,
        weekendCycle: 999_999,
        isServerDerived: true,
        isLegacyDummy: isDummy
    )
}
```

- [ ] **Step 2: Run focused tests and verify RED**

Run the Task 1 Step 2 command.

Expected: counts are 47/92 because no replacement projection exists.

- [ ] **Step 3: Implement the pure scope-aware projection**

Add:

```swift
static func projectedProfiles(
    _ profiles: [SeedHikerProfile],
    scope: SeedLeaderboardScope,
    asOf date: Date
) -> [SeedHikerProfile] {
    let realProfiles = profiles.filter { !$0.isLegacyDummy }
    let dummyProfiles = profiles.filter(\.isLegacyDummy)
    let retainedDummyCount = max(0, dummyProfiles.count - realProfiles.count)
    let retainedDummies = rankedProfiles(
        profiles: dummyProfiles,
        scope: scope,
        asOf: date
    )
    .prefix(retainedDummyCount)
    .map(\.profile)
    return realProfiles + retainedDummies
}
```

Update `entries(profiles:scope:asOf:)` and `rank(for:among:scope:asOf:)` to call `projectedProfiles` once before `rankedProfiles`.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the Task 1 Step 2 command.

Expected: all focused tests pass, including real-user exact rank and aggregate-only detail tests.

---

### Task 3: Full Verification And Replacement Build

**Files:**
- Modify: `ios/WildFrogNative/WildFrogNative.xcodeproj/project.pbxproj`
- Modify: `ios/WildFrogNative/Sources/WildFrogNative/Info.plist`
- Modify: `ios/WildFrogNative/LiveActivityWidget/Info.plist`
- Update: `/Users/rainsday/Obsidian/RainVault/40_AI_SESSIONS/Shared/Handoffs/20260818-wildfrog-production-rollout.md`

**Interfaces:**
- Consumes: completed Task 1/2 source and tests.
- Produces: signed `1.0.3 (10)` archive, FyuRa install/readback, and App Store Connect upload evidence.

- [ ] **Step 1: Run the complete iOS target**

```bash
xcodebuild test \
  -project ios/WildFrogNative/WildFrogNative.xcodeproj \
  -scheme WildFrogNative \
  -destination 'platform=iOS Simulator,id=B07F718E-943B-4C9B-ABDB-E13FB8FB1EF2' \
  -derivedDataPath .build/xcode-derived \
  -only-testing:WildFrogNativeTests
```

Expected: all existing 78 tests plus the new regressions pass.

- [ ] **Step 2: Run unchanged-backend confidence gates**

```bash
npm --prefix functions run build
npm --prefix functions test
./functions/node_modules/.bin/firebase emulators:exec --only firestore --project demo-wildfrog \
  "npm --prefix functions test -- rebuild.integration.test.ts firestore.rules.test.ts"
```

Expected: TypeScript build succeeds, unit/config 4/4 pass, and Rules/rebuild 25/25 pass.

- [ ] **Step 3: Run hygiene checks**

```bash
git diff --check
plutil -lint ios/WildFrogNative/Sources/WildFrogNative/Info.plist
plutil -lint ios/WildFrogNative/LiveActivityWidget/Info.plist
```

Expected: exit 0.

- [ ] **Step 4: Increment build number to 10**

Use `xcrun agvtool new-version -all 10`, then verify all app/widget build settings and plists read `10`; retain marketing version `1.0.3`.

- [ ] **Step 5: Archive and verify version metadata**

```bash
xcodebuild archive \
  -project ios/WildFrogNative/WildFrogNative.xcodeproj \
  -scheme WildFrogNative \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/WildFrogNative-1.0.3-10-20260818.xcarchive \
  -allowProvisioningUpdates
```

Expected: `ARCHIVE SUCCEEDED`; archive metadata is `1.0.3 (10)`.

- [ ] **Step 6: Install, read back, and launch on FyuRa**

```bash
xcrun devicectl device install app \
  --device 9754514D-B33A-5503-A05C-12A16585680E \
  /tmp/WildFrogNative-1.0.3-10-20260818.xcarchive/Products/Applications/WildFrogNative.app
xcrun devicectl device info apps \
  --device 9754514D-B33A-5503-A05C-12A16585680E \
  --bundle-id com.rainsday.WildFrogNative
xcrun devicectl device process launch \
  --device 9754514D-B33A-5503-A05C-12A16585680E \
  --terminate-existing com.rainsday.WildFrogNative
```

Expected: installed version `1.0.3`, build `10`, launch succeeds.

- [ ] **Step 7: Upload the replacement build**

Create a temporary upload ExportOptions plist outside version control using the already validated automatic App Store Connect signing settings, then run `xcodebuild -exportArchive` with `destination=upload`.

Expected: Apple reports `Upload succeeded` for `1.0.3 (10)`. Remove the temporary plist afterward.

- [ ] **Step 8: Update and validate the RainVault handoff**

Record the exact RED/GREEN logs, build 10 device proof, upload state, and unchanged backend/rules boundary. Run:

```bash
python3 /Users/rainsday/Obsidian/RainVault/00_SYSTEM/scripts/rainvault_context.py check --strict-warnings \
  /Users/rainsday/Obsidian/RainVault/40_AI_SESSIONS/Shared/Handoffs/20260818-wildfrog-production-rollout.md
rainvault-wiki-doctor
```

Expected: strict check `0 errors, 0 warnings`; Wiki Doctor `Findings: OK`.
