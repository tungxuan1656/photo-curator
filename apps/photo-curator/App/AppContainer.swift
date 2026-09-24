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
        let catalogStore: LibraryCatalogStore?
        let catalogStorageAvailability: CatalogStorageAvailability
        let albumOperations: AlbumSaveOperationStore?
        let albumSaveService: AlbumSaveService?
        let deletionOperations: DeletionOperationStore?
        let deletionService: PhotoDeletionService?
        let photoLibrary: any PhotoLibraryService
        let exporter: any AlbumExportService
    }

    let photoLibrary: any PhotoLibraryService
    let imageLoader: any PhotoImageLoader
    let visibleImageLoader: any PhotoImageLoader
    let analyzer: any ImageAnalysisService
    let analysisCache: any AnalysisCache
    let checkpointStore: SessionCheckpointStore
    let workspaceModelContainer: ModelContainer?
    let workspaceStore: WorkspaceStore?
    let workspaceImporter: LegacyWorkspaceImporter?
    let workspaceAvailability: WorkspaceAvailability
    /// Nil means the V6 durable container did not open. A non-nil store can
    /// independently report access/reconciliation availability through state().
    let catalogStore: LibraryCatalogStore?
    let catalogStorageAvailability: CatalogStorageAvailability
    /// The single arbiter shared by every image-work lane and visible loading.
    let imageWorkArbiter: ImageWorkArbiter
    /// Nil only when the durable catalog container could not be opened.
    let libraryAnalysisCoordinator: LibraryAnalysisCoordinator?
    /// Rebuilds transient Vision comparisons into the guarded V5 projection.
    let libraryComparisonCoordinator: LibraryComparisonCoordinator?
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
    /// Durable original-deletion operation store (feat-036 owner). Shares the
    /// workspace container but is independent from album-save state.
    let deletionOperations: DeletionOperationStore?
    /// The only original-deletion PhotoKit mutation boundary.
    let deletionService: PhotoDeletionService?
    let analytics: any AnalyticsService
    let memoryPressure: MemoryPressureObserver
    let modelInstallation: ModelInstallationService

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
        deletionOperations: DeletionOperationStore? = nil,
        deletionService: PhotoDeletionService? = nil,
        analytics: any AnalyticsService,
        memoryPressure: MemoryPressureObserver,
        modelInstallation: ModelInstallationService,
        qwenJudge: QwenPairJudge? = nil,
        catalogStore: LibraryCatalogStore? = nil,
        catalogStorageAvailability: CatalogStorageAvailability = .unavailable,
        imageWorkArbiter: ImageWorkArbiter,
        libraryAnalysisCoordinator: LibraryAnalysisCoordinator? = nil,
        libraryComparisonCoordinator: LibraryComparisonCoordinator? = nil
    ) {
        self.photoLibrary = photoLibrary
        self.imageLoader = imageLoader
        visibleImageLoader = ArbitratedPhotoImageLoader(
            loader: imageLoader, imageWorkArbiter: imageWorkArbiter
        )
        self.analyzer = analyzer
        self.analysisCache = analysisCache
        self.checkpointStore = checkpointStore
        self.workspaceModelContainer = workspaceModelContainer
        self.workspaceStore = workspaceStore
        self.workspaceImporter = workspaceImporter
        self.workspaceAvailability = workspaceAvailability
        self.catalogStore = catalogStore
        self.catalogStorageAvailability = catalogStorageAvailability
        self.imageWorkArbiter = imageWorkArbiter
        self.libraryAnalysisCoordinator = libraryAnalysisCoordinator
        self.libraryComparisonCoordinator = libraryComparisonCoordinator
        self.selectionEngine = selectionEngine
        self.tierCProvider = tierCProvider
        self.semanticJuryProvider = semanticJuryProvider
        self.exporter = exporter
        self.albumOperations = albumOperations
        self.albumSaveService = albumSaveService
        self.deletionOperations = deletionOperations
        self.deletionService = deletionService
        self.analytics = analytics
        self.memoryPressure = memoryPressure
        self.modelInstallation = modelInstallation
        // The legacy Qwen argument remains source-compatible for callers that
        // still construct a container, but is intentionally not retained or
        // wired into production execution.
        _ = qwenJudge
    }

    /// Catalog reconciliation availability is durable state, not a launch-time
    /// copy. A missing store represents the separate V3 container failure.
    func catalogState() async -> CatalogStateSnapshot {
        guard let catalogStore else {
            return CatalogStateSnapshot(
                currentGenerationID: nil,
                latestAttemptID: nil,
                availability: .unavailable,
                updatedAt: nil
            )
        }
        return (try? await catalogStore.state()) ?? CatalogStateSnapshot(
            currentGenerationID: nil,
            latestAttemptID: nil,
            availability: .unavailable,
            updatedAt: nil
        )
    }

    // swiftlint:disable function_body_length
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
        let analyzer = VisionAnalysisService()
        let imageWorkArbiter = ImageWorkArbiter()
        let libraryAnalysisCoordinator = workspace.catalogStore.map {
            LibraryAnalysisCoordinator(
                catalogStore: $0,
                evidenceStore: LibraryAnalysisEvidenceStore(files: files),
                checkpointStore: LibraryAnalysisCheckpointStore(files: files),
                imageLoader: imageLoader,
                analyzer: analyzer,
                imageWorkArbiter: imageWorkArbiter
            )
        }
        let libraryComparisonCoordinator = workspace.catalogStore.map {
            LibraryComparisonCoordinator(
                catalogStore: $0,
                imageLoader: imageLoader,
                analyzer: analyzer,
                imageWorkArbiter: imageWorkArbiter
            )
        }
        return Self(
            photoLibrary: workspace.photoLibrary,
            imageLoader: imageLoader,
            analyzer: analyzer,
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
            exporter: workspace.exporter,
            albumOperations: workspace.albumOperations,
            albumSaveService: workspace.albumSaveService,
            deletionOperations: workspace.deletionOperations,
            deletionService: workspace.deletionService,
            analytics: NoopAnalytics(),
            memoryPressure: MemoryPressureObserver(),
            modelInstallation: ModelInstallationService(
                rootDirectory: root.appendingPathComponent("models", isDirectory: true)
            ),
            qwenJudge: QwenPairJudge(
                imageLoader: imageLoader, imageWorkArbiter: imageWorkArbiter
            ),
            catalogStore: workspace.catalogStore,
            catalogStorageAvailability: workspace.catalogStorageAvailability,
            imageWorkArbiter: imageWorkArbiter,
            libraryAnalysisCoordinator: libraryAnalysisCoordinator,
            libraryComparisonCoordinator: libraryComparisonCoordinator
        )
    }

    /// Opens the V7 workspace/catalog schema exactly once. A failed migration
    /// is reported as unavailable; reopening the same store through V2 would
    /// risk hiding or misinterpreting the additive catalog migration.
    private static func makeWorkspaceSetup(
        root: URL,
        checkpointStore: SessionCheckpointStore
    ) -> WorkspaceSetup {
        let workspaceURL = root.appendingPathComponent("workspace.store")
        do {
            let modelContainer = try ModelContainer(
                for: Schema(versionedSchema: PhotoCuratorSchemaV8.self),
                migrationPlan: PhotoCuratorMigrationPlan.self,
                configurations: ModelConfiguration(url: workspaceURL)
            )
            return makeAvailableWorkspaceSetup(
                modelContainer: modelContainer,
                checkpointStore: checkpointStore,
                deletionEnabled: true
            )
        } catch {
            Logger(
                subsystem: Bundle.main.bundleIdentifier ?? "photo-curator", category: "workspace"
            ).error(
                """
                V7 workspace/catalog schema unavailable; preserving the store file.
                Failure category: schema_migration.
                """
            )
            return WorkspaceSetup(
                modelContainer: nil,
                store: nil,
                importer: nil,
                availability: .unavailable,
                catalogStore: nil,
                catalogStorageAvailability: .unavailable,
                albumOperations: nil,
                albumSaveService: nil,
                deletionOperations: nil,
                deletionService: nil,
                photoLibrary: PhotoLibraryPermissionService(),
                exporter: PhotoKitAlbumExporter()
            )
        }
    }

    private static func makeAvailableWorkspaceSetup(
        modelContainer: ModelContainer,
        checkpointStore: SessionCheckpointStore,
        deletionEnabled: Bool
    ) -> WorkspaceSetup {
        let store = WorkspaceStore(modelContainer: modelContainer)
        let photoLibrary = PhotoLibraryPermissionService()
        let exporter = PhotoKitAlbumExporter()
        let albumOperations = AlbumSaveOperationStore(modelContainer: modelContainer)
        let albumSaveService = AlbumSaveService(
            exporter: exporter, operations: albumOperations, photoLibrary: photoLibrary
        )
        let deletionOperations = deletionEnabled
            ? DeletionOperationStore(modelContainer: modelContainer)
            : nil
        let deletionService = deletionOperations.map {
            PhotoDeletionService(operations: $0, photoLibrary: photoLibrary)
        }
        return WorkspaceSetup(
            modelContainer: modelContainer,
            store: store,
            importer: LegacyWorkspaceImporter(checkpointStore: checkpointStore, workspaceStore: store),
            availability: .available,
            catalogStore: LibraryCatalogStore(modelContainer: modelContainer),
            catalogStorageAvailability: .available,
            albumOperations: albumOperations,
            albumSaveService: albumSaveService,
            deletionOperations: deletionOperations,
            deletionService: deletionService,
            photoLibrary: photoLibrary,
            exporter: exporter
        )
    }

    // swiftlint:enable function_body_length
}
