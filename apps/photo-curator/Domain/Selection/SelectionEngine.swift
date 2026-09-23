import Foundation

/// Minimal engine errors. Typed per-layer errors arrive with their owning stages.
enum SelectionError: Error, Sendable {
    case invalidInput, cancelled, `internal`
    /// Memory-critical pause: current safe unit finished, checkpoint persisted,
    /// resume continues without redo. Maps to the same paused UI as cancel.
    case memoryCritical
}

// swiftlint:disable type_body_length function_body_length function_parameter_count
/// Pure deterministic selection facade. Same assets + analyses + configuration + feedback give the same
/// result (tie-breaks: selection-rules §15). Pipeline: chrono order → available partition → duplicate
/// resolution → moment construction → quality rank/shortlist → diversity selection → final verify/order.
/// Feat-023: the graph scopes merged FeaturePrint + Tier-C edges to the exact shortlist the selector
/// consumes (non-overlapping member pairs, capped, canonical). Empty merged edges mark the fallback
/// graph, which runs the exact pre-feat-023 path. Clusters + moments stay FeaturePrint-only
/// (feat-021/feat-022 frozen). Final picks are chronologically ordered and each carries reason codes.
struct SelectionEngine: Sendable {
    let duplicateResolver = DuplicateResolver()
    let momentBuilder = MomentBuilder()
    let qualityScorer = QualityScorer()
    let diversitySelector = DiversitySelector()
    let finalAlbumBuilder = FinalAlbumBuilder()
    func duplicateCandidates(for assets: [PhotoAsset], configuration: SelectionConfiguration) -> [SimilarityCandidate] {
        duplicateResolver.candidates(for: assets, configuration: configuration)
    }

    /// Shortlist-scope assets for Tier-C routing (feat-023, DEC-037): the exact
    /// shortlist the diversity graph consumes, mapped back to assets.
    /// Production routes Tier-C pairs over this scope (non-overlapping with
    /// the duplicate-candidate source); router refusal or empty output falls
    /// back to noop. Pure + deterministic: same inputs give the same scope.
    /// Callers MUST pass the same FeaturePrint `similarityEdges` given to
    /// `select` (default `[]` is the fallback arm only); clusters + moments
    /// stay FeaturePrint-only (feat-021/feat-022 frozen).
    func shortlistScope(
        for assets: [PhotoAsset], analyses: [AssetID: PhotoAnalysis],
        configuration: SelectionConfiguration, feedback: SelectionFeedback? = nil,
        similarityEdges: [SimilarityEdge] = []
    ) -> [PhotoAsset] {
        let ordered = assets.sorted {
            if ($0.creationDate ?? .distantPast) != ($1.creationDate ?? .distantPast) {
                return ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
            }
            return $0.id.rawValue < $1.id.rawValue
        }
        let available = ordered.filter { analyses[$0.id] != nil }
        let resolution = duplicateResolver.resolve(
            assets: available, analyses: analyses, edges: similarityEdges, configuration: configuration
        )
        let byAvailableID = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
        let repAssets = resolution.representativeIDs.compactMap { byAvailableID[$0] }
        let moments = momentBuilder.build(
            representatives: repAssets, analyses: analyses, edges: similarityEdges, configuration: configuration
        )
        let lookups = Self.lookups(
            byAvailableID: byAvailableID, repAssets: repAssets,
            clusters: resolution.clusters, moments: moments
        )
        let scored = lookups.repAssets.compactMap { asset -> ScoredCandidate? in
            guard let analysis = analyses[asset.id], let momentID = lookups.momentByID[asset.id] else { return nil }
            return qualityScorer.score(
                asset: asset, analysis: analysis, clusterID: lookups.clusterByID[asset.id],
                momentID: momentID, configuration: configuration
            )
        }
        let target = Self.targetCount(for: scored, configuration: configuration)
        return qualityScorer.shortlist(
            candidates: scored, targetCount: target, configuration: configuration
        ).map(\.asset)
    }

    func select(
        assets: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        configuration: SelectionConfiguration,
        feedback: SelectionFeedback?,
        similarityEdges: [SimilarityEdge] = [],
        // feat-024: Tier-C edges feed diversity novelty only; default is the FeaturePrint fallback.
        tierCEdges: [SimilarityEdge] = []
    ) throws -> SelectionResult {
        let ordered = assets.sorted {
            if ($0.creationDate ?? .distantPast) != ($1.creationDate ?? .distantPast) {
                return ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
            }
            return $0.id.rawValue < $1.id.rawValue
        }
        let available = ordered.filter { analyses[$0.id] != nil }
        // Feat-021/feat-022 frozen: duplicates and moments see FeaturePrint edges only.
        let resolution = duplicateResolver.resolve(
            assets: available, analyses: analyses, edges: similarityEdges, configuration: configuration
        )
        let byAvailableID = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
        let repAssets = resolution.representativeIDs.compactMap { byAvailableID[$0] }
        let moments = momentBuilder.build(
            representatives: repAssets, analyses: analyses, edges: similarityEdges, configuration: configuration
        )
        let lookups = Self.lookups(
            byAvailableID: byAvailableID, repAssets: repAssets,
            clusters: resolution.clusters, moments: moments
        )
        // Every duplicate loser inherits its representative's moment so restored
        // losers and swap winners resolve to a real moment even though moments are built
        // from representatives only. Existing entries win.
        let memberMomentByID = Dictionary(uniqueKeysWithValues: resolution.clusters.flatMap { cluster in
            guard let rep = cluster.representativeAssetID, let momentID = lookups.momentByID[rep] else {
                return [] as [(AssetID, MomentID)]
            }
            return cluster.assetIDs.map { ($0, momentID) }
        })
        let fullMomentByID = lookups.momentByID.merging(memberMomentByID) { current, _ in current }
        let scored = lookups.repAssets.compactMap { asset -> ScoredCandidate? in
            guard let analysis = analyses[asset.id], let momentID = lookups.momentByID[asset.id] else { return nil }
            return qualityScorer.score(
                asset: asset, analysis: analysis, clusterID: lookups.clusterByID[asset.id],
                momentID: momentID, configuration: configuration
            )
        }
        let overridden = OverrideContext(
            available: available, analyses: analyses, momentByID: fullMomentByID, configuration: configuration
        ).applySwaps(scored: scored, clusters: resolution.clusters, feedback: feedback)
        let target = Self.targetCount(for: overridden, configuration: configuration)
        var shortlist = qualityScorer.shortlist(
            candidates: overridden,
            targetCount: target,
            configuration: configuration
        )
        shortlist = unionRestoredCandidates(
            scored: overridden, shortlist: shortlist, feedback: feedback, available: available,
            analyses: analyses, momentByID: fullMomentByID, clusterByID: lookups.clusterByID,
            configuration: configuration
        )
        let picked = diversitySelector.select(
            shortlist: shortlist, allMomentIDs: moments.map(\.id), targetCount: target,
            graph: Self.diversityGraph(
                shortlist: shortlist, similarityEdges: similarityEdges, tierCEdges: tierCEdges
            ),
            configuration: configuration, feedback: feedback
        )
        let boundedPicked = Self.boundedSelection(
            selected: picked, candidates: shortlist, moments: moments,
            targetCount: target, forcedIDs: feedback?.restoredIDs ?? []
        )
        let graph = Self.diversityGraph(
            shortlist: shortlist, similarityEdges: similarityEdges, tierCEdges: tierCEdges
        )
        let base = try finalAlbumBuilder.build(
            FinalAlbumBuildInput(
                sourceAssets: assets,
                analyses: analyses,
                clusters: effectiveClusters(
                    clusters: resolution.clusters, scored: overridden, feedback: feedback
                ),
                moments: moments,
                scored: overridden,
                selectedIDs: boundedPicked
            )
        )
        let uncovered = Set(moments.compactMap { moment in
            boundedPicked.contains(where: moment.assetIDs.contains) ? nil : moment.id
        })
        let alternatives = Set(overridden.filter {
            $0.disposition == .usable && !boundedPicked.contains($0.asset.id)
        }.map(\.asset.id))
        return Self.withSelectionEvidence(
            base,
            scored: overridden,
            coverage: SelectionCoverageEvidence(
                usableCount: overridden.filter { $0.disposition == .usable }.count,
                targetCount: target,
                selectedCount: base.selectedAssetIDs.count,
                maximumCount: configuration.maximumFinalCount,
                uncoveredMomentIDs: uncovered.sorted {
                    $0.rawValue.uuidString < $1.rawValue.uuidString
                },
                alternativeAssetIDs: alternatives.sorted { $0.rawValue < $1.rawValue },
                candidateCount: shortlist.count + graph.truncatedMemberCount,
                candidateLimit: GlobalDiversityGraphBuilder.maxGraphMembers,
                truncatedCandidateCount: graph.truncatedMemberCount,
                pairCount: graph.edges.count,
                pairLimit: GlobalDiversityGraphBuilder.maxGraphPairs,
                truncatedPairCount: graph.truncatedPairCount,
                coveredMemberCount: graph.coveredMemberCount,
                unknownPairCount: graph.unknownPairCount
            )
        )
    }

    /// Applies validated jury swaps to the existing deterministic result.
    /// Unlike a fresh selection pass, this changes only one compared cluster;
    /// every unrelated selected ID and decision remains untouched.
    func applyJuryOverrides(
        to result: SelectionResult,
        assets: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        configuration: SelectionConfiguration,
        similarityEdges: [SimilarityEdge],
        overrides: [SemanticJuryOverride]
    ) throws -> SelectionResult {
        guard !overrides.isEmpty else { return result }
        let available = assets.filter { analyses[$0.id] != nil }
        let resolution = duplicateResolver.resolve(
            assets: available, analyses: analyses, edges: similarityEdges, configuration: configuration
        )
        let selectedBefore = Set(result.selectedAssetIDs)
        guard selectedBefore.count == result.selectedAssetIDs.count else { throw SelectionError.internal }
        var selected = selectedBefore
        var decisionsByID = Dictionary(uniqueKeysWithValues: result.decisions.map { ($0.assetID, $0) })
        var touchedClusters = Set<ClusterID>()
        var changed = false
        for override in overrides where override.choice == .chooseA || override.choice == .chooseB {
            guard override.first != override.second,
                  let cluster = resolution.clusters.first(where: {
                      $0.assetIDs.contains(override.first) && $0.assetIDs.contains(override.second)
                  }),
                  !touchedClusters.contains(cluster.id)
            else { continue }
            let winner = override.choice == .chooseA ? override.first : override.second
            let loser = winner == override.first ? override.second : override.first
            guard selected.contains(loser), !selected.contains(winner),
                  let winnerAsset = available.first(where: { $0.id == winner }),
                  let winnerAnalysis = analyses[winner]
            else { continue }
            let replacement = qualityScorer.score(
                asset: winnerAsset,
                analysis: winnerAnalysis,
                clusterID: cluster.id,
                momentID: MomentID(rawValue: UUID()),
                configuration: configuration
            )
            guard replacement.disposition == .usable else { continue }
            selected.remove(loser)
            selected.insert(winner)
            touchedClusters.insert(cluster.id)
            changed = true
            let winnerScore = replacement.score
            var reasons = decisionsByID[winner]?.reasons.filter { $0 != "nearDuplicate" } ?? []
            if !reasons.contains("nearDuplicateRepresentative") {
                reasons.append("nearDuplicateRepresentative")
            }
            if winnerAnalysis.people.faceCount >= 2 {
                if !reasons.contains("bestGroupPhoto") {
                    reasons.append("bestGroupPhoto")
                }
                if winnerAnalysis.people.minFaceQuality != nil, !reasons.contains("betterFaceQuality") {
                    reasons.append("betterFaceQuality")
                }
            } else if winnerAnalysis.people.faceCount == 1, !reasons.contains("bestPortrait") {
                reasons.append("bestPortrait")
            }
            decisionsByID[winner] = Decision(
                assetID: winner,
                status: .selected,
                score: winnerScore,
                qualityBreakdown: winnerAnalysis.qualityBreakdown,
                scoreContributions: replacement.scoreContributions,
                reasons: reasons,
                competingIDs: []
            )
            decisionsByID[loser] = Decision(
                assetID: loser,
                status: .rejected,
                score: nil,
                qualityBreakdown: nil,
                scoreContributions: nil,
                reasons: ["nearDuplicate"],
                competingIDs: [winner]
            )
        }
        guard changed else { return result }
        let sourceOrder = Dictionary(uniqueKeysWithValues: assets.enumerated().map { ($1.id, $0) })
        let orderedSelected = selected.sorted {
            (sourceOrder[$0] ?? Int.max) < (sourceOrder[$1] ?? Int.max)
        }
        let orderedRejected = assets.map(\.id).filter { !selected.contains($0) }
        let orderedDecisions = assets.compactMap { decisionsByID[$0.id] }
        guard orderedDecisions.count == assets.count else { throw SelectionError.internal }
        return SelectionResult(
            sessionID: result.sessionID,
            selectedAssetIDs: orderedSelected,
            rejectedAssetIDs: orderedRejected,
            decisions: orderedDecisions,
            generatedAt: result.generatedAt,
            engineVersion: result.engineVersion,
            qualityEvidence: result.qualityEvidence,
            coverageEvidence: result.coverageEvidence,
            provenance: result.provenance
        )
    }

    /// Graph assembly (feat-023): merge FeaturePrint + Tier-C once, then scope
    /// to the exact shortlist the selector consumes (non-overlapping member
    /// pairs, capped, canonical). Empty merged edges mark the fallback graph,
    /// which selects exactly as engineVersion 2 on the same shortlist.
    /// Clusters + moments always see FeaturePrint edges only (feat-021/022).
    private static func diversityGraph(
        shortlist: [ScoredCandidate], similarityEdges: [SimilarityEdge], tierCEdges: [SimilarityEdge]
    ) -> GlobalDiversityGraph {
        GlobalDiversityGraphBuilder.build(
            shortlist: shortlist,
            mergedEdges: VisualEmbeddingEdges.merged(
                featurePrintEdges: similarityEdges, tierCEdges: tierCEdges
            )
        )
    }

    private struct SelectionLookups {
        let byAvailableID: [AssetID: PhotoAsset]
        let repAssets: [PhotoAsset]
        let clusterByID: [AssetID: ClusterID]
        let momentByID: [AssetID: MomentID]
    }

    private static func lookups(
        byAvailableID: [AssetID: PhotoAsset], repAssets: [PhotoAsset],
        clusters: [PhotoCluster], moments: [PhotoMoment]
    ) -> SelectionLookups {
        let clusterByID = Dictionary(uniqueKeysWithValues: clusters.flatMap { cluster in
            cluster.assetIDs.map { ($0, cluster.id) }
        })
        let momentByID = Dictionary(uniqueKeysWithValues: moments.flatMap { moment in
            moment.assetIDs.map { ($0, moment.id) }
        })
        return SelectionLookups(
            byAvailableID: byAvailableID, repAssets: repAssets,
            clusterByID: clusterByID, momentByID: momentByID
        )
    }

    private static func targetCount(for scored: [ScoredCandidate], configuration: SelectionConfiguration) -> Int {
        let usable = scored.filter { $0.disposition == .usable }.count
        return QualityScorer.albumTargetCount(usableCount: usable, configuration: configuration)
    }

    private static func boundedSelection(
        selected: Set<AssetID>, candidates: [ScoredCandidate], moments: [PhotoMoment],
        targetCount: Int, forcedIDs: Set<AssetID>
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
        for id in forcedIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let candidate = byID[id], selected.contains(id) else { continue }
            insert(candidate)
        }
        let selectedByMoment = Dictionary(grouping: selected.compactMap { byID[$0] }) { $0.momentID }
        for moment in moments {
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

    private static func withSelectionEvidence(
        _ result: SelectionResult, scored: [ScoredCandidate], coverage: SelectionCoverageEvidence
    ) -> SelectionResult {
        let byID = Dictionary(uniqueKeysWithValues: scored.map { ($0.asset.id, $0) })
        let decisions = result.decisions.map { decision in
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
        return SelectionResult(
            sessionID: result.sessionID,
            selectedAssetIDs: result.selectedAssetIDs,
            rejectedAssetIDs: result.rejectedAssetIDs,
            decisions: decisions,
            generatedAt: result.generatedAt,
            engineVersion: result.engineVersion,
            qualityEvidence: result.qualityEvidence,
            coverageEvidence: coverage,
            provenance: result.provenance?.updating(
                with: coverage, selectedAssetCount: result.selectedAssetIDs.count
            )
        )
    }

    /// Feedback override inputs bundled so helpers stay within the parameter limit.
    private struct OverrideContext {
        let available: [PhotoAsset]
        let analyses: [AssetID: PhotoAnalysis]
        let momentByID: [AssetID: MomentID]
        let configuration: SelectionConfiguration
        func applySwaps(
            scored: [ScoredCandidate], clusters: [PhotoCluster], feedback: SelectionFeedback?
        ) -> [ScoredCandidate] {
            guard let swaps = feedback?.swapWinner, !swaps.isEmpty else { return scored }
            let byID = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
            var overridden = scored
            // Auto representatives replaced by a usable swap winner leave the
            // pool so a swapped cluster contributes exactly one candidate.
            var replacedAutoIDs = Set<AssetID>()
            // The automatic representative leaves the pool only when a usable
            // swap winner exists for its cluster; otherwise the cluster keeps
            // its representative and the unusable swap is ignored downstream
            // (effectiveClusters only rewrites usable swaps — see below).
            for (clusterID, winnerID) in swaps.sorted(by: { $0.key.rawValue.uuidString < $1.key.rawValue.uuidString }) {
                guard let cluster = clusters.first(where: { $0.id == clusterID }),
                      cluster.assetIDs.contains(winnerID),
                      let asset = byID[winnerID],
                      let analysis = analyses[winnerID],
                      let momentID = momentByID[cluster.representativeAssetID ?? winnerID] ?? momentByID[winnerID]
                else { continue }
                // A swap to the current representative is a no-op: keep the
                // existing candidate instead of appending a duplicate.
                if winnerID == cluster.representativeAssetID {
                    if overridden.contains(where: { $0.asset.id == winnerID }) {
                        continue
                    }
                }
                // Score first: only replace the automatic representative when the
                // swapped winner is actually usable. Otherwise the cluster keeps
                // its automatic representative and the swap is ignored (the user
                // cannot force an unusable frame into the album).
                let replacement = SelectionEngine().qualityScorer.score(
                    asset: asset, analysis: analysis, clusterID: clusterID,
                    momentID: momentID, configuration: configuration
                )
                guard replacement.disposition == .usable else { continue }
                overridden.append(replacement)
                if let autoRep = cluster.representativeAssetID, autoRep != winnerID {
                    replacedAutoIDs.insert(autoRep)
                }
            }
            if !replacedAutoIDs.isEmpty {
                overridden.removeAll { replacedAutoIDs.contains($0.asset.id) }
            }
            return overridden.sorted { QualityScorer.compareRank($0, $1) }
        }
    }

    private func unionRestoredCandidates(
        scored: [ScoredCandidate], shortlist: [ScoredCandidate], feedback: SelectionFeedback?,
        available: [PhotoAsset], analyses: [AssetID: PhotoAnalysis],
        momentByID: [AssetID: MomentID], clusterByID: [AssetID: ClusterID],
        configuration: SelectionConfiguration
    ) -> [ScoredCandidate] {
        guard let restored = feedback?.restoredIDs, !restored.isEmpty else { return shortlist }
        let byAvailableID = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
        let scoreByID = Dictionary(uniqueKeysWithValues: scored.map { ($0.asset.id, $0) })
        var merged = shortlist
        var seen = Set(shortlist.map(\.asset.id))
        for id in restored.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard !seen.contains(id) else { continue }
            if let candidate = scoreByID[id], candidate.disposition == .usable {
                merged.append(candidate)
                seen.insert(id)
                continue
            }
            // A restored duplicate loser was never scored: construct its
            // candidate from the available analysis so §14 explicit-include
            // survives unless the asset is unavailable or unusable.
            guard let asset = byAvailableID[id], let analysis = analyses[id],
                  let momentID = momentByID[id] else { continue }
            let candidate = qualityScorer.score(
                asset: asset, analysis: analysis, clusterID: clusterByID[id],
                momentID: momentID, configuration: configuration
            )
            guard candidate.disposition == .usable else { continue }
            merged.append(candidate)
            seen.insert(id)
        }
        return merged
    }
}

// swiftlint:enable type_body_length function_body_length function_parameter_count
