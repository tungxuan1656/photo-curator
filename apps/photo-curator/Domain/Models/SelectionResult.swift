import Foundation

enum DecisionStatus: String, Codable, Sendable {
    case selected, rejected
}

/// One keep/reject choice. Rejected means "not in this album", never "safe to delete" (DEC-026).
struct Decision: Codable, Sendable {
    let assetID: AssetID
    let status: DecisionStatus
    let score: Double?
    let qualityBreakdown: QualityScoreBreakdown?
    let reasons: [String]
    let competingIDs: [AssetID]
}

struct SelectionResult: Codable, Sendable {
    let sessionID: SessionID
    let selectedAssetIDs: [AssetID]
    let rejectedAssetIDs: [AssetID]
    let decisions: [Decision]
    let generatedAt: Date
    let engineVersion: Int
}

/// Review overrides collected by UI. Stored per session; learning from it is post-MVP (DEC-020).
struct SelectionFeedback: Codable, Sendable {
    var removedIDs: Set<AssetID> = []
    var restoredIDs: Set<AssetID> = []
    var favoriteIDs: Set<AssetID> = []
    var swapWinner: [ClusterID: AssetID] = [:]
}
