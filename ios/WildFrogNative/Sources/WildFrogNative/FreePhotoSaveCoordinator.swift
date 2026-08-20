import Foundation
import UIKit

struct FreePhotoSaveRequest: Equatable {
    let id: UUID
    let captureRevision: Int
    let renderedAt: Date
    let placeName: String
    let altitudeMetres: Int?
    let altitudeSource: FreePhotoAltitudeSource
    let cardStyle: FreePhotoCardStyle
    let location: FreePhotoLocationCandidate?
}

enum FreePhotoSaveOutcome: Equatable {
    case completed
    case photoSavedMapFailed(assetIdentifier: String)
    case failed
    case ignored
}

enum FreePhotoDeletionMode: Equatable {
    case recordOnly
    case recordAndFramedPhoto
}

enum FreePhotoDeletionOutcome: Equatable {
    case completed
    case assetNotFound
    case photosFailed
    case recordFailed
    case missingPhotosIdentifier
}

@MainActor
final class FreePhotoDeletionCoordinator {
    func delete(
        record: FreePhotoRecord,
        mode: FreePhotoDeletionMode,
        photos: PhotoLibraryAssetDeleting,
        records: FreePhotoRecordDeleting
    ) async -> FreePhotoDeletionOutcome {
        if mode == .recordAndFramedPhoto {
            guard let identifier = record.photosAssetIdentifier else {
                return .missingPhotosIdentifier
            }
            do {
                try await photos.deleteAsset(localIdentifier: identifier)
            } catch PhotoLibrarySaveError.assetNotFound {
                return .assetNotFound
            } catch {
                return .photosFailed
            }
        }
        do {
            try records.removeRecord(id: record.id)
            return .completed
        } catch {
            return .recordFailed
        }
    }
}

@MainActor
final class FreePhotoSaveCoordinator {
    private struct Recovery {
        let request: FreePhotoSaveRequest
        let assetIdentifier: String
    }

    private var activeRequestID: UUID?
    private var recovery: Recovery?

    func save(
        request: FreePhotoSaveRequest,
        renderedImage: UIImage,
        thumbnailData: Data,
        photos: PhotoLibrarySaving,
        store: FreePhotoRecordPersisting
    ) async -> FreePhotoSaveOutcome {
        activeRequestID = request.id
        do {
            let identifier = try await photos.save(renderedImage)
            guard activeRequestID == request.id else { return .ignored }
            recovery = Recovery(request: request, assetIdentifier: identifier)
            do {
                try store.append(
                    record: makeRecord(request: request, assetIdentifier: identifier),
                    thumbnailData: thumbnailData
                )
                guard activeRequestID == request.id else { return .ignored }
                recovery = nil
                activeRequestID = nil
                return .completed
            } catch {
                return .photoSavedMapFailed(assetIdentifier: identifier)
            }
        } catch {
            guard activeRequestID == request.id else { return .ignored }
            activeRequestID = nil
            return .failed
        }
    }

    func retry(
        request: FreePhotoSaveRequest,
        thumbnailData: Data,
        store: FreePhotoRecordPersisting
    ) -> FreePhotoSaveOutcome {
        guard let recovery,
              recovery.request == request else { return .ignored }
        do {
            try store.append(
                record: makeRecord(request: request, assetIdentifier: recovery.assetIdentifier),
                thumbnailData: thumbnailData
            )
            self.recovery = nil
            activeRequestID = nil
            return .completed
        } catch {
            return .photoSavedMapFailed(assetIdentifier: recovery.assetIdentifier)
        }
    }

    func invalidate() {
        activeRequestID = nil
    }

    private func makeRecord(
        request: FreePhotoSaveRequest,
        assetIdentifier: String
    ) -> FreePhotoRecord {
        FreePhotoRecord(
            id: request.id,
            createdAt: request.renderedAt,
            renderedAt: request.renderedAt,
            placeName: request.placeName,
            altitudeMetres: request.altitudeMetres,
            altitudeSource: request.altitudeSource,
            cardStyle: request.cardStyle,
            coordinate: request.location?.coordinate,
            locationSource: request.location?.source ?? .missing,
            horizontalAccuracy: request.location?.horizontalAccuracy,
            locationTimestamp: request.location?.timestamp,
            photosAssetIdentifier: assetIdentifier,
            thumbnailFilename: "\(request.id.uuidString).jpg"
        )
    }
}
