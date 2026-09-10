import Foundation

/// Minimal engine errors. Typed per-layer errors arrive with their owning stages.
enum SelectionError: Error, Sendable {
    case invalidInput, cancelled, `internal`
}

/// Pure deterministic selection facade. Same assets + analyses + configuration + feedback give the same
/// result (tie-breaks: selection-rules §15). Real stages land in G4; this G0 stub returns an empty result
/// so lanes link without waiting. Final picks are chronologically ordered and each carries reason codes.
struct SelectionEngine: Sendable {
    func select(
        assets: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        configuration: SelectionConfiguration,
        feedback: SelectionFeedback?
    ) throws -> SelectionResult {
        SelectionResult(
            sessionID: SessionID(rawValue: UUID()),
            selectedAssetIDs: [],
            rejectedAssetIDs: assets.map(\.id),
            decisions: [],
            generatedAt: Date(),
            engineVersion: 1
        )
    }
}
