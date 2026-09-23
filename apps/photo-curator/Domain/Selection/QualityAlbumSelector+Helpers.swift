import Foundation

extension QualityAlbumSelector {
    func clusters(_ groups: [PhotoCluster], selectedIDs: Set<AssetID>) -> [PhotoCluster] {
        groups.map { group in
            guard let representative = group.assetIDs.first(where: selectedIDs.contains) else { return group }
            return PhotoCluster(
                id: group.id,
                type: group.type,
                assetIDs: group.assetIDs,
                representativeAssetID: representative,
                similarityScore: group.similarityScore
            )
        }
    }
}
