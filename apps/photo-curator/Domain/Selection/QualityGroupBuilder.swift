import Foundation

/// Run-local grouping evidence for the quality path. It preserves every asset
/// that has analysis; representative selection happens in a later stage.
struct QualityGroupSet: Sendable {
    let candidateIDs: [AssetID]
    let retakeGroups: [PhotoCluster]
    let coverageGroups: [PhotoMoment]
}

/// Builds the first quality-path grouping arm from existing native evidence.
/// The FeaturePrint/time fallback is explicit until a separately admitted pixel
/// encoder supplies an additional distance table.
struct QualityGroupBuilder: Sendable {
    private let duplicateResolver = DuplicateResolver()
    private let momentBuilder = MomentBuilder()

    func build(
        assets: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        similarityEdges: [SimilarityEdge],
        configuration: SelectionConfiguration
    ) -> QualityGroupSet {
        let analyzed = assets
            .filter { analyses[$0.id] != nil }
            .sorted(by: Self.stableOrder)
        let resolution = duplicateResolver.resolve(
            assets: analyzed,
            analyses: analyses,
            edges: similarityEdges,
            configuration: configuration
        )
        let coverageGroups = momentBuilder.build(
            representatives: analyzed,
            analyses: analyses,
            edges: similarityEdges,
            configuration: configuration
        )
        return QualityGroupSet(
            candidateIDs: analyzed.map(\.id),
            retakeGroups: resolution.clusters,
            coverageGroups: coverageGroups
        )
    }

    private static func stableOrder(_ left: PhotoAsset, _ right: PhotoAsset) -> Bool {
        let leftDate = left.creationDate ?? .distantPast
        let rightDate = right.creationDate ?? .distantPast
        if leftDate != rightDate {
            return leftDate < rightDate
        }
        return left.id.rawValue < right.id.rawValue
    }
}
