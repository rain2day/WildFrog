import Foundation

enum FreePhotoAltitudeSource: String, Codable, Equatable {
    case none
    case gpsApproximate
    case manual
}

enum FreePhotoValidationError: Equatable {
    case missingPlaceName
    case placeNameTooLong
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

    init(
        captureRevision: Int,
        placeName: String,
        altitudeMetres: Int?,
        altitudeSource: FreePhotoAltitudeSource = .none,
        cardStyle: FreePhotoCardStyle,
        renderedAt: Date = .distantPast
    ) {
        self.captureRevision = captureRevision
        self.placeName = placeName
        self.altitudeMetres = altitudeMetres
        self.altitudeSource = altitudeSource
        self.cardStyle = cardStyle
        self.renderedAt = renderedAt
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
    private(set) var altitudeText = ""
    private(set) var altitudeSource: FreePhotoAltitudeSource = .none
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

    var validationError: FreePhotoValidationError? {
        if validatedName.isEmpty { return .missingPlaceName }
        if validatedName.count > 40 { return .placeNameTooLong }
        guard !altitudeText.isEmpty else { return nil }
        guard let altitude = Int(altitudeText) else { return .invalidAltitude }
        return (-500...9_000).contains(altitude) ? nil : .altitudeOutOfRange
    }

    mutating func setAltitudeText(_ value: String) {
        altitudeText = value.trimmingCharacters(in: .whitespacesAndNewlines)
        altitudeSource = altitudeText.isEmpty ? .none : .manual
        didResolveAltitude = true
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
}
