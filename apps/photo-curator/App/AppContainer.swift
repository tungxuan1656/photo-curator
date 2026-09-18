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
    /// Tier-C visual-embedding provider (feat-024, DEC-035): native derived
    /// by default, injected into `SelectionSessionCoordinator` for both
    /// production selection paths. No model, no persisted state.
    let tierCProvider: any VisualEmbeddingProvider
    /// Optional iOS 27 semantic jury; router gates invocation and all fallbacks are deterministic.
    let semanticJuryProvider: any SemanticJuryProvider
    let exporter: any AlbumExportService
    let analytics: any AnalyticsService
    let memoryPressure: MemoryPressureObserver
    let modelInstallation: ModelInstallationService
    let qwenJudge: QwenPairJudge?

    init(
        photoLibrary: any PhotoLibraryService,
        imageLoader: any PhotoImageLoader,
        analyzer: any ImageAnalysisService,
        analysisCache: any AnalysisCache,
        checkpointStore: SessionCheckpointStore,
        selectionEngine: SelectionEngine,
        tierCProvider: any VisualEmbeddingProvider,
        semanticJuryProvider: any SemanticJuryProvider,
        exporter: any AlbumExportService,
        analytics: any AnalyticsService,
        memoryPressure: MemoryPressureObserver,
        modelInstallation: ModelInstallationService,
        qwenJudge: QwenPairJudge? = nil
    ) {
        self.photoLibrary = photoLibrary
        self.imageLoader = imageLoader
        self.analyzer = analyzer
        self.analysisCache = analysisCache
        self.checkpointStore = checkpointStore
        self.selectionEngine = selectionEngine
        self.tierCProvider = tierCProvider
        self.semanticJuryProvider = semanticJuryProvider
        self.exporter = exporter
        self.analytics = analytics
        self.memoryPressure = memoryPressure
        self.modelInstallation = modelInstallation
        self.qwenJudge = qwenJudge
    }

    /// G1 wiring: real permission service + file-backed cache/checkpoint + real
    /// analysis pipeline (feat-006 flips the analyzer switch); analytics stays
    /// Noop until its owning stage. Export is concrete since feat-011.
    static func live() -> Self {
        let dirs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let base =
            dirs.first ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let base else {
            preconditionFailure("AppContainer.live() needs a writable app directory.")
        }
        let root = base.appendingPathComponent("photo-curator", isDirectory: true)
        let files = FileStore(rootDirectory: root)
        let imageLoader = ImageLoaderService()
        return Self(
            photoLibrary: PhotoLibraryPermissionService(),
            imageLoader: imageLoader,
            analyzer: VisionAnalysisService(),
            analysisCache: FileAnalysisCache(
                files: files,
                analysisVersion: AppConfiguration.default.analysis.analysisVersion
            ),
            checkpointStore: SessionCheckpointStore(files: files),
            selectionEngine: SelectionEngine(),
            tierCProvider: NativeDerivedEmbeddingProvider(),
            semanticJuryProvider: FoundationModelsSemanticJuryProvider(),
            exporter: PhotoKitAlbumExporter(),
            analytics: NoopAnalytics(),
            memoryPressure: MemoryPressureObserver(),
            modelInstallation: ModelInstallationService(
                rootDirectory: root.appendingPathComponent("models", isDirectory: true)
            ),
            qwenJudge: QwenPairJudge(imageLoader: imageLoader)
        )
    }
}
