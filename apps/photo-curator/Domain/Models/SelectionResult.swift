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
    let qualityEvidence: QualityCurationEvidence?

    init(
        sessionID: SessionID,
        selectedAssetIDs: [AssetID],
        rejectedAssetIDs: [AssetID],
        decisions: [Decision],
        generatedAt: Date,
        engineVersion: Int,
        qualityEvidence: QualityCurationEvidence? = nil
    ) {
        self.sessionID = sessionID
        self.selectedAssetIDs = selectedAssetIDs
        self.rejectedAssetIDs = rejectedAssetIDs
        self.decisions = decisions
        self.generatedAt = generatedAt
        self.engineVersion = engineVersion
        self.qualityEvidence = qualityEvidence
    }
}

/// Review overrides collected by UI. Stored per session; learning from it is post-MVP (DEC-020).
///
/// Custom string-keyed coding: `swapWinner` uses `ClusterID` keys, which JSON
/// cannot encode directly, so it persists as UUID-string to asset-ID maps.
struct SelectionFeedback: Sendable {
    var removedIDs: Set<AssetID> = []
    var restoredIDs: Set<AssetID> = []
    var favoriteIDs: Set<AssetID> = []
    var swapWinner: [ClusterID: AssetID] = [:]
}

extension SelectionFeedback: Codable {
    enum CodingKeys: String, CodingKey {
        case removedIDs, restoredIDs, favoriteIDs, swapWinner
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let removed = try container.decodeIfPresent([String].self, forKey: .removedIDs) ?? []
        let restored = try container.decodeIfPresent([String].self, forKey: .restoredIDs) ?? []
        let favorites = try container.decodeIfPresent([String].self, forKey: .favoriteIDs) ?? []
        removedIDs = Set(removed.map(AssetID.init(rawValue:)))
        restoredIDs = Set(restored.map(AssetID.init(rawValue:)))
        favoriteIDs = Set(favorites.map(AssetID.init(rawValue:)))
        let swaps = try container.decodeIfPresent([String: String].self, forKey: .swapWinner) ?? [:]
        var winners: [ClusterID: AssetID] = [:]
        for (key, value) in swaps {
            guard let uuid = UUID(uuidString: key) else { continue }
            winners[ClusterID(rawValue: uuid)] = AssetID(rawValue: value)
        }
        swapWinner = winners
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(removedIDs.map(\.rawValue).sorted(), forKey: .removedIDs)
        try container.encode(restoredIDs.map(\.rawValue).sorted(), forKey: .restoredIDs)
        try container.encode(favoriteIDs.map(\.rawValue).sorted(), forKey: .favoriteIDs)
        var swaps: [String: String] = [:]
        for (key, value) in swapWinner {
            swaps[key.rawValue.uuidString] = value.rawValue
        }
        try container.encode(swaps, forKey: .swapWinner)
    }
}
