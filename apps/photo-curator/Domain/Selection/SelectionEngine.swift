import Foundation

/// Minimal engine errors. Typed per-layer errors arrive with their owning stages.
enum SelectionError: Error, Sendable {
    case invalidInput, cancelled, `internal`
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
            available: available, analyses: analyses, momentByID: momentByID, configuration: configuration
        ).applySwaps(scored: scored, clusters: resolution.clusters, feedback: feedback)
        let usableCount = overridden.filter { $0.disposition == .usable }.count
        let scaled = Int((Double(usableCount) * configuration.targetSelectionRatio).rounded(.up))
        let target = min(max(scaled, configuration.minimumFinalCount), configuration.maximumFinalCount)
        var shortlist = qualityScorer.shortlist(
            candidates: overridden,
            targetCount: target,
            configuration: configuration
        )
        shortlist = unionRestoredCandidates(scored: overridden, shortlist: shortlist, feedback: feedback)
        let picked = diversitySelector.select(
            shortlist: shortlist, allMomentIDs: moments.map(\.id), targetCount: target,
            similarityEdges: similarityEdges, configuration: configuration, feedback: feedback
        )
        return try finalAlbumBuilder.build(
            sourceAssets: assets, analyses: analyses, clusters: effectiveClusters(
                clusters: resolution.clusters, feedback: feedback
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
            for (clusterID, winnerID) in swaps.sorted(by: { $0.key.rawValue.uuidString < $1.key.rawValue.uuidString }) {
                guard let cluster = clusters.first(where: { $0.id == clusterID }),
                      cluster.assetIDs.contains(winnerID),
                      let asset = byID[winnerID],
                      let analysis = analyses[winnerID],
                      let momentID = momentByID[cluster.representativeAssetID ?? winnerID] ?? momentByID[winnerID]
                else { continue }
                overridden.removeAll { $0.asset.id == cluster.representativeAssetID || $0.asset.id == winnerID }
                let replacement = SelectionEngine().qualityScorer.score(
                    asset: asset, analysis: analysis, clusterID: clusterID,
                    momentID: momentID, configuration: configuration
                )
                guard replacement.disposition == .usable else { continue }
                overridden.append(replacement)
            }
            return overridden.sorted { QualityScorer.compareRank($0, $1) }
        }
    }

    private func unionRestoredCandidates(
        scored: [ScoredCandidate], shortlist: [ScoredCandidate], feedback: SelectionFeedback?
    ) -> [ScoredCandidate] {
        guard let restored = feedback?.restoredIDs, !restored.isEmpty else { return shortlist }
        var merged = shortlist
        var seen = Set(shortlist.map(\.asset.id))
        for candidate in scored where restored.contains(candidate.asset.id) && candidate.disposition == .usable {
            guard !seen.contains(candidate.asset.id) else { continue }
            merged.append(candidate)
            seen.insert(candidate.asset.id)
        }
        return merged
    }

    private func effectiveClusters(clusters: [PhotoCluster], feedback: SelectionFeedback?) -> [PhotoCluster] {
        guard let swaps = feedback?.swapWinner, !swaps.isEmpty else { return clusters }
        return clusters.map { cluster in
            guard let winner = swaps[cluster.id], cluster.assetIDs.contains(winner) else { return cluster }
            return PhotoCluster(
                id: cluster.id, type: cluster.type, assetIDs: cluster.assetIDs,
                representativeAssetID: winner, similarityScore: cluster.similarityScore
            )
        }
    }
}
