/// Plain dependency holder, not a framework. Holds no feature state.
/// `SessionCheckpointStore` joins in feat-002A; real DI replaces Noops in feat-002INT.
struct AppContainer: Sendable {
    let photoLibrary: any PhotoLibraryService
    let imageLoader: any PhotoImageLoader
    let analyzer: any ImageAnalysisService
    let analysisCache: any AnalysisCache
    let selectionEngine: SelectionEngine
    let exporter: any AlbumExportService
    let analytics: any AnalyticsService

    /// G0 wiring: Noop doubles so lanes A and B link without waiting for each other.
    static func live() -> Self {
        Self(
            photoLibrary: NoopPhotoLibrary(),
            imageLoader: NoopImageLoader(),
            analyzer: NoopImageAnalyzer(),
            analysisCache: NoopAnalysisCache(),
            selectionEngine: SelectionEngine(),
            exporter: NoopAlbumExporter(),
            analytics: NoopAnalytics()
        )
    }
}
