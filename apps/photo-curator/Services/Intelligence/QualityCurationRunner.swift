import Foundation

/// Coordinates the quality path without allowing model output to own selection.
/// Grouping, scoring, and final verification remain deterministic domain work.
struct QualityCurationRunner: Sendable {
    private let groupBuilder = QualityGroupBuilder()
    private let selector = QualityAlbumSelector()
    private let modelInstallation: ModelInstallationService?
    private let judge: (any QualityPairModelManaging)?
    private let policy: QualityCurationPolicy

    init(
        modelInstallation: ModelInstallationService? = nil,
        judge: (any QualityPairModelManaging)? = nil,
        policy: QualityCurationPolicy = .default
    ) {
        self.modelInstallation = modelInstallation
        self.judge = judge
        self.policy = policy
    }

    // swiftlint:disable:next function_body_length function_parameter_count
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

        var executedMode = requestedMode
        var comparisons: [QualityPairComparison] = []
        var comparisonCounts = QualityComparisonCounts()
        var degradationReason: QualityDegradationReason?
        var model: QualityModelProvenance?

        if requestedMode.requiresModel {
            if requestedMode == .qualityQwen4B {
                executedMode = .qualityNative
                degradationReason = .modelUnavailable
            } else if modelAvailableAtStart, let judge, let modelInstallation {
                if let installation = await modelInstallation.installedModel() {
                    do {
                        try Task.checkCancellation()
                        let load = try await judge.load(from: installation)
                        try Task.checkCancellation()
                        model = QualityModelProvenance(
                            id: load.modelID,
                            revision: load.revision,
                            manifestDigest: installation.manifestDigest,
                            runtimeRevision: ModelManifest.qwen35TwoBFourBit.runtimeRevision
                        )
                        let scheduler = QualityComparisonScheduler(judge: judge, policy: policy)
                        let run = await scheduler.run(
                            Self.requests(from: groups, generation: generation, policy: policy)
                        )
                        comparisons = run.comparisons
                        comparisonCounts = run.counts
                        degradationReason = run.degradationReason
                        try await judge.unload()
                        try Task.checkCancellation()
                    } catch is CancellationError {
                        try? await judge.unload()
                        throw CancellationError()
                    } catch {
                        try? await judge.unload()
                        executedMode = .qualityNative
                        degradationReason = .runtimeUnsupported
                    }
                } else {
                    executedMode = .qualityNative
                    degradationReason = .modelUnavailable
                }
            } else {
                executedMode = .qualityNative
                degradationReason = .modelUnavailable
            }
        }

        let selection = try selector.select(
            QualityAlbumSelectionRequest(
                sessionID: sessionID,
                sourceAssets: sourceAssets,
                analyses: analyses,
                similarityEdges: similarityEdges,
                groups: groups,
                comparisons: comparisons,
                requestedMode: requestedMode,
                executedMode: executedMode,
                model: model,
                comparisonCounts: comparisonCounts,
                degradationReason: degradationReason,
                configuration: configuration,
                qualityPolicy: policy
            )
        )
        return selection.result
    }

    private static func requests(
        from groups: QualityGroupSet,
        generation: Int,
        policy: QualityCurationPolicy
    ) -> [QualityPairRequest] {
        var requests: [QualityPairRequest] = []
        requests.reserveCapacity(min(policy.pairDistanceCap, policy.maxQwenRequests))

        for group in groups.retakeGroups.sorted(by: { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }) {
            let ids = group.assetIDs.sorted(by: { $0.rawValue < $1.rawValue })
            guard ids.count > 1 else { continue }
            for firstIndex in 0 ..< ids.count - 1 {
                for secondIndex in (firstIndex + 1) ..< ids.count {
                    guard requests.count < policy.pairDistanceCap else { return requests }
                    requests.append(
                        QualityPairRequest(
                            requestID: UUID(),
                            generation: generation,
                            first: ids[firstIndex],
                            second: ids[secondIndex],
                            task: "compare-v1"
                        )
                    )
                }
            }
        }
        return requests
    }
}
