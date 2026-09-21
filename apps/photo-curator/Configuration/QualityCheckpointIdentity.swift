import Foundation

/// Immutable quality inputs that make an analysis checkpoint safe to resume.
struct QualityCheckpointIdentity: Codable, Equatable, Sendable {
    let requestedMode: QualityMode
    let modelID: String?
    let modelRevision: String?
    let manifestDigest: String?
    let runtimeRevision: String?
    let modelAvailableAtStart: Bool?

    init(
        requestedMode: QualityMode,
        modelID: String? = nil,
        modelRevision: String? = nil,
        manifestDigest: String? = nil,
        runtimeRevision: String? = nil,
        modelAvailableAtStart: Bool? = nil
    ) {
        self.requestedMode = requestedMode
        self.modelID = modelID
        self.modelRevision = modelRevision
        self.manifestDigest = manifestDigest
        self.runtimeRevision = runtimeRevision
        self.modelAvailableAtStart = modelAvailableAtStart
    }

    /// Native checkpoints intentionally remain nil-compatible with pre-quality sessions.
    nonisolated static func expected(for mode: QualityMode, modelAvailableAtStart: Bool? = nil) -> Self? {
        guard mode != .native else { return nil }
        guard mode == .qualityQwen2B else {
            return Self(requestedMode: mode)
        }
        let manifest = ModelManifest.qwen35TwoBFourBit
        return Self(
            requestedMode: mode,
            modelID: manifest.modelID,
            modelRevision: manifest.revision,
            manifestDigest: manifest.manifestDigest,
            runtimeRevision: manifest.runtimeRevision,
            modelAvailableAtStart: modelAvailableAtStart
        )
    }
}
