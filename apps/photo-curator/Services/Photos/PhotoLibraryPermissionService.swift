import Foundation
import OSLog
import Photos
import PhotosUI
import UIKit

/// Real PhotoKit permission service (feat-002). Auth + limited-library picker only;
/// asset fetch arrives with feat-003.
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
        // TODO(feat-003): implement asset fetch.
        throw SelectionError.internal
    }

    func presentLimitedLibraryPicker() {
        Task { @MainActor in
            let scenes = UIApplication.shared.connectedScenes
            // Present from the topmost controller: the call site lives inside
            // a sheet, so rootViewController is already presenting (presenting
            // from it mid-dismissal drops the picker).
            guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
                  var topViewController = window.rootViewController
            else {
                Logger(subsystem: Bundle.main.bundleIdentifier ?? "photo-curator", category: "photos")
                    .warning("Limited-library picker dropped: no window to present from.")
                return
            }
            while let presented = topViewController.presentedViewController {
                topViewController = presented
            }
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: topViewController)
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
