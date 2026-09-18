import Foundation

struct QualityAlbumSelection: Sendable {
    let result: SelectionResult
    let evidence: QualityCurationEvidence
}

struct QualityAlbumSelectionRequest: Sendable {
    let sessionID: SessionID
    let sourceAssets: [PhotoAsset]
    let analyses: [AssetID: PhotoAnalysis]
    let similarityEdges: [SimilarityEdge]
    let groups: QualityGroupSet
    let comparisons: [QualityPairComparison]
    let requestedMode: QualityMode
    let executedMode: QualityMode
    let model: QualityModelProvenance?
    let comparisonCounts: QualityComparisonCounts
    let degradationReason: QualityDegradationReason?
    let configuration: SelectionConfiguration
    let qualityPolicy: QualityCurationPolicy
}

struct QualityModelProvenance: Sendable {
    let id: String
    let revision: String
    let manifestDigest: String?
    let runtimeRevision: String?
}

/// Selects from all analyzed quality candidates before any Qwen evidence is applied.
struct QualityAlbumSelector: Sendable {
    private let scorer = QualityScorer()
    private let diversity = DiversitySelector()
    private let finalBuilder = FinalAlbumBuilder()

    func select(_ request: QualityAlbumSelectionRequest) throws -> QualityAlbumSelection {
        let lookups = GroupLookups(groups: request.groups)
        let scored = scoredCandidates(request: request, lookups: lookups)
        let selected = selectedIDs(
            request: request,
            scored: scored,
            comparisons: request.comparisons
        )
        let base = try finalBuilder.build(
            sourceAssets: request.sourceAssets,
            analyses: request.analyses,
            clusters: request.groups.retakeGroups,
            moments: request.groups.coverageGroups,
            scored: scored,
            selectedIDs: selected,
            configuration: request.configuration
        )
        let evidence = makeEvidence(request: request, result: base)
        let result = SelectionResult(
            sessionID: request.sessionID,
            selectedAssetIDs: base.selectedAssetIDs,
            rejectedAssetIDs: base.rejectedAssetIDs,
            decisions: base.decisions,
            generatedAt: base.generatedAt,
            engineVersion: evidence.metadata.engineVersion,
            qualityEvidence: evidence
        )
        return QualityAlbumSelection(result: result, evidence: evidence)
    }

    private struct GroupLookups {
        let clusterByAsset: [AssetID: ClusterID]
        let momentByAsset: [AssetID: MomentID]

        init(groups: QualityGroupSet) {
            clusterByAsset = Dictionary(uniqueKeysWithValues: groups.retakeGroups.flatMap { cluster in
                cluster.assetIDs.map { ($0, cluster.id) }
            })
            momentByAsset = Dictionary(uniqueKeysWithValues: groups.coverageGroups.flatMap { moment in
                moment.assetIDs.map { ($0, moment.id) }
            })
        }
    }

    private func scoredCandidates(
        request: QualityAlbumSelectionRequest,
        lookups: GroupLookups
    ) -> [ScoredCandidate] {
        request.sourceAssets.compactMap { asset -> ScoredCandidate? in
            guard let analysis = request.analyses[asset.id], let momentID = lookups.momentByAsset[asset.id] else {
                return nil
            }
            return scorer.score(
                asset: asset,
                analysis: analysis,
                clusterID: lookups.clusterByAsset[asset.id],
                momentID: momentID,
                configuration: request.configuration
            )
        }
    }

    private func selectedIDs(
        request: QualityAlbumSelectionRequest,
        scored: [ScoredCandidate],
        comparisons: [QualityPairComparison]
    ) -> Set<AssetID> {
        let usable = scored.filter { $0.disposition == .usable }
        let target = min(
            max(
                Int((Double(usable.count) * request.configuration.targetSelectionRatio).rounded(.up)),
                usable.isEmpty ? 0 : 1
            ),
            request.configuration.maximumFinalCount
        )
        let graph = GlobalDiversityGraphBuilder.build(shortlist: usable, mergedEdges: request.similarityEdges)
        let selected = diversity.select(
            shortlist: usable,
            allMomentIDs: request.groups.coverageGroups.map(\.id),
            targetCount: target,
            graph: graph,
            configuration: request.configuration,
            feedback: nil
        )
        return applyRetakeComparisons(
            selected: selected,
            comparisons: comparisons,
            groups: request.groups.retakeGroups,
            scored: scored
        )
    }

    private func makeEvidence(
        request: QualityAlbumSelectionRequest,
        result: SelectionResult
    ) -> QualityCurationEvidence {
        let audits = request.groups.coverageGroups.map { moment in
            let selectedCount = moment.assetIDs.filter { result.selectedAssetIDs.contains($0) }.count
            return QualityGroupAudit(
                groupID: moment.id.rawValue,
                memberCount: moment.assetIDs.count,
                selectedAssetCount: selectedCount,
                outcome: selectedCount > 0 ? .selected : .unusableOnly
            )
        }
        let metadata = QualityExecutionMetadata(
            requestedMode: request.requestedMode,
            executedMode: request.executedMode,
            configVersion: request.qualityPolicy.policyVersion,
            modelID: request.model?.id,
            modelRevision: request.model?.revision,
            modelManifestDigest: request.model?.manifestDigest,
            runtimeRevision: request.model?.runtimeRevision,
            comparisonCounts: request.comparisonCounts,
            degradationReason: request.degradationReason
        )
        return QualityCurationEvidence(metadata: metadata, groupAudits: audits)
    }

    private func applyRetakeComparisons(
        selected: Set<AssetID>,
        comparisons: [QualityPairComparison],
        groups: [PhotoCluster],
        scored: [ScoredCandidate]
    ) -> Set<AssetID> {
        let clusterByAsset = Dictionary(uniqueKeysWithValues: groups.flatMap { cluster in
            cluster.assetIDs.map { ($0, cluster) }
        })
        let scoredByID = Dictionary(uniqueKeysWithValues: scored.map { ($0.asset.id, $0) })
        var output = selected
        for comparison in comparisons where comparison.judgment.relation == .retake {
            guard let cluster = clusterByAsset[comparison.first], cluster.assetIDs.contains(comparison.second) else {
                continue
            }
            let winner: AssetID
            let loser: AssetID
            switch comparison.judgment.preference {
            case .chooseA:
                winner = comparison.first
                loser = comparison.second
            case .chooseB:
                winner = comparison.second
                loser = comparison.first
            case .tie, .abstain:
                continue
            }
            guard output.contains(loser), !output.contains(winner) else { continue }
            guard scoredByID[winner]?.disposition == .usable else { continue }
            output.remove(loser)
            output.insert(winner)
        }
        return output
    }
}
