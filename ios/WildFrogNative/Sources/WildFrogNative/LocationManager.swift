import CoreLocation
import Foundation

struct LocationAcquisitionState: Equatable {
    private var consumers: Set<UUID> = []

    var activeCount: Int { consumers.count }
    var isActive: Bool { !consumers.isEmpty }

    /// Returns true only when this acquisition transitions the shared manager
    /// from zero active consumers to one.
    mutating func acquire(_ consumerID: UUID) -> Bool {
        let wasEmpty = consumers.isEmpty
        guard consumers.insert(consumerID).inserted else { return false }
        return wasEmpty
    }

    /// Returns true only when this release removes the final active consumer.
    mutating func release(_ consumerID: UUID) -> Bool {
        guard consumers.remove(consumerID) != nil else { return false }
        return consumers.isEmpty
    }
}

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var systemAuthorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?

    /// Coordinate override for developer QA and approved reviewer/tester
    /// accounts. The UI decides who can set this; when set, distance and auth
    /// gating behave as if the user is standing at this coordinate.
    @Published var mockCoordinate: CLLocationCoordinate2D? {
        didSet {
            persistMock()
            if mockCoordinate != nil {
                manager.stopUpdatingLocation()
            } else if acquisitions.isActive {
                manager.startUpdatingLocation()
            }
        }
    }
    private static let mockOnKey = "wildfrog.location.simulator.on"
    private static let mockLatKey = "wildfrog.location.simulator.lat"
    private static let mockLonKey = "wildfrog.location.simulator.lon"

    private let manager = CLLocationManager()
    private var acquisitions = LocationAcquisitionState()

    override init() {
        systemAuthorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        loadMock()
    }

    /// Authorization seen by the rest of the app. A reviewer/developer mock
    /// counts as authorized so location-gated test flows work without real GPS.
    var authorizationStatus: CLAuthorizationStatus {
        if mockCoordinate != nil { return .authorizedWhenInUse }
        return systemAuthorizationStatus
    }

    /// Location used for all distance maths — the mock when set, else real GPS.
    var resolvedLocation: CLLocation? {
        if let mock = mockCoordinate {
            return CLLocation(latitude: mock.latitude, longitude: mock.longitude)
        }
        return currentLocation
    }

    func requestAuthorization() {
        guard mockCoordinate == nil else { return }
        guard systemAuthorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating(for consumerID: UUID) {
        let shouldStart = acquisitions.acquire(consumerID)
        guard shouldStart, mockCoordinate == nil else { return }
        manager.startUpdatingLocation()
    }

    func stopUpdating(for consumerID: UUID) {
        guard acquisitions.release(consumerID) else { return }
        manager.stopUpdatingLocation()
    }

    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let origin = resolvedLocation else { return nil }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return origin.distance(from: target)
    }

    private func persistMock() {
        let defaults = UserDefaults.standard
        if let mock = mockCoordinate {
            defaults.set(true, forKey: Self.mockOnKey)
            defaults.set(mock.latitude, forKey: Self.mockLatKey)
            defaults.set(mock.longitude, forKey: Self.mockLonKey)
        } else {
            defaults.set(false, forKey: Self.mockOnKey)
        }
    }

    private func loadMock() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Self.mockOnKey) else { return }
        mockCoordinate = CLLocationCoordinate2D(
            latitude: defaults.double(forKey: Self.mockLatKey),
            longitude: defaults.double(forKey: Self.mockLonKey)
        )
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.systemAuthorizationStatus = status
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Location failures are non-fatal; keep the last known fix.
    }
}
