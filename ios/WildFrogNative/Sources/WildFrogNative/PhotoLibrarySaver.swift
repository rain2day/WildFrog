import Photos
import UIKit

protocol PhotoLibrarySaving {
    func save(_ image: UIImage) async throws
}

enum PhotoLibrarySaveError: Error {
    case permissionDenied
    case unknown
}

struct PhotoLibrarySaver: PhotoLibrarySaving {
    func save(_ image: UIImage) async throws {
        let status = await requestAddOnlyAuthorization()
        guard status == .authorized || status == .limited else {
            throw PhotoLibrarySaveError.permissionDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
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
}
