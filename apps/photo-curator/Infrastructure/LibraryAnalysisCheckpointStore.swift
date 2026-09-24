import Foundation

/// Durable scheduling progress for library analysis. This is deliberately a
/// cursor/handoff hint, not a list of completed evidence rows: the evidence
/// store and the catalog commit remain the authorities for completion.
nonisolated struct LibraryAnalysisCheckpoint: Codable, Sendable, Equatable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let catalogGenerationID: UUID
    let capability: AnalysisCapability
    let revision: AnalysisCapabilityRevision
    let resumeCursor: AssetID?
    let scheduledAssetCount: Int
    let updatedAt: Date

    init(
        catalogGenerationID: UUID,
        capability: AnalysisCapability = .nativeImageFacts,
        revision: AnalysisCapabilityRevision,
        resumeCursor: AssetID? = nil,
        scheduledAssetCount: Int = 0,
        updatedAt: Date = Date()
    ) {
        schemaVersion = Self.schemaVersion
        self.catalogGenerationID = catalogGenerationID
        self.capability = capability
        self.revision = revision
        self.resumeCursor = resumeCursor
        self.scheduledAssetCount = max(0, scheduledAssetCount)
        self.updatedAt = updatedAt
    }
}

enum LibraryAnalysisCheckpointStoreError: Error, Sendable, Equatable {
    case unsupportedCapability
    case revisionMismatch
    case invalidCheckpoint
}

/// Independent durable handoff for the library-analysis scheduler. It records
/// only the catalog generation, capability revision, and a safe scheduling
/// cursor. It never writes or infers evidence completion.
actor LibraryAnalysisCheckpointStore {
    static let defaultDirectory = "library-analysis-checkpoints"

    private let files: FileStore
    private let directory: String

    init(files: FileStore, directory: String = "library-analysis-checkpoints") {
        self.files = files
        self.directory = directory
    }

    func save(_ checkpoint: LibraryAnalysisCheckpoint) async throws {
        try validate(checkpoint)
        try await files.save(checkpoint, to: path(for: checkpoint))
    }

    func load(
        catalogGenerationID: UUID,
        capability: AnalysisCapability = .nativeImageFacts,
        revision: AnalysisCapabilityRevision
    ) async throws -> LibraryAnalysisCheckpoint? {
        try validate(capability: capability, revision: revision)

        let relativePath = path(
            catalogGenerationID: catalogGenerationID,
            capability: capability,
            revision: revision
        )
        do {
            let checkpoint = try await files.load(
                LibraryAnalysisCheckpoint.self,
                from: relativePath
            )
            guard checkpoint.schemaVersion == LibraryAnalysisCheckpoint.schemaVersion,
                  checkpoint.catalogGenerationID == catalogGenerationID,
                  checkpoint.capability == capability,
                  checkpoint.revision == revision
            else {
                throw LibraryAnalysisCheckpointStoreError.invalidCheckpoint
            }
            return checkpoint
        } catch {
            if Self.isMissingFile(error) {
                return nil
            }
            throw error
        }
    }

    func remove(_ checkpoint: LibraryAnalysisCheckpoint) async throws {
        try validate(checkpoint)
        do {
            try await files.remove(relativePath: path(for: checkpoint))
        } catch {
            if !Self.isMissingFile(error) {
                throw error
            }
        }
    }

    func remove(
        catalogGenerationID: UUID,
        capability: AnalysisCapability = .nativeImageFacts,
        revision: AnalysisCapabilityRevision
    ) async throws {
        try validate(capability: capability, revision: revision)
        do {
            try await files.remove(
                relativePath: path(
                    catalogGenerationID: catalogGenerationID,
                    capability: capability,
                    revision: revision
                )
            )
        } catch {
            if !Self.isMissingFile(error) {
                throw error
            }
        }
    }

    /// Clears only analysis scheduling hints. Evidence and session checkpoint
    /// compatibility files live in separate stores and are not touched.
    func reset() async {
        await files.removeDirectory(relativePath: directory)
    }

    private func validate(_ checkpoint: LibraryAnalysisCheckpoint) throws {
        guard checkpoint.schemaVersion == LibraryAnalysisCheckpoint.schemaVersion else {
            throw LibraryAnalysisCheckpointStoreError.invalidCheckpoint
        }
        try validate(capability: checkpoint.capability, revision: checkpoint.revision)
    }

    private func validate(
        capability: AnalysisCapability,
        revision: AnalysisCapabilityRevision
    ) throws {
        guard capability == .nativeImageFacts,
              revision.capability == .nativeImageFacts
        else {
            throw LibraryAnalysisCheckpointStoreError.unsupportedCapability
        }
        guard capability == revision.capability else {
            throw LibraryAnalysisCheckpointStoreError.revisionMismatch
        }
    }

    private func path(for checkpoint: LibraryAnalysisCheckpoint) -> String {
        path(
            catalogGenerationID: checkpoint.catalogGenerationID,
            capability: checkpoint.capability,
            revision: checkpoint.revision
        )
    }

    private func path(
        catalogGenerationID: UUID,
        capability: AnalysisCapability,
        revision: AnalysisCapabilityRevision
    ) -> String {
        let provider = component(revision.providerRuntimeRevision.rawValue)
        return "\(directory)/\(catalogGenerationID.uuidString)-\(capability.rawValue)-\(revision.analysisRevision.rawValue)-\(provider).json"
    }

    private func component(_ value: String) -> String {
        value.utf8.map { String(format: "%02x", $0) }.joined()
    }

    private static func isMissingFile(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError
    }
}
