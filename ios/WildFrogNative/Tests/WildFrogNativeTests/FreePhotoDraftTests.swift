import CoreLocation
import Testing
@testable import WildFrogNative

@Test func trimsAndRequiresPlaceName() {
    var draft = FreePhotoDraft()
    draft.placeName = "  大東山日落位  "
    #expect(draft.validatedName == "大東山日落位")

    draft.placeName = "   "
    #expect(draft.validationError == .missingPlaceName)
}

@Test func rejectsNamesLongerThanFortyCharacters() {
    var draft = FreePhotoDraft()
    draft.placeName = String(repeating: "山", count: 41)
    #expect(draft.validationError == .placeNameTooLong)
}

@Test func acceptsOnlyConfiguredAltitudeRange() {
    var draft = FreePhotoDraft()
    draft.placeName = "山頂"
    draft.setAltitudeText("438")
    #expect(draft.altitudeMetres == 438)

    draft.setAltitudeText("9001")
    #expect(draft.validationError == .altitudeOutOfRange)

    draft.setAltitudeText("12.5")
    #expect(draft.validationError == .invalidAltitude)
}

@Test func validLocationPrefillsAltitudeOnce() {
    var draft = FreePhotoDraft()
    let presentedAt = Date(timeIntervalSince1970: 1_000)
    draft.beginLocationPrefillSession(at: presentedAt)
    draft.applyLocationSuggestion(
        altitude: 437.6,
        verticalAccuracy: 18,
        timestamp: presentedAt.addingTimeInterval(1)
    )
    #expect(draft.altitudeText == "438")
    #expect(draft.altitudeSource == .gpsApproximate)

    draft.setAltitudeText("500")
    draft.applyLocationSuggestion(
        altitude: 610,
        verticalAccuracy: 12,
        timestamp: presentedAt.addingTimeInterval(2)
    )
    #expect(draft.altitudeText == "500")
    #expect(draft.altitudeSource == .manual)
}

@Test func loadedPhotoAltitudeCanBeEditedClearedAndEditedAgain() {
    var draft = FreePhotoDraft()
    let started = Date(timeIntervalSince1970: 1_000)
    draft.placeName = "大東山"
    draft.beginLocationPrefillSession(at: started)
    draft.applyLocationSuggestion(
        altitude: 438,
        verticalAccuracy: 8,
        timestamp: started.addingTimeInterval(1)
    )

    draft.setAltitudeText("500")
    #expect(draft.altitudeMetres == 500)
    #expect(draft.altitudeSource == .manual)

    draft.setAltitudeText("")
    #expect(draft.altitudeMetres == nil)
    #expect(draft.altitudeSource == .none)

    draft.setAltitudeText("321")
    draft.applyLocationSuggestion(
        altitude: 900,
        verticalAccuracy: 8,
        timestamp: started.addingTimeInterval(2)
    )
    #expect(draft.altitudeMetres == 321)
    #expect(draft.altitudeSource == .manual)
}

@Test func invalidLocationDoesNotPrefill() {
    var draft = FreePhotoDraft()
    let presentedAt = Date(timeIntervalSince1970: 1_000)
    draft.beginLocationPrefillSession(at: presentedAt)
    draft.applyLocationSuggestion(
        altitude: 438,
        verticalAccuracy: -1,
        timestamp: presentedAt.addingTimeInterval(1)
    )
    #expect(draft.altitudeText.isEmpty)
}

@Test func frameMetadataDefaultsAndFormattingAreDisplayOnly() {
    var draft = FreePhotoDraft()
    let date = Date(timeIntervalSince1970: 1_777_777_777)
    let gps = FreePhotoCoordinate(latitude: 22.4084, longitude: 114.1201)

    draft.applyFrameMetadata(date: date, coordinate: gps)

    #expect(draft.showsDate)
    #expect(draft.frameDate == date)
    // Prefilled, but printing them onto a shareable image stays opt-in.
    #expect(!draft.showsCoordinates)
    #expect(draft.displayCoordinate == gps)
    #expect(draft.coordinateLabel == "22.40840° N · 114.12010° E")

    draft.setLatitudeText("-22.50000")
    draft.setLongitudeText("-114.25000")
    #expect(draft.coordinateLabel == "22.50000° S · 114.25000° W")

    draft.showsCoordinates = false
    #expect(draft.latitudeText == "-22.50000")
    #expect(draft.longitudeText == "-114.25000")
}

@Test func replacingThePhotoNeverFlipsTheCoordinatePrivacyToggle() {
    var draft = FreePhotoDraft()
    let gps = FreePhotoCoordinate(latitude: 22.4084, longitude: 114.1201)

    draft.applyFrameMetadata(date: Date(timeIntervalSince1970: 1), coordinate: gps)
    #expect(!draft.showsCoordinates)

    draft.showsCoordinates = true
    draft.applyFrameMetadata(
        date: Date(timeIntervalSince1970: 2),
        coordinate: FreePhotoCoordinate(latitude: 35, longitude: 139)
    )
    #expect(draft.showsCoordinates)
    #expect(draft.latitudeText == "35.00000")

    // A replacement without GPS clears the values but keeps the user's choice.
    draft.applyFrameMetadata(date: Date(timeIntervalSince1970: 3), coordinate: nil)
    #expect(draft.showsCoordinates)
    #expect(draft.latitudeText.isEmpty)

    draft.showsCoordinates = false
    draft.applyFrameMetadata(date: Date(timeIntervalSince1970: 4), coordinate: gps)
    #expect(!draft.showsCoordinates)
}

@Test func manualDateAndCoordinateEditsAreTrackedForTheFrameBadge() {
    var draft = FreePhotoDraft()
    let captured = Date(timeIntervalSince1970: 1_777_777_777)
    draft.applyFrameMetadata(
        date: captured,
        coordinate: FreePhotoCoordinate(latitude: 22.4084, longitude: 114.1201)
    )
    #expect(!draft.isDateEdited)
    #expect(!draft.isCoordinateEdited)

    // Re-applying the same text is not an edit.
    draft.setLatitudeText("22.40840")
    #expect(!draft.isCoordinateEdited)

    draft.frameDate = captured.addingTimeInterval(-86_400)
    draft.setLongitudeText("114.20000")
    #expect(draft.isDateEdited)
    #expect(draft.isCoordinateEdited)

    // A fresh capture resets both badges.
    draft.applyFrameMetadata(date: captured, coordinate: nil)
    #expect(!draft.isDateEdited)
    #expect(!draft.isCoordinateEdited)
}

@Test func missingFrameGPSLeavesCoordinatesHiddenAndEditable() {
    var draft = FreePhotoDraft()
    let date = Date(timeIntervalSince1970: 1_777_777_777)

    draft.applyFrameMetadata(date: date, coordinate: nil)

    #expect(draft.showsDate)
    #expect(!draft.showsCoordinates)
    #expect(draft.latitudeText.isEmpty)
    #expect(draft.longitudeText.isEmpty)

    draft.setLatitudeText("22.4084")
    draft.setLongitudeText("114.1201")
    draft.showsCoordinates = true
    #expect(draft.displayCoordinate == FreePhotoCoordinate(latitude: 22.4084, longitude: 114.1201))
}

@Test func coordinateValidationOnlyBlocksVisibleInvalidCoordinates() {
    var draft = FreePhotoDraft()
    draft.placeName = "獅子山"
    draft.showsCoordinates = true
    #expect(draft.validationError == .missingCoordinates)

    draft.setLatitudeText("north")
    draft.setLongitudeText("114")
    #expect(draft.validationError == .invalidCoordinates)

    draft.setLatitudeText("91")
    draft.setLongitudeText("114")
    #expect(draft.validationError == .coordinatesOutOfRange)
    #expect(!draft.canExport(hasPhoto: true))

    draft.setLatitudeText("90")
    draft.setLongitudeText("-180")
    #expect(draft.validationError == nil)

    draft.setLatitudeText("nan")
    #expect(draft.validationError == .invalidCoordinates)

    draft.showsCoordinates = false
    #expect(draft.validationError == nil)
    #expect(draft.canExport(hasPhoto: true))
}

@Test func staleRetainedFixDoesNotConsumeTheFreshAltitudePrefill() {
    var draft = FreePhotoDraft()
    let presentedAt = Date(timeIntervalSince1970: 1_000)
    draft.beginLocationPrefillSession(at: presentedAt)

    draft.applyLocationSuggestion(
        altitude: 111,
        verticalAccuracy: 8,
        timestamp: presentedAt.addingTimeInterval(-30)
    )
    #expect(draft.altitudeText.isEmpty)

    draft.applyLocationSuggestion(
        altitude: 438,
        verticalAccuracy: 8,
        timestamp: presentedAt.addingTimeInterval(2)
    )
    #expect(draft.altitudeText == "438")
    #expect(draft.altitudeSource == .gpsApproximate)
}

@Test func photosRemainAvailableWhenTheDeviceHasNoCamera() {
    #expect(FreePhotoCaptureAvailability.sources(cameraAvailable: false) == [.photos])
    #expect(FreePhotoCaptureAvailability.sources(cameraAvailable: true) == [.camera, .photos])
}

@Test func photoSelectionOnlyAcceptsTheLatestAsyncResult() {
    var state = FreePhotoSelectionRequestState()
    let first = state.beginPhotosLoad()
    let second = state.beginPhotosLoad()

    let acceptedFirst = state.acceptPhotosResult(first)
    let acceptedSecond = state.acceptPhotosResult(second)
    let acceptedSecondAgain = state.acceptPhotosResult(second)
    #expect(!acceptedFirst)
    #expect(acceptedSecond)
    #expect(!acceptedSecondAgain)
}

@Test func cameraChoiceAndDismissalInvalidatePendingPhotosResults() {
    var state = FreePhotoSelectionRequestState()
    let beforeCamera = state.beginPhotosLoad()
    state.invalidateForNewChoice()
    let acceptedAfterCamera = state.acceptPhotosResult(beforeCamera)
    #expect(!acceptedAfterCamera)

    let beforeDismissal = state.beginPhotosLoad()
    state.invalidateForDismissal()
    let acceptedAfterDismissal = state.acceptPhotosResult(beforeDismissal)
    #expect(!acceptedAfterDismissal)
}

@Test func officialCheckInPhotosAThenBOnlyAcceptsB() {
    var state = PhotoSelectionRequestState()
    let photoA = state.beginPhotosLoad()
    let photoB = state.beginPhotosLoad()
    let acceptedA = state.acceptPhotosResult(photoA)
    let acceptedB = state.acceptPhotosResult(photoB)

    #expect(!acceptedA)
    #expect(acceptedB)
}

@Test func officialCheckInCameraAndDismissalInvalidatePendingPhotos() {
    var state = PhotoSelectionRequestState()
    let beforeCamera = state.beginPhotosLoad()
    state.invalidateForNewChoice()
    let acceptedAfterCamera = state.acceptPhotosResult(beforeCamera)
    #expect(!acceptedAfterCamera)

    let beforeDismissal = state.beginPhotosLoad()
    state.invalidateForDismissal()
    let acceptedAfterDismissal = state.acceptPhotosResult(beforeDismissal)
    #expect(!acceptedAfterDismissal)
}

@Test func exportRequiresAValidDraftAndPhoto() {
    var draft = FreePhotoDraft()
    draft.placeName = "城門水塘"

    #expect(!draft.canExport(hasPhoto: false))
    #expect(draft.canExport(hasPhoto: true))
}

@Test func trailStudioUsesApprovedSpacingAndMetadataHierarchy() {
    var draft = FreePhotoDraft()
    draft.placeName = "大東山日落位"
    draft.setAltitudeText("438")
    draft.showsDate = false
    draft.showsCoordinates = true
    draft.setLatitudeText("22.4084")
    draft.setLongitudeText("114.1201")

    let summary = FreePhotoMetadataSummary(draft: draft)
    #expect(summary.altitude.value.contains("438"))
    #expect(summary.date.visibility == .hidden)
    #expect(summary.coordinates.visibility == .shown)
}

@Test func trailStudioSummaryKeepsDenseMetadataConcise() {
    var draft = FreePhotoDraft()
    draft.placeName = "大東山日落位"
    draft.setAltitudeText("438")
    draft.showsCoordinates = true
    draft.setLatitudeText("22.4084")
    draft.setLongitudeText("114.1201")

    let summary = FreePhotoMetadataSummary(draft: draft)
    #expect(summary.altitude.value.count <= 12)
    #expect(summary.coordinates.value.contains("22.40840"))
    #expect(summary.coordinates.value.contains { $0.isNumber })
    #expect(summary.coordinates.value != summary.coordinates.visibility.label)
    #expect(summary.coordinates.visibility == .shown)

    var hiddenDraft = draft
    hiddenDraft.showsCoordinates = false
    let hidden = FreePhotoMetadataSummary(draft: hiddenDraft)
    #expect(hidden.coordinates.value.contains("22.40840"))
    #expect(hidden.coordinates.visibility == .hidden)

    let empty = FreePhotoMetadataSummary(draft: FreePhotoDraft())
    #expect(empty.coordinates.value == AppText.value(zh: "未設定", en: "Not set"))
    #expect(empty.coordinates.visibility == .notSet)

    let content = FreePhotoFrameContent(
        placeName: draft.validatedName,
        altitudeMetres: 438,
        altitudeSource: .gpsApproximate,
        date: .now
    )
    #expect((content.altitudeLabel?.count ?? 100) <= 18)
}

@Test func freePhotoEditorShowsCaptureBeforePhotoAndStudioAfterPhoto() {
    #expect(FreePhotoEditorPresentation(hasPhoto: false).mode == .capture)
    #expect(FreePhotoEditorPresentation(hasPhoto: true).mode == .studio)
    #expect(FreePhotoEditorPresentation(hasPhoto: true).usesStickySave)
    #expect(!FreePhotoEditorPresentation(hasPhoto: true).showsExpandedMetadataOnCanvas)
}

@Test func previewHeightUsesTheSelectedRendererCanvasAspectRatio() {
    let availableWidth: CGFloat = 335
    let polaroid = FreePhotoPreviewLayout(style: .polaroid)
    let passport = FreePhotoPreviewLayout(style: .passport)

    #expect(polaroid.height(forAvailableWidth: availableWidth) == availableWidth * 1400 / 1080)
    #expect(passport.height(forAvailableWidth: availableWidth) == availableWidth * 1110 / 1080)
    #expect(polaroid.height(forAvailableWidth: 0) == 0)
}

@Test func loadedPhotoCanRoundTripPassportAndPolaroidLayouts() {
    let width: CGFloat = 335
    let passportBefore = FreePhotoPreviewLayout(style: .passport)
        .height(forAvailableWidth: width)
    let polaroid = FreePhotoPreviewLayout(style: .polaroid)
        .height(forAvailableWidth: width)
    let passportAfter = FreePhotoPreviewLayout(style: .passport)
        .height(forAvailableWidth: width)

    #expect(passportBefore != polaroid)
    #expect(passportAfter == passportBefore)
    #expect(!FreePhotoPreviewInteractionContract.cardAllowsHitTesting)
}

@Test func savedFreePhotoConfirmationOnlyAppliesToTheCurrentRenderedInputs() {
    let saved = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .none,
        cardStyle: .passport,
        renderedAt: .distantPast,
        frameDate: .distantPast,
        showsDate: true,
        latitudeText: "",
        longitudeText: "",
        showsCoordinates: false
    )
    var confirmation = FreePhotoSaveConfirmation()
    confirmation.markSaved(for: saved)

    #expect(confirmation.isCurrent(for: saved))
    #expect(!confirmation.isCurrent(for: FreePhotoExportFingerprint(
        captureRevision: 2,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .none,
        cardStyle: .passport,
        renderedAt: .distantPast,
        frameDate: .distantPast,
        showsDate: true,
        latitudeText: "",
        longitudeText: "",
        showsCoordinates: false
    )))
    #expect(!confirmation.isCurrent(for: FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "獅子山",
        altitudeMetres: 869,
        altitudeSource: .none,
        cardStyle: .passport,
        renderedAt: .distantPast,
        frameDate: .distantPast,
        showsDate: true,
        latitudeText: "",
        longitudeText: "",
        showsCoordinates: false
    )))
    #expect(!confirmation.isCurrent(for: FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 900,
        altitudeSource: .none,
        cardStyle: .passport,
        renderedAt: .distantPast,
        frameDate: .distantPast,
        showsDate: true,
        latitudeText: "",
        longitudeText: "",
        showsCoordinates: false
    )))
    #expect(!confirmation.isCurrent(for: FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .none,
        cardStyle: .polaroid,
        renderedAt: .distantPast,
        frameDate: .distantPast,
        showsDate: true,
        latitudeText: "",
        longitudeText: "",
        showsCoordinates: false
    )))
}

@Test func saveRequestIdentityIncludesAltitudeSourceAndExactRenderDate() {
    let renderedAt = ISO8601DateFormatter().date(from: "2026-08-18T15:59:59Z")!
    let nextDate = ISO8601DateFormatter().date(from: "2026-08-18T16:00:00Z")!
    let gps = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .gpsApproximate,
        cardStyle: .passport,
        renderedAt: renderedAt,
        frameDate: .distantPast,
        showsDate: true,
        latitudeText: "",
        longitudeText: "",
        showsCoordinates: false
    )
    let manualSameValue = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .manual,
        cardStyle: .passport,
        renderedAt: renderedAt,
        frameDate: .distantPast,
        showsDate: true,
        latitudeText: "",
        longitudeText: "",
        showsCoordinates: false
    )
    let nextDay = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .gpsApproximate,
        cardStyle: .passport,
        renderedAt: nextDate,
        frameDate: .distantPast,
        showsDate: true,
        latitudeText: "",
        longitudeText: "",
        showsCoordinates: false
    )

    #expect(gps != manualSameValue)
    #expect(gps != nextDay)
}

@Test func saveFingerprintIncludesEditableDateCoordinatesAndSwitches() {
    let renderedAt = Date(timeIntervalSince1970: 10)
    let frameDate = Date(timeIntervalSince1970: 5)
    let baseline = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .none,
        cardStyle: .passport,
        renderedAt: renderedAt,
        frameDate: frameDate,
        showsDate: true,
        latitudeText: "22.40840",
        longitudeText: "114.12010",
        showsCoordinates: true
    )
    let dateHidden = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .none,
        cardStyle: .passport,
        renderedAt: renderedAt,
        frameDate: frameDate,
        showsDate: false,
        latitudeText: "22.40840",
        longitudeText: "114.12010",
        showsCoordinates: true
    )
    let editedLatitude = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .none,
        cardStyle: .passport,
        renderedAt: renderedAt,
        frameDate: frameDate,
        showsDate: true,
        latitudeText: "22.50000",
        longitudeText: "114.12010",
        showsCoordinates: true
    )
    let coordinatesHidden = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .none,
        cardStyle: .passport,
        renderedAt: renderedAt,
        frameDate: frameDate,
        showsDate: true,
        latitudeText: "22.40840",
        longitudeText: "114.12010",
        showsCoordinates: false
    )

    #expect(baseline != dateHidden)
    #expect(baseline != editedLatitude)
    #expect(baseline != coordinatesHidden)
}

@Test func lateSaveSuccessAndErrorCannotUpdateChangedRenderedContent() {
    let saved = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .gpsApproximate,
        cardStyle: .passport,
        renderedAt: Date(timeIntervalSince1970: 1_000),
        frameDate: .distantPast,
        showsDate: true,
        latitudeText: "",
        longitudeText: "",
        showsCoordinates: false
    )
    let changed = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .manual,
        cardStyle: .passport,
        renderedAt: Date(timeIntervalSince1970: 1_000),
        frameDate: .distantPast,
        showsDate: true,
        latitudeText: "",
        longitudeText: "",
        showsCoordinates: false
    )
    var request = FreePhotoSaveRequestState()

    request.begin(for: saved)
    let staleSuccess = request.completeSuccess(for: saved, currentFingerprint: changed)
    #expect(!staleSuccess)

    request.begin(for: saved)
    let staleFailure = request.completeFailure(for: saved, currentFingerprint: changed)
    #expect(!staleFailure)

    request.begin(for: saved)
    let currentSuccess = request.completeSuccess(for: saved, currentFingerprint: saved)
    #expect(currentSuccess)
}

@Test func overlappingLocationConsumersAreReferenceCountedByScope() {
    var acquisitions = LocationAcquisitionState()
    let ranked = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    let freePhoto = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002")!

    let rankedStartedUpdates = acquisitions.acquire(ranked)
    let duplicateRankedStart = acquisitions.acquire(ranked)
    let freePhotoStartedUpdates = acquisitions.acquire(freePhoto)
    #expect(rankedStartedUpdates)
    #expect(!duplicateRankedStart)
    #expect(!freePhotoStartedUpdates)
    #expect(acquisitions.activeCount == 2)

    let freePhotoStoppedUpdates = acquisitions.release(freePhoto)
    #expect(!freePhotoStoppedUpdates)
    #expect(acquisitions.isActive)
    let rankedStoppedUpdates = acquisitions.release(ranked)
    #expect(rankedStoppedUpdates)
    #expect(!acquisitions.isActive)
}
