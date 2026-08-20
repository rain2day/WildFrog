import Photos
import UIKit

private final class PhotoAssetIdentifierBox: @unchecked Sendable {
    var value: String?
}

@MainActor
protocol PhotoLibrarySaving {
    func save(_ image: UIImage) async throws -> String
}

@MainActor
protocol PhotoLibraryAssetDeleting {
    func deleteAsset(localIdentifier: String) async throws
}

enum PhotoLibrarySaveError: Error {
    case permissionDenied
    case missingAssetIdentifier
    case assetNotFound
    case unknown
}

struct PhotoLibrarySaver: PhotoLibrarySaving, PhotoLibraryAssetDeleting {
    func save(_ image: UIImage) async throws -> String {
        let status = await requestAddOnlyAuthorization()
        guard status == .authorized || status == .limited else {
            throw PhotoLibrarySaveError.permissionDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            let createdIdentifier = PhotoAssetIdentifierBox()
            PHPhotoLibrary.shared().performChanges {
                createdIdentifier.value = PHAssetChangeRequest
                    .creationRequestForAsset(from: image)
                    .placeholderForCreatedAsset?
                    .localIdentifier
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success,
                          let identifier = createdIdentifier.value,
                          !identifier.isEmpty {
                    continuation.resume(returning: identifier)
                } else if success {
                    continuation.resume(throwing: PhotoLibrarySaveError.missingAssetIdentifier)
                } else {
                    continuation.resume(throwing: PhotoLibrarySaveError.unknown)
                }
            }
        }
    }

    func deleteAsset(localIdentifier: String) async throws {
        let status = await requestReadWriteAuthorization()
        guard status == .authorized || status == .limited else {
            throw PhotoLibrarySaveError.permissionDenied
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard assets.count == 1 else { throw PhotoLibrarySaveError.assetNotFound }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoLibrarySaveError.unknown)
                }
            }
        }
    }

    private func requestAddOnlyAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestReadWriteAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
