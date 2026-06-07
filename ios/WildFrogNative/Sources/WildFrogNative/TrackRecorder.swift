import CoreLocation
import Foundation

/// Records a live hike using its own `CLLocationManager` instance, accumulating
/// haversine distance and positive-delta ascent as fixes arrive.
@MainActor
final class TrackRecorder: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var ascentMeters: Double = 0
    @Published private(set) var points: [TrackPoint] = []

    private let manager = CLLocationManager()
    private var timer: Timer?
    private var startDate: Date?
    private var lastLocation: CLLocation?
    private var lastElevation: Double?

    /// Discards fixes that are too inaccurate or stale to trust for distance math.
    private let horizontalAccuracyThreshold: CLLocationAccuracy = 50

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = kCLDistanceFilterNone
    }

    // MARK: - Control

    func start() {
        guard !isRecording else { return }

        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        distanceMeters = 0
        ascentMeters = 0
        elapsedSeconds = 0
        points = []
        lastLocation = nil
        lastElevation = nil
        startDate = Date()
        isRecording = true

        manager.startUpdatingLocation()
        startTimer()
    }

    /// Stops recording and returns the finished `Track` (nil if no points were captured).
    @discardableResult
    func stop() -> Track? {
        guard isRecording else { return nil }
        isRecording = false
        manager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil

        let start = startDate ?? points.first?.timestamp ?? Date()
        let end = points.last?.timestamp ?? Date()

        guard !points.isEmpty else {
            reset()
            return nil
        }

        let track = Track(
            name: defaultName(for: start),
            points: points,
            distanceMeters: distanceMeters,
            durationSeconds: max(elapsedSeconds, end.timeIntervalSince(start)),
            ascentMeters: ascentMeters,
            startDate: start,
            endDate: end
        )
        reset()
        return track
    }

    // MARK: - Derived helpers

    private func defaultName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_HK")
        formatter.dateFormat = "M月d日 HH:mm 軌跡"
        return formatter.string(from: date)
    }

    private func reset() {
        startDate = nil
        lastLocation = nil
        lastElevation = nil
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startDate = self.startDate, self.isRecording else { return }
                self.elapsedSeconds = Date().timeIntervalSince(startDate)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        let fixes = locations
        Task { @MainActor in
            self.ingest(fixes)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Transient GPS failures are non-fatal; keep accumulating from the next fix.
    }

    private func ingest(_ locations: [CLLocation]) {
        guard isRecording else { return }
        for location in locations {
            guard location.horizontalAccuracy >= 0,
                  location.horizontalAccuracy <= horizontalAccuracyThreshold else { continue }

            if let last = lastLocation {
                let step = location.distance(from: last)
                // Ignore jitter while standing still.
                if step >= 1 {
                    distanceMeters += step
                }
            }

            if location.verticalAccuracy >= 0 {
                if let previousElevation = lastElevation {
                    let delta = location.altitude - previousElevation
                    if delta > 0 {
                        ascentMeters += delta
                    }
                }
                lastElevation = location.altitude
            }

            points.append(
                TrackPoint(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    elevation: location.verticalAccuracy >= 0 ? location.altitude : nil,
                    timestamp: location.timestamp
                )
            )
            lastLocation = location
        }
    }
}
