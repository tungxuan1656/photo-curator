import Foundation

/// Plain dependency holder, not a framework. Holds no feature state.
/// `SessionCheckpointStore` joined in feat-002; real DI in feat-002.
struct AppContainer: Sendable {
    let photoLibrary: any PhotoLibraryService
    let imageLoader: any PhotoImageLoader
    let analyzer: any ImageAnalysisService
    let analysisCache: any AnalysisCache
    let checkpointStore: SessionCheckpointStore
    let selectionEngine: SelectionEngine
    let exporter: any AlbumExportService
    let analytics: any AnalyticsService

    /// G1 wiring: real permission service + file-backed cache/checkpoint;
    /// everything else stays Noop until its owning stage.
    static func live() -> Self {
        let dirs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let base =
            dirs.first ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let base else {
            preconditionFailure("AppContainer.live() needs a writable app directory.")
        }
        let root = base.appendingPathComponent("photo-curator", isDirectory: true)
        let files = FileStore(rootDirectory: root)
        return Self(
            photoLibrary: PhotoLibraryPermissionService(),
            imageLoader: NoopImageLoader(),
            analyzer: NoopImageAnalyzer(),
            analysisCache: FileAnalysisCache(
                files: files,
                analysisVersion: AppConfiguration.default.analysis.analysisVersion
            ),
            checkpointStore: SessionCheckpointStore(files: files),
            selectionEngine: SelectionEngine(),
            exporter: NoopAlbumExporter(),
            analytics: NoopAnalytics()
        )
    }
}
