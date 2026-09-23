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
    /// Grouping provenance: 0 when no retake groups fed the run, else the
    /// current retake-grouping schema.
    private static let emptyGroupingVersion = 0
    private static let retakeGroupingVersion = 1
    /// Prompt provenance: `none` when no comparison ran, else the judge
    /// prompt named in `QwenPairJudge.promptVersion`.
    private static let noPromptVersion = "none"
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
            FinalAlbumBuildInput(
                sourceAssets: request.sourceAssets,
                analyses: request.analyses,
                clusters: effectiveClusters,
                moments: request.groups.coverageGroups,
                scored: scored,
                selectedIDs: selection.ids
            )
        )
        let evidence = makeEvidence(
            request: request,
            result: base,
            scored: scored,
            selection: selection
        )
        let coverage = coverageEvidence(from: evidence.sizing)
        let result = SelectionResult(
            sessionID: request.sessionID,
            selectedAssetIDs: base.selectedAssetIDs,
            rejectedAssetIDs: base.rejectedAssetIDs,
            decisions: decisionsWithContributions(base.decisions, scored: scored),
            generatedAt: base.generatedAt,
            engineVersion: evidence.metadata.engineVersion,
            qualityEvidence: evidence,
            coverageEvidence: coverage,
            provenance: base.provenance.map {
                guard let coverage else { return $0 }
                return $0.updating(
                    with: coverage,
                    selectedAssetCount: base.selectedAssetIDs.count,
                    qualityEvidenceAvailable: true
                )
            }
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

    private func decisionsWithContributions(
        _ decisions: [Decision], scored: [ScoredCandidate]
    ) -> [Decision] {
        let byID = Dictionary(uniqueKeysWithValues: scored.map { ($0.asset.id, $0) })
        return decisions.map { decision in
            guard let candidate = byID[decision.assetID] else { return decision }
            return Decision(
                assetID: decision.assetID,
                status: decision.status,
                score: decision.score ?? candidate.score,
                qualityBreakdown: decision.qualityBreakdown,
                scoreContributions: candidate.scoreContributions,
                reasons: decision.reasons,
                competingIDs: decision.competingIDs
            )
        }
    }

    private struct SelectionPlan {
        let ids: Set<AssetID>
        let repairedMomentIDs: Set<MomentID>
        let uncoveredMomentIDs: Set<MomentID>
        let alternativeAssetIDs: Set<AssetID>
        let usableCount: Int
        let targetCount: Int
        let graph: GlobalDiversityGraph
    }

    private struct CoverageRepairInput {
        let selected: Set<AssetID>
        let groups: [PhotoMoment]
        let scored: [ScoredCandidate]
        let targetCount: Int
        let graph: GlobalDiversityGraph
        let usableCount: Int
    }
}

extension QualityAlbumSelector {
    private func coverageEvidence(
        from sizing: QualityAlbumSizingEvidence?
    ) -> SelectionCoverageEvidence? {
        sizing.map {
            SelectionCoverageEvidence(
                usableCount: $0.usableCount,
                targetCount: $0.targetCount,
                selectedCount: $0.selectedCount,
                maximumCount: $0.maximumCount,
                uncoveredMomentIDs: $0.uncoveredMomentIDs,
                alternativeAssetIDs: $0.alternativeAssetIDs,
                candidateCount: $0.candidateCount,
                candidateLimit: $0.candidateLimit,
                truncatedCandidateCount: $0.truncatedCandidateCount,
                pairCount: $0.pairCount,
                pairLimit: $0.pairLimit,
                truncatedPairCount: $0.truncatedPairCount,
                coveredMemberCount: $0.coveredMemberCount,
                unknownPairCount: $0.unknownPairCount
            )
        }
    }

    /// DiversitySelector protects coverage before checking the target. Apply
    /// the hard album bound after that phase, preserving deterministic
    /// round-robin moment coverage and one representative per cluster.
    private func boundedSelection(
        selected: Set<AssetID>, candidates: [ScoredCandidate], groups: [PhotoMoment], targetCount: Int
    ) -> Set<AssetID> {
        guard selected.count > targetCount else { return selected }
        let byID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.asset.id, $0) })
        var output = Set<AssetID>()
        var clusters = Set<ClusterID>()
        func insert(_ candidate: ScoredCandidate) {
            guard output.count < targetCount else { return }
            if let clusterID = candidate.clusterID, clusters.contains(clusterID) {
                return
            }
            output.insert(candidate.asset.id)
            if let clusterID = candidate.clusterID {
                clusters.insert(clusterID)
            }
        }

        let selectedByMoment = Dictionary(grouping: selected.compactMap { byID[$0] }) { $0.momentID }
        for moment in groups {
            guard let candidatesForMoment = selectedByMoment[moment.id] else { continue }
            for candidate in candidatesForMoment.sorted(by: QualityScorer.compareRank) {
                insert(candidate)
                if output.count == targetCount {
                    return output
                }
            }
        }
        for candidate in selected.compactMap({ byID[$0] }).sorted(by: QualityScorer.compareRank) {
            insert(candidate)
            if output.count == targetCount {
                break
            }
        }
        return output
    }

    private func selectedIDs(
        request: QualityAlbumSelectionRequest,
        scored: [ScoredCandidate],
        comparisons: [QualityPairComparison]
    ) -> SelectionPlan {
        let usable = scored.filter { $0.disposition == .usable }
        let target = QualityScorer.albumTargetCount(
            usableCount: usable.count, configuration: request.configuration
        )
        let shortlist = scorer.shortlist(
            candidates: usable, targetCount: target, configuration: request.configuration
        )
        let graph = GlobalDiversityGraphBuilder.build(shortlist: shortlist, mergedEdges: request.similarityEdges)
        let selected = diversity.select(
            shortlist: shortlist,
            allMomentIDs: request.groups.coverageGroups.map(\.id),
            targetCount: target,
            graph: graph,
            configuration: request.configuration,
            feedback: nil
        )
        let bounded = boundedSelection(
            selected: selected, candidates: shortlist,
            groups: request.groups.coverageGroups, targetCount: target
        )
        let compared = applyRetakeComparisons(
            selected: bounded,
            comparisons: comparisons,
            groups: request.groups.retakeGroups,
            scored: scored
        )
        return repairCoverage(
            CoverageRepairInput(
                selected: compared,
                groups: request.groups.coverageGroups,
                scored: scored,
                targetCount: target,
                graph: graph,
                usableCount: usable.count
            )
        )
    }

    private func makeEvidence(
        request: QualityAlbumSelectionRequest,
        result: SelectionResult,
        scored: [ScoredCandidate],
        selection: SelectionPlan
    ) -> QualityCurationEvidence {
        let scoredByID = Dictionary(uniqueKeysWithValues: scored.map { ($0.asset.id, $0) })
        let audits = request.groups.coverageGroups.map { moment in
            let selectedCount = moment.assetIDs.filter { result.selectedAssetIDs.contains($0) }.count
            let outcome: QualityGroupOutcome
            if selectedCount > 0 {
                outcome = selection.repairedMomentIDs.contains(moment.id) ? .repaired : .selected
            } else if !moment.assetIDs.contains(where: { scoredByID[$0] != nil }) {
                outcome = .unavailableOnly
            } else if !moment.assetIDs.contains(where: { scoredByID[$0]?.disposition == .usable }) {
                outcome = .unusableOnly
            } else {
                outcome = .uncovered
            }
            let alternatives = moment.assetIDs.filter {
                scoredByID[$0]?.disposition == .usable && !result.selectedAssetIDs.contains($0)
            }
            return QualityGroupAudit(
                groupID: moment.id.rawValue,
                memberCount: moment.assetIDs.count,
                selectedAssetCount: selectedCount,
                outcome: outcome,
                alternativeAssetIDs: alternatives.isEmpty ? nil : alternatives
            )
        }
        let metadata = QualityExecutionMetadata(
            requestedMode: request.requestedMode,
            executedMode: request.executedMode,
            configVersion: request.configVersion,
            groupingVersion: request.groups.retakeGroups.isEmpty
                ? Self.emptyGroupingVersion : Self.retakeGroupingVersion,
            promptVersion: Self.noPromptVersion,
            modelID: request.model?.id,
            modelRevision: request.model?.revision,
            modelManifestDigest: request.model?.manifestDigest,
            runtimeRevision: request.model?.runtimeRevision,
            comparisonCounts: request.comparisonCounts,
            degradationReason: request.degradationReason
        )
        let sizing = makeSizingEvidence(request: request, result: result, selection: selection)
        return QualityCurationEvidence(metadata: metadata, groupAudits: audits, sizing: sizing)
    }

    private func makeSizingEvidence(
        request: QualityAlbumSelectionRequest,
        result: SelectionResult,
        selection: SelectionPlan
    ) -> QualityAlbumSizingEvidence {
        let graph = selection.graph
        return QualityAlbumSizingEvidence(
            usableCount: selection.usableCount,
            targetCount: selection.targetCount,
            minimumCount: request.configuration.minimumFinalCount,
            maximumCount: request.configuration.maximumFinalCount,
            selectedCount: result.selectedAssetIDs.count,
            uncoveredMomentIDs: selection.uncoveredMomentIDs.sorted {
                $0.rawValue.uuidString < $1.rawValue.uuidString
            },
            alternativeAssetIDs: selection.alternativeAssetIDs.sorted {
                $0.rawValue < $1.rawValue
            },
            candidateCount: graph.members.count + graph.truncatedMemberCount,
            candidateLimit: GlobalDiversityGraphBuilder.maxGraphMembers,
            truncatedCandidateCount: graph.truncatedMemberCount,
            pairCount: graph.edges.count,
            pairLimit: GlobalDiversityGraphBuilder.maxGraphPairs,
            truncatedPairCount: graph.truncatedPairCount,
            coveredMemberCount: graph.coveredMemberCount,
            unknownPairCount: graph.unknownPairCount
        )
    }

    private func repairCoverage(_ input: CoverageRepairInput) -> SelectionPlan {
        var output = input.selected
        var repairedMomentIDs = Set<MomentID>()
        var selectedClusters = Set(
            input.scored.compactMap { candidate in
                output.contains(candidate.asset.id) ? candidate.clusterID : nil
            }
        )
        let scoredByID = Dictionary(uniqueKeysWithValues: input.scored.map { ($0.asset.id, $0) })

        for moment in input.groups {
            guard output.count < input.targetCount else { break }
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

        let uncoveredMomentIDs = Set(input.groups.compactMap { moment in
            output.contains(where: moment.assetIDs.contains) ? nil : moment.id
        })
        let alternatives = Set(input.scored.filter {
            $0.disposition == .usable && !output.contains($0.asset.id)
        }.map(\.asset.id))
        return SelectionPlan(
            ids: output,
            repairedMomentIDs: repairedMomentIDs,
            uncoveredMomentIDs: uncoveredMomentIDs,
            alternativeAssetIDs: alternatives,
            usableCount: input.usableCount,
            targetCount: input.targetCount,
            graph: input.graph
        )
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
}

private struct RetakePreference: Hashable {
    let winner: AssetID
    let loser: AssetID
}
