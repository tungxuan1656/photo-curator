import Foundation

extension SelectionEngine {
    func effectiveClusters(
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
