import Foundation

/// Plain dependency holder, not a framework. Holds no feature state.
/// `SessionCheckpointStore` joins in feat-002A; real DI replaces Noops in feat-002INT.
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
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("photo-curator", isDirectory: true)
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
