import Foundation
import Photos
import PhotosUI
import UIKit

/// Real PhotoKit permission service (feat-002INT). Auth + limited-library picker only;
/// asset fetch arrives with feat-003A.
struct PhotoLibraryPermissionService: PhotoLibraryService, Sendable {
    func authorizationStatus() async -> PhotoLibraryAuthorization {
        Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAuthorization() async -> PhotoLibraryAuthorization {
        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
        return Self.map(status)
    }

    func fetchAssets() async throws -> [PhotoAsset] {
        // TODO(feat-003A): implement asset fetch.
        throw SelectionError.internal
    }

    func presentLimitedLibraryPicker() {
        Task { @MainActor in
            let scenes = UIApplication.shared.connectedScenes
            guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let window = scene.windows.first(where: { $0.isKeyWindow }),
                  let rootViewController = window.rootViewController
            else {
                return
            }
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: rootViewController)
        }
    }

    private static func map(_ status: PHAuthorizationStatus) -> PhotoLibraryAuthorization {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }
}
