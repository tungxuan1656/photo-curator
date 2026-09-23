import Foundation

/// Coordinates the native quality path. Grouping, scoring, and final
/// verification remain deterministic domain work; legacy model arguments are
/// accepted only so older callers continue to compile and are never executed.
struct QualityCurationRunner: Sendable {
    private let groupBuilder = QualityGroupBuilder()
    private let selector = QualityAlbumSelector()
    private let policy: QualityCurationPolicy

    init(
        modelInstallation: ModelInstallationService? = nil,
        judge: (any QualityPairModelManaging)? = nil,
        memoryPressure: MemoryPressureObserver? = nil,
        policy: QualityCurationPolicy = .default
    ) {
        self.policy = policy
        // These parameters are retained for source compatibility with the
        // pre-native-only construction seam. Production no longer admits a
        // model installation or judge.
        _ = modelInstallation
        _ = judge
        _ = memoryPressure
    }

    // swiftlint:disable:next function_parameter_count
    func run(
        sessionID: SessionID,
        sourceAssets: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        similarityEdges: [SimilarityEdge],
        configuration: SelectionConfiguration,
        requestedMode: QualityMode,
        modelAvailableAtStart: Bool,
        generation: Int
    ) async throws -> SelectionResult {
        let groups = groupBuilder.build(
            assets: sourceAssets,
            analyses: analyses,
            similarityEdges: similarityEdges,
            configuration: configuration
        )

        // Requested Qwen modes are historical persisted input, not an
        // instruction to execute a model. Normalize all quality requests to
        // the native route without recording a fallback or AI failure.
        let nativeMode = QualityMode.qualityNative
        let comparisons: [QualityPairComparison] = []
        let comparisonCounts = QualityComparisonCounts()
        let model: QualityModelProvenance? = nil
        let degradationReason: QualityDegradationReason? = nil
        _ = modelAvailableAtStart
        _ = generation

        let selection = try selector.select(
            QualityAlbumSelectionRequest(
                sessionID: sessionID,
                sourceAssets: sourceAssets,
                analyses: analyses,
                similarityEdges: similarityEdges,
                groups: groups,
                comparisons: comparisons,
                requestedMode: nativeMode,
                executedMode: nativeMode,
                model: model,
                comparisonCounts: comparisonCounts,
                degradationReason: degradationReason,
                configuration: configuration,
                qualityPolicy: policy,
                configVersion: AppConfiguration.default.configVersion
            )
        )
        return selection.result
    }
}
