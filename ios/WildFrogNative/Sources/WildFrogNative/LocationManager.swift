import CoreLocation
import Foundation

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var systemAuthorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?

    #if DEBUG
    /// Developer-only location override (DEBUG builds only — never ships to
    /// TestFlight/Release). When set, distance + auth gating behave as if the
    /// user is standing at this coordinate, so check-in can be tested anywhere.
    @Published var mockCoordinate: CLLocationCoordinate2D? {
        didSet { persistMock() }
    }
    private static let mockOnKey = "wildfrog.debug.mock.on"
    private static let mockLatKey = "wildfrog.debug.mock.lat"
    private static let mockLonKey = "wildfrog.debug.mock.lon"
    #endif

    private let manager = CLLocationManager()

    override init() {
        systemAuthorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        #if DEBUG
        loadMock()
        #endif
    }

    /// Authorization seen by the rest of the app. A DEBUG mock counts as
    /// authorized so location-gated test flows work without real GPS.
    var authorizationStatus: CLAuthorizationStatus {
        #if DEBUG
        if mockCoordinate != nil { return .authorizedWhenInUse }
        #endif
        return systemAuthorizationStatus
    }

    /// Location used for all distance maths — the mock when set, else real GPS.
    var resolvedLocation: CLLocation? {
        #if DEBUG
        if let mock = mockCoordinate {
            return CLLocation(latitude: mock.latitude, longitude: mock.longitude)
        }
        #endif
        return currentLocation
    }

    func requestAuthorization() {
        guard systemAuthorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let origin = resolvedLocation else { return nil }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return origin.distance(from: target)
    }

    #if DEBUG
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
    #endif

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
