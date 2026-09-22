import Foundation
import OSLog
import SwiftData

/// Plain dependency holder, not a framework. Holds no feature state.
/// `SessionCheckpointStore` joined in feat-002; real DI in feat-002.
struct AppContainer: Sendable {
    private struct WorkspaceSetup {
        let modelContainer: ModelContainer?
        let store: WorkspaceStore?
        let importer: LegacyWorkspaceImporter?
        let availability: WorkspaceAvailability
        let albumOperations: AlbumSaveOperationStore?
        let albumSaveService: AlbumSaveService?
    }

    let photoLibrary: any PhotoLibraryService
    let imageLoader: any PhotoImageLoader
    let analyzer: any ImageAnalysisService
    let analysisCache: any AnalysisCache
    let checkpointStore: SessionCheckpointStore
    let workspaceModelContainer: ModelContainer?
    let workspaceStore: WorkspaceStore?
    let workspaceImporter: LegacyWorkspaceImporter?
    let workspaceAvailability: WorkspaceAvailability
    let selectionEngine: SelectionEngine
    /// Tier-C visual-embedding provider (feat-024, DEC-035): native derived
    /// by default, injected into `SelectionSessionCoordinator` for both
    /// production selection paths. No model, no persisted state.
    let tierCProvider: any VisualEmbeddingProvider
    /// Optional iOS 27 semantic jury; router gates invocation and all fallbacks are deterministic.
    let semanticJuryProvider: any SemanticJuryProvider
    let exporter: any AlbumExportService
    /// Durable album-save operation store (feat-035 owner). Shares the
    /// workspace `ModelContainer`; nil when workspace storage is
    /// unavailable (callers fall back to the file `SaveState` handoff).
    let albumOperations: AlbumSaveOperationStore?
    /// Independent album-save boundary (feat-035 owner). The only caller of
    /// album mutation APIs; nil when workspace storage is unavailable.
    let albumSaveService: AlbumSaveService?
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
        workspaceModelContainer: ModelContainer?,
        workspaceStore: WorkspaceStore?,
        workspaceImporter: LegacyWorkspaceImporter?,
        workspaceAvailability: WorkspaceAvailability,
        selectionEngine: SelectionEngine,
        tierCProvider: any VisualEmbeddingProvider,
        semanticJuryProvider: any SemanticJuryProvider,
        exporter: any AlbumExportService,
        albumOperations: AlbumSaveOperationStore? = nil,
        albumSaveService: AlbumSaveService? = nil,
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
        self.workspaceModelContainer = workspaceModelContainer
        self.workspaceStore = workspaceStore
        self.workspaceImporter = workspaceImporter
        self.workspaceAvailability = workspaceAvailability
        self.selectionEngine = selectionEngine
        self.tierCProvider = tierCProvider
        self.semanticJuryProvider = semanticJuryProvider
        self.exporter = exporter
        self.albumOperations = albumOperations
        self.albumSaveService = albumSaveService
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
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let files = FileStore(rootDirectory: root)
        let checkpointStore = SessionCheckpointStore(files: files)
        let workspace = makeWorkspaceSetup(root: root, checkpointStore: checkpointStore)
        let imageLoader = ImageLoaderService()
        let photoLibrary = PhotoLibraryPermissionService()
        let exporter = PhotoKitAlbumExporter()
        return Self(
            photoLibrary: photoLibrary,
            imageLoader: imageLoader,
            analyzer: VisionAnalysisService(),
            analysisCache: FileAnalysisCache(
                files: files,
                analysisVersion: AppConfiguration.default.analysis.analysisVersion
            ),
            checkpointStore: checkpointStore,
            workspaceModelContainer: workspace.modelContainer,
            workspaceStore: workspace.store,
            workspaceImporter: workspace.importer,
            workspaceAvailability: workspace.availability,
            selectionEngine: SelectionEngine(),
            tierCProvider: NativeDerivedEmbeddingProvider(),
            semanticJuryProvider: FoundationModelsSemanticJuryProvider(),
            exporter: exporter,
            albumOperations: workspace.albumOperations,
            albumSaveService: workspace.albumSaveService,
            analytics: NoopAnalytics(),
            memoryPressure: MemoryPressureObserver(),
            modelInstallation: ModelInstallationService(
                rootDirectory: root.appendingPathComponent("models", isDirectory: true)
            ),
            qwenJudge: QwenPairJudge(imageLoader: imageLoader)
        )
    }

    /// feat-035 explicit SwiftData schema migration: the workspace store
    /// opens with `AlbumSaveOperation` alongside the feat-033 models. The
    /// added model is additive: pre-existing scope/item/marker rows reopen
    /// untouched. Rollback removes the model from this list; operation rows
    /// stay on disk unread while scopes/items keep working and unresolved
    /// saves fall back to the file `SaveState` handoff.
    private static func makeWorkspaceSetup(
        root: URL,
        checkpointStore: SessionCheckpointStore
    ) -> WorkspaceSetup {
        let workspaceURL = root.appendingPathComponent("workspace.store")
        do {
            let modelContainer = try ModelContainer(
                for: ReviewScope.self,
                WorkspaceItem.self,
                WorkspaceMigrationMarker.self,
                AlbumSaveOperation.self,
                configurations: ModelConfiguration(url: workspaceURL)
            )
            let store = WorkspaceStore(modelContainer: modelContainer)
            let photoLibrary = PhotoLibraryPermissionService()
            let exporter = PhotoKitAlbumExporter()
            let albumOperations = AlbumSaveOperationStore(modelContainer: modelContainer)
            let albumSaveService = AlbumSaveService(
                exporter: exporter, operations: albumOperations, photoLibrary: photoLibrary
            )
            return WorkspaceSetup(
                modelContainer: modelContainer,
                store: store,
                importer: LegacyWorkspaceImporter(checkpointStore: checkpointStore, workspaceStore: store),
                availability: .available,
                albumOperations: albumOperations,
                albumSaveService: albumSaveService
            )
        } catch {
            Logger(
                subsystem: Bundle.main.bundleIdentifier ?? "photo-curator", category: "workspace"
            ).error(
                """
                Durable workspace unavailable; preserving legacy file-backed flow and skipping migration.
                Failure category: workspace_unavailable.
                """
            )
            return WorkspaceSetup(
                modelContainer: nil,
                store: nil,
                importer: nil,
                availability: .unavailable,
                albumOperations: nil,
                albumSaveService: nil
            )
        }
    }
}
