import CoreGraphics
import Foundation

/// Photo-library access level. Full/limited/denied flow is wired in feat-002.
enum PhotoLibraryAuthorization: Sendable {
    case notDetermined, limited, authorized, denied, restricted
}

/// Aggregate-only analytics event. Never carries image pixels or face data (DEC-018).
/// Typed per-event cases arrive with feat-009; G0 tracks by name.
struct AnalyticsEvent: Sendable {
    let name: String
}

/// Auth state, asset fetch, metadata map. No pixels, no scoring.
protocol PhotoLibraryService: Sendable {
    func authorizationStatus() async -> PhotoLibraryAuthorization
    func requestAuthorization() async -> PhotoLibraryAuthorization
    func fetchAssets() async throws -> [PhotoAsset]
    func presentLimitedLibraryPicker()
}

/// Sized image delivery. Picks request parameters; owns cancellation via task cooperation.
/// Sizes are pixels (PhotoKit units), not points: `thumbnail` callers multiply layout
/// points by display scale; `analysisImage` always uses the fixed 512 px edge.
protocol PhotoImageLoader: Sendable {
    func thumbnail(for id: AssetID, targetSize: CGSize) async throws -> CGImage
    func analysisImage(for id: AssetID) async throws -> CGImage
    /// Bounded detail preview (capped at 2048 px, aspect-fit). Reuses the
    /// single manager/request state, final-quality delivery, iCloud handling,
    /// and cancellation; honors a smaller caller targetSize.
    func preview(for id: AssetID, targetSize: CGSize) async throws -> CGImage
}

/// Image facts in, `ImageAnalysisOutput` (durable analysis + transient similarity) out.
/// No albums, no SwiftUI, no final picks. `similarityArtifact(for:)` rebuilds only
/// the deliberately non-persisted feature print for cache/resume hits.
protocol ImageAnalysisService: Sendable {
    func analyze(_ input: AnalysisInput) async throws -> ImageAnalysisOutput
    func similarityArtifact(for input: AnalysisInput) async throws -> ImageSimilarityArtifact?
}

/// Actor-isolated store of recomputable derived analysis. Original photo bytes never enter.
protocol AnalysisCache: Actor {
    func analysis(for id: AssetID) async -> PhotoAnalysis?
    /// Revision-aware read. A cache hit is valid only when both the analysis
    /// version and the current PhotoKit asset revision match.
    func analysis(for id: AssetID, assetRevision: AssetModificationFingerprint) async -> PhotoAnalysis?
    func store(_ analysis: PhotoAnalysis) async
    /// Revision-aware write for newly analyzed facts.
    func store(_ analysis: PhotoAnalysis, assetRevision: AssetModificationFingerprint) async
    /// Reset Analysis: drops cached rows; originals untouched.
    func reset() async
}

extension AnalysisCache {
    /// Compatibility defaults keep older cache implementations and callers
    /// source-compatible. The file-backed implementation overrides these
    /// overloads with actual revision validation.
    func analysis(for id: AssetID, assetRevision _: AssetModificationFingerprint) async -> PhotoAnalysis? {
        await analysis(for: id)
    }

    func store(_ analysis: PhotoAnalysis, assetRevision _: AssetModificationFingerprint) async {
        await store(analysis)
    }
}

/// Creates a new collision-safe album from existing assets. Never modifies or deletes originals.
protocol AlbumExportService: Sendable {
    /// Creates a new collision-safe album (`name`, `name 2`, …). Never reuses
    /// a pre-existing album. Throws `permissionLost` / `creationFailed`.
    func createAlbum(name: String) async throws -> CreatedAlbum
    /// Adds exactly these IDs to the existing album in one change request.
    /// Missing IDs resolve to no `PHAsset` and return as missing data, never
    /// a crash. Throws `permissionLost` / `creationFailed` / `assetsUnavailable`.
    func addToAlbum(albumLocalIdentifier: String, assetIDs: [AssetID]) async throws -> ExportResult
}

/// Identity of one newly created output album.
struct CreatedAlbum: Sendable {
    let localIdentifier: String
    let title: String
}

/// What one add call created or filled, and what actually landed. Missing IDs
/// resolved to no `PHAsset` (deleted, revoked, changed limited set); the album
/// still holds every resolvable asset. UI copy never shows raw error text.
struct ExportResult: Sendable {
    let albumLocalIdentifier: String
    let albumTitle: String
    let addedIDs: [AssetID]
    let missingIDs: [AssetID]
}

/// Typed export failures for S15 mapping. No raw `NSError` text reaches UI.
enum ExportError: Error, Sendable {
    case permissionLost
    case creationFailed
    case assetsUnavailable
}

/// Product-behavior logging within the approved privacy model. Stays separate from OSLog logging.
protocol AnalyticsService: Sendable {
    func track(_ event: AnalyticsEvent)
}

// MARK: - Noop doubles for AppContainer.live()

struct NoopPhotoLibrary: PhotoLibraryService {
    func authorizationStatus() async -> PhotoLibraryAuthorization {
        .denied
    }

    func requestAuthorization() async -> PhotoLibraryAuthorization {
        .denied
    }

    func fetchAssets() async throws -> [PhotoAsset] {
        []
    }

    func presentLimitedLibraryPicker() {}
}

/// G0 Noop only: typed service errors arrive with their owning stages.
struct NoopImageLoader: PhotoImageLoader {
    func thumbnail(for id: AssetID, targetSize: CGSize) async throws -> CGImage {
        throw SelectionError.internal
    }

    func analysisImage(for id: AssetID) async throws -> CGImage {
        throw SelectionError.internal
    }

    func preview(for id: AssetID, targetSize: CGSize) async throws -> CGImage {
        throw SelectionError.internal
    }
}

struct NoopImageAnalyzer: ImageAnalysisService {
    func analyze(_ input: AnalysisInput) async throws -> ImageAnalysisOutput {
        throw SelectionError.internal
    }

    func similarityArtifact(for input: AnalysisInput) async throws -> ImageSimilarityArtifact? {
        nil
    }
}

actor NoopAnalysisCache: AnalysisCache {
    func analysis(for id: AssetID) async -> PhotoAnalysis? {
        nil
    }

    func analysis(for id: AssetID, assetRevision: AssetModificationFingerprint) async -> PhotoAnalysis? {
        nil
    }

    func store(_ analysis: PhotoAnalysis) async {}

    func store(_ analysis: PhotoAnalysis, assetRevision: AssetModificationFingerprint) async {}

    func reset() async {}
}

struct NoopAnalytics: AnalyticsService {
    func track(_ event: AnalyticsEvent) {}
}
