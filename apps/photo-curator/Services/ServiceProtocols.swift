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
}

/// Image facts in, `PhotoAnalysis` out. No albums, no SwiftUI, no final picks.
protocol ImageAnalysisService: Sendable {
    func analyze(_ input: AnalysisInput) async throws -> PhotoAnalysis
}

/// Actor-isolated store of recomputable derived analysis. Original photo bytes never enter.
protocol AnalysisCache: Actor {
    func analysis(for id: AssetID) async -> PhotoAnalysis?
    func store(_ analysis: PhotoAnalysis) async
}

/// Creates a new collision-safe album from existing assets. Never modifies or deletes originals.
protocol AlbumExportService: Sendable {
    func exportAlbum(name: String, assetIDs: [AssetID]) async throws
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
}

struct NoopImageAnalyzer: ImageAnalysisService {
    func analyze(_ input: AnalysisInput) async throws -> PhotoAnalysis {
        throw SelectionError.internal
    }
}

actor NoopAnalysisCache: AnalysisCache {
    func analysis(for id: AssetID) async -> PhotoAnalysis? {
        nil
    }

    func store(_ analysis: PhotoAnalysis) async {}
}

struct NoopAlbumExporter: AlbumExportService {
    func exportAlbum(name: String, assetIDs: [AssetID]) async throws {}
}

struct NoopAnalytics: AnalyticsService {
    func track(_ event: AnalyticsEvent) {}
}
