import CoreLocation
import Foundation
import Testing
import UIKit
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

    @Test func layerStateIsMutuallyExclusive() {
        var state = HomeMapLayerState()
        state.select(.freePhotos)
        #expect(state.layer == .freePhotos)
        #expect(!state.showsPeakMarkers)
        #expect(state.showsFreePhotoMarkers)
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
