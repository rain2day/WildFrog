import CoreLocation
import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import WildFrogNative

@MainActor
private final class FakeFreePhotoLibrary: PhotoLibrarySaving {
    private(set) var saveCount = 0

    func save(_ image: UIImage) async throws -> String {
        saveCount += 1
        return "framed-output-\(saveCount)"
    }
}

@MainActor
private final class FailingOnceFreePhotoPersistence: FreePhotoRecordPersisting {
    private var shouldFail = true
    private(set) var records: [FreePhotoRecord] = []

    func append(record: FreePhotoRecord, thumbnailData: Data) throws {
        if shouldFail {
            shouldFail = false
            throw FreePhotoStoreError.thumbnailWriteFailed
        }
        records.append(record)
    }
}

@MainActor
private final class FakeDeletionLibrary: PhotoLibraryAssetDeleting {
    var deletedIdentifiers: [String] = []
    var error: Error?

    func deleteAsset(localIdentifier: String) async throws {
        if let error { throw error }
        deletedIdentifiers.append(localIdentifier)
    }
}

@MainActor
private final class FakeRecordDeletion: FreePhotoRecordDeleting {
    var deletedIDs: [UUID] = []
    func removeRecord(id: UUID) throws { deletedIDs.append(id) }
}

@Suite("Free Photo private map")
struct FreePhotoPrivateMapTests {
    private func record(
        id: UUID = UUID(),
        createdAt: Date = Date(timeIntervalSince1970: 1),
        coordinate: FreePhotoCoordinate? = FreePhotoCoordinate(latitude: 22.3, longitude: 114.1),
        source: FreePhotoLocationSource = .cameraGPS,
        thumbnailFilename: String = "thumb.jpg"
    ) -> FreePhotoRecord {
        FreePhotoRecord(
            id: id,
            createdAt: createdAt,
            renderedAt: createdAt,
            placeName: "大東山",
            altitudeMetres: 869,
            altitudeSource: .gpsApproximate,
            cardStyle: .passport,
            coordinate: coordinate,
            locationSource: source,
            horizontalAccuracy: 8,
            locationTimestamp: createdAt,
            photosAssetIdentifier: "framed-output",
            thumbnailFilename: thumbnailFilename
        )
    }

    @Test func missingLocationNeverProjectsCoordinate() {
        let item = record(coordinate: nil, source: .missing)
        let projection = FreePhotoMapProjection(records: [item])
        #expect(projection.located.isEmpty)
        #expect(projection.needsLocation == [item])
    }

    @Test func projectionIsNewestFirst() {
        let old = record(createdAt: Date(timeIntervalSince1970: 1), thumbnailFilename: "old.jpg")
        let new = record(createdAt: Date(timeIntervalSince1970: 2), thumbnailFilename: "new.jpg")
        #expect(FreePhotoMapProjection(records: [old, new]).located.map(\.id) == [new.id, old.id])
    }

    @Test @MainActor func storePersistsAndManualPlacementOnlyChangesSelectedRecord() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = FreePhotoStorePaths(rootDirectory: root)
        let store = FreePhotoStore(paths: paths)
        let first = record(coordinate: nil, source: .missing, thumbnailFilename: "first.jpg")
        let second = record(thumbnailFilename: "second.jpg")
        try store.append(record: first, thumbnailData: Data([1]))
        try store.append(record: second, thumbnailData: Data([2]))
        try store.setManualLocation(
            recordID: first.id,
            coordinate: FreePhotoCoordinate(latitude: 22.42, longitude: 114.21)
        )

        let reloaded = FreePhotoStore(paths: paths)
        #expect(reloaded.records.first(where: { $0.id == first.id })?.locationSource == .manual)
        #expect(reloaded.records.first(where: { $0.id == second.id })?.coordinate == second.coordinate)
        #expect(try Data(contentsOf: reloaded.thumbnailURL(for: first)) == Data([1]))
    }

    @Test @MainActor func corruptEnvelopeFailsSoftAndIsPreserved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = FreePhotoStorePaths(rootDirectory: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: paths.envelopeURL)
        let store = FreePhotoStore(paths: paths)
        #expect(store.records.isEmpty)
        #expect(store.lastCorruptEnvelopeURL != nil)
    }

    @Test func cameraLocationIsFreshAccurateAndRevisionBound() {
        let now = Date(timeIntervalSince1970: 100)
        let valid = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 22.3, longitude: 114.1),
            altitude: 10,
            horizontalAccuracy: 8,
            verticalAccuracy: 9,
            timestamp: now
        )
        #expect(FreePhotoLocationResolver.cameraCandidate(location: valid, captureRevision: 3, activeRevision: 3, now: now)?.source == .cameraGPS)
        #expect(FreePhotoLocationResolver.cameraCandidate(location: valid, captureRevision: 2, activeRevision: 3, now: now) == nil)

        let stale = CLLocation(
            coordinate: valid.coordinate,
            altitude: 10,
            horizontalAccuracy: 8,
            verticalAccuracy: 9,
            timestamp: now.addingTimeInterval(-61)
        )
        #expect(FreePhotoLocationResolver.cameraCandidate(location: stale, captureRevision: 3, activeRevision: 3, now: now) == nil)
    }

    @Test func importedMetadataWinsAndMissingNeedsExplicitChoice() {
        let metadata = FreePhotoLocationCandidate(
            coordinate: FreePhotoCoordinate(latitude: 35, longitude: 139),
            source: .sourcePhotoMetadata,
            horizontalAccuracy: nil,
            timestamp: nil
        )
        #expect(FreePhotoLocationSelectionState.imported(metadata: metadata).candidate == metadata)
        #expect(FreePhotoLocationSelectionState.imported(metadata: nil).requiresFallbackChoice)
    }

    @Test func imageMetadataReadsOriginalDateAndGPSTogether() throws {
        let data = try fixtureJPEG(
            latitude: 22.4084,
            latitudeRef: "N",
            longitude: 114.1201,
            longitudeRef: "E",
            dateTimeOriginal: "2026:08:20 09:30:00"
        )
        let fallback = Date(timeIntervalSince1970: 1)
        let timeZone = try #require(TimeZone(identifier: "Asia/Hong_Kong"))
        let metadata = FreePhotoMetadataReader.metadata(
            from: data,
            acceptedAt: fallback,
            timeZone: timeZone
        )

        #expect(metadata.location?.coordinate == FreePhotoCoordinate(latitude: 22.4084, longitude: 114.1201))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: metadata.creationDate)
        #expect(components.year == 2026)
        #expect(components.month == 8)
        #expect(components.day == 20)
        #expect(components.hour == 9)
        #expect(components.minute == 30)
    }

    @Test func missingSourceDateFallsBackToAcceptedImportTime() {
        let acceptedAt = Date(timeIntervalSince1970: 1_234)
        let metadata = FreePhotoMetadataReader.metadata(from: Data(), acceptedAt: acceptedAt)
        #expect(metadata.creationDate == acceptedAt)
        #expect(metadata.location == nil)
    }

    @Test func layerStateIsMutuallyExclusive() {
        var state = HomeMapLayerState()
        state.select(.freePhotos)
        #expect(state.layer == .freePhotos)
        #expect(!state.showsPeakMarkers)
        #expect(state.showsFreePhotoMarkers)
    }

    @Test func legacyRecordsWithoutAFrameDateStillDecode() throws {
        let legacy = """
        {
          "id": "1E2E5C1A-0000-4000-8000-000000000001",
          "createdAt": 1,
          "renderedAt": 2,
          "placeName": "大東山",
          "altitudeSource": "manual",
          "cardStyle": "passport",
          "locationSource": "missing",
          "thumbnailFilename": "thumb.jpg"
        }
        """
        let decoded = try JSONDecoder().decode(
            FreePhotoRecord.self,
            from: Data(legacy.utf8)
        )
        #expect(decoded.frameDate == nil)
        #expect(decoded.placeName == "大東山")
        // `createdAt` is export time and stays the map/calendar sort key.
        #expect(decoded.createdAt == Date(timeIntervalSinceReferenceDate: 1))

        let roundTripped = try JSONDecoder().decode(
            FreePhotoRecord.self,
            from: JSONEncoder().encode(record(id: decoded.id))
        )
        #expect(roundTripped.frameDate == nil)
    }

    @Test @MainActor func retryAfterLocalFailureDoesNotDuplicatePhotosAsset() async {
        let photos = FakeFreePhotoLibrary()
        let persistence = FailingOnceFreePhotoPersistence()
        let coordinator = FreePhotoSaveCoordinator()
        let request = FreePhotoSaveRequest(
            id: UUID(),
            captureRevision: 1,
            renderedAt: Date(timeIntervalSince1970: 10),
            placeName: "大東山",
            altitudeMetres: 869,
            altitudeSource: .gpsApproximate,
            cardStyle: .passport,
            frameDate: .distantPast,
            showsDate: true,
            displayCoordinate: nil,
            showsCoordinates: false,
            location: nil
        )

        let first = await coordinator.save(
            request: request,
            renderedImage: UIImage(),
            thumbnailData: Data([1]),
            photos: photos,
            store: persistence
        )
        #expect(first == .photoSavedMapFailed(assetIdentifier: "framed-output-1"))

        let retry = coordinator.retry(
            request: request,
            thumbnailData: Data([1]),
            store: persistence
        )
        #expect(retry == .completed)
        #expect(photos.saveCount == 1)
        #expect(persistence.records.first?.photosAssetIdentifier == "framed-output-1")
    }

    @Test @MainActor func printedCoordinateNeverBecomesPrivateMapCoordinate() async {
        let printed = FreePhotoCoordinate(latitude: 35, longitude: 139)
        let map = FreePhotoLocationCandidate(
            coordinate: FreePhotoCoordinate(latitude: 22.3, longitude: 114.1),
            source: .cameraGPS,
            horizontalAccuracy: 8,
            timestamp: nil
        )
        let request = FreePhotoSaveRequest(
            id: UUID(),
            captureRevision: 1,
            renderedAt: Date(timeIntervalSince1970: 10),
            placeName: "大東山",
            altitudeMetres: 869,
            altitudeSource: .gpsApproximate,
            cardStyle: .passport,
            frameDate: Date(timeIntervalSince1970: 5),
            showsDate: true,
            displayCoordinate: printed,
            showsCoordinates: true,
            location: map
        )
        let presentationChanged = FreePhotoSaveRequest(
            id: request.id,
            captureRevision: request.captureRevision,
            renderedAt: request.renderedAt,
            placeName: request.placeName,
            altitudeMetres: request.altitudeMetres,
            altitudeSource: request.altitudeSource,
            cardStyle: request.cardStyle,
            frameDate: request.frameDate,
            showsDate: request.showsDate,
            displayCoordinate: FreePhotoCoordinate(latitude: 51.5, longitude: -0.12),
            showsCoordinates: request.showsCoordinates,
            location: request.location
        )

        #expect(request != presentationChanged)
        #expect(request.displayCoordinate == printed)
        #expect(request.location?.coordinate == map.coordinate)

        let photos = FakeFreePhotoLibrary()
        let persistence = FailingOnceFreePhotoPersistence()
        let coordinator = FreePhotoSaveCoordinator()
        _ = await coordinator.save(
            request: request,
            renderedImage: UIImage(),
            thumbnailData: Data([1]),
            photos: photos,
            store: persistence
        )
        #expect(coordinator.retry(
            request: request,
            thumbnailData: Data([1]),
            store: persistence
        ) == .completed)
        #expect(persistence.records.first?.coordinate == map.coordinate)
        #expect(persistence.records.first?.coordinate != printed)
    }

    @Test @MainActor func recordOnlyDeleteNeverCallsPhotos() async {
        let library = FakeDeletionLibrary()
        let records = FakeRecordDeletion()
        let item = record()
        let outcome = await FreePhotoDeletionCoordinator().delete(
            record: item,
            mode: .recordOnly,
            photos: library,
            records: records
        )
        #expect(outcome == .completed)
        #expect(library.deletedIdentifiers.isEmpty)
        #expect(records.deletedIDs == [item.id])
    }

    @Test @MainActor func combinedDeletePreservesRecordWhenPhotosFails() async {
        let library = FakeDeletionLibrary()
        library.error = PhotoLibrarySaveError.permissionDenied
        let records = FakeRecordDeletion()
        let outcome = await FreePhotoDeletionCoordinator().delete(
            record: record(),
            mode: .recordAndFramedPhoto,
            photos: library,
            records: records
        )
        #expect(outcome == .photosFailed)
        #expect(records.deletedIDs.isEmpty)
    }
}

private func fixtureJPEG(
    latitude: Double,
    latitudeRef: String,
    longitude: Double,
    longitudeRef: String,
    dateTimeOriginal: String
) throws -> Data {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(
        data,
        UTType.jpeg.identifier as CFString,
        1,
        nil
    ))
    let properties: [CFString: Any] = [
        kCGImagePropertyGPSDictionary: [
            kCGImagePropertyGPSLatitude: latitude,
            kCGImagePropertyGPSLatitudeRef: latitudeRef,
            kCGImagePropertyGPSLongitude: longitude,
            kCGImagePropertyGPSLongitudeRef: longitudeRef
        ],
        kCGImagePropertyExifDictionary: [
            kCGImagePropertyExifDateTimeOriginal: dateTimeOriginal
        ]
    ]
    CGImageDestinationAddImage(
        destination,
        try #require(image.cgImage),
        properties as CFDictionary
    )
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}
