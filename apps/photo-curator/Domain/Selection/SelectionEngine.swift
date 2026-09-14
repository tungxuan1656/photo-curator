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
        let usableCount = scored.filter { $0.disposition == .usable }.count
        let scaled = Int((Double(usableCount) * configuration.targetSelectionRatio).rounded(.up))
        let target = min(max(scaled, configuration.minimumFinalCount), configuration.maximumFinalCount)
        let shortlist = qualityScorer.shortlist(candidates: scored, targetCount: target, configuration: configuration)
        let picked = diversitySelector.select(
            shortlist: shortlist, allMomentIDs: moments.map(\.id), targetCount: target,
            similarityEdges: similarityEdges, configuration: configuration, feedback: feedback
        )
        return try finalAlbumBuilder.build(
            sourceAssets: assets, analyses: analyses, clusters: resolution.clusters,
            moments: moments, scored: scored, selectedIDs: picked, configuration: configuration
        )
    }
}
