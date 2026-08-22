import Foundation

enum FreePhotoAltitudeSource: String, Codable, Equatable {
    case none
    case gpsApproximate
    case manual
}

enum FreePhotoValidationError: Equatable {
    case missingPlaceName
    case placeNameTooLong
    case missingCoordinates
    case invalidCoordinates
    case coordinatesOutOfRange
    case invalidAltitude
    case altitudeOutOfRange
}

enum FreePhotoCaptureSource: Equatable {
    case camera
    case photos
}

enum FreePhotoCaptureAvailability {
    static func sources(cameraAvailable: Bool) -> [FreePhotoCaptureSource] {
        cameraAvailable ? [.camera, .photos] : [.photos]
    }
}

enum FreePhotoPreviewInteractionContract {
    static let cardAllowsHitTesting = false
}

struct PhotoSelectionRequestState: Equatable {
    private var revision = 0
    private var activePhotosRevision: Int?

    mutating func beginPhotosLoad() -> Int {
        revision += 1
        activePhotosRevision = revision
        return revision
    }

    mutating func acceptPhotosResult(_ requestRevision: Int) -> Bool {
        guard activePhotosRevision == requestRevision else { return false }
        activePhotosRevision = nil
        return true
    }

    mutating func invalidateForNewChoice() {
        revision += 1
        activePhotosRevision = nil
    }

    mutating func invalidateForDismissal() {
        invalidateForNewChoice()
    }
}

typealias FreePhotoSelectionRequestState = PhotoSelectionRequestState

struct FreePhotoExportFingerprint: Equatable {
    let captureRevision: Int
    let placeName: String
    let altitudeMetres: Int?
    let altitudeSource: FreePhotoAltitudeSource
    let cardStyle: FreePhotoCardStyle
    let renderedAt: Date
    let frameDate: Date
    let showsDate: Bool
    let latitudeText: String
    let longitudeText: String
    let showsCoordinates: Bool

    // Every field is required: a silent default here would let two visually
    // different exports share a fingerprint and suppress a needed re-save.
    init(
        captureRevision: Int,
        placeName: String,
        altitudeMetres: Int?,
        altitudeSource: FreePhotoAltitudeSource,
        cardStyle: FreePhotoCardStyle,
        renderedAt: Date,
        frameDate: Date,
        showsDate: Bool,
        latitudeText: String,
        longitudeText: String,
        showsCoordinates: Bool
    ) {
        self.captureRevision = captureRevision
        self.placeName = placeName
        self.altitudeMetres = altitudeMetres
        self.altitudeSource = altitudeSource
        self.cardStyle = cardStyle
        self.renderedAt = renderedAt
        self.frameDate = frameDate
        self.showsDate = showsDate
        self.latitudeText = latitudeText
        self.longitudeText = longitudeText
        self.showsCoordinates = showsCoordinates
    }
}

struct FreePhotoSaveConfirmation: Equatable {
    private var savedFingerprint: FreePhotoExportFingerprint?

    mutating func markSaved(for fingerprint: FreePhotoExportFingerprint) {
        savedFingerprint = fingerprint
    }

    mutating func clear() {
        savedFingerprint = nil
    }

    func isCurrent(for fingerprint: FreePhotoExportFingerprint) -> Bool {
        savedFingerprint == fingerprint
    }
}

struct FreePhotoSaveRequestState: Equatable {
    private var activeFingerprint: FreePhotoExportFingerprint?

    mutating func begin(for fingerprint: FreePhotoExportFingerprint) {
        activeFingerprint = fingerprint
    }

    mutating func completeSuccess(
        for fingerprint: FreePhotoExportFingerprint,
        currentFingerprint: FreePhotoExportFingerprint
    ) -> Bool {
        complete(for: fingerprint, currentFingerprint: currentFingerprint)
    }

    mutating func completeFailure(
        for fingerprint: FreePhotoExportFingerprint,
        currentFingerprint: FreePhotoExportFingerprint
    ) -> Bool {
        complete(for: fingerprint, currentFingerprint: currentFingerprint)
    }

    private mutating func complete(
        for fingerprint: FreePhotoExportFingerprint,
        currentFingerprint: FreePhotoExportFingerprint
    ) -> Bool {
        guard activeFingerprint == fingerprint else { return false }
        activeFingerprint = nil
        return currentFingerprint == fingerprint
    }
}

struct FreePhotoDraft: Equatable {
    var placeName = ""
    var frameDate = Date() {
        didSet {
            guard frameDate != oldValue else { return }
            isDateEdited = true
        }
    }
    var showsDate = true
    private(set) var latitudeText = ""
    private(set) var longitudeText = ""
    var showsCoordinates = false
    private(set) var altitudeText = ""
    private(set) var altitudeSource: FreePhotoAltitudeSource = .none
    private(set) var isDateEdited = false
    private(set) var isCoordinateEdited = false
    private var didResolveAltitude = false
    private var locationPrefillStartedAt: Date?

    mutating func beginLocationPrefillSession(at date: Date) {
        locationPrefillStartedAt = date
    }

    var validatedName: String {
        placeName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var altitudeMetres: Int? {
        altitudeText.isEmpty ? nil : Int(altitudeText)
    }

    var displayDate: Date? {
        showsDate ? frameDate : nil
    }

    var displayCoordinate: FreePhotoCoordinate? {
        guard let latitude = Double(latitudeText),
              let longitude = Double(longitudeText),
              latitude.isFinite,
              longitude.isFinite else { return nil }
        let coordinate = FreePhotoCoordinate(latitude: latitude, longitude: longitude)
        return coordinate.isValid ? coordinate : nil
    }

    /// The formatted coordinate value, independent of whether it is printed on
    /// the frame. Visibility is a separate signal so the editor can show a real
    /// value next to a hidden badge instead of claiming "not set".
    var coordinateLabel: String? {
        guard let displayCoordinate else { return nil }
        return Self.coordinateLabel(for: displayCoordinate)
    }

    var validationError: FreePhotoValidationError? {
        if validatedName.isEmpty { return .missingPlaceName }
        if validatedName.count > 40 { return .placeNameTooLong }
        if showsCoordinates {
            guard !latitudeText.isEmpty, !longitudeText.isEmpty else {
                return .missingCoordinates
            }
            guard let latitude = Double(latitudeText),
                  let longitude = Double(longitudeText),
                  latitude.isFinite,
                  longitude.isFinite else {
                return .invalidCoordinates
            }
            guard FreePhotoCoordinate(latitude: latitude, longitude: longitude).isValid else {
                return .coordinatesOutOfRange
            }
        }
        guard !altitudeText.isEmpty else { return nil }
        guard let altitude = Int(altitudeText) else { return .invalidAltitude }
        return (-500...9_000).contains(altitude) ? nil : .altitudeOutOfRange
    }

    mutating func setAltitudeText(_ value: String) {
        altitudeText = value.trimmingCharacters(in: .whitespacesAndNewlines)
        altitudeSource = altitudeText.isEmpty ? .none : .manual
        didResolveAltitude = true
    }

    /// Prefills the frame values captured with the photo. Printing coordinates
    /// on an image the user may share is opt-in, so `showsCoordinates` is never
    /// switched on here and an explicit user toggle survives a photo replace.
    mutating func applyFrameMetadata(date: Date, coordinate: FreePhotoCoordinate?) {
        frameDate = date
        if let coordinate, coordinate.isValid {
            latitudeText = Self.editableCoordinateString(coordinate.latitude)
            longitudeText = Self.editableCoordinateString(coordinate.longitude)
        } else {
            latitudeText = ""
            longitudeText = ""
        }
        isDateEdited = false
        isCoordinateEdited = false
    }

    mutating func setLatitudeText(_ value: String) {
        let next = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard next != latitudeText else { return }
        latitudeText = next
        isCoordinateEdited = true
    }

    mutating func setLongitudeText(_ value: String) {
        let next = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard next != longitudeText else { return }
        longitudeText = next
        isCoordinateEdited = true
    }

    mutating func applyLocationSuggestion(
        altitude: Double,
        verticalAccuracy: Double,
        timestamp: Date = .now
    ) {
        guard !didResolveAltitude,
              verticalAccuracy >= 0,
              let locationPrefillStartedAt,
              timestamp >= locationPrefillStartedAt else { return }
        let rounded = Int(altitude.rounded())
        guard (-500...9_000).contains(rounded) else { return }
        altitudeText = String(rounded)
        altitudeSource = .gpsApproximate
        didResolveAltitude = true
    }

    func canExport(hasPhoto: Bool) -> Bool {
        hasPhoto && validationError == nil
    }

    private static func editableCoordinateString(_ value: Double) -> String {
        String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func coordinateLabel(for coordinate: FreePhotoCoordinate) -> String {
        let latitudeDirection = coordinate.latitude < 0 ? "S" : "N"
        let longitudeDirection = coordinate.longitude < 0 ? "W" : "E"
        return String(
            format: "%.5f° %@ · %.5f° %@",
            locale: Locale(identifier: "en_US_POSIX"),
            abs(coordinate.latitude),
            latitudeDirection,
            abs(coordinate.longitude),
            longitudeDirection
        )
    }
}
