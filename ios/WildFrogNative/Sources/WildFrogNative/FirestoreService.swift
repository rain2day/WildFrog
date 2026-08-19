import Foundation
#if canImport(FirebaseFirestore)
@preconcurrency import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
@preconcurrency import FirebaseAuth
#endif

enum LeaderboardProfileDecoder {
    static func decode(
        documentID: String,
        data: [String: Any],
        index: Int
    ) -> SeedHikerProfile? {
        guard (data["isVisible"] as? Bool) == true else { return nil }
        if let publicAlias = nonEmptyString(data["publicAlias"]) {
            return realProfile(
                documentID: documentID,
                publicAlias: publicAlias,
                data: data,
                index: index
            )
        }

        guard let displayName = nonEmptyString(data["displayName"])
                ?? nonEmptyString(data["name"])
                ?? nonEmptyString(data["nickname"]),
              let monthScore = numericValue(data["monthScore"]),
              let totalScore = numericValue(data["totalScore"]),
              let distinctPeaks = numericValue(data["distinctPeaks"]) else { return nil }

        return SeedHikerProfile(
            id: documentID,
            name: displayName,
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

    private static func realProfile(
        documentID: String,
        publicAlias: String,
        data: [String: Any],
        index: Int
    ) -> SeedHikerProfile {
        let monthly = data["monthlyCheckIns"] as? [String: Any]
        let monthScore = numericValue(monthly?[LeaderboardMonth.key()]) ?? 0
        let totalScore = numericValue(data["totalCheckIns"]) ?? monthScore
        let distinctPeaks = numericValue(data["distinctPeaks"]) ?? min(totalScore, MountainCatalog.catalogCount)

        return SeedHikerProfile(
            id: documentID,
            name: publicAlias,
            homeRegion: "香港",
            style: "山友",
            titleMountainId: nil,
            heroMountainId: "lantau-peak",
            progressSeed: 10_000 + index,
            baseMonthCheckIns: max(0, monthScore),
            baseTotalCheckIns: max(0, totalScore),
            baseDistinctPeaks: max(0, distinctPeaks),
            cadenceDays: 999_999,
            weekendCycle: 999_999,
            isServerDerived: true
        )
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func validMountainID(_ value: Any?) -> String? {
        guard let id = nonEmptyString(value),
              MountainCatalog.mountains.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    private static func numericValue(_ value: Any?) -> Int? {
        switch value {
        case let value as Int: value
        case let value as Int64: Int(value)
        case let value as Double: Int(value)
        case let value as NSNumber: value.intValue
        case let value as String: Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        default: nil
        }
    }
}

struct FirestoreService {
    enum FirestoreServiceError: Error {
        case sdkUnavailable
        case invalidPublicAlias
        case accountMismatch
        case staleSyncRequest
        case accountDeletionFinal
        case deletionCleanupUnconfirmed
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func recordCheckIn(id: UUID, userId: String, mountainId: String, date: Date) async throws {
        #if canImport(FirebaseFirestore)
        try requireCurrentAuthenticatedUser(userId)
        let data: [String: Any] = [
            "clientId": id.uuidString,
            "userId": userId,
            "mountainId": mountainId,
            "dayKey": Self.dayKeyFormatter.string(from: date),
            "checkInAt": Timestamp(date: date),
            "createdAt": FieldValue.serverTimestamp(),
        ]
        try await Firestore.firestore()
            .collection("checkIns")
            .document(id.uuidString)
            .setData(data, merge: true)
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    func fetchUserCheckIns(userId: String) async throws -> [CheckInRecord] {
        #if canImport(FirebaseFirestore)
        let snapshot = try await Firestore.firestore()
            .collection("checkIns")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt")
            .getDocuments()

        return snapshot.documents.compactMap { document -> CheckInRecord? in
            let data = document.data()
            guard let mountainId = data["mountainId"] as? String else { return nil }

            let date: Date
            if let timestamp = data["checkInAt"] as? Timestamp {
                date = timestamp.dateValue()
            } else if let timestamp = data["createdAt"] as? Timestamp {
                date = timestamp.dateValue()
            } else {
                date = Date()
            }

            let clientId = (data["clientId"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
            return CheckInRecord(
                id: clientId,
                mountainId: mountainId,
                date: date,
                photoFilename: nil
            )
        }
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    func deleteUserCheckIns(userId: String) async throws {
        #if canImport(FirebaseFirestore)
        let snapshot = try await Firestore.firestore()
            .collection("checkIns")
            .whereField("userId", isEqualTo: userId)
            .getDocuments(source: .server)
        for document in snapshot.documents {
            try await document.reference.delete()
        }
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    func fetchLeaderboardParticipation(userId: String) async throws -> LeaderboardParticipation? {
        #if canImport(FirebaseFirestore)
        let document = try await Firestore.firestore()
            .collection("leaderboardOptIns")
            .document(userId)
            .getDocument(source: .server)
        guard document.exists, let data = document.data(),
              let isVisible = data["isVisible"] as? Bool else { return nil }

        return LeaderboardParticipation(
            isVisible: isVisible,
            publicAlias: stringValue(data["publicAlias"]),
            migrationVersion: intValue(data["migrationVersion"]) ?? 1,
            publicProfileId: stringValue(data["publicProfileId"]),
            publicationRequested: (data["publicationRequested"] as? Bool) ?? isVisible,
            syncRequestId: stringValue(data["syncRequestId"]),
            completedSyncRequestId: stringValue(data["completedSyncRequestId"])
        )
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    func setLeaderboardParticipation(
        userId: String,
        publicAlias: String?,
        isVisible: Bool
    ) async throws {
        #if canImport(FirebaseFirestore)
        try requireCurrentAuthenticatedUser(userId)
        guard !isVisible else {
            // Publication must always use `finalizeLeaderboardPublication`,
            // whose transaction checks the exact originating request.
            throw FirestoreServiceError.staleSyncRequest
        }
        let trimmedAlias = publicAlias?.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestID = UUID().uuidString
        var data: [String: Any] = [
            "isVisible": false,
            "publicationRequested": false,
            "migrationVersion": 1,
            "syncRequestId": requestID,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let trimmedAlias, !trimmedAlias.isEmpty {
            data["publicAlias"] = trimmedAlias
        }
        let database = Firestore.firestore()
        let preferenceReference = database.collection("leaderboardOptIns").document(userId)
        let tombstoneReference = database.collection("leaderboardDeletionTombstones").document(userId)
        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let tombstone = try transaction.getDocument(tombstoneReference)
                guard !tombstone.exists else {
                    Self.rejectTransaction(errorPointer, error: .accountDeletionFinal)
                    return nil
                }
                transaction.setData(data, forDocument: preferenceReference, merge: true)
                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    func persistLeaderboardDecline(
        ticket: LeaderboardSyncTicket
    ) async throws -> LeaderboardDeclineMutationOutcome {
        #if canImport(FirebaseFirestore)
        try requireCurrentAuthenticatedUser(ticket.ownerUID)
        let database = Firestore.firestore()
        let preferenceReference = database.collection("leaderboardOptIns").document(ticket.ownerUID)
        let tombstoneReference = database.collection("leaderboardDeletionTombstones").document(ticket.ownerUID)
        let rawOutcome = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let tombstone = try transaction.getDocument(tombstoneReference)
                let preference = try transaction.getDocument(preferenceReference)
                let outcome = LeaderboardConditionalMutation.declineOutcome(
                    ticket: ticket,
                    currentUID: ticket.ownerUID,
                    currentParticipation: Self.participation(from: preference.data()),
                    hasAccountDeletionTombstone: tombstone.exists
                )
                guard outcome == .apply else { return outcome.rawValue }
                transaction.setData([
                    "isVisible": false,
                    "publicationRequested": false,
                    "publicAlias": FieldValue.delete(),
                    "migrationVersion": 1,
                    "syncRequestId": ticket.syncRequestID,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: preferenceReference, merge: true)
                return outcome.rawValue
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }
        guard let rawValue = rawOutcome as? String,
              let outcome = LeaderboardDeclineMutationOutcome(rawValue: rawValue) else {
            throw FirestoreServiceError.staleSyncRequest
        }
        return outcome
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    func beginLeaderboardPublication(
        ticket: LeaderboardSyncTicket,
        publicAlias: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        try requireCurrentAuthenticatedUser(ticket.ownerUID)
        let trimmedAlias = publicAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAlias.isEmpty, trimmedAlias.unicodeScalars.count <= 24 else {
            throw FirestoreServiceError.invalidPublicAlias
        }
        let database = Firestore.firestore()
        let preferenceReference = database.collection("leaderboardOptIns").document(ticket.ownerUID)
        let tombstoneReference = database.collection("leaderboardDeletionTombstones").document(ticket.ownerUID)
        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let tombstone = try transaction.getDocument(tombstoneReference)
                guard !tombstone.exists else {
                    Self.rejectTransaction(errorPointer, error: .accountDeletionFinal)
                    return nil
                }
                let preference = try transaction.getDocument(preferenceReference)
                let data = preference.data()
                let currentRequestID = Self.nonEmptyString(data?["syncRequestId"])
                let currentAlias = Self.nonEmptyString(data?["publicAlias"])
                let isIdempotentRetry = currentRequestID == ticket.syncRequestID
                    && data?["publicationRequested"] as? Bool == true
                    && currentAlias == trimmedAlias
                if isIdempotentRetry { return nil }

                guard currentRequestID == ticket.expectedPreviousSyncRequestID else {
                    Self.rejectTransaction(errorPointer, error: .staleSyncRequest)
                    return nil
                }
                transaction.setData([
                "isVisible": false,
                "publicationRequested": true,
                "publicAlias": trimmedAlias,
                "migrationVersion": 1,
                "syncRequestId": ticket.syncRequestID,
                "consentedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: preferenceReference, merge: true)
                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    func finalizeLeaderboardPublication(
        ticket: LeaderboardSyncTicket,
        publicAlias: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        try requireCurrentAuthenticatedUser(ticket.ownerUID)
        let trimmedAlias = publicAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAlias.isEmpty, trimmedAlias.unicodeScalars.count <= 24 else {
            throw FirestoreServiceError.invalidPublicAlias
        }
        let database = Firestore.firestore()
        let preferenceReference = database.collection("leaderboardOptIns").document(ticket.ownerUID)
        let tombstoneReference = database.collection("leaderboardDeletionTombstones").document(ticket.ownerUID)
        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let tombstone = try transaction.getDocument(tombstoneReference)
                let preference = try transaction.getDocument(preferenceReference)
                let data = preference.data()
                let participation = Self.participation(from: data)
                guard LeaderboardConditionalMutation.canFinalize(
                    ticket: ticket,
                    currentUID: ticket.ownerUID,
                    currentParticipation: participation,
                    hasAccountDeletionTombstone: tombstone.exists
                ), Self.nonEmptyString(data?["publicAlias"]) == trimmedAlias else {
                    Self.rejectTransaction(
                        errorPointer,
                        error: tombstone.exists ? .accountDeletionFinal : .staleSyncRequest
                    )
                    return nil
                }
                if data?["isVisible"] as? Bool == true { return nil }
                transaction.updateData([
                    "isVisible": true,
                    "publicationRequested": true,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: preferenceReference)
                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    func renameLeaderboardPublicAlias(
        ticket: LeaderboardSyncTicket,
        publicAlias: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        try requireCurrentAuthenticatedUser(ticket.ownerUID)
        let trimmedAlias = publicAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAlias.isEmpty, trimmedAlias.unicodeScalars.count <= 24 else {
            throw FirestoreServiceError.invalidPublicAlias
        }
        let database = Firestore.firestore()
        let preferenceReference = database.collection("leaderboardOptIns").document(ticket.ownerUID)
        let tombstoneReference = database.collection("leaderboardDeletionTombstones").document(ticket.ownerUID)
        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let tombstone = try transaction.getDocument(tombstoneReference)
                let preference = try transaction.getDocument(preferenceReference)
                let data = preference.data()
                guard !tombstone.exists,
                      preference.exists,
                      data?["isVisible"] as? Bool == true,
                      data?["publicationRequested"] as? Bool == true else {
                    Self.rejectTransaction(
                        errorPointer,
                        error: tombstone.exists ? .accountDeletionFinal : .staleSyncRequest
                    )
                    return nil
                }
                let currentRequestID = Self.nonEmptyString(data?["syncRequestId"])
                let currentAlias = Self.nonEmptyString(data?["publicAlias"])
                let isIdempotentRetry = currentRequestID == ticket.syncRequestID
                    && currentAlias == trimmedAlias
                if isIdempotentRetry { return nil }
                guard currentRequestID == ticket.expectedPreviousSyncRequestID else {
                    Self.rejectTransaction(errorPointer, error: .staleSyncRequest)
                    return nil
                }
                transaction.updateData([
                    "publicAlias": trimmedAlias,
                    "syncRequestId": ticket.syncRequestID,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: preferenceReference)
                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    func fetchLeaderboardServerRead(userId: String) async -> LeaderboardServerRead {
        do {
            if let participation = try await fetchLeaderboardParticipation(userId: userId) {
                return .loaded(participation)
            }
            return .missing
        } catch {
            return .failed
        }
    }

    func fetchLeaderboardPublicationState(
        userId: String,
        hasLocalHistoricalCheckIns: Bool
    ) async -> LeaderboardPublicationState {
        let serverRead = await fetchLeaderboardServerRead(userId: userId)
        switch serverRead {
        case .failed:
            return .failed
        case .unknown:
            return .unknown
        case .missing:
            do {
                let hasCloudHistory = try await hasOfficialCheckIns(userId: userId)
                return .missing(hasHistoricalCheckIns: hasLocalHistoricalCheckIns || hasCloudHistory)
            } catch {
                return .failed
            }
        case .loaded(let participation):
            if participation.publicationRequested && !participation.isVisible {
                return .pending(participation)
            }
            guard participation.isVisible else { return .declined(participation) }
            guard let publicProfileId = participation.publicProfileId else {
                return .pending(participation)
            }
            do {
                let readbackAlias = try await fetchVisiblePublicAlias(id: publicProfileId)
                return LeaderboardPublicationResolver.resolve(
                    serverRead: .loaded(participation),
                    hasHistoricalCheckIns: hasLocalHistoricalCheckIns,
                    hasPublicProfileReadback: LeaderboardPublicationResolver.hasMatchingPublicReadback(
                        participation: participation,
                        publicAlias: readbackAlias
                    )
                )
            } catch {
                return .failed
            }
        }
    }

    func hasOfficialCheckIns(userId: String) async throws -> Bool {
        #if canImport(FirebaseFirestore)
        let snapshot = try await Firestore.firestore()
            .collection("checkIns")
            .whereField("userId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments(source: .server)
        return !snapshot.documents.isEmpty
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    func fetchVisiblePublicAlias(id: String) async throws -> String? {
        #if canImport(FirebaseFirestore)
        let document = try await Firestore.firestore()
            .collection("leaderboardProfiles")
            .document(id)
            .getDocument(source: .server)
        guard document.exists,
              (document.data()?["isVisible"] as? Bool) == true else { return nil }
        return Self.nonEmptyString(document.data()?["publicAlias"])
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    @discardableResult
    func requestLeaderboardRebuild(
        userId: String,
        expectedSyncRequestID: String
    ) async throws -> String {
        #if canImport(FirebaseFirestore)
        try requireCurrentAuthenticatedUser(userId)
        let nextRequestID = UUID().uuidString
        let database = Firestore.firestore()
        let preferenceReference = database.collection("leaderboardOptIns").document(userId)
        let tombstoneReference = database.collection("leaderboardDeletionTombstones").document(userId)
        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let tombstone = try transaction.getDocument(tombstoneReference)
                let preference = try transaction.getDocument(preferenceReference)
                let data = preference.data()
                guard !tombstone.exists,
                      preference.exists,
                      data?["isVisible"] as? Bool == true,
                      data?["publicationRequested"] as? Bool == true,
                      Self.nonEmptyString(data?["syncRequestId"]) == expectedSyncRequestID else {
                    Self.rejectTransaction(
                        errorPointer,
                        error: tombstone.exists ? .accountDeletionFinal : .staleSyncRequest
                    )
                    return nil
                }
                transaction.updateData([
                    "syncRequestId": nextRequestID,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: preferenceReference)
                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }
        return nextRequestID
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    func deleteLeaderboardParticipation(
        userId: String,
        proposedDeletionRequestID: String
    ) async throws -> String {
        #if canImport(FirebaseFirestore)
        try requireCurrentAuthenticatedUser(userId)
        let database = Firestore.firestore()
        let preferenceReference = database.collection("leaderboardOptIns").document(userId)
        let tombstoneReference = database.collection("leaderboardDeletionTombstones").document(userId)
        let cleanupRequestReference = database.collection("leaderboardDeletionCleanupRequests").document(userId)
        let result = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let tombstone = try transaction.getDocument(tombstoneReference)
                _ = try transaction.getDocument(preferenceReference)
                let tombstoneRequestID = Self.nonEmptyString(
                    tombstone.data()?["deletionRequestId"]
                )
                let plan = AccountDeletionRequestPlan.resolve(
                    tombstoneRequestID: tombstoneRequestID,
                    proposedRequestID: proposedDeletionRequestID
                )
                if !tombstone.exists {
                    transaction.setData([
                        "deletionRequested": true,
                        "deletionRequestId": plan.requestID,
                        "deletedAt": FieldValue.serverTimestamp()
                    ], forDocument: tombstoneReference)
                }
                transaction.setData([
                    "deletionRequestId": plan.requestID,
                    "requestedAt": FieldValue.serverTimestamp()
                ], forDocument: cleanupRequestReference)
                transaction.deleteDocument(preferenceReference)
                return plan.requestID
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }
        guard let deletionRequestID = result as? String else {
            throw FirestoreServiceError.deletionCleanupUnconfirmed
        }
        return deletionRequestID
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    func waitForLeaderboardDeletionCleanup(
        userId: String,
        deletionRequestID: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        let tombstoneReference = Firestore.firestore()
            .collection("leaderboardDeletionTombstones")
            .document(userId)
        for attempt in 0..<60 {
            try requireCurrentAuthenticatedUser(userId)
            let snapshot = try await tombstoneReference.getDocument(source: .server)
            let completedRequestID = Self.nonEmptyString(
                snapshot.data()?["cleanupCompletedRequestId"]
            )
            if AccountDeletionCleanupAcknowledgement.matches(
                requestID: deletionRequestID,
                completedRequestID: completedRequestID
            ) {
                return
            }
            if attempt < 59 {
                try await Task.sleep(for: .milliseconds(500))
            }
        }
        throw FirestoreServiceError.deletionCleanupUnconfirmed
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    func syncOfficialCheckIns(_ records: [CheckInRecord], userId: String) async throws {
        for record in records {
            try await recordCheckIn(
                id: record.id,
                userId: userId,
                mountainId: record.mountainId,
                date: record.date
            )
        }
    }

    func fetchLeaderboardProfiles() async throws -> [SeedHikerProfile] {
        #if canImport(FirebaseFirestore)
        let snapshot = try await Firestore.firestore()
            .collection("leaderboardProfiles")
            .whereField("isVisible", isEqualTo: true)
            .getDocuments(source: .server)

        return snapshot.documents.enumerated().compactMap { index, document in
            LeaderboardProfileDecoder.decode(
                documentID: document.documentID,
                data: document.data(),
                index: index
            )
        }
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    private func stringValue(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let int64 as Int64:
            return Int(int64)
        case let double as Double:
            return Int(double)
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private func requireCurrentAuthenticatedUser(_ userId: String) throws {
        #if canImport(FirebaseAuth)
        guard Auth.auth().currentUser?.uid == userId else {
            throw FirestoreServiceError.accountMismatch
        }
        #endif
    }

    private static func participation(from data: [String: Any]?) -> LeaderboardParticipation? {
        guard let data,
              let isVisible = data["isVisible"] as? Bool else { return nil }
        return LeaderboardParticipation(
            isVisible: isVisible,
            publicAlias: nonEmptyString(data["publicAlias"]),
            migrationVersion: (data["migrationVersion"] as? NSNumber)?.intValue ?? 1,
            publicProfileId: nonEmptyString(data["publicProfileId"]),
            publicationRequested: (data["publicationRequested"] as? Bool) ?? isVisible,
            syncRequestId: nonEmptyString(data["syncRequestId"]),
            completedSyncRequestId: nonEmptyString(data["completedSyncRequestId"])
        )
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func rejectTransaction(
        _ errorPointer: AutoreleasingUnsafeMutablePointer<NSError?>?,
        error: FirestoreServiceError
    ) {
        let code: Int
        let message: String
        switch error {
        case .staleSyncRequest:
            code = 1
            message = "The leaderboard request was superseded by a newer decision."
        case .accountDeletionFinal:
            code = 2
            message = "Account deletion is final for leaderboard publication."
        default:
            code = 3
            message = "The leaderboard transaction could not be completed."
        }
        errorPointer?.pointee = NSError(
            domain: "WildFrog.LeaderboardTransaction",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

}
