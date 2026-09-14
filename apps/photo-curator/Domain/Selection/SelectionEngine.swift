import Foundation

/// Minimal engine errors. Typed per-layer errors arrive with their owning stages.
enum SelectionError: Error, Sendable {
    case invalidInput, cancelled, `internal`
    /// Memory-critical pause: current safe unit finished, checkpoint persisted,
    /// resume continues without redo. Maps to the same paused UI as cancel.
    case memoryCritical
}

/// Pure deterministic selection facade. Same assets + analyses + configuration + feedback give the same
/// result (tie-breaks: selection-rules §15). Pipeline: chrono order → available partition → duplicate
/// resolution → moment construction → quality rank/shortlist → diversity selection → final verify/order.
/// Final picks are chronologically ordered and each carries reason codes.
struct SelectionEngine: Sendable {
    let duplicateResolver = DuplicateResolver()
    let momentBuilder = MomentBuilder()
    let qualityScorer = QualityScorer()
    let diversitySelector = DiversitySelector()
    let finalAlbumBuilder = FinalAlbumBuilder()

    func duplicateCandidates(for assets: [PhotoAsset], configuration: SelectionConfiguration) -> [SimilarityCandidate] {
        duplicateResolver.candidates(for: assets, configuration: configuration)
    }

    func select(
        assets: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        configuration: SelectionConfiguration,
        feedback: SelectionFeedback?,
        similarityEdges: [SimilarityEdge] = []
    ) throws -> SelectionResult {
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
        let clusterByID = Dictionary(uniqueKeysWithValues: resolution.clusters.flatMap { cluster in
            cluster.assetIDs.map { ($0, cluster.id) }
        })
        let momentByID = Dictionary(uniqueKeysWithValues: moments.flatMap { moment in
            moment.assetIDs.map { ($0, moment.id) }
        })
        // Every duplicate loser inherits its representative's moment so restored
        // losers and swap winners resolve to a real moment even though moments
        // are built from representatives only. Existing entries win.
        let memberMomentByID = Dictionary(uniqueKeysWithValues: resolution.clusters.flatMap { cluster in
            guard let rep = cluster.representativeAssetID, let momentID = momentByID[rep] else {
                return [] as [(AssetID, MomentID)]
            }
            return cluster.assetIDs.map { ($0, momentID) }
        })
        let fullMomentByID = momentByID.merging(memberMomentByID) { current, _ in current }
        let scored = repAssets.compactMap { asset -> ScoredCandidate? in
            guard let analysis = analyses[asset.id], let momentID = momentByID[asset.id] else { return nil }
            return qualityScorer.score(
                asset: asset, analysis: analysis, clusterID: clusterByID[asset.id],
                momentID: momentID, configuration: configuration
            )
        }
        // Explicit user overrides (§14) apply before automatic ranking: swapped
        // cluster representatives replace the automatic winner in every
        // downstream stage, and user-restored IDs join the candidate pool even
        // when the shortlist cap would omit them. Both paths stay deterministic
        // (sorted IDs, same tie order) and usable-only.
        let overridden = OverrideContext(
            available: available, analyses: analyses, momentByID: fullMomentByID, configuration: configuration
        ).applySwaps(scored: scored, clusters: resolution.clusters, feedback: feedback)
        let usableCount = overridden.filter { $0.disposition == .usable }.count
        let scaled = Int((Double(usableCount) * configuration.targetSelectionRatio).rounded(.up))
        let target = min(max(scaled, configuration.minimumFinalCount), configuration.maximumFinalCount)
        var shortlist = qualityScorer.shortlist(
            candidates: overridden,
            targetCount: target,
            configuration: configuration
        )
        shortlist = unionRestoredCandidates(
            scored: overridden, shortlist: shortlist, feedback: feedback, available: available,
            analyses: analyses, momentByID: fullMomentByID, clusterByID: clusterByID, configuration: configuration
        )
        let picked = diversitySelector.select(
            shortlist: shortlist, allMomentIDs: moments.map(\.id), targetCount: target,
            similarityEdges: similarityEdges, configuration: configuration, feedback: feedback
        )
        return try finalAlbumBuilder.build(
            sourceAssets: assets, analyses: analyses, clusters: effectiveClusters(
                clusters: resolution.clusters, scored: overridden, feedback: feedback
            ),
            moments: moments, scored: overridden, selectedIDs: picked, configuration: configuration
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

    // swiftlint:disable:next function_parameter_count
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

    private func effectiveClusters(
        clusters: [PhotoCluster], scored: [ScoredCandidate], feedback: SelectionFeedback?
    ) -> [PhotoCluster] {
        guard let swaps = feedback?.swapWinner, !swaps.isEmpty else { return clusters }
        let usableIDs = Set(scored.filter { $0.disposition == .usable }.map(\.asset.id))
        return clusters.map { cluster in
            guard let winner = swaps[cluster.id], cluster.assetIDs.contains(winner),
                  usableIDs.contains(winner) else { return cluster }
            return PhotoCluster(
                id: cluster.id, type: cluster.type, assetIDs: cluster.assetIDs,
                representativeAssetID: winner, similarityScore: cluster.similarityScore
            )
        }
    }
}
