import Foundation

/// Time-ordered moment segmentation over duplicate representatives.
///
/// Pure synchronous Domain: no PhotoKit, Vision types, file I/O, or async.
/// Walks representatives in deterministic chronological order; gaps below
/// `momentSoftGap` continue a moment, gaps at or above `momentHardGap` start
/// a new one, and the middle band applies conservative semantic change-points:
/// a close visual edge continues the moment (continuity), otherwise two known
/// differing semantic facts (people presence, document, panorama/screenshot
/// framing class, scene) start a new moment (feat-022). Every change-point
/// needs positive evidence on both sides — missing analyses, nil facts, or
/// `.unknown` scenes/subtypes continue the moment, so sparse evidence degrades
/// to the deterministic legacy grouping exactly. Moment IDs are deterministic
/// over ordered member IDs.
struct MomentBuilder: Sendable {
    func build(
        representatives: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        edges: [SimilarityEdge],
        configuration: SelectionConfiguration,
        memberIDsByRepresentative: [AssetID: [AssetID]] = [:],
        allAssets: [PhotoAsset] = []
    ) -> [PhotoMoment] {
        let ordered = canonicalOrder(representatives)
        let indexByID = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($1.id, $0) })
        var closePairs = Set<EdgeKey>()
        for edge in edges {
            guard edge.distance < configuration.nearDuplicateSimilarityThreshold,
                  edge.distance.isFinite,
                  boundedPair(
                      edge.first,
                      edge.second,
                      ordered: ordered,
                      indexByID: indexByID,
                      configuration: configuration
                  )
            else { continue }
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
        let assetsByID = Dictionary(uniqueKeysWithValues: allAssets.map { ($0.id, $0) })
            .merging(Dictionary(uniqueKeysWithValues: representatives.map { ($0.id, $0) })) { current, _ in current }
        return groups.map {
            let members = expandedMembers(
                for: $0,
                memberIDsByRepresentative: memberIDsByRepresentative,
                assetsByID: assetsByID
            )
            return makeMoment($0, members: members, analyses: analyses)
        }
    }

    private func expandedMembers(
        for representatives: [PhotoAsset],
        memberIDsByRepresentative: [AssetID: [AssetID]],
        assetsByID: [AssetID: PhotoAsset]
    ) -> [PhotoAsset] {
        let ids = representatives.flatMap { memberIDsByRepresentative[$0.id] ?? [$0.id] }
        return canonicalOrder(Set(ids).compactMap { assetsByID[$0] })
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
            // Middle band: split only on a positive semantic change-point.
            // Missing evidence continues the moment (legacy fallback).
            return !Self.semanticChangeSplits(
                leftAsset: previous, leftAnalysis: analyses[previous.id],
                rightAsset: next, rightAnalysis: analyses[next.id]
            )
        default:
            // An unknown date is not an event-order hint. Only a direct,
            // bounded visual edge may connect it to another candidate;
            // otherwise it starts its own moment.
            return closePairs.contains(EdgeKey(previous.id, next.id))
        }
    }

    private func boundedPair(
        _ leftID: AssetID, _ rightID: AssetID, ordered: [PhotoAsset],
        indexByID: [AssetID: Int], configuration: SelectionConfiguration
    ) -> Bool {
        guard let left = ordered.first(where: { $0.id == leftID }),
              let right = ordered.first(where: { $0.id == rightID })
        else { return false }
        switch (left.creationDate, right.creationDate) {
        case let (leftDate?, rightDate?):
            // Moment continuity has its own bounded comparison horizon. It
            // must not inherit the narrower duplicate-candidate window, or a
            // supplied 180–900 second continuity edge can never be observed.
            return abs(leftDate.timeIntervalSince(rightDate)) <= configuration.momentHardGap
        default:
            guard let leftIndex = indexByID[leftID], let rightIndex = indexByID[rightID] else { return false }
            return abs(leftIndex - rightIndex) == 1
        }
    }

    /// Semantic change-point policy (feat-022): the pair starts a new moment
    /// only when persisted facts positively distinguish the two sides. People
    /// presence (any face vs none), document-vs-scene, panorama/screenshot
    /// framing class, and known scene all split; unknown scenes, nil facts,
    /// unknown media subtypes, and missing analyses defer to the
    /// legacy-compatible continue. Categorical equality only: no threshold,
    /// no tuning knob, no new config key. Single-vs-group face counts stay
    /// mergeable (one event can hold a portrait plus a group); orientation
    /// alone never splits (selection-rules §12).
    static func semanticChangeSplits(
        leftAsset: PhotoAsset, leftAnalysis: PhotoAnalysis?,
        rightAsset: PhotoAsset, rightAnalysis: PhotoAnalysis?
    ) -> Bool {
        guard let leftAnalysis, let rightAnalysis else {
            // Missing facts never force a boundary: legacy fallback.
            return false
        }
        // People presence: a faceless street frame vs a group at a table is
        // an activity transition. Count differences alone never split.
        if (leftAnalysis.people.faceCount > 0) != (rightAnalysis.people.faceCount > 0) {
            return true
        }
        // Document: an identified document vs a scene photo is a transition.
        // Either side nil defers to legacy, in both argument orders.
        if documentDiffers(leftAnalysis.content.isDocument, rightAnalysis.content.isDocument) {
            return true
        }
        // Framing class: panorama/screenshot captures are categorical, but
        // only when BOTH sides are known. `.unknown` defers to legacy.
        if framingClassDiffers(leftAsset.mediaSubtype, rightAsset.mediaSubtype) {
            return true
        }
        let leftScene = leftAnalysis.content.sceneType
        let rightScene = rightAnalysis.content.sceneType
        if leftScene != .unknown, rightScene != .unknown, leftScene != rightScene {
            return true
        }
        return false
    }

    /// Bilateral framing-class check, mirroring the DuplicateResolver rule:
    /// panorama or screenshot on one side splits only when the other side is
    /// a known different subtype. Kept as a local copy so moment policy stays
    /// owned here and never drifts with cluster-membership tuning.
    private static func framingClassDiffers(_ left: PhotoMediaSubtype, _ right: PhotoMediaSubtype) -> Bool {
        guard left != right, left != .unknown, right != .unknown else { return false }
        return left == .panorama || right == .panorama || left == .screenshot || right == .screenshot
    }

    /// Bilateral document check, mirroring the DuplicateResolver rule: a
    /// true-vs-false split needs Tier-B facts on both sides.
    private static func documentDiffers(_ left: Bool?, _ right: Bool?) -> Bool {
        guard let left, let right else { return false }
        return left != right
    }

    private func makeMoment(
        _ representatives: [PhotoAsset], members: [PhotoAsset], analyses: [AssetID: PhotoAnalysis]
    ) -> PhotoMoment {
        let memberIDs = members.map(\.id)
        let dates = members.compactMap(\.creationDate)
        let representative = representatives.max {
            let leftScore = analyses[$0.id]?.qualityScore ?? -1
            let rightScore = analyses[$1.id]?.qualityScore ?? -1
            if leftScore != rightScore {
                return leftScore < rightScore
            }
            if $0.isEdited != $1.isEdited {
                return !$0.isEdited
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
        for asset in members {
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

    /// Same chronological order as DuplicateResolver/SelectionEngine:
    /// missing dates first, equal dates by stable asset ID (§15).
    private func canonicalOrder(_ assets: [PhotoAsset]) -> [PhotoAsset] {
        assets.sorted {
            let leftDate = $0.creationDate ?? .distantPast
            let rightDate = $1.creationDate ?? .distantPast
            if leftDate != rightDate {
                return leftDate < rightDate
            }
            return $0.id.rawValue < $1.id.rawValue
        }
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
