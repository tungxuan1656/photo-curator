# feat-003 — PhotoKit fetch + ImageLoader + iCloud

## Goal

Land PhotoKit fetch + ImageLoader + iCloud so 1k local assets load.

## Scope

- `Services/Photos/PhotoLibraryPermissionService.swift` (fetch + map + tracker; the owns entry `PhotoLibraryService.swift` predates the real filename)
- `Services/Photos/ImageLoaderService.swift` (new)
- Sequential touch: `App/AppContainer.swift` (DI swap only; owned by feat-002, allowed per flat-sequential rule)

## Non-goals

- Anything outside owns; SourceSelection UI stays in feat-004.
- No Vision, scoring, or custom disk image cache.

## Design (accepted 2026-09-10, Approach A: split services; reconciled per oracle review)

- Architecture: `PhotoLibraryPermissionService` adds fetch + metadata map + one shared change tracker; `ImageLoaderService` owns one `PHCachingImageManager` + locked once-only request state + single-request iCloud. Wired in `AppContainer.live()`. No stored fetch state (keeps the struct `Sendable`). Owner: `docs/design-docs/apple-frameworks.md` §4–§7, §9–§10.
- Fetch: `.image` only, exclude hidden, `includeAllBurstAssets = true` (keeps burst members for feat-007; no burst field on `PhotoAsset` in MVP), Live as still, screenshots included, sort by `creationDate` ascending; map cheap fields to `PhotoAsset`. Album/date-range/trip filters have no input on `fetchAssets()` and arrive with feat-004. Owner: `apple-frameworks.md` §4.
- Loading: thumbnail fast/opportunistic (first usable frame wins, then cancel second delivery); analysis image 512 px long edge, final frame only, orientation baked by redrawing into a new `CGImage` (protocol returns `CGImage` only, so Vision gets upright pixels), single decode then release. `targetSize` is pixels, validated finite/positive. Owner: `apple-frameworks.md` §6 + `docs/ship-gates/performance.md` §1.
- iCloud: Stage A metadata only; Stage B downloads with `isNetworkAccessAllowed = true` and posts per-asset progress (`.imageDownloadProgress` with `assetID` + `fraction`). Aggregate `Downloading n/total` + 4 Hz ownership moves to the feat-005 batch pipeline. One transient network retry inside the loader, then the caller counts unavailable. Owner: `apple-frameworks.md` §7.
- Cancel/observer: task cancel → `cancelImageRequest` + resume `.cancelled` under a locked claim (late results discarded; sync first-delivery safe). Tracker posts `.photoLibraryDidChange`; subscribers owned by feat-004/005; every fetch re-reads fresh so staleness surfaces as missing. Owner: `apple-frameworks.md` §5, §9–§10, §12.
- Errors: stale ID → `.invalidInput`; cancel → `.cancelled`; network/decode → `.internal` after one network retry. Callers gate on `authorizationStatus()` first (feat-002 flow); `fetchAssets()` defensively throws `.invalidInput` with a log when called without access.

## Implementation Plan (inline per AGENTS.md; no docs/plans file)

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `fetchAssets()` plus a real `ImageLoaderService` so 1k local assets load with iCloud download + progress, cancel, and observer.

**Architecture:** Two thin services behind existing protocols. `PhotoLibraryPermissionService` adds fetch + metadata map + one change observer. New `ImageLoaderService` owns one `PHCachingImageManager` with task-cooperative cancel and single-request iCloud (network allowed, progress surfaced). `AppContainer.live()` swaps the loader. No Vision, no scoring, no UI.

**Tech Stack:** Swift 5, PhotoKit (`PHAsset`, `PHFetchOptions`, `PHCachingImageManager`, `PHPhotoLibraryChangeObserver`), CoreGraphics `CGImage`, SwiftLint (strict) + SwiftFormat, Xcode project `apps/photo-curator.xcodeproj` scheme `photo-curator`.

## Global Constraints

- No test targets, no `*Test*.swift`, no test frameworks; validation is manual only and `./init.sh` reports `SKIP [test]`.
- `./init.sh` must pass (format, `swiftlint --strict`, `BUILD SUCCEEDED`).
- `AssetID` wraps `PHAsset.localIdentifier` (`AssetID(rawValue:)`); never persist `PHAsset`, `UIImage`, or `CGImage`.
- Analysis image long edge is `analysisImageMaxDimension: 512` (`AppConfiguration.default.selection`).
- Respect `maxConcurrentImageRequests: 2`, `analysisBatchSize: 32`, `checkpointEveryAssets: 25` / `checkpointEverySeconds: 10`, `progressMaxHertz: 4`.
- Reuse `SelectionError` (`.invalidInput`, `.cancelled`, `.internal`); typed per-layer errors arrive with owning stages.
- On-device only; never delete, edit, hide, or favorite originals; only write is user-approved album (later feat).
- Minimum deployment iOS 26; smoke on iOS 26.5 device/simulator.

## File Structure

- Modify `apps/photo-curator/Services/Photos/PhotoLibraryPermissionService.swift:23-26` — replace `TODO(feat-003)` with fetch + map + observer. (Owns entry `Services/Photos/PhotoLibraryService.swift` maps to this existing file; no duplicate service file.)
- Create `apps/photo-curator/Services/Photos/ImageLoaderService.swift` — `final class ImageLoaderService: PhotoImageLoader` with one `PHCachingImageManager`.
- Modify `apps/photo-curator/App/AppContainer.swift:27-28` — `imageLoader: NoopImageLoader()` becomes `imageLoader: ImageLoaderService()`.

Explicitly out of this loader (owned by the feat-005 batch pipeline): concurrency cap enforcement, aggregate progress, checkpointing, and retry policy beyond the loader's single transient-network retry. This loader is per-asset only.

---

### Task 1: Fetch + metadata map + change observer

**Files:**
- Modify: `apps/photo-curator/Services/Photos/PhotoLibraryPermissionService.swift:23-26`

**Interfaces:**
- Consumes: `authorizationStatus()`, `PHAsset.fetchAssets(with:options:)`, `AssetID(rawValue:)`, `PhotoAsset(id:creationDate:pixelWidth:pixelHeight:mediaSubtype:isFavorite:source:)`, `SelectionError.invalidInput`, `Notification.Name.photoLibraryDidChange`
- Produces: `func fetchAssets() async throws -> [PhotoAsset]` sorted by `creationDate` ascending, hidden excluded, burst members kept, `.image` only

- [ ] **Step 1: Replace fetchAssets with guarded fetch + cheap-field map**

```swift
func fetchAssets() async throws -> [PhotoAsset] {
    LibraryChangeTracker.shared.ensureRegistered()
    let status = await self.authorizationStatus()
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

private static func map(_ ph: PHAsset) -> PhotoAsset {
    PhotoAsset(
        id: AssetID(rawValue: ph.localIdentifier),
        creationDate: ph.creationDate,
        pixelWidth: ph.pixelWidth,
        pixelHeight: ph.pixelHeight,
        mediaSubtype: Self.mapSubtype(ph.mediaSubtypes),
        isFavorite: ph.isFavorite,
        source: .unknown
    )
}

/// Precedence is intentional: screenshot > live > panorama > hdr > portrait.
/// Unmodeled flags map to .unknown; absence of flags maps to .standard.
private static func mapSubtype(_ s: PHAssetMediaSubtype) -> PhotoMediaSubtype {
    if s.contains(.photoScreenshot) { return .screenshot }
    if s.contains(.photoLive) { return .livePhoto }
    if s.contains(.photoPanorama) { return .panorama }
    if s.contains(.photoHDR) { return .hdr }
    if s.contains(.photoDepthEffect) { return .portrait }
    if s == [] { return .standard }
    return .unknown
}
```

Album/date-range/trip filters have no input on `fetchAssets()` (`ServiceProtocols.swift:19`); filtered fetching arrives with feat-004 SourceSelection.

- [ ] **Step 2: Add one shared change tracker that notifies, never reruns**

```swift
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
        self.lock.lock()
        defer { self.lock.unlock() }
        guard !self.didRegister else { return }
        self.didRegister = true
        PHPhotoLibrary.shared().register(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // No cached fetch to invalidate: every fetchAssets() re-reads the
        // library fresh, so stale IDs surface as missing on next call.
        // Never rerun the pipeline from the observer.
        NotificationCenter.default.post(name: .photoLibraryDidChange, object: nil)
    }
}
```

- [ ] **Step 3: Run format + lint + build**

Run: `./init.sh`
Expected: format clean, `swiftlint --strict` clean, `BUILD SUCCEEDED`, `SKIP [test]`.

### Task 2: ImageLoaderService with cancel + iCloud

**Files:**
- Create: `apps/photo-curator/Services/Photos/ImageLoaderService.swift`

**Interfaces:**
- Consumes: `AssetID(rawValue:)`, `AppConfiguration.default.selection.analysisImageMaxDimension` (512), `SelectionError.invalidInput/.cancelled/.internal`
- Produces: `func thumbnail(for id: AssetID, targetSize: CGSize) async throws -> CGImage`; `func analysisImage(for id: AssetID) async throws -> CGImage`

- [ ] **Step 1: Create service shell with one shared manager**

```swift
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
        try await self.requestImage(for: id, targetSize: targetSize, contentMode: .aspectFill, fast: true)
    }

    func analysisImage(for id: AssetID) async throws -> CGImage {
        let edge = CGFloat(AppConfiguration.default.selection.analysisImageMaxDimension)
        return try await self.requestImage(
            for: id, targetSize: CGSize(width: edge, height: edge), contentMode: .aspectFit, fast: false
        )
    }
}
```

- [ ] **Step 2: Add locked once-only request state + retry + orientation bake**

```swift
/// Per-request mutable state. All access is under `NSLock`; the single
/// terminal transition is claimed exactly once, so late results after cancel
/// are discarded and the continuation always resumes exactly once.
private final class ImageRequestState: @unchecked Sendable {
    private let lock = NSLock()
    private var _requestID: PHImageRequestID = PHInvalidImageRequestID
    private var _continuation: CheckedContinuation<CGImage, Error>?
    private var _finished = false

    var requestID: PHImageRequestID {
        get { self.lock.lock(); defer { self.lock.unlock() }; return self._requestID }
        set { self.lock.lock(); self._requestID = newValue; self.lock.unlock() }
    }

    func setContinuation(_ c: CheckedContinuation<CGImage, Error>) {
        self.lock.lock(); self._continuation = c; self.lock.unlock()
    }

    func claim() -> CheckedContinuation<CGImage, Error>? {
        self.lock.lock(); defer { self.lock.unlock() }
        guard !self._finished else { return nil }
        self._finished = true
        return self._continuation
    }
}

/// Internal cause before mapping to `SelectionError`. Kept private so the
/// three-case public error stays untouched while retry stays classifiable.
private enum AttemptError: Error {
    case missing, cancelled, network, failed
}

private func requestImage(for id: AssetID, targetSize: CGSize, contentMode: PHImageContentMode, fast: Bool) async throws -> CGImage {
    guard targetSize.width.isFinite, targetSize.height.isFinite,
          targetSize.width > 0, targetSize.height > 0
    else { throw SelectionError.invalidInput }
    for attempt in 0..<2 {
        do {
            return try await self.attemptRequest(for: id, targetSize: targetSize, contentMode: contentMode, fast: fast)
        } catch AttemptError.network where attempt == 0 {
            try? await Task.sleep(nanoseconds: 200_000_000)
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

private func attemptRequest(for id: AssetID, targetSize: CGSize, contentMode: PHImageContentMode, fast: Bool) async throws -> CGImage {
    guard let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [id.rawValue], options: nil).firstObject else {
        throw AttemptError.missing
    }
    let state = ImageRequestState()
    let options = PHImageRequestOptions()
    options.isSynchronous = false
    options.isNetworkAccessAllowed = true
    options.deliveryMode = fast ? .opportunistic : .highQualityFormat
    options.resizeMode = fast ? .fast : .exact
    options.progressHandler = { progress, _, _, _ in
        NotificationCenter.default.post(
            name: .imageDownloadProgress, object: nil,
            userInfo: ["assetID": id.rawValue, "fraction": progress]
        )
    }
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            state.setContinuation(continuation)
            state.requestID = self.manager.requestImage(
                for: phAsset, targetSize: targetSize, contentMode: contentMode, options: options
            ) { [state, weak self] image, info in
                guard let self else {
                    if let c = state.claim() { c.resume(throwing: AttemptError.failed) }
                    return
                }
                let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                if cancelled || Task.isCancelled {
                    if let c = state.claim() { c.resume(throwing: AttemptError.cancelled) }
                    return
                }
                if let nsError = info?[PHImageErrorKey] as? NSError {
                    if let c = state.claim() {
                        c.resume(throwing: nsError.domain == NSURLErrorDomain ? AttemptError.network : AttemptError.failed)
                    }
                    return
                }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !fast, isDegraded { return }
                guard let uiImage = image, let cg = Self.normalizedCGImage(from: uiImage) else {
                    if !isDegraded, let c = state.claim() { c.resume(throwing: AttemptError.failed) }
                    return
                }
                if let c = state.claim() {
                    if fast { self.manager.cancelImageRequest(state.requestID) }
                    c.resume(returning: cg)
                }
            }
        }
    } onCancel: {
        self.manager.cancelImageRequest(state.requestID)
        if let c = state.claim() { c.resume(throwing: AttemptError.cancelled) }
    }
}

/// Bakes `UIImage.imageOrientation` into fresh pixels (`UIGraphicsImageRenderer`
/// is safe off-main). The protocol returns `CGImage` only, so Vision in
/// feat-005 receives upright pixels with no orientation side-channel.
private static func normalizedCGImage(from image: UIImage) -> CGImage? {
    if image.imageOrientation == .up, let cg = image.cgImage { return cg }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
        image.draw(at: .zero)
    }.cgImage
}
```

Correctness notes: one request covers local + iCloud (PhotoKit downloads only when needed; no separate probe). `Task.isCancelled` in the callback is a hint only — the locked `claim()` decides the single winner, so a cancel racing a completion discards the late result either way. A synchronous first delivery before `requestImage` returns is safe for the same reason (stale IDs are no-ops to `cancelImageRequest`). When cancel arrives with no further callback, `onCancel` claims and resumes — the continuation never hangs.

Failure mapping (public surface stays three cases):

| Situation | Loader behavior | Caller sees |
|---|---|---|
| Unresolvable ID | Throw immediately | `.invalidInput` → count unavailable, continue |
| Called without access | Log + throw (callers gate on `authorizationStatus()` first) | `.invalidInput` → programming error, never in normal flow |
| Transient network (`NSURLErrorDomain`) | Sleep 0.2 s, retry once | `.internal` on second failure → unavailable, continue |
| Permanent decode / other error | No retry | `.internal` → unavailable, continue |
| Task cancel | Cancel request + resume, or discard late result | `.cancelled` → stop |

- [ ] **Step 3: Run format + lint + build**

Run: `./init.sh`
Expected: format clean, `swiftlint --strict` clean, `BUILD SUCCEEDED`, `SKIP [test]`.

### Task 3: DI wiring + device verification

**Files:**
- Modify: `apps/photo-curator/App/AppContainer.swift:27-28`

**Interfaces:**
- Consumes: `PhotoLibraryPermissionService()`, `ImageLoaderService()`
- Produces: `AppContainer.live()` with real fetch + loader

- [ ] **Step 1: Swap the loader in live()**

```swift
photoLibrary: PhotoLibraryPermissionService(),
imageLoader: ImageLoaderService(),
```

- [ ] **Step 2: Run full verification**

Run: `./init.sh`
Expected: `BUILD SUCCEEDED`, `SKIP [test]`.

- [ ] **Step 3: Manual smoke (no test targets per policy)**

Check: app launches with real services wired and shows no crash; permission states still behave per feat-002. Full 1k-load, iCloud download, cancel, and observer behavior are exercised in feat-004 (first real caller) — no temporary diagnostic code is added here by design.

## Acceptance

- [x] `./init.sh` passes
- [x] Launch smoke with real services wired, no crash
- [x] 1k-load exercise deferred to feat-004 gate (first real caller; decided per oracle blocker 8)

## Depends

- feat-002

## Handoff

- State: done
- Evidence: `./init.sh` PASS (format, `swiftlint --strict` 0 violations/21 files, BUILD SUCCEEDED generic/platform=iOS Simulator, SKIP [test]); Gate 1 GO on attempt 3 (atomic cancelClaim + take-and-nil, `SelectionError.cancelled` mapping, non-recursive `isNetworkError`) + Gate 2 GO with no findings (1-line DI); simulator smoke iPhone 17 Pro iOS 26.5 — install + launch PID 31336, alive at +5s, no crash; 1k-load/iCloud/cancel/observer exercise deferred to feat-004 per plan.
- Blockers: none
- Next: feat-004 (SourceSelection + Summary on real fetch).

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
