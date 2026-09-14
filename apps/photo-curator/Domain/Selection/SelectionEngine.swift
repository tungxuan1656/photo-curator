import Foundation

/// Minimal engine errors. Typed per-layer errors arrive with their owning stages.
enum SelectionError: Error, Sendable {
    case invalidInput, cancelled, `internal`
}

/// Pure deterministic selection facade. Same assets + analyses + configuration + feedback give the same
/// result (tie-breaks: selection-rules §15). feat-007 runs duplicate clustering and moment segmentation,
/// returning analyzed representatives in chronological order; ranking, sizing, diversity, and verification
/// arrive in feat-008. Final picks are chronologically ordered and each carries reason codes.
struct SelectionEngine: Sendable {
    let duplicateResolver = DuplicateResolver()
    let momentBuilder = MomentBuilder()

    func duplicateCandidates(for assets: [PhotoAsset], configuration: SelectionConfiguration) -> [SimilarityCandidate] {
        duplicateResolver.candidates(for: assets, configuration: configuration)
    }

    func select(
        assets: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        configuration: SelectionConfiguration,
        feedback _: SelectionFeedback?,
        similarityEdges: [SimilarityEdge] = []
    ) throws -> SelectionResult {
        let resolution = duplicateResolver.resolve(
            assets: assets,
            analyses: analyses,
            edges: similarityEdges,
            configuration: configuration
        )
        let winners = Set(resolution.representativeIDs)
        let repAssets = resolution.representativeIDs.compactMap { id in assets.first(where: { $0.id == id }) }
        _ = momentBuilder.build(
            representatives: repAssets,
            analyses: analyses,
            edges: similarityEdges,
            configuration: configuration
        )
        let ordered = repAssets.sorted {
            if ($0.creationDate ?? .distantPast) != ($1.creationDate ?? .distantPast) {
                return ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
            }
            return $0.id.rawValue < $1.id.rawValue
        }
        var decisions: [Decision] = []
        for asset in assets {
            guard let analysis = analyses[asset.id] else {
                decisions.append(Decision(
                    assetID: asset.id, status: .rejected, score: nil,
                    qualityBreakdown: nil, reasons: ["assetUnavailable"], competingIDs: []
                ))
                continue
            }
            if winners.contains(asset.id) {
                decisions.append(Decision(
                    assetID: asset.id, status: .selected, score: analysis.qualityScore,
                    qualityBreakdown: analysis.qualityBreakdown, reasons: ["nearDuplicateRepresentative"],
                    competingIDs: []
                ))
            } else {
                decisions.append(Decision(
                    assetID: asset.id, status: .rejected, score: nil,
                    qualityBreakdown: nil, reasons: ["nearDuplicate"], competingIDs: []
                ))
            }
        }
        return SelectionResult(
            sessionID: SessionID(rawValue: UUID()),
            selectedAssetIDs: ordered.map(\.id),
            rejectedAssetIDs: assets.map(\.id).filter { !winners.contains($0) },
            decisions: decisions,
            generatedAt: Date(),
            engineVersion: 1
        )
    }
}
