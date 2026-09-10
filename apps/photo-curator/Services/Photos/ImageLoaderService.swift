import CoreGraphics
import Photos
import UIKit

extension Notification.Name {
    static let imageDownloadProgress = Notification.Name("imageDownloadProgress")
}

/// One immutable manager for thumbs + analysis loads. `@unchecked Sendable` is
/// justified narrowly: the manager is never reassigned and Apple documents
/// concurrent request/cancel as safe; all mutable per-request state lives in
/// `ImageRequestState` under `NSLock`.
final class ImageLoaderService: PhotoImageLoader, @unchecked Sendable {
    private let manager = PHCachingImageManager()

    func thumbnail(for id: AssetID, targetSize: CGSize) async throws -> CGImage {
        try await requestImage(for: id, targetSize: targetSize, contentMode: .aspectFill, fast: true)
    }

    func analysisImage(for id: AssetID) async throws -> CGImage {
        let edge = CGFloat(AppConfiguration.default.selection.analysisImageMaxDimension)
        return try await requestImage(
            for: id, targetSize: CGSize(width: edge, height: edge), contentMode: .aspectFit, fast: false
        )
    }
}

/// Per-request mutable state. All access is under `NSLock`; the single
/// terminal transition is claimed exactly once, so late results after cancel
/// are discarded and the continuation always resumes exactly once.
/// Installation is terminal-aware: when cancel already terminated the request
/// before the continuation or request ID was installed, the just-installed
/// continuation resumes immediately with `.cancelled`, and a late request ID
/// is handed back so the caller can cancel it instead of leaking it.
/// Cancellation itself claims atomically: one lock takes the continuation and
/// captures the request ID together, so an ID installed in between can never
/// escape cancellation. Nothing ever resumes while holding the lock.
private final class ImageRequestState: @unchecked Sendable {
    private let lock = NSLock()
    private var _requestID: PHImageRequestID = PHInvalidImageRequestID
    private var _continuation: CheckedContinuation<CGImage, Error>?
    private var _finished = false

    var requestID: PHImageRequestID {
        lock.lock(); defer { self.lock.unlock() }; return _requestID
    }

    /// Stores the continuation, unless the request already terminated — then
    /// resumes it immediately with `.cancelled` and returns false so the
    /// caller skips creating the PhotoKit request entirely.
    func setContinuation(_ continuation: CheckedContinuation<CGImage, Error>) -> Bool {
        lock.lock()
        guard !_finished else {
            lock.unlock()
            continuation.resume(throwing: AttemptError.cancelled)
            return false
        }
        _continuation = continuation
        lock.unlock()
        return true
    }

    /// Installs the request ID. Returns a late ID installed after termination
    /// that the caller must cancel, or nil when installation won the race.
    func setRequestID(_ requestID: PHImageRequestID) -> PHImageRequestID? {
        lock.lock()
        defer { lock.unlock() }
        guard !_finished else { return requestID }
        _requestID = requestID
        return nil
    }

    func claim() -> CheckedContinuation<CGImage, Error>? {
        lock.lock(); defer { self.lock.unlock() }
        guard !_finished else { return nil }
        _finished = true
        let taken = _continuation
        _continuation = nil
        return taken
    }

    /// Atomic cancel claim: under one lock, marks termination, takes the
    /// installed continuation (if any), and captures the request ID, so an ID
    /// installed between a separate read and claim can never go uncancelled.
    func cancelClaim() -> (CheckedContinuation<CGImage, Error>?, PHImageRequestID) {
        lock.lock()
        defer { lock.unlock() }
        guard !_finished else { return (nil, _requestID) }
        _finished = true
        let taken = _continuation
        _continuation = nil
        return (taken, _requestID)
    }
}

/// Internal cause before mapping to `SelectionError`. Kept private so the
/// three-case public error stays untouched while retry stays classifiable.
private enum AttemptError: Error {
    case missing, cancelled, network, failed
}

/// Short spelling so the request signatures fit on one line (SwiftFormat and
/// SwiftLint disagree on brace placement for wrapped declarations).
private typealias Mode = PHImageContentMode

private extension ImageLoaderService {
    func requestImage(for id: AssetID, targetSize: CGSize, contentMode: Mode, fast: Bool) async throws -> CGImage {
        guard targetSize.width.isFinite, targetSize.height.isFinite,
              targetSize.width > 0, targetSize.height > 0
        else { throw SelectionError.invalidInput }
        for attempt in 0 ..< 2 {
            if attempt > 0, Task.isCancelled {
                throw SelectionError.cancelled
            }
            do {
                return try await attemptRequest(for: id, targetSize: targetSize, contentMode: contentMode, fast: fast)
            } catch AttemptError.network where attempt == 0 {
                do {
                    try await Task.sleep(nanoseconds: 200_000_000)
                } catch {
                    throw SelectionError.cancelled
                }
            } catch AttemptError.missing {
                throw SelectionError.invalidInput
            } catch AttemptError.cancelled {
                throw SelectionError.cancelled
            } catch {
                throw SelectionError.internal
            }
        }
        throw SelectionError.internal
    }

    func attemptRequest(for id: AssetID, targetSize: CGSize, contentMode: Mode, fast: Bool) async throws -> CGImage {
        guard let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [id.rawValue], options: nil).firstObject else {
            throw AttemptError.missing
        }
        let state = ImageRequestState()
        let options = imageRequestOptions(for: id.rawValue, fast: fast)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard state.setContinuation(continuation) else { return }
                let requestID = self.manager.requestImage(
                    for: phAsset, targetSize: targetSize, contentMode: contentMode, options: options
                ) { [state, weak self] image, info in
                    guard let self else {
                        if let claimed = state.claim() {
                            claimed.resume(throwing: AttemptError.failed)
                        }
                        return
                    }
                    self.completeRequest(image: image, info: info, fast: fast, state: state)
                }
                if let lateID = state.setRequestID(requestID) {
                    self.manager.cancelImageRequest(lateID)
                }
            }
        } onCancel: {
            let (continuation, id) = state.cancelClaim()
            self.manager.cancelImageRequest(id)
            if let continuation {
                continuation.resume(throwing: AttemptError.cancelled)
            }
        }
    }

    func imageRequestOptions(for assetID: String, fast: Bool) -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        options.deliveryMode = fast ? .opportunistic : .highQualityFormat
        options.resizeMode = fast ? .fast : .exact
        options.progressHandler = { progress, _, _, _ in
            NotificationCenter.default.post(
                name: .imageDownloadProgress, object: nil,
                userInfo: ["assetID": assetID, "fraction": progress]
            )
        }
        return options
    }

    func completeRequest(image: UIImage?, info: [AnyHashable: Any]?, fast: Bool, state: ImageRequestState) {
        let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
        if cancelled || Task.isCancelled {
            if let claimed = state.claim() {
                claimed.resume(throwing: AttemptError.cancelled)
            }
            return
        }
        if let nsError = info?[PHImageErrorKey] as? NSError {
            if let claimed = state.claim() {
                claimed.resume(throwing: isNetworkError(nsError) ? AttemptError.network : AttemptError.failed)
            }
            return
        }
        let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
        if !fast, isDegraded {
            return
        }
        guard let uiImage = image, let cg = Self.normalizedCGImage(from: uiImage) else {
            if !isDegraded, let claimed = state.claim() {
                claimed.resume(throwing: AttemptError.failed)
            }
            return
        }
        if let claimed = state.claim() {
            if fast {
                manager.cancelImageRequest(state.requestID)
            }
            claimed.resume(returning: cg)
        }
    }

    /// Transient network failures eligible for the single retry: URL-session
    /// transport errors (`NSURLErrorDomain`), the documented Photos iCloud
    /// download failure (`PHPhotosErrorDomain` / `.networkError`, verified in
    /// the iOS 26.5 SDK `Photos.framework/Headers/PHError.h`), and either
    /// wrapped exactly one level deep in `NSUnderlyingErrorKey`.
    func isNetworkError(_ error: NSError) -> Bool {
        isDirectNetworkError(error) || (error.userInfo[NSUnderlyingErrorKey] as? NSError)
            .map(isDirectNetworkError) ?? false
    }

    /// Direct (non-recursive) check for one error object. Kept separate so a
    /// cyclic underlying-error chain can never overflow the stack.
    func isDirectNetworkError(_ error: NSError) -> Bool {
        if error.domain == NSURLErrorDomain {
            return true
        }
        return error.domain == PHPhotosErrorDomain && PHPhotosError.Code(rawValue: error.code) == .networkError
    }

    /// Bakes `UIImage.imageOrientation` into fresh pixels (`UIGraphicsImageRenderer`
    /// is safe off-main). The protocol returns `CGImage` only, so Vision in
    /// feat-005 receives upright pixels with no orientation side-channel.
    static func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cg = image.cgImage {
            return cg
        }
        let format = UIGraphicsImageRendererFormat()
        // Preserve source pixels: size is points, so redraw at the image's own
        // scale (scale 1 would downsample scaled assets).
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(at: .zero)
        }.cgImage
    }
}
