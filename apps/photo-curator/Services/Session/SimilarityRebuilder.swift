import Foundation

/// Bounded transient artifact rebuild for the partial path. Loads analysis
/// images only for available IDs at the existing lane count, skips failures,
/// and checks cancellation between lanes and pairs.
struct SimilarityRebuilder: Sendable {
    let imageLoader: any PhotoImageLoader
    let analyzer: any ImageAnalysisService
    let laneCount: Int

    func rebuild(for ids: [AssetID]) async throws -> [AssetID: ImageSimilarityArtifact] {
        let lanes = max(1, laneCount)
        var artifacts: [AssetID: ImageSimilarityArtifact] = [:]
        for start in stride(from: 0, to: ids.count, by: lanes) {
            try Task.checkCancellation()
            let end = min(start + lanes, ids.count)
            await withTaskGroup(of: (AssetID, ImageSimilarityArtifact?).self) { group in
                for id in ids[start ..< end] {
                    group.addTask { [imageLoader, analyzer] in
                        guard let cgImage = try? await imageLoader.analysisImage(for: id) else { return (id, nil) }
                        let artifact = try? await analyzer.similarityArtifact(for: AnalysisInput(
                            assetID: id,
                            image: cgImage
                        ))
                        return (id, artifact)
                    }
                }
                for await(id, artifact) in group {
                    if let artifact {
                        artifacts[id] = artifact
                    }
                }
            }
        }
        return artifacts
    }
}
