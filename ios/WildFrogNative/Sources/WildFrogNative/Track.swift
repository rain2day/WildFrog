import CoreLocation
import Foundation

/// A single sampled GPS fix along a recorded track.
struct TrackPoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let elevation: Double?
    let timestamp: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// A recorded hike: an ordered sequence of GPS points plus derived statistics.
struct Track: Codable, Identifiable, Equatable {
    let id: UUID
    var mountainId: String?
    var name: String
    var points: [TrackPoint]
    var distanceMeters: Double
    var durationSeconds: Double
    var ascentMeters: Double
    let startDate: Date
    let endDate: Date

    init(
        id: UUID = UUID(),
        mountainId: String? = nil,
        name: String,
        points: [TrackPoint],
        distanceMeters: Double,
        durationSeconds: Double,
        ascentMeters: Double,
        startDate: Date,
        endDate: Date
    ) {
        self.id = id
        self.mountainId = mountainId
        self.name = name
        self.points = points
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.ascentMeters = ascentMeters
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Convenience for drawing `MapPolyline(coordinates:)`.
    var coordinates: [CLLocationCoordinate2D] {
        points.map(\.coordinate)
    }
}

// MARK: - Formatting helpers

enum TrackFormat {
    static func distance(_ meters: Double) -> String {
        meters < 1000
            ? "\(Int(meters))m"
            : String(format: "%.2fkm", meters / 1000)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
