import Foundation

/// Small resumable manifest. No image bytes, no face data, no pixels.
/// Stage stays an opaque label here; typed ProcessingStage mapping arrives with the coordinator.
/// nonisolated: the app target defaults to MainActor isolation, which would isolate the Codable
/// conformance and block use across actors.
nonisolated struct SessionCheckpoint: Codable, Sendable {
    let sessionID: SessionID
    let stage: String
    let completedAssetIDs: [AssetID]
    let sourceAssetIDs: [AssetID]
    let configVersion: Int
    let analysisVersion: Int
    let updatedAt: Date

    /// Explicit init so pre-006 call sites keep compiling: sourceAssetIDs defaults to [].
    init(
        sessionID: SessionID,
        stage: String,
        completedAssetIDs: [AssetID],
        sourceAssetIDs: [AssetID] = [],
        configVersion: Int,
        analysisVersion: Int,
        updatedAt: Date
    ) {
        self.sessionID = sessionID
        self.stage = stage
        self.completedAssetIDs = completedAssetIDs
        self.sourceAssetIDs = sourceAssetIDs
        self.configVersion = configVersion
        self.analysisVersion = analysisVersion
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case sessionID
        case stage
        case completedAssetIDs
        case sourceAssetIDs
        case configVersion
        case analysisVersion
        case updatedAt
    }

    /// Version-tolerant decode: pre-006 manifests lack `sourceAssetIDs`, which defaults to [].
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(SessionID.self, forKey: .sessionID)
        stage = try container.decode(String.self, forKey: .stage)
        completedAssetIDs = try container.decode([AssetID].self, forKey: .completedAssetIDs)
        sourceAssetIDs = try container.decodeIfPresent([AssetID].self, forKey: .sourceAssetIDs) ?? []
        configVersion = try container.decode(Int.self, forKey: .configVersion)
        analysisVersion = try container.decode(Int.self, forKey: .analysisVersion)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(stage, forKey: .stage)
        try container.encode(completedAssetIDs, forKey: .completedAssetIDs)
        try container.encode(sourceAssetIDs, forKey: .sourceAssetIDs)
        try container.encode(configVersion, forKey: .configVersion)
        try container.encode(analysisVersion, forKey: .analysisVersion)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

/// File-backed checkpoint skeleton. Wired in AppContainer.live() in feat-002.
actor SessionCheckpointStore {
    private let files: FileStore
    private let directory: String
    private let resultsDirectory = "results"

    init(files: FileStore, directory: String = "checkpoints") {
        self.files = files
        self.directory = directory
    }

    private func path(for sessionID: SessionID) -> String {
        "\(directory)/\(sessionID.rawValue.uuidString).json"
    }

    private func resultPath(for sessionID: SessionID) -> String {
        "\(resultsDirectory)/\(sessionID.rawValue.uuidString).json"
    }

    func save(_ checkpoint: SessionCheckpoint) async throws {
        try await files.save(checkpoint, to: path(for: checkpoint.sessionID))
    }

    func load(sessionID: SessionID) async throws -> SessionCheckpoint {
        try await files.load(SessionCheckpoint.self, from: path(for: sessionID))
    }

    func delete(sessionID: SessionID) async throws {
        do {
            try await files.remove(relativePath: path(for: sessionID))
        } catch {
            let nsError = error as NSError
            guard nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileNoSuchFileError else {
                throw error
            }
            // Already absent; treat as success.
        }
    }

    func saveResult(_ result: SelectionResult) async throws {
        try await files.save(result, to: resultPath(for: result.sessionID))
    }

    func loadResult(sessionID: SessionID) async throws -> SelectionResult {
        try await files.load(SelectionResult.self, from: resultPath(for: sessionID))
    }

    func deleteResult(sessionID: SessionID) async throws {
        do {
            try await files.remove(relativePath: resultPath(for: sessionID))
        } catch {
            let nsError = error as NSError
            guard nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileNoSuchFileError else {
                throw error
            }
            // Already absent; treat as success.
        }
    }
}
