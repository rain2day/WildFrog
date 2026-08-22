import CoreLocation
import Foundation

@MainActor
protocol TrackRecording: AnyObject {
    var isRecording: Bool { get }
    var isPaused: Bool { get }
    var elapsedSeconds: TimeInterval { get }
    var distanceMeters: Double { get }
    var ascentMeters: Double { get }
    var points: [TrackPoint] { get }

    /// Returns false when a recording is already in flight (nothing is started).
    @discardableResult
    func start(
        mountainId: String?,
        mountainName: String,
        summitCoordinate: CLLocationCoordinate2D?
    ) -> Bool
    func restore(
        checkpoint: TripSessionCheckpoint,
        mountainId: String?,
        mountainName: String,
        summitCoordinate: CLLocationCoordinate2D?
    )
    func pause()
    func resume()
    func stop() -> Track?
    func cancel()
}

/// Records a live hike using its own `CLLocationManager` instance, accumulating
/// haversine distance and positive-delta ascent as fixes arrive. Supports
/// pause/resume — paused time never counts toward duration, and the position
/// jump across a pause never counts toward distance — and drives the Live
/// Activity (elapsed, distance, summit approach progress, paused state).
@MainActor
final class TrackRecorder: NSObject, ObservableObject, CLLocationManagerDelegate, TrackRecording {
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var ascentMeters: Double = 0
    @Published private(set) var points: [TrackPoint] = []
    /// Live distance from the latest fix to the summit checkpoint (nil before a fix).
    @Published private(set) var distanceToSummitMeters: Double?
    @Published private(set) var activeMountainId: String?
    @Published private(set) var activeMountainName = ""

    /// The one live instance (owned by the app as a `@StateObject`); lets the
    /// Live Activity pause/resume intent reach the recorder.
    private(set) static weak var shared: TrackRecorder?

    /// Posted by `TrackPauseResumeIntent` (which also compiles in the widget
    /// target, so it relays by notification instead of touching app state).
    static let togglePauseNotification = Notification.Name("wildfrog.track.togglePause")

    #if canImport(ActivityKit)
    private let liveActivity = TrackLiveActivityController()
    #endif

    private let manager = CLLocationManager()
    private var timer: Timer?
    private var startDate: Date?
    private var lastLocation: CLLocation?
    private var lastElevation: Double?

    // Pause bookkeeping: duration = closed segments + the currently open one.
    private var accumulatedSeconds: TimeInterval = 0
    private var segmentStart: Date?
    /// After resume, the first fix re-anchors position without adding distance.
    private var resumeGapPending = false

    // Summit approach (drives the Dynamic Island distance + progress).
    private var summitCoordinate: CLLocationCoordinate2D?
    private var initialSummitDistance: Double?

    /// 0…1 approach progress toward the summit (nil before the first fix).
    var summitProgress: Double? {
        guard let current = distanceToSummitMeters,
              let initial = initialSummitDistance, initial > 0 else { return nil }
        return min(1, max(0, 1 - current / initial))
    }

    /// Discards fixes that are too inaccurate or stale to trust for distance math.
    private let horizontalAccuracyThreshold: CLLocationAccuracy = 50

    /// True when `UIBackgroundModes` declares `location`, gating background updates
    /// so we never call `allowsBackgroundLocationUpdates = true` without the entitlement.
    private static let backgroundLocationDeclared: Bool = {
        (Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String])?
            .contains("location") ?? false
    }()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = kCLDistanceFilterNone
        Self.shared = self
        NotificationCenter.default.addObserver(
            forName: Self.togglePauseNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.togglePause() }
        }
    }

    // MARK: - Control

    /// Starts a fresh recording. Returns false (and changes nothing) when a
    /// recording is already in flight, so callers can surface that to the user
    /// instead of silently doing nothing.
    @discardableResult
    func start(
        mountainId: String? = nil,
        mountainName: String = "",
        summitCoordinate: CLLocationCoordinate2D? = nil
    ) -> Bool {
        guard !isRecording else { return false }

        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        distanceMeters = 0
        ascentMeters = 0
        elapsedSeconds = 0
        points = []
        lastLocation = nil
        lastElevation = nil
        accumulatedSeconds = 0
        segmentStart = Date()
        startDate = Date()
        resumeGapPending = false
        self.summitCoordinate = summitCoordinate
        initialSummitDistance = nil
        distanceToSummitMeters = nil
        activeMountainId = mountainId
        activeMountainName = mountainName.isEmpty ? "Recording Trip" : mountainName
        isPaused = false
        isRecording = true

        beginSampling()
        #if canImport(ActivityKit)
        liveActivity.start(mountainName: activeMountainName, state: activityState())
        #endif
        return true
    }

    /// Turns the sensors and the duration clock back on. Shared by `start()` and
    /// `resume()` so a resumed (or relaunch-restored) session gets the exact same
    /// background-location configuration a fresh one does.
    private func beginSampling() {
        // Keep recording with the screen off / app backgrounded. Only enable when
        // the `location` background mode is declared, otherwise iOS raises.
        if Self.backgroundLocationDeclared {
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = false
            manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()
        startTimer()
    }

    /// Restores a persisted session as paused. Nothing is sampled and no Live
    /// Activity is raised until the user explicitly resumes — resuming then
    /// deliberately re-anchors the first new GPS fix so the unobserved relaunch
    /// gap never adds distance.
    func restore(
        checkpoint: TripSessionCheckpoint,
        mountainId: String? = nil,
        mountainName: String = "",
        summitCoordinate: CLLocationCoordinate2D? = nil
    ) {
        guard !isRecording else { return }

        points = checkpoint.points
        elapsedSeconds = checkpoint.elapsedSeconds
        distanceMeters = checkpoint.distanceMeters
        ascentMeters = checkpoint.ascentMeters
        accumulatedSeconds = checkpoint.elapsedSeconds
        startDate = checkpoint.points.first?.timestamp
            ?? checkpoint.savedAt.addingTimeInterval(-checkpoint.elapsedSeconds)
        segmentStart = nil
        lastLocation = nil
        lastElevation = nil
        resumeGapPending = true
        self.summitCoordinate = summitCoordinate
        initialSummitDistance = nil
        distanceToSummitMeters = nil
        activeMountainId = mountainId
        activeMountainName = mountainName.isEmpty ? "Recording Trip" : mountainName
        isPaused = true
        isRecording = true
    }

    /// Freezes the clock and the sensors; the hike can continue later with `resume()`.
    func pause() {
        guard isRecording, !isPaused else { return }
        if let segmentStart {
            accumulatedSeconds += Date().timeIntervalSince(segmentStart)
        }
        segmentStart = nil
        isPaused = true
        manager.stopUpdatingLocation()
        pushActivityUpdate()
    }

    func resume() {
        guard isRecording, isPaused else { return }
        segmentStart = Date()
        isPaused = false
        resumeGapPending = true
        beginSampling()
        #if canImport(ActivityKit)
        // No-op when an activity is already live; raises one for a session that
        // was restored from disk (restore deliberately leaves it dark).
        liveActivity.start(mountainName: activeMountainName, state: activityState())
        #endif
        pushActivityUpdate()
    }

    func togglePause() {
        guard isRecording else { return }
        isPaused ? resume() : pause()
    }

    /// Abandons the recording entirely: nothing is returned or persisted, and the
    /// Live Activity ends. The escape hatch for "started by mistake".
    func cancel() {
        guard isRecording else { return }
        finishSession()
        points = []
        distanceMeters = 0
        ascentMeters = 0
        elapsedSeconds = 0
        reset()
    }

    /// Stops recording and returns the finished `Track` (nil if no points were captured).
    @discardableResult
    func stop() -> Track? {
        guard isRecording else { return nil }
        // Close the open segment so the duration excludes paused time.
        if let segmentStart {
            accumulatedSeconds += Date().timeIntervalSince(segmentStart)
        }
        segmentStart = nil
        elapsedSeconds = accumulatedSeconds
        finishSession()

        let start = startDate ?? points.first?.timestamp ?? Date()
        let end = points.last?.timestamp ?? Date()

        guard !points.isEmpty else {
            reset()
            return nil
        }

        let track = Track(
            mountainId: activeMountainId,
            name: defaultName(for: start),
            points: points,
            distanceMeters: distanceMeters,
            durationSeconds: max(elapsedSeconds, 1),
            ascentMeters: ascentMeters,
            startDate: start,
            endDate: end
        )
        reset()
        return track
    }

    /// Shared teardown for stop/cancel: sensors, timer, Live Activity.
    private func finishSession() {
        isRecording = false
        isPaused = false
        manager.stopUpdatingLocation()
        #if canImport(ActivityKit)
        liveActivity.end()
        #endif
        if Self.backgroundLocationDeclared {
            manager.allowsBackgroundLocationUpdates = false
        }
        timer?.invalidate()
        timer = nil
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
        accumulatedSeconds = 0
        segmentStart = nil
        resumeGapPending = false
        summitCoordinate = nil
        initialSummitDistance = nil
        distanceToSummitMeters = nil
        activeMountainId = nil
        activeMountainName = ""
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                if !self.isPaused, let segmentStart = self.segmentStart {
                    self.elapsedSeconds = self.accumulatedSeconds + Date().timeIntervalSince(segmentStart)
                    if Int(self.elapsedSeconds) % 5 == 0 {
                        self.pushActivityUpdate()
                    }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func pushActivityUpdate() {
        #if canImport(ActivityKit)
        liveActivity.update(state: activityState())
        #endif
    }

    #if canImport(ActivityKit)
    private func activityState() -> WildFrogTrackAttributes.ContentState {
        WildFrogTrackAttributes.ContentState(
            elapsedSeconds: Int(elapsedSeconds),
            distanceMeters: distanceMeters,
            ascentMeters: ascentMeters,
            isPaused: isPaused,
            distanceToSummitMeters: distanceToSummitMeters,
            summitProgress: summitProgress
        )
    }
    #endif

    #if DEBUG
    // MARK: - Test seams

    /// True while the 1 s duration timer is live (i.e. the session is sampling).
    var isSamplingForTesting: Bool { timer != nil }
    /// Mirrors the background-location flag the recorder pushed onto its manager.
    var allowsBackgroundLocationUpdatesForTesting: Bool { manager.allowsBackgroundLocationUpdates }
    /// Whether `UIBackgroundModes` declares `location` for the running bundle.
    static var backgroundLocationDeclaredForTesting: Bool { backgroundLocationDeclared }
    #endif

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
        guard isRecording, !isPaused else { return }
        for location in locations {
            guard location.horizontalAccuracy >= 0,
                  location.horizontalAccuracy <= horizontalAccuracyThreshold else { continue }

            if resumeGapPending {
                // Re-anchor after a pause: distance walked while paused must not count.
                lastLocation = location
                if location.verticalAccuracy >= 0 {
                    lastElevation = location.altitude
                }
                resumeGapPending = false
            } else {
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
                lastLocation = location
            }

            if let summit = summitCoordinate {
                let d = location.distance(from: CLLocation(latitude: summit.latitude, longitude: summit.longitude))
                distanceToSummitMeters = d
                if initialSummitDistance == nil {
                    initialSummitDistance = max(d, 1)
                }
            }

            points.append(
                TrackPoint(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    elevation: location.verticalAccuracy >= 0 ? location.altitude : nil,
                    timestamp: location.timestamp
                )
            )
        }
    }
}
