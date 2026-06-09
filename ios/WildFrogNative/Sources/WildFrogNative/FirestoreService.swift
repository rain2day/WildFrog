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
}
