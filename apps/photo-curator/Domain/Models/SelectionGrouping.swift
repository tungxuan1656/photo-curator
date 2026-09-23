import CryptoKit
import Foundation

/// Windowed duplicate-candidate pair. Order is canonical: first sorts before
/// second by the resolver's chronological order.
struct SimilarityCandidate: Sendable, Hashable {
    let first: AssetID
    let second: AssetID
}

/// Raw Vision feature-print distance for one candidate pair.
/// Lower distance means more visually similar. Transient: computed per run
/// from run-local artifacts, never persisted.
struct SimilarityEdge: Sendable, Hashable {
    let first: AssetID
    let second: AssetID
    let distance: Double
}

/// Cluster kinds. This train emits only `.nearDuplicate`: the available
/// model has no burst identifier, location, edit state, or verified
/// file-content identity, so exact/burst categories cannot be inferred.
enum ClusterType: String, Codable, Sendable {
    case nearDuplicate, burstLike, sameScene, samePose, groupPhotoSequence
}

struct PhotoCluster: Identifiable, Codable, Sendable {
    let id: ClusterID
    let type: ClusterType
    /// Complete cluster membership; the representative is one member, not a
    /// replacement for the member list.
    let assetIDs: [AssetID]
    let representativeAssetID: AssetID?
    let similarityScore: Double?
}

struct PhotoMoment: Identifiable, Codable, Sendable {
    let id: MomentID
    /// Complete membership expanded from representative-driven segmentation.
    /// Older result payloads decode unchanged because the field remains the
    /// existing `assetIDs` contract.
    let assetIDs: [AssetID]
    let startDate: Date?
    let endDate: Date?
    let representativeAssetID: AssetID?
    let sceneDistribution: [SceneType: Double]
}

/// Deterministic UUIDv5-style IDs from kind plus canonical member order.
/// Identical inputs and configuration must produce identical cluster and
/// moment IDs, so randomness is forbidden here.
enum StableSelectionID {
    static func uuid(kind: String, members: [AssetID]) -> UUID {
        var hasher = SHA256()
        hasher.update(data: Data(kind.utf8))
        for member in members {
            hasher.update(data: Data(member.rawValue.utf8))
            hasher.update(data: Data([0x1F]))
        }
        let digest = Array(hasher.finalize().prefix(16))
        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], (digest[6] & 0x0F) | 0x50, digest[7],
            (digest[8] & 0x3F) | 0x80, digest[9],
            digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]
        ))
    }
}
