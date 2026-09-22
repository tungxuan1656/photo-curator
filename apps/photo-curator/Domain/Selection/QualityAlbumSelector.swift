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
    let configVersion: Int
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
        let selection = selectedIDs(
            request: request,
            scored: scored,
            comparisons: request.comparisons
        )
        let effectiveClusters = clusters(
            request.groups.retakeGroups,
            selectedIDs: selection.ids
        )
        // Model provenance only ever exists for an executed model run (the
        // runner nils it on every native fallback), so pass it through and
        // let unknown stay unknown downstream.
        let base = try finalBuilder.build(
            sourceAssets: request.sourceAssets,
            analyses: request.analyses,
            clusters: effectiveClusters,
            moments: request.groups.coverageGroups,
            scored: scored,
            selectedIDs: selection.ids,
            configuration: request.configuration
        )
        let evidence = makeEvidence(
            request: request,
            result: base,
            scored: scored,
            repairedMomentIDs: selection.repairedMomentIDs
        )
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

    private struct SelectionPlan {
        let ids: Set<AssetID>
        let repairedMomentIDs: Set<MomentID>
    }

    private func selectedIDs(
        request: QualityAlbumSelectionRequest,
        scored: [ScoredCandidate],
        comparisons: [QualityPairComparison]
    ) -> SelectionPlan {
        let usable = scored.filter { $0.disposition == .usable }
        let usableMomentCount = Set(usable.map(\.momentID)).count
        let target = min(usableMomentCount, request.configuration.maximumFinalCount)
        let graph = GlobalDiversityGraphBuilder.build(shortlist: usable, mergedEdges: request.similarityEdges)
        let selected = diversity.select(
            shortlist: usable,
            allMomentIDs: request.groups.coverageGroups.map(\.id),
            targetCount: target,
            graph: graph,
            configuration: request.configuration,
            feedback: nil
        )
        let compared = applyRetakeComparisons(
            selected: selected,
            comparisons: comparisons,
            groups: request.groups.retakeGroups,
            scored: scored
        )
        return repairCoverage(
            selected: compared,
            groups: request.groups.coverageGroups,
            scored: scored
        )
    }

    private func makeEvidence(
        request: QualityAlbumSelectionRequest,
        result: SelectionResult,
        scored: [ScoredCandidate],
        repairedMomentIDs: Set<MomentID>
    ) -> QualityCurationEvidence {
        let scoredByID = Dictionary(uniqueKeysWithValues: scored.map { ($0.asset.id, $0) })
        let audits = request.groups.coverageGroups.map { moment in
            let selectedCount = moment.assetIDs.filter { result.selectedAssetIDs.contains($0) }.count
            let outcome: QualityGroupOutcome
            if selectedCount > 0 {
                outcome = repairedMomentIDs.contains(moment.id) ? .repaired : .selected
            } else if !moment.assetIDs.contains(where: { scoredByID[$0] != nil }) {
                outcome = .unavailableOnly
            } else if !moment.assetIDs.contains(where: { scoredByID[$0]?.disposition == .usable }) {
                outcome = .unusableOnly
            } else {
                outcome = .coveredBySelectedRepresentative
            }
            return QualityGroupAudit(
                groupID: moment.id.rawValue,
                memberCount: moment.assetIDs.count,
                selectedAssetCount: selectedCount,
                outcome: outcome
            )
        }
        let metadata = QualityExecutionMetadata(
            requestedMode: request.requestedMode,
            executedMode: request.executedMode,
            configVersion: request.configVersion,
            groupingVersion: request.groups.retakeGroups.isEmpty ? 0 : 1,
            promptVersion: request.comparisons.isEmpty ? "none" : "compare-v1",
            modelID: request.model?.id,
            modelRevision: request.model?.revision,
            modelManifestDigest: request.model?.manifestDigest,
            runtimeRevision: request.model?.runtimeRevision,
            comparisonCounts: request.comparisonCounts,
            degradationReason: request.degradationReason
        )
        return QualityCurationEvidence(metadata: metadata, groupAudits: audits)
    }

    private func repairCoverage(
        selected: Set<AssetID>,
        groups: [PhotoMoment],
        scored: [ScoredCandidate]
    ) -> SelectionPlan {
        var output = selected
        var repairedMomentIDs = Set<MomentID>()
        var selectedClusters = Set(
            scored.compactMap { candidate in
                output.contains(candidate.asset.id) ? candidate.clusterID : nil
            }
        )
        let scoredByID = Dictionary(uniqueKeysWithValues: scored.map { ($0.asset.id, $0) })

        for moment in groups {
            guard !moment.assetIDs.contains(where: output.contains) else { continue }
            let usable = moment.assetIDs
                .compactMap { scoredByID[$0] }
                .filter { $0.disposition == .usable }
                .sorted(by: QualityScorer.compareRank)
            guard let candidate = usable.first else { continue }
            if let clusterID = candidate.clusterID, selectedClusters.contains(clusterID) {
                continue
            }
            output.insert(candidate.asset.id)
            if let clusterID = candidate.clusterID {
                selectedClusters.insert(clusterID)
            }
            repairedMomentIDs.insert(moment.id)
        }

        return SelectionPlan(ids: output, repairedMomentIDs: repairedMomentIDs)
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
        for cluster in groups {
            guard let current = cluster.assetIDs.first(where: output.contains) else { continue }
            guard let winner = preferredRetakeWinner(
                in: cluster,
                comparisons: comparisons,
                scoredByID: scoredByID,
                clusterByAsset: clusterByAsset
            ) else { continue }
            guard winner != current else { continue }
            output.remove(current)
            output.insert(winner)
        }
        return output
    }

    private func preferredRetakeWinner(
        in cluster: PhotoCluster,
        comparisons: [QualityPairComparison],
        scoredByID: [AssetID: ScoredCandidate],
        clusterByAsset: [AssetID: PhotoCluster]
    ) -> AssetID? {
        let members = Set(cluster.assetIDs)
        var preferences = Set<RetakePreference>()
        for comparison in comparisons where comparison.judgment.relation == .retake {
            guard members.contains(comparison.first),
                  members.contains(comparison.second),
                  clusterByAsset[comparison.first]?.id == cluster.id,
                  clusterByAsset[comparison.second]?.id == cluster.id,
                  scoredByID[comparison.first]?.disposition == .usable,
                  scoredByID[comparison.second]?.disposition == .usable
            else { continue }
            switch comparison.judgment.preference {
            case .chooseA:
                preferences.insert(RetakePreference(winner: comparison.first, loser: comparison.second))
            case .chooseB:
                preferences.insert(RetakePreference(winner: comparison.second, loser: comparison.first))
            case .tie, .abstain:
                continue
            }
        }
        guard !preferences.isEmpty else { return nil }

        let usable = cluster.assetIDs.compactMap { scoredByID[$0] }
            .filter { $0.disposition == .usable }
        guard !usable.isEmpty else { return nil }
        let candidates: [ScoredCandidate]
        if hasPreferenceCycle(preferences, members: Set(usable.map(\.asset.id))) {
            candidates = usable
        } else {
            let incoming = incomingCounts(preferences)
            let roots = usable.filter { incoming[$0.asset.id, default: 0] == 0 }
            candidates = roots.isEmpty ? usable : roots
        }
        return candidates.min(by: QualityScorer.compareRank)?.asset.id
    }

    private func incomingCounts(_ preferences: Set<RetakePreference>) -> [AssetID: Int] {
        var counts: [AssetID: Int] = [:]
        for preference in preferences {
            counts[preference.loser, default: 0] += 1
            counts[preference.winner, default: 0] += 0
        }
        return counts
    }

    private func hasPreferenceCycle(
        _ preferences: Set<RetakePreference>,
        members: Set<AssetID>
    ) -> Bool {
        var outgoing: [AssetID: Set<AssetID>] = [:]
        var incoming = Dictionary(uniqueKeysWithValues: members.map { ($0, 0) })
        for preference in preferences where members.contains(preference.winner) && members.contains(preference.loser) {
            guard outgoing[preference.winner, default: []].insert(preference.loser).inserted else { continue }
            incoming[preference.loser, default: 0] += 1
        }
        var ready = incoming.filter { $0.value == 0 }.map(\.key)
        var visited = 0
        while let next = ready.popLast() {
            visited += 1
            for child in outgoing[next, default: []] {
                incoming[child, default: 0] -= 1
                if incoming[child] == 0 {
                    ready.append(child)
                }
            }
        }
        return visited != members.count
    }

    private func clusters(_ groups: [PhotoCluster], selectedIDs: Set<AssetID>) -> [PhotoCluster] {
        groups.map { group in
            guard let representative = group.assetIDs.first(where: selectedIDs.contains) else { return group }
            return PhotoCluster(
                id: group.id,
                type: group.type,
                assetIDs: group.assetIDs,
                representativeAssetID: representative,
                similarityScore: group.similarityScore
            )
        }
    }
}

private struct RetakePreference: Hashable {
    let winner: AssetID
    let loser: AssetID
}
