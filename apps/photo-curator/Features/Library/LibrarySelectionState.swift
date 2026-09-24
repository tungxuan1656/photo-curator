import Foundation

/// Selection owned by discovery, not by albums or the legacy review session.
/// The parent replaces this value when a new query snapshot arrives.
struct LibrarySelectionState: Equatable, Sendable {
    private(set) var snapshot: LibraryQuerySelectionSnapshot

    var selectedAssetIDs: [AssetID] {
        snapshot.selectedAssetIDs
    }

    var isEmpty: Bool {
        selectedAssetIDs.isEmpty
    }

    mutating func apply(_ action: LibraryQuerySelectionAction, completeAssetIDs: [AssetID]) {
        snapshot = snapshot.applying(action, completeAssetIDs: completeAssetIDs)
    }

    mutating func replace(with snapshot: LibraryQuerySelectionSnapshot) {
        self.snapshot = snapshot
    }

    /// Reconciles an incoming result revision without carrying a selection
    /// across a changed catalog or label projection.
    mutating func reconcile(
        with incoming: LibraryQuerySelectionSnapshot,
        completeAssetIDs: [AssetID]
    ) -> Bool {
        let invalidated = snapshot.queryIdentity != incoming.queryIdentity
            || snapshot.catalogGenerationID != incoming.catalogGenerationID
            || snapshot.labelProjectionRevision != incoming.labelProjectionRevision
        if invalidated {
            snapshot = incoming
            return true
        }
        snapshot = incoming.applying(.select(selectedAssetIDs), completeAssetIDs: completeAssetIDs)
        return false
    }
}
