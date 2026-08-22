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

struct FreePhotoImportedMetadata: Equatable {
    let location: FreePhotoLocationCandidate?
    let creationDate: Date
}

enum FreePhotoMetadataReader {
    static func metadata(
        from imageData: Data,
        photosIdentifier: String?,
        acceptedAt: Date = .now
    ) async -> FreePhotoImportedMetadata {
        let embedded = metadata(from: imageData, acceptedAt: acceptedAt)
        if let photosIdentifier {
            let status = await photosAuthorizationStatus()
            if status == .authorized || status == .limited {
                let assets = PHAsset.fetchAssets(
                    withLocalIdentifiers: [photosIdentifier],
                    options: nil
                )
                if let asset = assets.firstObject {
                    var preferredLocation = embedded.location
                    if let location = asset.location {
                        let coordinate = FreePhotoCoordinate(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude
                        )
                        if coordinate.isValid {
                            preferredLocation = FreePhotoLocationCandidate(
                                coordinate: coordinate,
                                source: .sourcePhotoMetadata,
                                horizontalAccuracy: location.horizontalAccuracy >= 0
                                    ? location.horizontalAccuracy
                                    : nil,
                                timestamp: location.timestamp
                            )
                        }
                    }
                    // EXIF DateTimeOriginal is the wall clock at the shutter.
                    // `asset.creationDate` is an absolute instant that shifts a
                    // cross-time-zone photo onto the wrong calendar day, so the
                    // embedded value wins whenever the file carries one.
                    return FreePhotoImportedMetadata(
                        location: preferredLocation,
                        creationDate: embeddedCreationDate(from: imageData)
                            ?? asset.creationDate
                            ?? embedded.creationDate
                    )
                }
            }
        }
        return embedded
    }

    /// Wall-clock EXIF timestamps carry no zone unless `OffsetTimeOriginal` is
    /// present, so they are read in the app's Hong Kong convention by default —
    /// the same zone the frame and the records calendar format with.
    static let fallbackTimeZone = TimeZone(identifier: "Asia/Hong_Kong") ?? .current

    static func embeddedCreationDate(
        from imageData: Data,
        timeZone: TimeZone = fallbackTimeZone
    ) -> Date? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        return creationDate(from: properties, timeZone: timeZone)
    }

    static func metadata(
        from imageData: Data,
        acceptedAt: Date,
        timeZone: TimeZone = fallbackTimeZone
    ) -> FreePhotoImportedMetadata {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return FreePhotoImportedMetadata(location: nil, creationDate: acceptedAt)
        }

        return FreePhotoImportedMetadata(
            location: location(from: properties),
            creationDate: creationDate(from: properties, timeZone: timeZone) ?? acceptedAt
        )
    }

    private static func location(
        from properties: [CFString: Any]
    ) -> FreePhotoLocationCandidate? {
        guard let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
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

    private static func creationDate(
        from properties: [CFString: Any],
        timeZone: TimeZone
    ) -> Date? {
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let candidates: [(String?, TimeZone)] = [
            (
                exif?[kCGImagePropertyExifDateTimeOriginal] as? String,
                offset(exif?[kCGImagePropertyExifOffsetTimeOriginal]) ?? timeZone
            ),
            (
                exif?[kCGImagePropertyExifDateTimeDigitized] as? String,
                offset(exif?[kCGImagePropertyExifOffsetTimeDigitized]) ?? timeZone
            ),
            (
                tiff?[kCGImagePropertyTIFFDateTime] as? String,
                offset(exif?[kCGImagePropertyExifOffsetTime]) ?? timeZone
            )
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return candidates.compactMap { value, zone -> Date? in
            guard let value else { return nil }
            formatter.timeZone = zone
            return formatter.date(from: value)
        }.first
    }

    /// Parses an EXIF offset string such as `+09:00` or `-05:00`.
    private static func offset(_ value: Any?) -> TimeZone? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespaces),
              text.count == 6,
              let sign = text.first,
              sign == "+" || sign == "-" else { return nil }
        let parts = text.dropFirst().split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]),
              (0...14).contains(hours),
              (0...59).contains(minutes) else { return nil }
        let seconds = (hours * 3_600 + minutes * 60) * (sign == "-" ? -1 : 1)
        return TimeZone(secondsFromGMT: seconds)
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
