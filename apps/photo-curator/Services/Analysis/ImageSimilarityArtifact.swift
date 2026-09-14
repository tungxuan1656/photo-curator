import Foundation
import Vision

/// Transient visual-similarity evidence for one analyzed asset.
///
/// Lives only for the current selection run: created by
/// `VisionAnalysisService` alongside `PhotoAnalysis`, retained in
/// `BatchPipeline` run-local state, consumed once by
/// `BatchResult.similarityEdges(for:)`, then released. Never Codable,
/// never cached, never persisted, never logged.
final class ImageSimilarityArtifact: @unchecked Sendable {
    private let observation: VNFeaturePrintObservation

    init(observation: VNFeaturePrintObservation) {
        self.observation = observation
    }

    /// Raw Vision feature-print distance. Lower means more similar.
    /// A per-pair failure throws so the caller can skip that edge;
    /// it must never fail the session.
    func distance(to other: ImageSimilarityArtifact) throws -> Double {
        var distance: Float = 0
        try observation.computeDistance(&distance, to: other.observation)
        return Double(distance)
    }
}

/// Single-pass analyzer output: durable facts plus transient similarity.
struct ImageAnalysisOutput: @unchecked Sendable {
    let analysis: PhotoAnalysis
    let similarity: ImageSimilarityArtifact?
}
