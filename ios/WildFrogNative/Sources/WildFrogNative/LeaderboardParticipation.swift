import Foundation
import Combine

struct LeaderboardParticipation: Equatable {
    var isVisible: Bool
    var publicAlias: String?
    var migrationVersion: Int
    var publicProfileId: String?
    var publicationRequested: Bool
    var syncRequestId: String?
    var completedSyncRequestId: String?

    var isSyncAcknowledged: Bool {
        guard let syncRequestId, !syncRequestId.isEmpty else { return false }
        return completedSyncRequestId == syncRequestId
    }

    init(
        isVisible: Bool,
        publicAlias: String?,
        migrationVersion: Int,
        publicProfileId: String?,
        publicationRequested: Bool? = nil,
        syncRequestId: String? = nil,
        completedSyncRequestId: String? = nil
    ) {
        self.isVisible = isVisible
        self.publicAlias = publicAlias
        self.migrationVersion = migrationVersion
        self.publicProfileId = publicProfileId
        self.publicationRequested = publicationRequested ?? isVisible
        self.syncRequestId = syncRequestId
        self.completedSyncRequestId = completedSyncRequestId
    }
}

enum LeaderboardServerRead: Equatable {
    case unknown
    case missing
    case failed
    case loaded(LeaderboardParticipation)
}

enum LeaderboardPublicationState: Equatable {
    case unknown
    case missing(hasHistoricalCheckIns: Bool)
    case failed
    case pending(LeaderboardParticipation)
    case completed(LeaderboardParticipation)
    case declined(LeaderboardParticipation)
}

struct UIDBoundLeaderboardPublication: Equatable {
    private(set) var ownerUID: String?
    private(set) var publication: LeaderboardPublicationState

    init(currentUID: String? = nil) {
        ownerUID = currentUID
        publication = .unknown
    }

    mutating func reset(for currentUID: String?) {
        ownerUID = currentUID
        publication = .unknown
    }

    @discardableResult
    mutating func applyServerRead(
        _ read: LeaderboardPublicationState,
        originatingUID: String,
        currentUID: String?
    ) -> Bool {
        guard currentUID == originatingUID, ownerUID == originatingUID else { return false }
        publication = read
        return true
    }

    @discardableResult
    mutating func applyLocal(
        _ state: LeaderboardPublicationState,
        originatingUID: String,
        currentUID: String?
    ) -> Bool {
        guard canApplyLocal(
            originatingUID: originatingUID,
            currentUID: currentUID
        ) else { return false }
        publication = state
        return true
    }

    func canApplyLocal(originatingUID: String, currentUID: String?) -> Bool {
        currentUID == originatingUID && ownerUID == originatingUID
    }

    func authorizesVisibleMutation(currentUID: String?) -> Bool {
        guard let currentUID, ownerUID == currentUID else { return false }
        if case .completed = publication { return true }
        return false
    }
}

enum LeaderboardPublicationResolver {
    static func resolve(
        serverRead: LeaderboardServerRead,
        hasHistoricalCheckIns: Bool,
        hasPublicProfileReadback: Bool
    ) -> LeaderboardPublicationState {
        switch serverRead {
        case .unknown:
            return .unknown
        case .missing:
            return .missing(hasHistoricalCheckIns: hasHistoricalCheckIns)
        case .failed:
            return .failed
        case .loaded(let participation):
            if participation.publicationRequested && !participation.isVisible {
                return .pending(participation)
            }
            guard participation.isVisible else { return .declined(participation) }
            return hasPublicProfileReadback && participation.isSyncAcknowledged
                ? .completed(participation)
                : .pending(participation)
        }
    }

    static func hasMatchingPublicReadback(
        participation: LeaderboardParticipation,
        publicAlias: String?
    ) -> Bool {
        guard participation.isSyncAcknowledged,
              let expectedAlias = participation.publicAlias?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !expectedAlias.isEmpty,
              let publicAlias = publicAlias?
                .trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return publicAlias == expectedAlias
    }
}

enum LeaderboardConsentAuthority: Equatable {
    case unavailable
    case needsExplicitDecision
    case publish(publicAlias: String)

    static func resolve(serverRead: LeaderboardServerRead) -> LeaderboardConsentAuthority {
        switch serverRead {
        case .unknown:
            return .unavailable
        case .missing:
            return .needsExplicitDecision
        case .failed:
            return .unavailable
        case .loaded(let participation):
            if participation.publicationRequested && !participation.isVisible {
                return .unavailable
            }
            guard participation.isVisible, let alias = participation.publicAlias else {
                return .needsExplicitDecision
            }
            return .publish(publicAlias: alias)
        }
    }
}

enum LeaderboardPublicAliasError: Error, Equatable {
    case empty
    case tooLong
    case contactInformation
    case firebaseIdentifier
}

enum LeaderboardPublicAlias {
    static func validate(
        _ rawValue: String,
        uid: String,
        email: String?,
        phoneNumber: String?
    ) -> Result<String, LeaderboardPublicAliasError> {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard trimmed.unicodeScalars.count <= 24 else { return .failure(.tooLong) }

        let normalized = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let normalizedEmail = email?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let phoneDigits = phoneNumber?.filter(\.isNumber)
        let candidateDigits = trimmed.filter(\.isNumber)
        let phoneCharacters = CharacterSet(charactersIn: "+-() .").union(.decimalDigits)
        let looksLikePhone = trimmed.unicodeScalars.allSatisfy(phoneCharacters.contains)
            && candidateDigits.count >= 7

        if normalized.contains("@")
            || normalized == normalizedEmail
            || (phoneDigits?.count ?? 0) >= 7 && candidateDigits == phoneDigits
            || looksLikePhone {
            return .failure(.contactInformation)
        }

        let normalizedUID = uid.lowercased()
        if normalized.lowercased() == normalizedUID
            || normalizedUID.hasPrefix(normalized.lowercased()) && normalized.count >= 8 {
            return .failure(.firebaseIdentifier)
        }
        return .success(trimmed)
    }
}

enum LeaderboardMigrationDecision {
    static func shouldPrompt(
        participation: LeaderboardParticipation?,
        officialRecordCount: Int
    ) -> Bool {
        participation == nil && officialRecordCount > 0
    }

    static func shouldPrompt(state: LeaderboardPublicationState) -> Bool {
        if case .missing(let hasHistoricalCheckIns) = state {
            return hasHistoricalCheckIns
        }
        return false
    }
}

enum LeaderboardMonth {
    static func key(for date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    static func score(in monthlyCheckIns: [String: Int], for date: Date = Date()) -> Int {
        monthlyCheckIns[key(for: date)] ?? 0
    }

    static func contains(_ date: Date, inMonthOf referenceDate: Date) -> Bool {
        key(for: date) == key(for: referenceDate)
    }
}

enum LeaderboardPublicRank {
    static func entry(
        publicProfileId: String?,
        in entries: [SeedLeaderboardEntry]
    ) -> SeedLeaderboardEntry? {
        guard let publicProfileId else { return nil }
        return entries.first { $0.profile.id == publicProfileId }
    }
}

enum LeaderboardCurrentUserSnapshot {
    static func exactEntry(
        publication: LeaderboardPublicationState,
        listRefresh: LeaderboardPublicationListRefresh.ListRefresh,
        entries: [SeedLeaderboardEntry]
    ) -> SeedLeaderboardEntry? {
        guard listRefresh == .current,
              case .completed(let participation) = publication else { return nil }
        return LeaderboardPublicRank.entry(
            publicProfileId: participation.publicProfileId,
            in: entries
        )
    }
}

enum LeaderboardQueryPlan: Equatable {
    case allVisibleProfiles

    static let current: LeaderboardQueryPlan = .allVisibleProfiles
}

struct LeaderboardSyncTicket: Equatable {
    let ownerUID: String
    let syncRequestID: String
    let expectedPreviousSyncRequestID: String?
}

enum LeaderboardConditionalMutation {
    static func canBegin(
        ticket: LeaderboardSyncTicket,
        currentUID: String?,
        currentParticipation: LeaderboardParticipation?,
        hasAccountDeletionTombstone: Bool
    ) -> Bool {
        guard currentUID == ticket.ownerUID,
              !hasAccountDeletionTombstone else { return false }
        return currentParticipation?.syncRequestId == ticket.expectedPreviousSyncRequestID
    }

    static func canFinalize(
        ticket: LeaderboardSyncTicket,
        currentUID: String?,
        currentParticipation: LeaderboardParticipation?,
        hasAccountDeletionTombstone: Bool
    ) -> Bool {
        guard currentUID == ticket.ownerUID,
              !hasAccountDeletionTombstone,
              let currentParticipation else { return false }
        return currentParticipation.publicationRequested
            && currentParticipation.syncRequestId == ticket.syncRequestID
    }

    static func declineOutcome(
        ticket: LeaderboardSyncTicket,
        currentUID: String?,
        currentParticipation: LeaderboardParticipation?,
        hasAccountDeletionTombstone: Bool
    ) -> LeaderboardDeclineMutationOutcome {
        guard currentUID == ticket.ownerUID,
              !hasAccountDeletionTombstone else { return .superseded }
        if currentParticipation?.syncRequestId == ticket.syncRequestID,
           currentParticipation?.isVisible == false,
           currentParticipation?.publicationRequested == false {
            return .alreadyApplied
        }
        return currentParticipation?.syncRequestId == ticket.expectedPreviousSyncRequestID
            ? .apply
            : .superseded
    }
}

enum LeaderboardDeclineMutationOutcome: String, Equatable {
    case apply
    case alreadyApplied
    case superseded
}

enum LeaderboardMigrationProfileRefresh {
    static func replacingProfiles(
        _ current: [SeedHikerProfile],
        with refreshed: [SeedHikerProfile],
        after publicationState: LeaderboardPublicationState
    ) -> [SeedHikerProfile] {
        guard case .completed = publicationState else { return current }
        return refreshed
    }
}

struct LeaderboardPublicationListRefresh: Equatable {
    enum ListRefresh: Equatable {
        case refreshing
        case current
        case failed
    }

    let publication: LeaderboardPublicationState
    let listRefresh: ListRefresh

    var isStale: Bool {
        listRefresh == .failed
    }

    var isRetryable: Bool {
        isStale
    }

    var canShowExactOwnRank: Bool {
        listRefresh == .current
    }

    static func resolve(
        exactReadback: LeaderboardPublicationState,
        listRefresh: ListRefresh
    ) -> LeaderboardPublicationListRefresh {
        LeaderboardPublicationListRefresh(
            publication: exactReadback,
            listRefresh: listRefresh
        )
    }
}

struct LeaderboardListRefreshLifecycle: Equatable {
    private(set) var state: LeaderboardPublicationListRefresh.ListRefresh = .refreshing

    mutating func beginRefresh() {
        state = .refreshing
    }

    mutating func succeed() {
        state = .current
    }

    mutating func fail() {
        state = .failed
    }
}

struct LeaderboardListRefreshRequestState: Equatable {
    struct Request: Equatable {
        let revision: Int
        let ownerUID: String?
    }

    private var revision = 0
    private var contextUID: String?
    private(set) var listRefresh: LeaderboardPublicationListRefresh.ListRefresh = .refreshing

    mutating func invalidate(currentUID: String?) {
        revision += 1
        contextUID = currentUID
        listRefresh = .refreshing
    }

    mutating func begin(currentUID: String?) -> Request {
        revision += 1
        contextUID = currentUID
        listRefresh = .refreshing
        return Request(revision: revision, ownerUID: currentUID)
    }

    mutating func begin(expectedUID: String?, currentUID: String?) -> Request? {
        guard expectedUID == currentUID else { return nil }
        return begin(currentUID: currentUID)
    }

    @discardableResult
    mutating func succeed(_ request: Request, currentUID: String?) -> Bool {
        guard isLatest(request, currentUID: currentUID) else { return false }
        listRefresh = .current
        return true
    }

    @discardableResult
    mutating func fail(_ request: Request, currentUID: String?) -> Bool {
        guard isLatest(request, currentUID: currentUID) else { return false }
        listRefresh = .failed
        return true
    }

    func acceptCancellation(_ request: Request, currentUID: String?) -> Bool {
        isLatest(request, currentUID: currentUID)
    }

    private func isLatest(_ request: Request, currentUID: String?) -> Bool {
        request.revision == revision
            && request.ownerUID == contextUID
            && request.ownerUID == currentUID
    }
}

struct LeaderboardRecoveryActions: Equatable {
    let showRetainedDisclosure: Bool
    let showListRetry: Bool
    let showPublicationRetry: Bool

    static func resolve(
        publication: LeaderboardPublicationState,
        listRefresh: LeaderboardPublicationListRefresh.ListRefresh
    ) -> Self {
        let showPublicationRetry: Bool
        switch publication {
        case .failed, .pending:
            showPublicationRetry = true
        case .unknown, .missing, .completed, .declined:
            showPublicationRetry = false
        }
        return Self(
            showRetainedDisclosure: listRefresh != .current,
            showListRetry: listRefresh == .failed,
            showPublicationRetry: showPublicationRetry
        )
    }
}

struct FullLeaderboardSheetState: Equatable {
    let showRetainedDisclosure: Bool
    let showListRetry: Bool
    let showPublicationRetry: Bool

    var disclosesRetainedRows: Bool { showRetainedDisclosure }

    static func resolve(
        publication: LeaderboardPublicationState,
        listRefresh: LeaderboardPublicationListRefresh.ListRefresh
    ) -> Self {
        let actions = LeaderboardRecoveryActions.resolve(
            publication: publication,
            listRefresh: listRefresh
        )
        return Self(
            showRetainedDisclosure: actions.showRetainedDisclosure,
            showListRetry: actions.showListRetry,
            showPublicationRetry: actions.showPublicationRetry
        )
    }
}

struct FullLeaderboardListProjection {
    let pinnedExactEntry: SeedLeaderboardEntry?
    let publicEntries: [SeedLeaderboardEntry]

    static func resolve(
        entries: [SeedLeaderboardEntry],
        exactPublicEntry: SeedLeaderboardEntry?
    ) -> Self {
        Self(
            pinnedExactEntry: exactPublicEntry,
            publicEntries: entries.filter { $0.profile.id != exactPublicEntry?.profile.id }
        )
    }
}

enum CheckInAccountBinding {
    static func canContinue(expectedUID: String, currentUID: String?) -> Bool {
        currentUID == expectedUID
    }
}

enum CheckInTemporaryPhotoDisposition: Equatable {
    case keep
    case discard

    static func resolve(
        expectedUID: String,
        currentUID: String?,
        recordCreated: Bool
    ) -> Self {
        recordCreated ? .keep : .discard
    }
}

enum CheckInCloudIntent: Codable, Equatable {
    case deviceOnly
    case resolveServerAuthority
    case publishWithExistingConsent
    case optIn(publicAlias: String)
    case persistDecline
}

enum CheckInCloudOutboxItemState: Codable, Equatable {
    case pending
    case failed(message: String)
}

struct CheckInCloudOutboxItem: Codable, Equatable, Identifiable {
    let ownerUID: String
    let record: CheckInRecord
    let intent: CheckInCloudIntent
    let syncRequestID: String
    let expectedPreviousSyncRequestID: String?
    let createdAt: Date
    let officialRecordsSnapshot: [CheckInRecord]
    var state: CheckInCloudOutboxItemState

    var id: UUID { record.id }

    init(
        ownerUID: String,
        record: CheckInRecord,
        intent: CheckInCloudIntent,
        officialRecordsSnapshot: [CheckInRecord]? = nil,
        syncRequestID: String = UUID().uuidString,
        expectedPreviousSyncRequestID: String? = nil,
        createdAt: Date = .now,
        state: CheckInCloudOutboxItemState = .pending
    ) {
        self.ownerUID = ownerUID
        self.record = record
        self.intent = intent
        self.syncRequestID = syncRequestID
        self.expectedPreviousSyncRequestID = expectedPreviousSyncRequestID
        self.createdAt = createdAt
        self.officialRecordsSnapshot = Self.normalizedSnapshot(
            officialRecordsSnapshot ?? [record],
            including: record
        )
        self.state = state
    }

    var recordsToSync: [CheckInRecord] {
        Self.normalizedSnapshot(officialRecordsSnapshot, including: record)
    }

    var syncTicket: LeaderboardSyncTicket {
        LeaderboardSyncTicket(
            ownerUID: ownerUID,
            syncRequestID: syncRequestID,
            expectedPreviousSyncRequestID: expectedPreviousSyncRequestID
        )
    }

    private enum CodingKeys: String, CodingKey {
        case ownerUID
        case record
        case intent
        case syncRequestID
        case expectedPreviousSyncRequestID
        case createdAt
        case officialRecordsSnapshot
        case state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ownerUID = try container.decode(String.self, forKey: .ownerUID)
        record = try container.decode(CheckInRecord.self, forKey: .record)
        intent = try container.decode(CheckInCloudIntent.self, forKey: .intent)
        syncRequestID = try container.decode(String.self, forKey: .syncRequestID)
        expectedPreviousSyncRequestID = try container.decodeIfPresent(
            String.self,
            forKey: .expectedPreviousSyncRequestID
        )
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        let decodedSnapshot = try container.decodeIfPresent(
            [CheckInRecord].self,
            forKey: .officialRecordsSnapshot
        ) ?? [record]
        officialRecordsSnapshot = Self.normalizedSnapshot(decodedSnapshot, including: record)
        state = try container.decode(CheckInCloudOutboxItemState.self, forKey: .state)
    }

    private static func normalizedSnapshot(
        _ records: [CheckInRecord],
        including current: CheckInRecord
    ) -> [CheckInRecord] {
        var seen: Set<UUID> = []
        return (records + [current])
            .filter { seen.insert($0.id).inserted }
            .sorted {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.id.uuidString < $1.id.uuidString
            }
    }
}

enum CheckInCloudWorkEligibility {
    static func canExecute(item: CheckInCloudOutboxItem, currentUID: String?) -> Bool {
        currentUID == item.ownerUID
    }
}

enum CheckInCloudCompletion: Equatable {
    case synced
    case deviceOnly
    case superseded
}

struct CheckInCloudOutboxStatus: Equatable {
    let pendingCount: Int
    let failedCount: Int
    let lastError: String?

    var hasOutstandingWork: Bool { pendingCount + failedCount > 0 }
}

enum CheckInCloudOutboxError: LocalizedError {
    case accountChanged
    case authorityUnavailable
    case invalidPublicAlias

    var errorDescription: String? {
        switch self {
        case .accountChanged:
            "The signed-in account changed before this upload could finish."
        case .authorityUnavailable:
            "The server leaderboard setting is unavailable or still pending."
        case .invalidPublicAlias:
            "The public alias is no longer valid."
        }
    }
}

@MainActor
final class CheckInCloudOutboxStore: ObservableObject {
    @Published private(set) var items: [CheckInCloudOutboxItem]

    private let defaults: UserDefaults
    private let storageKey: String
    private var isReconciling = false
    private var completions: [String: CheckInCloudCompletion] = [:]

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "wildfrog.checkin-cloud-outbox.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CheckInCloudOutboxItem].self, from: data) {
            items = decoded.sorted { $0.createdAt < $1.createdAt }
        } else {
            items = []
        }
    }

    func enqueue(_ item: CheckInCloudOutboxItem) {
        guard self.item(ownerUID: item.ownerUID, recordID: item.id) == nil else { return }
        items.append(item)
        items.sort { $0.createdAt < $1.createdAt }
        persist()
    }

    func nextItem(for currentUID: String?) -> CheckInCloudOutboxItem? {
        guard let currentUID else { return nil }
        return items.first { $0.ownerUID == currentUID && $0.state == .pending }
            ?? items.first { $0.ownerUID == currentUID }
    }

    func item(ownerUID: String, recordID: UUID) -> CheckInCloudOutboxItem? {
        items.first { $0.ownerUID == ownerUID && $0.id == recordID }
    }

    func status(for ownerUID: String) -> CheckInCloudOutboxStatus {
        let ownerItems = items.filter { $0.ownerUID == ownerUID }
        let pendingCount = ownerItems.filter { $0.state == .pending }.count
        let errors = ownerItems.compactMap { item -> String? in
            guard case .failed(let message) = item.state else { return nil }
            return message
        }
        return CheckInCloudOutboxStatus(
            pendingCount: pendingCount,
            failedCount: errors.count,
            lastError: errors.last
        )
    }

    func completion(ownerUID: String, recordID: UUID) -> CheckInCloudCompletion? {
        completions[itemKey(ownerUID: ownerUID, recordID: recordID)]
    }

    func markFailed(ownerUID: String, recordID: UUID, message: String) {
        guard let index = items.firstIndex(where: { $0.ownerUID == ownerUID && $0.id == recordID }) else {
            return
        }
        items[index].state = .failed(message: message)
        persist()
    }

    func retry(ownerUID: String, recordID: UUID) {
        guard let index = items.firstIndex(where: { $0.ownerUID == ownerUID && $0.id == recordID }) else {
            return
        }
        items[index].state = .pending
        persist()
    }

    func retryAll(for ownerUID: String) {
        var didChange = false
        for index in items.indices where items[index].ownerUID == ownerUID {
            if case .failed = items[index].state {
                items[index].state = .pending
                didChange = true
            }
        }
        if didChange { persist() }
    }

    func removeAll(for ownerUID: String) {
        items.removeAll { $0.ownerUID == ownerUID }
        let ownerPrefix = "\(ownerUID)|"
        completions = completions.filter { !$0.key.hasPrefix(ownerPrefix) }
        persist()
    }

    func reconcile(authService: ProfileAuthService) async {
        guard !isReconciling else { return }
        isReconciling = true
        defer { isReconciling = false }

        guard let ownerUID = authService.session?.uid,
              let item = nextItem(for: ownerUID),
              CheckInCloudWorkEligibility.canExecute(item: item, currentUID: ownerUID) else {
            return
        }

        do {
            let outcome = try await execute(item: item, authService: authService)
            guard authService.session?.uid == item.ownerUID else { return }
            complete(item: item, outcome: outcome)

            if nextItem(for: ownerUID) != nil {
                await reconcileRemaining(authService: authService, ownerUID: ownerUID)
            }
        } catch is CancellationError {
            return
        } catch {
            guard authService.session?.uid == item.ownerUID else { return }
            markFailed(
                ownerUID: item.ownerUID,
                recordID: item.id,
                message: error.localizedDescription
            )
        }
    }

    private func reconcileRemaining(authService: ProfileAuthService, ownerUID: String) async {
        while authService.session?.uid == ownerUID,
              let item = nextItem(for: ownerUID) {
            do {
                let outcome = try await execute(item: item, authService: authService)
                guard authService.session?.uid == ownerUID else { return }
                complete(item: item, outcome: outcome)
            } catch is CancellationError {
                return
            } catch {
                guard authService.session?.uid == ownerUID else { return }
                markFailed(ownerUID: ownerUID, recordID: item.id, message: error.localizedDescription)
                return
            }
        }
    }

    private func execute(
        item: CheckInCloudOutboxItem,
        authService: ProfileAuthService
    ) async throws -> CheckInCloudCompletion {
        try ensureCurrentOwner(item: item, authService: authService)
        let service = FirestoreService()

        switch item.intent {
        case .deviceOnly:
            return .deviceOnly
        case .persistDecline:
            let outcome = try await service.persistLeaderboardDecline(ticket: item.syncTicket)
            try ensureCurrentOwner(item: item, authService: authService)
            return outcome == .superseded ? .superseded : .deviceOnly

        case .optIn(let publicAlias):
            guard let session = authService.session,
                  case .success = LeaderboardPublicAlias.validate(
                    publicAlias,
                    uid: session.uid,
                    email: session.email,
                    phoneNumber: session.phoneNumber
                  ) else {
                throw CheckInCloudOutboxError.invalidPublicAlias
            }
            do {
                try await service.beginLeaderboardPublication(
                    ticket: item.syncTicket,
                    publicAlias: publicAlias
                )
                try ensureCurrentOwner(item: item, authService: authService)
                try await service.syncOfficialCheckIns(
                    item.recordsToSync,
                    userId: item.ownerUID
                )
                try ensureCurrentOwner(item: item, authService: authService)
                try await service.finalizeLeaderboardPublication(
                    ticket: item.syncTicket,
                    publicAlias: publicAlias
                )
                try ensureCurrentOwner(item: item, authService: authService)
                return .synced
            } catch {
                try ensureCurrentOwner(item: item, authService: authService)
                let current = await service.fetchLeaderboardServerRead(userId: item.ownerUID)
                try ensureCurrentOwner(item: item, authService: authService)
                if case .loaded(let participation) = current,
                   !participation.isVisible,
                   !participation.publicationRequested {
                    return .deviceOnly
                }
                throw error
            }

        case .resolveServerAuthority, .publishWithExistingConsent:
            let serverRead = await service.fetchLeaderboardServerRead(userId: item.ownerUID)
            try ensureCurrentOwner(item: item, authService: authService)
            guard case .loaded(let participation) = serverRead else {
                throw CheckInCloudOutboxError.authorityUnavailable
            }
            guard participation.isVisible else {
                if !participation.publicationRequested {
                    return .deviceOnly
                }
                throw CheckInCloudOutboxError.authorityUnavailable
            }
            guard let session = authService.session,
                  let alias = participation.publicAlias,
                  case .success = LeaderboardPublicAlias.validate(
                    alias,
                    uid: session.uid,
                    email: session.email,
                    phoneNumber: session.phoneNumber
                  ) else {
                throw CheckInCloudOutboxError.invalidPublicAlias
            }
            try await service.recordCheckIn(
                id: item.record.id,
                userId: item.ownerUID,
                mountainId: item.record.mountainId,
                date: item.record.date
            )
            try ensureCurrentOwner(item: item, authService: authService)
            return .synced
        }
    }

    private func ensureCurrentOwner(
        item: CheckInCloudOutboxItem,
        authService: ProfileAuthService
    ) throws {
        try Task.checkCancellation()
        guard CheckInCloudWorkEligibility.canExecute(
            item: item,
            currentUID: authService.session?.uid
        ) else {
            throw CheckInCloudOutboxError.accountChanged
        }
    }

    private func complete(item: CheckInCloudOutboxItem, outcome: CheckInCloudCompletion) {
        completions[itemKey(ownerUID: item.ownerUID, recordID: item.id)] = outcome
        items.removeAll { $0.ownerUID == item.ownerUID && $0.id == item.id }
        persist()
    }

    private func itemKey(ownerUID: String, recordID: UUID) -> String {
        "\(ownerUID)|\(recordID.uuidString)"
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
