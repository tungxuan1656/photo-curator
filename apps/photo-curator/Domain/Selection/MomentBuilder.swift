import Foundation

/// Time-ordered moment segmentation over duplicate representatives.
///
/// Pure synchronous Domain: no PhotoKit, Vision types, file I/O, or async.
/// Walks representatives in deterministic chronological order; gaps below
/// `momentSoftGap` continue a moment, gaps at or above `momentHardGap` start
/// a new one, and the middle band continues only on visual-edge continuity
/// or a shared non-`.unknown` scene. Missing dates or analyses never force a
/// boundary. Moment IDs are deterministic over ordered member IDs.
struct MomentBuilder: Sendable {
    func build(
        representatives: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        edges: [SimilarityEdge],
        configuration: SelectionConfiguration
    ) -> [PhotoMoment] {
        let ordered = canonicalOrder(representatives)
        var closePairs = Set<EdgeKey>()
        for edge in edges where edge.distance < configuration.nearDuplicateSimilarityThreshold {
            closePairs.insert(EdgeKey(edge.first, edge.second))
        }
        var groups: [[PhotoAsset]] = []
        for asset in ordered {
            let last = groups.last?.last
            let continues = last.map {
                continuesMoment(
                    previous: $0,
                    next: asset,
                    analyses: analyses,
                    closePairs: closePairs,
                    configuration: configuration
                )
            } ?? false
            if last != nil, !continues {
                groups.append([asset])
            } else if groups.isEmpty {
                groups.append([asset])
            } else {
                groups[groups.count - 1].append(asset)
            }
        }
        return groups.map { makeMoment($0, analyses: analyses) }
    }

    private func continuesMoment(
        previous: PhotoAsset,
        next: PhotoAsset,
        analyses: [AssetID: PhotoAnalysis],
        closePairs: Set<EdgeKey>,
        configuration: SelectionConfiguration
    ) -> Bool {
        switch (previous.creationDate, next.creationDate) {
        case let (left?, right?):
            let gap = right.timeIntervalSince(left)
            if gap < 0 {
                return true
            }
            if gap < configuration.momentSoftGap {
                return true
            }
            if gap >= configuration.momentHardGap {
                return false
            }
            if closePairs.contains(EdgeKey(previous.id, next.id)) {
                return true
            }
            guard let leftScene = analyses[previous.id]?.content.sceneType,
                  let rightScene = analyses[next.id]?.content.sceneType
            else {
                return false
            }
            return leftScene != .unknown && leftScene == rightScene
        default:
            if closePairs.contains(EdgeKey(previous.id, next.id)) {
                return true
            }
            guard let leftScene = analyses[previous.id]?.content.sceneType,
                  let rightScene = analyses[next.id]?.content.sceneType
            else {
                return true
            }
            if leftScene == .unknown || rightScene == .unknown {
                return true
            }
            return leftScene == rightScene
        }
    }

    private func makeMoment(_ assets: [PhotoAsset], analyses: [AssetID: PhotoAnalysis]) -> PhotoMoment {
        let memberIDs = assets.map(\.id)
        let dates = assets.compactMap(\.creationDate)
        let representative = assets.max {
            let leftScore = analyses[$0.id]?.qualityScore ?? -1
            let rightScore = analyses[$1.id]?.qualityScore ?? -1
            if leftScore != rightScore {
                return leftScore < rightScore
            }
            if $0.isFavorite != $1.isFavorite {
                return !$0.isFavorite
            }
            let leftArea = $0.pixelWidth * $0.pixelHeight
            let rightArea = $1.pixelWidth * $1.pixelHeight
            if leftArea != rightArea {
                return leftArea < rightArea
            }
            return $0.id.rawValue > $1.id.rawValue
        }?.id
        var sceneCounts: [SceneType: Int] = [:]
        for asset in assets {
            if let scene = analyses[asset.id]?.content.sceneType {
                sceneCounts[scene, default: 0] += 1
            }
        }
        let total = max(1, sceneCounts.values.reduce(0, +))
        let distribution = Dictionary(
            uniqueKeysWithValues: sceneCounts.map { ($0.key, Double($0.value) / Double(total)) }
        )
        return PhotoMoment(
            id: MomentID(rawValue: StableSelectionID.uuid(kind: "moment", members: memberIDs)),
            assetIDs: memberIDs,
            startDate: dates.min(),
            endDate: dates.max(),
            representativeAssetID: representative,
            sceneDistribution: distribution
        )
    }

    private func canonicalOrder(_ assets: [PhotoAsset]) -> [PhotoAsset] {
        assets.enumerated().sorted {
            let leftDate = $0.element.creationDate
            let rightDate = $1.element.creationDate
            if leftDate != rightDate {
                switch (leftDate, rightDate) {
                case let (left?, right?): return left < right
                case (nil, _?): return false
                case (_?, nil): return true
                default: break
                }
            }
            if $0.offset != $1.offset {
                return $0.offset < $1.offset
            }
            return $0.element.id.rawValue < $1.element.id.rawValue
        }.map(\.element)
    }
}

/// Order-independent pair key for close visual edges.
private struct EdgeKey: Hashable {
    let first: AssetID
    let second: AssetID

    init(_ left: AssetID, _ right: AssetID) {
        if left.rawValue < right.rawValue {
            first = left
            second = right
        } else {
            first = right
            second = left
        }
    }
}
