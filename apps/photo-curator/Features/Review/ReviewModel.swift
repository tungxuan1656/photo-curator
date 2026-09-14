import Foundation
import Observation

/// Session-local review state over the persisted chronological result.
///
/// Wraps one `SelectionResult` plus frozen `PhotoAsset` metadata for S09–S11.
/// `displayIDs` preserves engine chronology including removed IDs so grid
/// cells dim in place instead of shifting. Edits mutate only this model and
/// survive navigation; they are not persisted and never rerun the engine
/// (feat-010/012 own durable review state).
@MainActor @Observable
final class ReviewModel {
    let sessionID: SessionID
    let result: SelectionResult
    let sourceByID: [AssetID: PhotoAsset]
    private(set) var selectedIDs: Set<AssetID>
    let displayIDs: [AssetID]
    private(set) var lastRemovedID: AssetID?

    init(sessionID: SessionID, result: SelectionResult, sourceByID: [AssetID: PhotoAsset]) {
        self.sessionID = sessionID
        self.result = result
        self.sourceByID = sourceByID
        selectedIDs = Set(result.selectedAssetIDs)
        displayIDs = result.selectedAssetIDs
    }

    var selectedAssetIDs: [AssetID] {
        displayIDs.filter(selectedIDs.contains)
    }

    func isSelected(_ id: AssetID) -> Bool {
        selectedIDs.contains(id)
    }

    func remove(_ id: AssetID) {
        guard selectedIDs.remove(id) != nil else { return }
        lastRemovedID = id
    }

    func restore(_ id: AssetID) {
        guard displayIDs.contains(id) else { return }
        selectedIDs.insert(id)
        if lastRemovedID == id {
            lastRemovedID = nil
        }
    }

    func toggle(_ id: AssetID) {
        if isSelected(id) {
            remove(id)
        } else {
            restore(id)
        }
    }

    func undoLastRemoval() {
        guard let id = lastRemovedID else { return }
        restore(id)
        lastRemovedID = nil
    }
}
