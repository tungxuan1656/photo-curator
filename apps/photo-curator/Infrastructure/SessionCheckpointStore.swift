import Foundation

/// Small resumable manifest. No image bytes, no face data, no pixels.
/// Stage stays an opaque label here; typed ProcessingStage mapping arrives with the coordinator.
/// nonisolated: the app target defaults to MainActor isolation, which would isolate the Codable
/// conformance and block use across actors.
nonisolated struct SessionCheckpoint: Codable, Sendable {
    let sessionID: SessionID
    let stage: String
    let completedAssetIDs: [AssetID]
    let configVersion: Int
    let analysisVersion: Int
    let updatedAt: Date
}

/// File-backed checkpoint skeleton. Wired in AppContainer.live() in feat-002.
actor SessionCheckpointStore {
    private let files: FileStore
    private let directory: String

    init(files: FileStore, directory: String = "checkpoints") {
        self.files = files
        self.directory = directory
    }

    private func path(for sessionID: SessionID) -> String {
        "\(directory)/\(sessionID.rawValue.uuidString).json"
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
}
