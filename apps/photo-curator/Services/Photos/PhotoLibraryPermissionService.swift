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
        LibraryChangeTracker.shared.ensureRegistered()
        let status = await authorizationStatus()
        guard status == .authorized || status == .limited else {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "photo-curator", category: "photos")
                .warning("fetchAssets called without photo access.")
            throw SelectionError.invalidInput
        }
        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        options.includeAllBurstAssets = true
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PhotoAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { phAsset, _, _ in
            assets.append(Self.map(phAsset))
        }
        return assets
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

    private static func map(_ ph: PHAsset) -> PhotoAsset {
        PhotoAsset(
            id: AssetID(rawValue: ph.localIdentifier),
            creationDate: ph.creationDate,
            pixelWidth: ph.pixelWidth,
            pixelHeight: ph.pixelHeight,
            mediaSubtype: mapSubtype(ph.mediaSubtypes),
            isFavorite: ph.isFavorite,
            source: .unknown
        )
    }

    /// Precedence is intentional: screenshot > live > panorama > hdr > portrait.
    /// Unmodeled flags map to .unknown; absence of flags maps to .standard.
    private static func mapSubtype(_ subtypes: PHAssetMediaSubtype) -> PhotoMediaSubtype {
        if subtypes.contains(.photoScreenshot) {
            return .screenshot
        }
        if subtypes.contains(.photoLive) {
            return .livePhoto
        }
        if subtypes.contains(.photoPanorama) {
            return .panorama
        }
        if subtypes.contains(.photoHDR) {
            return .hdr
        }
        if subtypes.contains(.photoDepthEffect) {
            return .portrait
        }
        if subtypes == [] {
            return .standard
        }
        return .unknown
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

extension Notification.Name {
    static let photoLibraryDidChange = Notification.Name("photoLibraryDidChange")
}

/// Shared, stateless tracker. The lock guards registration only; the callback
/// posts a thread-safe notification (PhotoKit calls it on an arbitrary queue).
/// Subscribers are owned by feat-004/005.
private final class LibraryChangeTracker: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    static let shared = LibraryChangeTracker()
    private let lock = NSLock()
    private var didRegister = false

    func ensureRegistered() {
        lock.lock()
        defer { self.lock.unlock() }
        guard !didRegister else { return }
        didRegister = true
        PHPhotoLibrary.shared().register(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // No cached fetch to invalidate: every fetchAssets() re-reads the
        // library fresh, so stale IDs surface as missing on next call.
        // Never rerun the pipeline from the observer.
        NotificationCenter.default.post(name: .photoLibraryDidChange, object: nil)
    }
}
