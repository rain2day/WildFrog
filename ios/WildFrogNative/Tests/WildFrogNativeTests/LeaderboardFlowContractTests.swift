import Foundation
import Testing
@testable import WildFrogNative

@Test func leaderboardFlowWiresConsentMigrationVisibilityAndCleanup() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceRoot = projectRoot.appendingPathComponent("Sources/WildFrogNative")

    let camera = try String(contentsOf: sourceRoot.appendingPathComponent("CheckInCameraView.swift"), encoding: .utf8)
    let leaderboard = try String(contentsOf: sourceRoot.appendingPathComponent("LeaderboardView.swift"), encoding: .utf8)
    let profile = try String(contentsOf: sourceRoot.appendingPathComponent("ProfileView.swift"), encoding: .utf8)
    let auth = try String(contentsOf: sourceRoot.appendingPathComponent("ProfileAuthService.swift"), encoding: .utf8)
    let freePhoto = try String(contentsOf: sourceRoot.appendingPathComponent("FreePhotoView.swift"), encoding: .utf8)

    #expect(camera.contains("cloudOutbox.enqueue"))
    #expect(camera.contains("originatingSession.uid"))
    #expect(camera.contains("performCheckIn(cloudIntent:"))
    #expect(camera.contains("expectedUID: expectedUID"))
    #expect(camera.contains("CheckInAccountBinding.canContinue"))
    #expect(camera.contains("removePhotoFromDocuments"))
    #expect(camera.contains("PhotoSelectionRequestState"))
    #expect(camera.contains("photoSelectionState.acceptPhotosResult"))
    #expect(camera.contains("公開顯示名稱"))
    #expect(leaderboard.contains("LeaderboardMigrationDecision.shouldPrompt"))
    #expect(profile.contains("公開排行榜"))
    #expect(profile.contains("setLeaderboardParticipation"))
    #expect(profile.contains("renameLeaderboardPublicAlias"))
    #expect(profile.contains("Private Account Name"))
    #expect(!profile.contains("Leaderboard Name"))
    #expect(auth.contains("deleteLeaderboardParticipation"))
    #expect(!freePhoto.contains("setLeaderboardParticipation"))
}

@Test func publicRankComesFromTheSharedSortedEntry() {
    let profiles = [
        leaderboardTestProfile(id: "other", month: 8, total: 20),
        leaderboardTestProfile(id: "mine", month: 5, total: 12),
        leaderboardTestProfile(id: "third", month: 2, total: 6)
    ]
    let entries = SeedLeaderboard.entries(profiles: profiles, scope: .month, asOf: Date(timeIntervalSince1970: 0))

    #expect(LeaderboardPublicRank.entry(publicProfileId: "mine", in: entries)?.rank == 2)
    #expect(LeaderboardPublicRank.entry(publicProfileId: nil, in: entries) == nil)
}

@Test func serverDerivedLeaderboardEntriesKeepExactBackendTotals() {
    let profile = SeedHikerProfile(
        id: "server-profile",
        name: "Trail Rain",
        homeRegion: "香港",
        style: "山友",
        titleMountainId: nil,
        heroMountainId: "lion-rock",
        progressSeed: 7,
        baseMonthCheckIns: 4,
        baseTotalCheckIns: 72,
        baseDistinctPeaks: 3,
        cadenceDays: 2,
        weekendCycle: 2,
        isServerDerived: true
    )

    let entry = SeedLeaderboard.entries(
        profiles: [profile],
        scope: .all,
        asOf: Date(timeIntervalSince1970: 2_000_000_000)
    ).first

    #expect(entry?.score == 72)
    #expect(entry?.distinctPeaks == 3)
}

@Test func exactCurrentUserRankRequiresCompletedPublicationAndCurrentServerSnapshot() throws {
    let participation = LeaderboardParticipation(
        isVisible: true,
        publicAlias: "Trail Rain",
        migrationVersion: 1,
        publicProfileId: "mine",
        syncRequestId: "request-1",
        completedSyncRequestId: "request-1"
    )
    let entries = SeedLeaderboard.entries(
        profiles: [
            leaderboardTestProfile(id: "other", month: 8, total: 20),
            leaderboardTestProfile(id: "mine", month: 5, total: 12)
        ],
        scope: .month,
        asOf: Date(timeIntervalSince1970: 0)
    )

    let exact = try #require(LeaderboardCurrentUserSnapshot.exactEntry(
        publication: .completed(participation),
        listRefresh: .current,
        entries: entries
    ))
    #expect(exact.rank == 2)
    #expect(exact.score == 5)
    #expect(exact.profile.name == "mine")

    #expect(LeaderboardCurrentUserSnapshot.exactEntry(
        publication: .completed(participation),
        listRefresh: .failed,
        entries: entries
    ) == nil)
    #expect(LeaderboardCurrentUserSnapshot.exactEntry(
        publication: .declined(participation),
        listRefresh: .current,
        entries: entries
    ) == nil)
}

@Test func leaderboardMonthMatchingUsesHongKongTime() {
    let beforeMidnightUTC = ISO8601DateFormatter().date(from: "2026-07-31T15:59:59Z")!
    let afterMidnightHKT = ISO8601DateFormatter().date(from: "2026-07-31T16:00:00Z")!
    let augustReference = ISO8601DateFormatter().date(from: "2026-08-18T00:00:00Z")!

    #expect(!LeaderboardMonth.contains(beforeMidnightUTC, inMonthOf: augustReference))
    #expect(LeaderboardMonth.contains(afterMidnightHKT, inMonthOf: augustReference))
}

@Test func serverDerivedProfilesNeverFabricatePrivateDetail() {
    let profile = SeedHikerProfile(
        id: "server-profile",
        name: "Trail Rain",
        homeRegion: "香港",
        style: "山友",
        titleMountainId: nil,
        heroMountainId: "lion-rock",
        progressSeed: 7,
        baseMonthCheckIns: 4,
        baseTotalCheckIns: 72,
        baseDistinctPeaks: 3,
        cadenceDays: 2,
        weekendCycle: 2,
        isServerDerived: true
    )

    #expect(SeedLeaderboard.checkedMountains(for: profile, asOf: .now).isEmpty)
    #expect(SeedLeaderboard.recentVisits(for: profile, asOf: .now).isEmpty)
    #expect(SeedLeaderboard.unlockedAchievements(for: profile, asOf: .now).isEmpty)
    #expect(LeaderboardProfileDetailAvailability.forProfile(profile) == .publicAggregatesOnly)
}

@Test func equalPublicScoresShareCompetitionRankBeyondOneHundredUsers() throws {
    let profiles = (1...125).map { index in
        leaderboardTestProfile(
            id: String(format: "profile-%03d", index),
            month: index >= 124 ? 1 : 200 - index,
            total: index >= 124 ? 1 : 200 - index
        )
    }
    let entries = SeedLeaderboard.entries(
        profiles: profiles,
        scope: .all,
        asOf: Date(timeIntervalSince1970: 0)
    )
    let firstTied = try #require(entries.first { $0.profile.id == "profile-124" })
    let secondTied = try #require(entries.first { $0.profile.id == "profile-125" })

    #expect(entries.count == 125)
    #expect(firstTied.rank == 124)
    #expect(secondTied.rank == 124)
    #expect(entries.filter { $0.rank == 124 }.count == 2)
}

@Test func backendProfileDecoderUsesPublicAliasAndExactCountsWithoutPublicLocationMetadata() throws {
    let profile = try #require(LeaderboardProfileDecoder.decode(
        documentID: "anonymous-public-id",
        data: [
            "isVisible": true,
            "publicAlias": "Trail Rain",
            "monthlyCheckIns": [LeaderboardMonth.key(): 5],
            "totalCheckIns": 12,
            "distinctPeaks": 2
        ],
        index: 0
    ))

    #expect(profile.name == "Trail Rain")
    #expect(profile.heroMountainId == "lantau-peak")
    #expect(profile.isServerDerived)
    let entry = try #require(SeedLeaderboard.entries(profiles: [profile], scope: .all, asOf: .now).first)
    #expect(entry.score == 12)
    #expect(entry.distinctPeaks == 2)

    #expect(LeaderboardProfileDecoder.decode(
        documentID: "legacy-contact-profile",
        data: [
            "isVisible": true,
            "displayName": "rain@example.com",
            "totalCheckIns": 99
        ],
        index: 1
    ) == nil)
}

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
        data: [
            "isVisible": false,
            "displayName": "Hidden",
            "monthScore": 4,
            "totalScore": 10,
            "distinctPeaks": 3
        ],
        index: 1
    ) == nil)
}

@Test func eachRealProfileReplacesOneLowestRankedDummyAndAlwaysAppears() {
    let date = Date(timeIntervalSince1970: 0)
    let dummies = (1...46).map {
        transitionProfile(id: "dummy-\($0)", score: $0, isDummy: true)
    }
    let lowScoringReal = transitionProfile(id: "real-low", score: 0, isDummy: false)
    let entries = SeedLeaderboard.entries(
        profiles: dummies + [lowScoringReal],
        scope: .all,
        asOf: date
    )

    #expect(entries.count == 46)
    #expect(entries.contains { $0.profile.id == "real-low" })
    #expect(!entries.contains { $0.profile.id == "dummy-1" })
    #expect(entries.filter { $0.profile.isLegacyDummy }.count == 45)
}

@Test func realProfilesProgressivelyReplaceAndThenRestoreDummySlots() {
    let date = Date(timeIntervalSince1970: 0)
    let dummies = (1...46).map {
        transitionProfile(id: "dummy-\($0)", score: $0, isDummy: true)
    }
    let reals = (1...47).map {
        transitionProfile(id: "real-\($0)", score: $0, isDummy: false)
    }

    let twentyReal = SeedLeaderboard.entries(
        profiles: dummies + Array(reals.prefix(20)),
        scope: .all,
        asOf: date
    )
    #expect(twentyReal.count == 46)
    #expect(twentyReal.filter { !$0.profile.isLegacyDummy }.count == 20)
    #expect(twentyReal.filter { $0.profile.isLegacyDummy }.count == 26)

    let fullReal = SeedLeaderboard.entries(
        profiles: dummies + Array(reals.prefix(46)),
        scope: .all,
        asOf: date
    )
    #expect(fullReal.count == 46)
    #expect(fullReal.allSatisfy { !$0.profile.isLegacyDummy })

    let aboveCapacity = SeedLeaderboard.entries(
        profiles: dummies + reals,
        scope: .all,
        asOf: date
    )
    #expect(aboveCapacity.count == 47)
    #expect(aboveCapacity.allSatisfy { !$0.profile.isLegacyDummy })

    let afterOptOut = SeedLeaderboard.entries(
        profiles: dummies + Array(reals.prefix(45)),
        scope: .all,
        asOf: date
    )
    #expect(afterOptOut.count == 46)
    #expect(afterOptOut.filter { $0.profile.isLegacyDummy }.count == 1)
}

@Test func legacyDummiesKeepTheirSeedAvatarWhileRealProfilesStayAnonymous() {
    let dummy = transitionProfile(id: "dummy-1", score: 10, isDummy: true)
    let real = transitionProfile(id: "real-1", score: 10, isDummy: false)
    let localSeed = leaderboardTestProfile(id: "local-1", month: 1, total: 1)

    #expect(dummy.usesSeedAvatarAsset)
    #expect(!real.usesSeedAvatarAsset)
    #expect(localSeed.usesSeedAvatarAsset)
}

private func leaderboardTestProfile(id: String, month: Int, total: Int) -> SeedHikerProfile {
    SeedHikerProfile(
        id: id,
        name: id,
        homeRegion: "香港",
        style: "山友",
        titleMountainId: nil,
        heroMountainId: "lion-rock",
        progressSeed: 0,
        baseMonthCheckIns: month,
        baseTotalCheckIns: total,
        baseDistinctPeaks: min(total, 10),
        cadenceDays: 999_999,
        weekendCycle: 999_999,
        isServerDerived: false
    )
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
