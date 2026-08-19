import Foundation
import Testing
@testable import WildFrogNative

@Test func hktMonthKeyCrossesUtcBoundaryCorrectly() {
    let date = ISO8601DateFormatter().date(from: "2026-07-31T16:30:00Z")!
    #expect(LeaderboardMonth.key(for: date) == "2026-08")
}

@Test func migrationStateKeepsMissingFailedPendingCompletedAndDeclinedDistinct() {
    let visible = LeaderboardParticipation(
        isVisible: true,
        publicAlias: "Trail Rain",
        migrationVersion: 1,
        publicProfileId: "public-rain",
        syncRequestId: "request-1",
        completedSyncRequestId: "request-1"
    )
    let declined = LeaderboardParticipation(
        isVisible: false,
        publicAlias: nil,
        migrationVersion: 1,
        publicProfileId: nil
    )

    #expect(LeaderboardPublicationResolver.resolve(
        serverRead: .missing,
        hasHistoricalCheckIns: true,
        hasPublicProfileReadback: false
    ) == .missing(hasHistoricalCheckIns: true))
    #expect(LeaderboardPublicationResolver.resolve(
        serverRead: .failed,
        hasHistoricalCheckIns: true,
        hasPublicProfileReadback: false
    ) == .failed)
    #expect(LeaderboardPublicationResolver.resolve(
        serverRead: .loaded(visible),
        hasHistoricalCheckIns: true,
        hasPublicProfileReadback: false
    ) == .pending(visible))
    #expect(LeaderboardPublicationResolver.resolve(
        serverRead: .loaded(visible),
        hasHistoricalCheckIns: true,
        hasPublicProfileReadback: true
    ) == .completed(visible))

    var unacknowledged = visible
    unacknowledged.completedSyncRequestId = "older-request"
    #expect(LeaderboardPublicationResolver.resolve(
        serverRead: .loaded(unacknowledged),
        hasHistoricalCheckIns: true,
        hasPublicProfileReadback: true
    ) == .pending(unacknowledged))
    #expect(LeaderboardPublicationResolver.resolve(
        serverRead: .loaded(declined),
        hasHistoricalCheckIns: true,
        hasPublicProfileReadback: false
    ) == .declined(declined))

    let durableBackfill = LeaderboardParticipation(
        isVisible: false,
        publicAlias: "Trail Rain",
        migrationVersion: 1,
        publicProfileId: nil,
        publicationRequested: true,
        syncRequestId: "backfill-request"
    )
    #expect(LeaderboardPublicationResolver.resolve(
        serverRead: .loaded(durableBackfill),
        hasHistoricalCheckIns: true,
        hasPublicProfileReadback: false
    ) == .pending(durableBackfill))
}

@Test func consentAuthorityFailsClosedForMissingAndFailedServerReads() {
    #expect(LeaderboardConsentAuthority.resolve(serverRead: .unknown) == .unavailable)
    #expect(LeaderboardConsentAuthority.resolve(serverRead: .failed) == .unavailable)
    #expect(LeaderboardConsentAuthority.resolve(serverRead: .missing) == .needsExplicitDecision)

    let optedOut = LeaderboardParticipation(
        isVisible: false,
        publicAlias: "Old Alias",
        migrationVersion: 1,
        publicProfileId: "old-public-id"
    )
    #expect(LeaderboardConsentAuthority.resolve(serverRead: .loaded(optedOut)) == .needsExplicitDecision)

    var pending = optedOut
    pending.publicationRequested = true
    #expect(LeaderboardConsentAuthority.resolve(serverRead: .loaded(pending)) == .unavailable)

    let optedIn = LeaderboardParticipation(
        isVisible: true,
        publicAlias: "Trail Rain",
        migrationVersion: 1,
        publicProfileId: "public-id"
    )
    #expect(LeaderboardConsentAuthority.resolve(serverRead: .loaded(optedIn)) == .publish(publicAlias: "Trail Rain"))
}

@Test func publicAliasRejectsContactInformationAndFirebaseIdentifiers() {
    #expect(LeaderboardPublicAlias.validate(
        "  Trail Rain  ",
        uid: "firebase-user-12345678",
        email: "rain@example.com",
        phoneNumber: "+85291234567"
    ) == .success("Trail Rain"))
    #expect(LeaderboardPublicAlias.validate(
        "rain@example.com",
        uid: "firebase-user-12345678",
        email: "rain@example.com",
        phoneNumber: nil
    ) == .failure(.contactInformation))
    #expect(LeaderboardPublicAlias.validate(
        "+852 9123 4567",
        uid: "firebase-user-12345678",
        email: nil,
        phoneNumber: "+85291234567"
    ) == .failure(.contactInformation))
    #expect(LeaderboardPublicAlias.validate(
        "firebase-user-12345678",
        uid: "firebase-user-12345678",
        email: nil,
        phoneNumber: nil
    ) == .failure(.firebaseIdentifier))
    #expect(LeaderboardPublicAlias.validate(
        "firebase",
        uid: "firebase-user-12345678",
        email: nil,
        phoneNumber: nil
    ) == .failure(.firebaseIdentifier))
}

@Test func publicAliasUsesUnicodeScalarLengthSharedWithBackendAndRules() {
    let twentyFourEmoji = String(repeating: "😀", count: 24)
    let twentyFiveEmoji = String(repeating: "😀", count: 25)
    let fourFamilyEmoji = String(repeating: "👨‍👩‍👧‍👦", count: 4)

    #expect(LeaderboardPublicAlias.validate(
        twentyFourEmoji,
        uid: "owner-a",
        email: nil,
        phoneNumber: nil
    ) == .success(twentyFourEmoji))
    #expect(LeaderboardPublicAlias.validate(
        twentyFiveEmoji,
        uid: "owner-a",
        email: nil,
        phoneNumber: nil
    ) == .failure(.tooLong))
    #expect(LeaderboardPublicAlias.validate(
        fourFamilyEmoji,
        uid: "owner-a",
        email: nil,
        phoneNumber: nil
    ) == .failure(.tooLong))
}

@Test func publicAliasRejectsDottedPhoneNumbersLikeBackendAndRules() {
    #expect(LeaderboardPublicAlias.validate(
        "123.456.7890",
        uid: "owner-a",
        email: nil,
        phoneNumber: nil
    ) == .failure(.contactInformation))
}

@Test func failedCloudSyncRemainsExplicitlyRetryableAfterLocalSuccess() {
    #expect(CheckInCloudSyncState.failed.isRetryable)
    #expect(!CheckInCloudSyncState.pending.isRetryable)
    #expect(!CheckInCloudSyncState.synced.isRetryable)
    #expect(!CheckInCloudSyncState.deviceOnly.isRetryable)
}

@MainActor
@Test func pendingCloudWorkIsBoundToItsOriginatingUIDAndStableRecordID() {
    let defaults = UserDefaults(suiteName: "wildfrog.tests.outbox.uid-switch")!
    defaults.removePersistentDomain(forName: "wildfrog.tests.outbox.uid-switch")
    let record = CheckInRecord(
        id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
        mountainId: "lion-rock",
        date: Date(timeIntervalSince1970: 1_000)
    )
    let item = CheckInCloudOutboxItem(
        ownerUID: "owner-a",
        record: record,
        intent: .publishWithExistingConsent,
        syncRequestID: "request-a"
    )

    let outbox = CheckInCloudOutboxStore(defaults: defaults)
    outbox.enqueue(item)

    #expect(outbox.nextItem(for: "owner-b") == nil)
    #expect(outbox.nextItem(for: "owner-a")?.id == record.id)
    #expect(!CheckInCloudWorkEligibility.canExecute(item: item, currentUID: "owner-b"))
    #expect(CheckInCloudWorkEligibility.canExecute(item: item, currentUID: "owner-a"))
}

@MainActor
@Test func cloudOutboxSurvivesViewDismissalAndRelaunchWithFailureVisible() {
    let suiteName = "wildfrog.tests.outbox.persistence"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let record = CheckInRecord(
        id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
        mountainId: "tai-mo-shan",
        date: Date(timeIntervalSince1970: 2_000)
    )
    let item = CheckInCloudOutboxItem(
        ownerUID: "owner-a",
        record: record,
        intent: .resolveServerAuthority,
        syncRequestID: "stable-request"
    )

    do {
        let firstLaunch = CheckInCloudOutboxStore(defaults: defaults)
        firstLaunch.enqueue(item)
        firstLaunch.markFailed(
            ownerUID: "owner-a",
            recordID: record.id,
            message: "offline"
        )
    }

    let relaunched = CheckInCloudOutboxStore(defaults: defaults)
    #expect(relaunched.item(ownerUID: "owner-a", recordID: record.id)?.syncRequestID == "stable-request")
    #expect(relaunched.status(for: "owner-a").failedCount == 1)
    #expect(relaunched.status(for: "owner-a").lastError == "offline")
}

@MainActor
@Test func firstOptInOutboxDurablyCarriesPreviousAndCurrentOfficialHistory() throws {
    let suiteName = "wildfrog.tests.outbox.first-opt-in-history"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let previous = CheckInRecord(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
        mountainId: "lion-rock",
        date: Date(timeIntervalSince1970: 1_000)
    )
    let current = CheckInRecord(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
        mountainId: "tai-mo-shan",
        date: Date(timeIntervalSince1970: 2_000)
    )
    let item = CheckInCloudOutboxItem(
        ownerUID: "owner-a",
        record: current,
        intent: .optIn(publicAlias: "Trail Rain"),
        officialRecordsSnapshot: [previous, current, current],
        syncRequestID: "request-new",
        expectedPreviousSyncRequestID: "request-old"
    )

    #expect(item.recordsToSync.map(\.id) == [previous.id, current.id])
    #expect(item.syncTicket.ownerUID == "owner-a")
    #expect(item.syncTicket.syncRequestID == "request-new")
    #expect(item.syncTicket.expectedPreviousSyncRequestID == "request-old")

    CheckInCloudOutboxStore(defaults: defaults).enqueue(item)
    let relaunched = try #require(CheckInCloudOutboxStore(defaults: defaults).nextItem(for: "owner-a"))
    #expect(relaunched.recordsToSync.map(\.id) == [previous.id, current.id])
    #expect(relaunched.syncTicket == item.syncTicket)
}

@Test func legacyOutboxDecodeBackfillsItsCurrentRecordSnapshot() throws {
    let record = CheckInRecord(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000003")!,
        mountainId: "sunset-peak",
        date: Date(timeIntervalSince1970: 3_000)
    )
    let legacyJSON: [String: Any] = [
        "ownerUID": "legacy-owner",
        "record": [
            "id": record.id.uuidString,
            "mountainId": record.mountainId,
            "date": record.date.timeIntervalSinceReferenceDate
        ],
        "intent": ["optIn": ["publicAlias": "Legacy Trail"]],
        "syncRequestID": "legacy-request",
        "createdAt": Date(timeIntervalSince1970: 4_000).timeIntervalSinceReferenceDate,
        "state": ["pending": [:]]
    ]
    let data = try JSONSerialization.data(withJSONObject: legacyJSON)
    let decoded = try JSONDecoder().decode(CheckInCloudOutboxItem.self, from: data)

    #expect(decoded.recordsToSync.map(\.id) == [record.id])
}

@Test func finalVisibilityRequiresTheExactOwnerRequestAndNoDeletionTombstone() {
    let pending = LeaderboardParticipation(
        isVisible: false,
        publicAlias: "Trail Rain",
        migrationVersion: 1,
        publicProfileId: nil,
        publicationRequested: true,
        syncRequestId: "request-new"
    )
    let ticket = LeaderboardSyncTicket(
        ownerUID: "owner-a",
        syncRequestID: "request-new",
        expectedPreviousSyncRequestID: "request-old"
    )

    #expect(LeaderboardConditionalMutation.canFinalize(
        ticket: ticket,
        currentUID: "owner-a",
        currentParticipation: pending,
        hasAccountDeletionTombstone: false
    ))

    var optedOut = pending
    optedOut.isVisible = false
    optedOut.publicationRequested = false
    optedOut.syncRequestId = "request-opt-out"
    #expect(!LeaderboardConditionalMutation.canFinalize(
        ticket: ticket,
        currentUID: "owner-a",
        currentParticipation: optedOut,
        hasAccountDeletionTombstone: false
    ))
    #expect(!LeaderboardConditionalMutation.canFinalize(
        ticket: ticket,
        currentUID: "owner-a",
        currentParticipation: nil,
        hasAccountDeletionTombstone: true
    ))
    #expect(!LeaderboardConditionalMutation.canFinalize(
        ticket: ticket,
        currentUID: "owner-b",
        currentParticipation: pending,
        hasAccountDeletionTombstone: false
    ))
}

@Test func staleDeviceOnlyDecisionIsSupersededByNewerCrossDeviceOptIn() {
    let staleDecline = LeaderboardSyncTicket(
        ownerUID: "owner-a",
        syncRequestID: "device-only-request",
        expectedPreviousSyncRequestID: "request-before-device-only"
    )
    let newerOptIn = LeaderboardParticipation(
        isVisible: true,
        publicAlias: "Newer Cross Device Opt In",
        migrationVersion: 1,
        publicProfileId: "public-a",
        publicationRequested: true,
        syncRequestId: "newer-opt-in-request"
    )

    #expect(LeaderboardConditionalMutation.declineOutcome(
        ticket: staleDecline,
        currentUID: "owner-a",
        currentParticipation: newerOptIn,
        hasAccountDeletionTombstone: false
    ) == .superseded)

    let expectedPrevious = LeaderboardParticipation(
        isVisible: false,
        publicAlias: nil,
        migrationVersion: 1,
        publicProfileId: nil,
        publicationRequested: false,
        syncRequestId: "request-before-device-only"
    )
    #expect(LeaderboardConditionalMutation.declineOutcome(
        ticket: staleDecline,
        currentUID: "owner-a",
        currentParticipation: expectedPrevious,
        hasAccountDeletionTombstone: false
    ) == .apply)

    var idempotentRetry = expectedPrevious
    idempotentRetry.syncRequestId = staleDecline.syncRequestID
    #expect(LeaderboardConditionalMutation.declineOutcome(
        ticket: staleDecline,
        currentUID: "owner-a",
        currentParticipation: idempotentRetry,
        hasAccountDeletionTombstone: false
    ) == .alreadyApplied)
}

@MainActor
@Test func accountDeletionTombstonesBeforeEveryFinalCheckInSweep() async throws {
    var steps: [String] = []
    let workflow = AccountDeletionCloudWorkflow(
        establishTombstone: { steps.append("establish-tombstone") },
        awaitPublicCleanup: { steps.append("await-public-cleanup") },
        finalCheckInSweep: { steps.append("final-check-in-sweep") }
    )

    try await workflow.run()
    try await workflow.run()

    #expect(steps == [
        "establish-tombstone",
        "await-public-cleanup",
        "final-check-in-sweep",
        "establish-tombstone",
        "await-public-cleanup",
        "final-check-in-sweep"
    ])
}

@MainActor
@Test func accountDeletionFailsClosedBeforeAuthDeletionWhenPublicCleanupIsUnacknowledged() async {
    enum ExpectedFailure: Error { case unacknowledged }
    var steps: [String] = []
    let workflow = AccountDeletionCloudWorkflow(
        establishTombstone: { steps.append("establish-tombstone") },
        awaitPublicCleanup: {
            steps.append("await-public-cleanup")
            throw ExpectedFailure.unacknowledged
        },
        finalCheckInSweep: { steps.append("final-check-in-sweep") }
    )

    await #expect(throws: ExpectedFailure.self) {
        try await workflow.run()
    }
    #expect(steps == ["establish-tombstone", "await-public-cleanup"])
}

@Test func deletionCleanupAcknowledgementRequiresTheExactRequest() {
    #expect(AccountDeletionCleanupAcknowledgement.matches(
        requestID: "delete-new",
        completedRequestID: "delete-new"
    ))
    #expect(!AccountDeletionCleanupAcknowledgement.matches(
        requestID: "delete-new",
        completedRequestID: "delete-old"
    ))
    #expect(!AccountDeletionCleanupAcknowledgement.matches(
        requestID: "delete-new",
        completedRequestID: nil
    ))
}

@Test func staleListDoesNotHidePendingOrFailedPublicationRecovery() {
    let pendingParticipation = LeaderboardParticipation(
        isVisible: false,
        publicAlias: "Trail Rain",
        migrationVersion: 1,
        publicProfileId: nil,
        publicationRequested: true,
        syncRequestId: "pending-request"
    )
    let pending = LeaderboardRecoveryActions.resolve(
        publication: .pending(pendingParticipation),
        listRefresh: .failed
    )
    let failed = LeaderboardRecoveryActions.resolve(
        publication: .failed,
        listRefresh: .failed
    )

    #expect(pending.showListRetry)
    #expect(pending.showPublicationRetry)
    #expect(failed.showListRetry)
    #expect(failed.showPublicationRetry)
}

@Test func fullLeaderboardSheetDisclosesRetainedRowsAndBothRetryActions() {
    let pendingParticipation = LeaderboardParticipation(
        isVisible: false,
        publicAlias: "Trail Rain",
        migrationVersion: 1,
        publicProfileId: nil,
        publicationRequested: true,
        syncRequestId: "pending-request"
    )
    let state = FullLeaderboardSheetState.resolve(
        publication: .pending(pendingParticipation),
        listRefresh: .failed
    )

    #expect(state.disclosesRetainedRows)
    #expect(state.showListRetry)
    #expect(state.showPublicationRetry)
}

@Test func fullLeaderboardProjectionPinsExactPublicUserOnceAndPreservesRanks() {
    let currentProfile = SeedHikerProfile(
        id: "public-current",
        name: "Current Rain",
        homeRegion: "",
        style: "",
        titleMountainId: nil,
        heroMountainId: "lion-rock",
        progressSeed: 0,
        baseMonthCheckIns: 9,
        baseTotalCheckIns: 20,
        baseDistinctPeaks: 8,
        cadenceDays: 1,
        weekendCycle: 1,
        isServerDerived: true
    )
    let otherProfile = SeedHikerProfile(
        id: "public-other",
        name: "Other Rain",
        homeRegion: "",
        style: "",
        titleMountainId: nil,
        heroMountainId: "lion-rock",
        progressSeed: 0,
        baseMonthCheckIns: 8,
        baseTotalCheckIns: 19,
        baseDistinctPeaks: 7,
        cadenceDays: 1,
        weekendCycle: 1,
        isServerDerived: true
    )
    let exactEntry = SeedLeaderboardEntry(
        rank: 7,
        profile: currentProfile,
        score: 20,
        distinctPeaks: 8,
        delta: .flat,
        deltaN: 0
    )
    let otherEntry = SeedLeaderboardEntry(
        rank: 8,
        profile: otherProfile,
        score: 19,
        distinctPeaks: 7,
        delta: .flat,
        deltaN: 0
    )

    let exactProjection = FullLeaderboardListProjection.resolve(
        entries: [exactEntry, otherEntry],
        exactPublicEntry: exactEntry
    )
    let renderedIDs = [exactProjection.pinnedExactEntry?.profile.id].compactMap { $0 }
        + exactProjection.publicEntries.map(\.profile.id)

    #expect(renderedIDs.filter { $0 == "public-current" }.count == 1)
    #expect(exactProjection.publicEntries.map(\.profile.id) == ["public-other"])
    #expect(exactProjection.publicEntries.map(\.rank) == [8])

    let privateProjection = FullLeaderboardListProjection.resolve(
        entries: [exactEntry, otherEntry],
        exactPublicEntry: nil
    )
    #expect(privateProjection.pinnedExactEntry == nil)
    #expect(privateProjection.publicEntries.map(\.profile.id) == ["public-current", "public-other"])
    #expect(privateProjection.publicEntries.map(\.rank) == [7, 8])
}

@Test func deletionRequestPlanRetriggersLegacyTombstoneWithExactNewRequest() {
    let legacy = AccountDeletionRequestPlan.resolve(
        tombstoneRequestID: nil,
        proposedRequestID: "delete-new"
    )
    let current = AccountDeletionRequestPlan.resolve(
        tombstoneRequestID: "delete-existing",
        proposedRequestID: "delete-new"
    )

    #expect(legacy.requestID == "delete-new")
    #expect(legacy.mustWriteCleanupRequest)
    #expect(current.requestID == "delete-existing")
    #expect(current.mustWriteCleanupRequest)
}

@Test func checkInConsentResolutionCannotCrossFromOneAccountToAnother() {
    #expect(CheckInAccountBinding.canContinue(expectedUID: "owner-a", currentUID: "owner-a"))
    #expect(!CheckInAccountBinding.canContinue(expectedUID: "owner-a", currentUID: "owner-b"))
    #expect(!CheckInAccountBinding.canContinue(expectedUID: "owner-a", currentUID: nil))
}

@Test func uidBoundPublicationRejectsDelayedPreviousAccountAndCannotAuthorizeItsMutation() {
    let publicationA = LeaderboardParticipation(
        isVisible: true,
        publicAlias: "Account A",
        migrationVersion: 1,
        publicProfileId: "public-a",
        syncRequestId: "request-a",
        completedSyncRequestId: "request-a"
    )
    let publicationB = LeaderboardParticipation(
        isVisible: true,
        publicAlias: "Account B",
        migrationVersion: 1,
        publicProfileId: "public-b",
        syncRequestId: "request-b",
        completedSyncRequestId: "request-b"
    )
    var state = UIDBoundLeaderboardPublication(currentUID: "owner-a")

    state.reset(for: "owner-b")
    let appliedB = state.applyServerRead(
        .completed(publicationB),
        originatingUID: "owner-b",
        currentUID: "owner-b"
    )
    let appliedDelayedA = state.applyServerRead(
        .completed(publicationA),
        originatingUID: "owner-a",
        currentUID: "owner-b"
    )
    #expect(appliedB)
    #expect(!appliedDelayedA)
    #expect(state.publication == .completed(publicationB))
    #expect(state.authorizesVisibleMutation(currentUID: "owner-b"))

    var staleOnly = UIDBoundLeaderboardPublication(currentUID: "owner-b")
    let appliedStaleA = staleOnly.applyServerRead(
        .completed(publicationA),
        originatingUID: "owner-a",
        currentUID: "owner-b"
    )
    #expect(!appliedStaleA)
    #expect(staleOnly.publication == .unknown)
    #expect(!staleOnly.authorizesVisibleMutation(currentUID: "owner-b"))

    state.reset(for: nil)
    #expect(state.publication == .unknown)
    #expect(!state.authorizesVisibleMutation(currentUID: nil))
}

@Test func delayedAMutationCompletionCannotChangeBPublicationBusyOrErrorState() {
    let completedA = LeaderboardParticipation(
        isVisible: true,
        publicAlias: "Account A",
        migrationVersion: 1,
        publicProfileId: "public-a",
        syncRequestId: "request-a",
        completedSyncRequestId: "request-a"
    )
    let completedB = LeaderboardParticipation(
        isVisible: true,
        publicAlias: "Account B",
        migrationVersion: 1,
        publicProfileId: "public-b",
        syncRequestId: "request-b",
        completedSyncRequestId: "request-b"
    )
    var publication = UIDBoundLeaderboardPublication(currentUID: "owner-a")
    _ = publication.applyServerRead(
        .completed(completedA),
        originatingUID: "owner-a",
        currentUID: "owner-a"
    )

    publication.reset(for: "owner-b")
    _ = publication.applyServerRead(
        .completed(completedB),
        originatingUID: "owner-b",
        currentUID: "owner-b"
    )
    var isBusy = true
    var errorMessage: String? = "B current error"

    let appliedAFailure = publication.applyLocal(
        .failed,
        originatingUID: "owner-a",
        currentUID: "owner-b"
    )
    if publication.canApplyLocal(originatingUID: "owner-a", currentUID: "owner-b") {
        isBusy = false
        errorMessage = "A late failure"
    }

    #expect(!appliedAFailure)
    #expect(publication.publication == .completed(completedB))
    #expect(publication.authorizesVisibleMutation(currentUID: "owner-b"))
    #expect(isBusy)
    #expect(errorMessage == "B current error")
}

@Test func profileAndLeaderboardMutationCompletionsUseOriginatingUIDGuards() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    for filename in ["ProfileView.swift", "LeaderboardView.swift"] {
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent("Sources/WildFrogNative/\(filename)"),
            encoding: .utf8
        )
        #expect(source.contains("applyLocal("), "\(filename) must tag local publication changes with the originating UID")
        #expect(source.contains("canApplyLocal("), "\(filename) must guard error, prompt, and busy cleanup by originating UID")
        #expect(!source.contains(".setLocal("), "\(filename) must not use current-owner-only local writes")
        #expect(
            source.range(
                of: #"leaderboardPublicationState\s*=\s*[^=]"#,
                options: .regularExpression
            ) == nil,
            "\(filename) must not bypass originating-UID publication writes"
        )
    }
}

@Test func profileAndLeaderboardConsumersUseUIDBoundPublicationState() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    for filename in ["ProfileView.swift", "LeaderboardView.swift"] {
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent("Sources/WildFrogNative/\(filename)"),
            encoding: .utf8
        )
        #expect(source.contains("UIDBoundLeaderboardPublication"), "\(filename) must store UID-tagged publication state")
        #expect(source.contains(".task(id: authService.session?.uid)"), "\(filename) must restart its publication read when UID changes")
        #expect(source.contains("applyServerRead("), "\(filename) must gate delayed server results by originating UID")
        #expect(source.contains("reset(for: newUID)"), "\(filename) must clear visible publication state immediately on account change")
    }
}

@Test func temporaryCheckInPhotoIsDiscardedWhenBoundRecordWasNotCreated() {
    #expect(CheckInTemporaryPhotoDisposition.resolve(
        expectedUID: "owner-a",
        currentUID: "owner-b",
        recordCreated: false
    ) == .discard)
    #expect(CheckInTemporaryPhotoDisposition.resolve(
        expectedUID: "owner-a",
        currentUID: "owner-a",
        recordCreated: true
    ) == .keep)
}

@Test func failedLocalCommitRemovesTheJustWrittenOrphanPhoto() throws {
    let fileManager = FileManager.default
    let directory = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: directory) }
    let orphan = directory.appendingPathComponent("orphan.jpg")
    try Data([1, 2, 3]).write(to: orphan)

    #expect(fileManager.fileExists(atPath: orphan.path))
    TemporaryPhotoFileCleanup.remove(
        filename: "orphan.jpg",
        documentsDirectory: directory,
        fileManager: fileManager
    )
    #expect(!fileManager.fileExists(atPath: orphan.path))
}

@MainActor
@Test func successfulDeletionClearsTheUIDOutboxAndCheckInCache() throws {
    let suiteName = "wildfrog.tests.account-deletion-local-cleanup"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let ownerUID = "deleted-owner"
    let record = CheckInRecord(
        id: UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!,
        mountainId: "lion-rock",
        date: Date(timeIntervalSince1970: 3_000)
    )
    defaults.set(
        try JSONEncoder().encode([record]),
        forKey: "wildfrog.checkins.v2.\(ownerUID)"
    )
    let checkInStore = CheckInStore(defaults: defaults)
    let outbox = CheckInCloudOutboxStore(defaults: defaults)
    outbox.enqueue(CheckInCloudOutboxItem(
        ownerUID: ownerUID,
        record: record,
        intent: .publishWithExistingConsent,
        syncRequestID: "stale-upload"
    ))

    checkInStore.removeAll(for: ownerUID)
    outbox.removeAll(for: ownerUID)

    #expect(defaults.data(forKey: "wildfrog.checkins.v2.\(ownerUID)") == nil)
    #expect(CheckInCloudOutboxStore(defaults: defaults).nextItem(for: ownerUID) == nil)
}

@MainActor
@Test func accountPhotoDeletionPlanPreservesOtherAccountsAndUnrelatedJpegs() throws {
    let suiteName = "wildfrog.tests.account-photo-isolation"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let ownerARecord = CheckInRecord(
        mountainId: "lion-rock",
        date: Date(timeIntervalSince1970: 1_000),
        photoFilename: "owner-a.jpg"
    )
    let ownerBRecord = CheckInRecord(
        mountainId: "tai-mo-shan",
        date: Date(timeIntervalSince1970: 2_000),
        photoFilename: "owner-b.jpg"
    )
    defaults.set(
        try JSONEncoder().encode([ownerARecord]),
        forKey: "wildfrog.checkins.v2.owner-a"
    )
    defaults.set(
        try JSONEncoder().encode([ownerBRecord]),
        forKey: "wildfrog.checkins.v2.owner-b"
    )

    let store = CheckInStore(defaults: defaults)
    let documents = URL(fileURLWithPath: "/private/tmp/wildfrog-documents", isDirectory: true)
    let contents = ["owner-a.jpg", "owner-b.jpg", "unrelated.jpg", "note.txt"].map {
        documents.appendingPathComponent($0)
    }
    let deletion = AccountPhotoDeletionPlan.urlsToDelete(
        from: contents,
        ownedFilenames: store.photoFilenamesOwned(by: "owner-a")
    )

    #expect(deletion.map(\.lastPathComponent) == ["owner-a.jpg"])
    #expect(store.photoFilenamesOwned(by: "owner-b") == ["owner-b.jpg"])
}

@Test func completedMigrationReplacesTheVisibleRankSnapshotWithoutViewRecreation() throws {
    let participation = LeaderboardParticipation(
        isVisible: true,
        publicAlias: "Trail Rain",
        migrationVersion: 1,
        publicProfileId: "mine",
        publicationRequested: true,
        syncRequestId: "migration-request",
        completedSyncRequestId: "migration-request"
    )
    let oldSnapshot = [leaderboardRefreshTestProfile(id: "other", score: 8)]
    let refreshedSnapshot = oldSnapshot + [leaderboardRefreshTestProfile(id: "mine", score: 5)]

    let visibleSnapshot = LeaderboardMigrationProfileRefresh.replacingProfiles(
        oldSnapshot,
        with: refreshedSnapshot,
        after: .completed(participation)
    )
    let entries = SeedLeaderboard.entries(
        profiles: visibleSnapshot,
        scope: .all,
        asOf: Date(timeIntervalSince1970: 0)
    )

    #expect(visibleSnapshot.map(\.id) == ["other", "mine"])
    #expect(try #require(LeaderboardPublicRank.entry(publicProfileId: "mine", in: entries)).rank == 2)
    #expect(LeaderboardMigrationProfileRefresh.replacingProfiles(
        oldSnapshot,
        with: refreshedSnapshot,
        after: .pending(participation)
    ) == oldSnapshot)
}

@Test func aliasRenameNeedsMatchingBackendAcknowledgementAndAliasReadback() {
    let renamed = LeaderboardParticipation(
        isVisible: true,
        publicAlias: "New Trail Name",
        migrationVersion: 1,
        publicProfileId: "public-a",
        publicationRequested: true,
        syncRequestId: "rename-request",
        completedSyncRequestId: "rename-request"
    )

    #expect(!LeaderboardPublicationResolver.hasMatchingPublicReadback(
        participation: renamed,
        publicAlias: "Old Trail Name"
    ))
    #expect(LeaderboardPublicationResolver.hasMatchingPublicReadback(
        participation: renamed,
        publicAlias: "New Trail Name"
    ))
}

@Test func completeLeaderboardQueryAndRankingRemainGlobalBeyondOneHundredUsers() throws {
    #expect(LeaderboardQueryPlan.current == .allVisibleProfiles)

    let profiles = (1...125).map { index in
        SeedHikerProfile(
            id: "profile-\(index)",
            name: "Hiker \(index)",
            homeRegion: "Hong Kong",
            style: "Hiker",
            titleMountainId: nil,
            heroMountainId: "lion-rock",
            progressSeed: index,
            baseMonthCheckIns: 126 - index,
            baseTotalCheckIns: 126 - index,
            baseDistinctPeaks: 1,
            cadenceDays: 999_999,
            weekendCycle: 999_999,
            isServerDerived: true
        )
    }
    let entries = SeedLeaderboard.entries(
        profiles: profiles,
        scope: .all,
        asOf: Date(timeIntervalSince1970: 0)
    )

    #expect(entries.count == 125)
    #expect(try #require(LeaderboardPublicRank.entry(publicProfileId: "profile-125", in: entries)).rank == 125)
}

@Test func exactPublicationSurvivesAnInitialOrRetryRankListRefreshFailure() {
    let confirmed = LeaderboardParticipation(
        isVisible: true,
        publicAlias: "Trail Rain",
        migrationVersion: 1,
        publicProfileId: "mine",
        publicationRequested: true,
        syncRequestId: "request-1",
        completedSyncRequestId: "request-1"
    )

    let initial = LeaderboardPublicationListRefresh.resolve(
        exactReadback: .completed(confirmed),
        listRefresh: .failed
    )
    let retry = LeaderboardPublicationListRefresh.resolve(
        exactReadback: initial.publication,
        listRefresh: .failed
    )

    #expect(initial.publication == .completed(confirmed))
    #expect(initial.listRefresh == .failed)
    #expect(retry.publication == .completed(confirmed))
    #expect(retry.listRefresh == .failed)
}

@Test func retainedRowsStayRetryableAndNonExactUntilARefreshSucceeds() {
    let confirmed = LeaderboardParticipation(
        isVisible: true,
        publicAlias: "Trail Rain",
        migrationVersion: 1,
        publicProfileId: "mine",
        publicationRequested: true,
        syncRequestId: "request-1",
        completedSyncRequestId: "request-1"
    )
    let declined = LeaderboardParticipation(
        isVisible: false,
        publicAlias: nil,
        migrationVersion: 1,
        publicProfileId: nil,
        publicationRequested: false
    )

    for publication in [
        LeaderboardPublicationState.completed(confirmed),
        .declined(declined)
    ] {
        let stale = LeaderboardPublicationListRefresh.resolve(
            exactReadback: publication,
            listRefresh: .failed
        )
        #expect(stale.isStale)
        #expect(stale.isRetryable)
        #expect(!stale.canShowExactOwnRank)

        let refreshed = LeaderboardPublicationListRefresh.resolve(
            exactReadback: publication,
            listRefresh: .current
        )
        #expect(!refreshed.isStale)
        #expect(!refreshed.isRetryable)
        #expect(refreshed.canShowExactOwnRank)
    }
}

@Test func retainedListRefreshIsNonExactFromStartAndThroughoutRetry() {
    let confirmed = LeaderboardParticipation(
        isVisible: true,
        publicAlias: "Trail Rain",
        migrationVersion: 1,
        publicProfileId: "mine",
        publicationRequested: true,
        syncRequestId: "request-1",
        completedSyncRequestId: "request-1"
    )
    var lifecycle = LeaderboardListRefreshLifecycle()

    let initial = LeaderboardPublicationListRefresh.resolve(
        exactReadback: .completed(confirmed),
        listRefresh: lifecycle.state
    )
    let initialSheet = FullLeaderboardSheetState.resolve(
        publication: initial.publication,
        listRefresh: lifecycle.state
    )
    #expect(lifecycle.state == .refreshing)
    #expect(!initial.canShowExactOwnRank)
    #expect(initialSheet.disclosesRetainedRows)
    #expect(!initialSheet.showListRetry)

    lifecycle.succeed()
    let current = LeaderboardPublicationListRefresh.resolve(
        exactReadback: .completed(confirmed),
        listRefresh: lifecycle.state
    )
    #expect(current.canShowExactOwnRank)

    lifecycle.beginRefresh()
    let retrying = LeaderboardPublicationListRefresh.resolve(
        exactReadback: current.publication,
        listRefresh: lifecycle.state
    )
    #expect(lifecycle.state == .refreshing)
    #expect(!retrying.canShowExactOwnRank)

    lifecycle.fail()
    let failed = LeaderboardPublicationListRefresh.resolve(
        exactReadback: retrying.publication,
        listRefresh: lifecycle.state
    )
    #expect(failed.isStale)
    #expect(failed.isRetryable)
    #expect(!failed.canShowExactOwnRank)
}

@Test func latestListRefreshRequestKeepsFastNewRowsAgainstSlowOldSuccessAndFailure() {
    var requestState = LeaderboardListRefreshRequestState()
    var visibleRows = ["retained"]
    let slowOld = requestState.begin(currentUID: "owner-a")
    let fastNew = requestState.begin(currentUID: "owner-a")

    let acceptedNew = requestState.succeed(fastNew, currentUID: "owner-a")
    if acceptedNew { visibleRows = ["new"] }
    let acceptedOldSuccess = requestState.succeed(slowOld, currentUID: "owner-a")
    if acceptedOldSuccess { visibleRows = ["old"] }
    let acceptedOldFailure = requestState.fail(slowOld, currentUID: "owner-a")

    #expect(acceptedNew)
    #expect(!acceptedOldSuccess)
    #expect(!acceptedOldFailure)
    #expect(visibleRows == ["new"])
    #expect(requestState.listRefresh == .current)
}

@Test func listRefreshRequestRejectsLatestCompletionAfterUIDContextChanges() {
    var requestState = LeaderboardListRefreshRequestState()
    let requestA = requestState.begin(currentUID: "owner-a")

    let acceptedSuccess = requestState.succeed(requestA, currentUID: "owner-b")
    let acceptedFailure = requestState.fail(requestA, currentUID: "owner-b")
    let acceptedCancellation = requestState.acceptCancellation(requestA, currentUID: "owner-b")

    #expect(!acceptedSuccess)
    #expect(!acceptedFailure)
    #expect(!acceptedCancellation)
    #expect(requestState.listRefresh == .refreshing)
}

@Test func uidChangeInvalidatesAAndLetsBRestoreCurrentOrFailedState() throws {
    var successState = LeaderboardListRefreshRequestState()
    let requestA = successState.begin(currentUID: "owner-a")
    successState.invalidate(currentUID: "owner-b")
    let requestBValue = successState.begin(
        expectedUID: "owner-b",
        currentUID: "owner-b"
    )
    let requestB = try #require(requestBValue)

    let acceptedOldA = successState.fail(requestA, currentUID: "owner-b")
    let acceptedB = successState.succeed(requestB, currentUID: "owner-b")
    #expect(!acceptedOldA)
    #expect(acceptedB)
    #expect(successState.listRefresh == .current)

    var failureState = LeaderboardListRefreshRequestState()
    _ = failureState.begin(currentUID: "owner-a")
    failureState.invalidate(currentUID: "owner-b")
    let failingBValue = failureState.begin(
        expectedUID: "owner-b",
        currentUID: "owner-b"
    )
    let failingB = try #require(failingBValue)
    let acceptedBFailure = failureState.fail(failingB, currentUID: "owner-b")
    #expect(acceptedBFailure)
    #expect(failureState.listRefresh == .failed)
}

@Test func staleAPostPublicationRefreshCannotSupersedeAnActiveBRequest() throws {
    var requestState = LeaderboardListRefreshRequestState()
    requestState.invalidate(currentUID: "owner-b")
    let requestBValue = requestState.begin(
        expectedUID: "owner-b",
        currentUID: "owner-b"
    )
    let requestB = try #require(requestBValue)

    let staleA = requestState.begin(
        expectedUID: "owner-a",
        currentUID: "owner-b"
    )
    let acceptedB = requestState.succeed(requestB, currentUID: "owner-b")

    #expect(staleA == nil)
    #expect(acceptedB)
    #expect(requestState.listRefresh == .current)
}

@Test func leaderboardUsesOneUIDKeyedContextTaskForListAndPublication() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: projectRoot.appendingPathComponent("Sources/WildFrogNative/LeaderboardView.swift"),
        encoding: .utf8
    )

    #expect(source.components(separatedBy: ".task(id: authService.session?.uid)").count - 1 == 1)
    #expect(!source.contains(".task { await loadLeaderboardProfiles() }"))
    #expect(source.contains("await loadLeaderboardContext(for: authService.session?.uid)"))
    #expect(source.contains("leaderboardListRefreshRequest.invalidate(currentUID: newUID)"))
    #expect(source.contains("await loadLeaderboardProfiles(expectedUID: expectedUID)"), "guest and signed-in contexts must both fetch the public list")
    #expect(source.contains("expectedUID: uid,\n            currentUID: authService.session?.uid"), "post-publication refresh must reject stale UID before allocating a token")
}

@Test func everyLeaderboardListFetchUsesTheSharedLatestRequestGate() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: projectRoot.appendingPathComponent("Sources/WildFrogNative/LeaderboardView.swift"),
        encoding: .utf8
    )

    #expect(source.contains("LeaderboardListRefreshRequestState"))
    #expect(source.components(separatedBy: "leaderboardListRefreshRequest.begin(").count - 1 == 2)
    #expect(source.components(separatedBy: "leaderboardListRefreshRequest.succeed(").count - 1 == 2)
    #expect(source.components(separatedBy: "leaderboardListRefreshRequest.fail(").count - 1 >= 2)
    #expect(source.contains("leaderboardListRefreshRequest.acceptCancellation("))
    #expect(source.contains("await loadLeaderboardProfiles(expectedUID:"), "Retry must route through the same request-gated fetch")
}

@Test func retainedRowsPresentationSeparatesDisclosureFromFailedRetry() {
    let publication = LeaderboardPublicationState.missing(hasHistoricalCheckIns: false)
    var lifecycle = LeaderboardListRefreshLifecycle()

    let refreshing = LeaderboardRecoveryActions.resolve(
        publication: publication,
        listRefresh: lifecycle.state
    )
    let refreshingSheet = FullLeaderboardSheetState.resolve(
        publication: publication,
        listRefresh: lifecycle.state
    )
    #expect(refreshing.showRetainedDisclosure)
    #expect(!refreshing.showListRetry)
    #expect(refreshingSheet.showRetainedDisclosure)
    #expect(!refreshingSheet.showListRetry)

    lifecycle.succeed()
    let current = LeaderboardRecoveryActions.resolve(
        publication: publication,
        listRefresh: lifecycle.state
    )
    #expect(!current.showRetainedDisclosure)
    #expect(!current.showListRetry)

    lifecycle.beginRefresh()
    lifecycle.fail()
    let failed = LeaderboardRecoveryActions.resolve(
        publication: publication,
        listRefresh: lifecycle.state
    )
    let failedSheet = FullLeaderboardSheetState.resolve(
        publication: publication,
        listRefresh: lifecycle.state
    )
    #expect(failed.showRetainedDisclosure)
    #expect(failed.showListRetry)
    #expect(failedSheet.showRetainedDisclosure)
    #expect(failedSheet.showListRetry)
}

@Test func mainAndFullRankingsRenderRetainedDisclosureSeparatelyFromRetry() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    for filename in ["LeaderboardView.swift", "AllAchievementsView.swift"] {
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent("Sources/WildFrogNative/\(filename)"),
            encoding: .utf8
        )
        #expect(source.contains("showRetainedDisclosure"), "\(filename) must render refreshing and failed retained-row disclosure")
        #expect(source.contains("showListRetry"), "\(filename) must keep Retry exclusive to failed refreshes")
        #expect(source.contains("Updating leaderboard; showing last results."), "\(filename) must use non-error refreshing copy")
    }
}

@Test func leaderboardConsumersUseSynchronousRefreshLifecycleForMainAndFullRankings() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: projectRoot.appendingPathComponent("Sources/WildFrogNative/LeaderboardView.swift"),
        encoding: .utf8
    )
    let loadStart = try #require(source.range(of: "private func loadLeaderboardProfiles(expectedUID: String?) async"))
    let loadTail = source[loadStart.lowerBound...]
    let begin = try #require(loadTail.range(of: "leaderboardListRefreshRequest.begin("))
    let fetch = try #require(loadTail.range(of: "fetchLeaderboardProfiles()"))

    #expect(begin.lowerBound < fetch.lowerBound, "freshness must become non-authoritative before awaiting the server")
    #expect(source.contains("leaderboardListRefreshRequest.listRefresh == .current"), "main ranking must require current list state")
    #expect(source.contains("listRefresh: leaderboardListRefreshRequest.listRefresh"), "Full Ranking must receive the same list freshness")
}

@Test func authoritativeFirestoreOperationsUseServerOnlyReads() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: projectRoot.appendingPathComponent("Sources/WildFrogNative/FirestoreService.swift"),
        encoding: .utf8
    )

    for operation in [
        "func deleteUserCheckIns",
        "func fetchLeaderboardParticipation",
        "func hasOfficialCheckIns",
        "func fetchVisiblePublicAlias",
        "func fetchLeaderboardProfiles"
    ] {
        let operationRange = try #require(source.range(of: operation))
        let nextOperation = source[operationRange.upperBound...].range(of: "\n    func ")
        let body = nextOperation.map { source[operationRange.lowerBound..<$0.lowerBound] }
            ?? source[operationRange.lowerBound...]
        #expect(body.contains("source: .server"), "\(operation) must read Firestore with source: .server")
    }
}

@Test func nestedMonthlyMapUsesCurrentHongKongMonth() {
    let date = ISO8601DateFormatter().date(from: "2026-07-31T16:30:00Z")!
    let score = LeaderboardMonth.score(
        in: ["2026-07": 2, "2026-08": 5],
        for: date
    )
    #expect(score == 5)
}

private func leaderboardRefreshTestProfile(id: String, score: Int) -> SeedHikerProfile {
    SeedHikerProfile(
        id: id,
        name: id,
        homeRegion: "Hong Kong",
        style: "Hiker",
        titleMountainId: nil,
        heroMountainId: "lion-rock",
        progressSeed: 0,
        baseMonthCheckIns: score,
        baseTotalCheckIns: score,
        baseDistinctPeaks: 1,
        cadenceDays: 999_999,
        weekendCycle: 999_999,
        isServerDerived: true
    )
}
