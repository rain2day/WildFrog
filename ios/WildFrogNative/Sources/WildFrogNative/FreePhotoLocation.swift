import CoreLocation
import Foundation
import ImageIO
import Photos

struct FreePhotoLocationCandidate: Equatable {
    let coordinate: FreePhotoCoordinate
    let source: FreePhotoLocationSource
    let horizontalAccuracy: Double?
    let timestamp: Date?
}

enum FreePhotoLocationSelectionState: Equatable {
    case resolved(FreePhotoLocationCandidate)
    case needsChoice
    case addLater

    static func imported(metadata: FreePhotoLocationCandidate?) -> Self {
        if let metadata { return .resolved(metadata) }
        return .needsChoice
    }

    var candidate: FreePhotoLocationCandidate? {
        guard case let .resolved(candidate) = self else { return nil }
        return candidate
    }

    var requiresFallbackChoice: Bool {
        self == .needsChoice
    }
}

enum FreePhotoLocationResolver {
    static func cameraCandidate(
        location: CLLocation?,
        captureRevision: Int,
        activeRevision: Int,
        now: Date = .now
    ) -> FreePhotoLocationCandidate? {
        guard captureRevision == activeRevision,
              let location,
              location.horizontalAccuracy >= 0,
              location.coordinate.latitude.isFinite,
              location.coordinate.longitude.isFinite,
              location.timestamp >= now.addingTimeInterval(-60),
              location.timestamp <= now.addingTimeInterval(5) else { return nil }
        let coordinate = FreePhotoCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        guard coordinate.isValid else { return nil }
        return FreePhotoLocationCandidate(
            coordinate: coordinate,
            source: .cameraGPS,
            horizontalAccuracy: location.horizontalAccuracy,
            timestamp: location.timestamp
        )
    }

    static func currentLocationCandidate(_ location: CLLocation?) -> FreePhotoLocationCandidate? {
        guard let location,
              location.horizontalAccuracy >= 0 else { return nil }
        let coordinate = FreePhotoCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        guard coordinate.isValid else { return nil }
        return FreePhotoLocationCandidate(
            coordinate: coordinate,
            source: .currentLocationChoice,
            horizontalAccuracy: location.horizontalAccuracy,
            timestamp: location.timestamp
        )
    }
}

enum FreePhotoMetadataLocationReader {
    static func candidate(
        from imageData: Data,
        photosIdentifier: String?
    ) async -> FreePhotoLocationCandidate? {
        if let photosIdentifier {
            let status = await photosAuthorizationStatus()
            if status == .authorized || status == .limited {
                let assets = PHAsset.fetchAssets(
                    withLocalIdentifiers: [photosIdentifier],
                    options: nil
                )
                if let location = assets.firstObject?.location {
                    let coordinate = FreePhotoCoordinate(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    if coordinate.isValid {
                        return FreePhotoLocationCandidate(
                            coordinate: coordinate,
                            source: .sourcePhotoMetadata,
                            horizontalAccuracy: location.horizontalAccuracy >= 0
                                ? location.horizontalAccuracy
                                : nil,
                            timestamp: location.timestamp
                        )
                    }
                }
            }
        }
        return candidate(from: imageData)
    }

    static func candidate(from imageData: Data) -> FreePhotoLocationCandidate? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let latitude = number(gps[kCGImagePropertyGPSLatitude]),
              let longitude = number(gps[kCGImagePropertyGPSLongitude]) else { return nil }

        let latitudeRef = (gps[kCGImagePropertyGPSLatitudeRef] as? String)?.uppercased()
        let longitudeRef = (gps[kCGImagePropertyGPSLongitudeRef] as? String)?.uppercased()
        let coordinate = FreePhotoCoordinate(
            latitude: latitudeRef == "S" ? -latitude : latitude,
            longitude: longitudeRef == "W" ? -longitude : longitude
        )
        guard coordinate.isValid else { return nil }
        return FreePhotoLocationCandidate(
            coordinate: coordinate,
            source: .sourcePhotoMetadata,
            horizontalAccuracy: nil,
            timestamp: nil
        )
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let value = value as? Double { return value }
        if let text = value as? String { return Double(text) }
        return nil
    }

    private static func photosAuthorizationStatus() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
