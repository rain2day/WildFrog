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
        cardStyle: .passport
    )
    var confirmation = FreePhotoSaveConfirmation()
    confirmation.markSaved(for: saved)

    #expect(confirmation.isCurrent(for: saved))
    #expect(!confirmation.isCurrent(for: FreePhotoExportFingerprint(
        captureRevision: 2,
        placeName: "大東山",
        altitudeMetres: 869,
        cardStyle: .passport
    )))
    #expect(!confirmation.isCurrent(for: FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "獅子山",
        altitudeMetres: 869,
        cardStyle: .passport
    )))
    #expect(!confirmation.isCurrent(for: FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 900,
        cardStyle: .passport
    )))
    #expect(!confirmation.isCurrent(for: FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        cardStyle: .polaroid
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
        renderedAt: renderedAt
    )
    let manualSameValue = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .manual,
        cardStyle: .passport,
        renderedAt: renderedAt
    )
    let nextDay = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .gpsApproximate,
        cardStyle: .passport,
        renderedAt: nextDate
    )

    #expect(gps != manualSameValue)
    #expect(gps != nextDay)
}

@Test func lateSaveSuccessAndErrorCannotUpdateChangedRenderedContent() {
    let saved = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .gpsApproximate,
        cardStyle: .passport,
        renderedAt: Date(timeIntervalSince1970: 1_000)
    )
    let changed = FreePhotoExportFingerprint(
        captureRevision: 1,
        placeName: "大東山",
        altitudeMetres: 869,
        altitudeSource: .manual,
        cardStyle: .passport,
        renderedAt: Date(timeIntervalSince1970: 1_000)
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
