import Foundation

/// Protected-first greedy diversity fill over the shortlist.
///
/// Deterministic order: forced restores first, then sole usable candidates
/// of each moment, then the best candidate of each still-unrepresented
/// moment, then repeated greatest-utility picks. Utility combines the base
/// score with weighted coverage/category-novelty/visual-novelty minus
/// redundancy; equal utilities break by the canonical rank order
/// (`QualityScorer.compareRank`), so `AssetID.rawValue` is the final
/// decider. One pick per cluster; `.lowQuality`/`.hardRejected` never enter;
/// protected sole picks may exceed target.
struct DiversitySelector: Sendable {
    // swiftlint:disable:next function_parameter_count
    func select(
        shortlist: [ScoredCandidate],
        allMomentIDs: [MomentID],
        targetCount: Int,
        similarityEdges: [SimilarityEdge],
        configuration: SelectionConfiguration,
        feedback: SelectionFeedback?
    ) -> Set<AssetID> {
        let excluded = feedback?.removedIDs.subtracting(feedback?.restoredIDs ?? []) ?? []
        let forced = feedback?.restoredIDs ?? []
        let pool = shortlist.filter { $0.disposition == .usable && !excluded.contains($0.asset.id) }
        var state = DiversityState(pool: pool)
        state.insertForced(Set(forced.intersection(pool.map(\.asset.id))))
        let byMoment = rankedByMoment(pool)
        state.insertProtectedSoleCandidates(byMoment, allMomentIDs: allMomentIDs)
        state.insertCoreRepresentatives(byMoment, allMomentIDs: allMomentIDs)
        state.fillGreedily(
            targetCount: targetCount, allCandidates: pool, edges: similarityEdges, configuration: configuration
        )
        return state.selected
    }

    private func rankedByMoment(_ pool: [ScoredCandidate]) -> [MomentID: [ScoredCandidate]] {
        var byMoment: [MomentID: [ScoredCandidate]] = [:]
        for candidate in pool.sorted(by: QualityScorer.compareRank) {
            byMoment[candidate.momentID, default: []].append(candidate)
        }
        return byMoment
    }

    private func clustersTaken(_ candidate: ScoredCandidate, in selectedClusters: Set<ClusterID>) -> Bool {
        guard let cluster = candidate.clusterID else { return false }
        return selectedClusters.contains(cluster)
    }

    // swiftlint:disable:next function_parameter_count
    static func utilityOrderStatic(
        _ left: ScoredCandidate, _ right: ScoredCandidate, selected: Set<AssetID>,
        pool: [ScoredCandidate], edges: [SimilarityEdge], configuration: SelectionConfiguration
    ) -> Bool {
        let leftScore = utilityStatic(left, selected: selected, pool: pool, edges: edges, configuration: configuration)
        let rightScore = utilityStatic(
            right,
            selected: selected,
            pool: pool,
            edges: edges,
            configuration: configuration
        )
        if leftScore != rightScore {
            return leftScore > rightScore
        }
        return QualityScorer.compareRank(left, right)
    }

    static func utilityStatic(
        _ candidate: ScoredCandidate,
        selected: Set<AssetID>,
        pool: [ScoredCandidate],
        edges: [SimilarityEdge],
        configuration: SelectionConfiguration
    ) -> Double {
        let selectedCandidates = pool.filter { selected.contains($0.asset.id) }
        let selectedMoments = Set(selectedCandidates.map(\.momentID))
        let selectedScenes = Set(selectedCandidates.map(\.sceneType))
        let selectedPeople = Set(selectedCandidates.map(\.containsPeople))
        let selectedOrientation = Set(selectedCandidates.map(\.isPortrait))
        var coverageCount = 0.0
        if !selectedMoments.contains(candidate.momentID) {
            coverageCount += 1
        }
        if !selectedScenes.contains(candidate.sceneType) {
            coverageCount += 1
        }
        if !selectedPeople.contains(candidate.containsPeople) {
            coverageCount += 1
        }
        if !selectedOrientation.contains(candidate.isPortrait) {
            coverageCount += 1
        }
        let coverage = coverageCount / 4.0
        var noveltyCount = 0.0
        if !selectedScenes.contains(candidate.sceneType) {
            noveltyCount += 1
        }
        if !selectedPeople.contains(candidate.containsPeople) {
            noveltyCount += 1
        }
        if !selectedOrientation.contains(candidate.isPortrait) {
            noveltyCount += 1
        }
        let categoryNovelty = noveltyCount / 3.0
        var proximity: Double = 0
        for edge in edges {
            let forward = edge.first == candidate.asset.id && selected.contains(edge.second)
            let backward = edge.second == candidate.asset.id && selected.contains(edge.first)
            guard forward || backward else { continue }
            proximity = max(proximity, 1 / (1 + edge.distance))
        }
        let visualNovelty = 1 - proximity
        let momentCount = Double(selectedCandidates.filter { $0.momentID == candidate.momentID }.count)
        let saturation = momentCount / Double(max(1, configuration.maxPhotosPerMoment))
        let redundancy = (saturation + proximity) / 2.0
        return candidate.score
            + configuration.coverageWeight * coverage
            + configuration.diversityWeight * categoryNovelty
            + configuration.uniquenessWeight * visualNovelty
            - configuration.redundancyPenaltyWeight * redundancy
    }
}

/// Mutable greedy-fill state: selected IDs plus claimed clusters.
private struct DiversityState {
    let pool: [ScoredCandidate]
    var selected = Set<AssetID>()
    var selectedClusters = Set<ClusterID>()

    mutating func insertForced(_ ids: Set<AssetID>) {
        for id in ids.sorted(by: { $0.rawValue < $1.rawValue }) {
            selected.insert(id)
            if let cluster = pool.first(where: { $0.asset.id == id })?.clusterID {
                selectedClusters.insert(cluster)
            }
        }
    }

    mutating func insertProtectedSoleCandidates(
        _ byMoment: [MomentID: [ScoredCandidate]], allMomentIDs: [MomentID]
    ) {
        for momentID in allMomentIDs {
            guard let list = byMoment[momentID], list.count == 1, let only = list.first else { continue }
            guard !isTaken(only) else { continue }
            selected.insert(only.asset.id)
            if let cluster = only.clusterID {
                selectedClusters.insert(cluster)
            }
        }
    }

    mutating func insertCoreRepresentatives(
        _ byMoment: [MomentID: [ScoredCandidate]], allMomentIDs: [MomentID]
    ) {
        for momentID in allMomentIDs {
            guard let list = byMoment[momentID] else { continue }
            guard !list.contains(where: { selected.contains($0.asset.id) }) else { continue }
            for candidate in list where !isTaken(candidate) {
                selected.insert(candidate.asset.id)
                if let cluster = candidate.clusterID {
                    selectedClusters.insert(cluster)
                }
                break
            }
        }
    }

    mutating func fillGreedily(
        targetCount: Int, allCandidates: [ScoredCandidate], edges: [SimilarityEdge],
        configuration: SelectionConfiguration
    ) {
        var remaining = pool.filter { !selected.contains($0.asset.id) }
        while selected.count < targetCount, !remaining.isEmpty {
            remaining.sort {
                DiversitySelector.utilityOrderStatic(
                    $0, $1, selected: selected, pool: allCandidates, edges: edges, configuration: configuration
                )
            }
            guard let next = remaining.first else { break }
            guard !isTaken(next) else {
                remaining.removeFirst()
                continue
            }
            selected.insert(next.asset.id)
            if let cluster = next.clusterID {
                selectedClusters.insert(cluster)
            }
            remaining.removeFirst()
        }
    }

    private func isTaken(_ candidate: ScoredCandidate) -> Bool {
        guard let cluster = candidate.clusterID else { return false }
        return selectedClusters.contains(cluster)
    }
}
