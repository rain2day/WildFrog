import Foundation
import HealthKit

enum TripEnergyError: LocalizedError {
    case unavailable
    case missingTripDates

    var errorDescription: String? {
        switch self {
        case .unavailable:
            AppText.value(zh: "此裝置未能讀取 Apple 健康資料。", en: "Apple Health data is unavailable on this device.")
        case .missingTripDates:
            AppText.value(zh: "行程未有完整開始及完成時間。", en: "This trip has no complete start and finish time.")
        }
    }
}

protocol TripEnergyProviding: Sendable {
    /// Returns `nil` when Health has no samples at all for the window, which is
    /// meaningfully different from a real 0 kcal reading: the UI keeps offering
    /// the connect/retry button instead of claiming the trip burned nothing.
    func requestAccessAndReadActiveEnergy(from start: Date, to end: Date) async throws -> Double?
}

final class AppleHealthTripEnergyProvider: TripEnergyProviding, @unchecked Sendable {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    func requestAccessAndReadActiveEnergy(from start: Date, to end: Date) async throws -> Double? {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw TripEnergyError.unavailable
        }

        try await healthStore.requestAuthorization(toShare: [], read: [type])
        // No strict date options: an active-energy sample that straddles the
        // start or the finish of the trip still belongs to it, and dropping
        // those samples systematically under-reports short trips.
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()))
            }
            healthStore.execute(query)
        }
    }
}
