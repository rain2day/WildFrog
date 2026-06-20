import Foundation
#if canImport(FirebaseFirestore)
@preconcurrency import FirebaseFirestore
#endif

struct FirestoreService {
    enum FirestoreServiceError: Error {
        case sdkUnavailable
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
        let data: [String: Any] = [
            "clientId": id.uuidString,
            "userId": userId,
            "mountainId": mountainId,
            "dayKey": Self.dayKeyFormatter.string(from: date),
            "createdAt": FieldValue.serverTimestamp(),
        ]
        try await Firestore.firestore().collection("checkIns").addDocument(data: data)
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
            if let timestamp = data["createdAt"] as? Timestamp {
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
            .getDocuments()
        for document in snapshot.documents {
            try await document.reference.delete()
        }
        #else
        throw FirestoreServiceError.sdkUnavailable
        #endif
    }

    func fetchLeaderboardProfiles(limit: Int = 100) async throws -> [SeedHikerProfile] {
        #if canImport(FirebaseFirestore)
        let snapshot = try await Firestore.firestore()
            .collection("leaderboardProfiles")
            .whereField("isVisible", isEqualTo: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.enumerated().compactMap { index, document in
            let data = document.data()
            guard (data["isVisible"] as? Bool) == true else { return nil }

            let name = stringValue(data["displayName"])
                ?? stringValue(data["name"])
                ?? stringValue(data["nickname"])
            guard let name, !name.isEmpty else { return nil }

            let monthScore = intValue(data["monthScore"]) ?? intValue(data["monthlyCheckIns"]) ?? 0
            let totalScore = intValue(data["totalScore"]) ?? intValue(data["totalCheckIns"]) ?? monthScore
            let distinctPeaks = intValue(data["distinctPeaks"]) ?? intValue(data["peakCount"]) ?? min(totalScore, MountainCatalog.catalogCount)
            let heroMountainId = validMountainId(data["heroMountainId"]) ?? validMountainId(data["avatarMountainId"]) ?? "lantau-peak"

            return SeedHikerProfile(
                id: document.documentID,
                name: name,
                homeRegion: stringValue(data["homeRegion"]) ?? "香港",
                style: stringValue(data["style"]) ?? "山友",
                titleMountainId: validMountainId(data["titleMountainId"]),
                heroMountainId: heroMountainId,
                progressSeed: 10_000 + index,
                baseMonthCheckIns: max(0, monthScore),
                baseTotalCheckIns: max(0, totalScore),
                baseDistinctPeaks: max(0, distinctPeaks),
                cadenceDays: 999_999,
                weekendCycle: 999_999
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

    private func validMountainId(_ value: Any?) -> String? {
        guard let id = stringValue(value) else { return nil }
        return MountainCatalog.mountains.contains { $0.id == id } ? id : nil
    }
}
