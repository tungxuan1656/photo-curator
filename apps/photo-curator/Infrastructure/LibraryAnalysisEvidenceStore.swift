import Foundation

/// Errors raised at the durable evidence boundary. A mismatch is not a cache
/// miss: it means that the caller supplied a reference or revision that cannot
/// identify this evidence row.
enum LibraryAnalysisEvidenceStoreError: Error, Sendable, Equatable {
    case unsupportedCapability
    case missingAssetFingerprint
    case assetMismatch
    case revisionMismatch
    case invalidReference
}

/// The file envelope keeps the reference beside the facts. The envelope is
/// intentionally limited to compact native facts; it never contains an image,
/// a feature-print blob, a face box, or another pixel-derived artifact that is
/// not part of `PhotoAnalysis`'s existing scalar contract.
private struct LibraryAnalysisEvidenceRecord: Codable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let reference: AnalysisEvidenceReference
    let nativeImageFacts: PhotoAnalysis

    init(reference: AnalysisEvidenceReference, nativeImageFacts: PhotoAnalysis) {
        schemaVersion = Self.schemaVersion
        self.reference = reference
        self.nativeImageFacts = nativeImageFacts
    }
}

/// The authoritative file boundary for revisioned `nativeImageFacts`.
///
/// `FileStore.save` uses an atomic replacement. This actor does not return an
/// evidence reference until that save has completed, so a reference is never
/// an assertion that was made before the durable boundary.
actor LibraryAnalysisEvidenceStore {
    static let defaultDirectory = "library-analysis-evidence"

    private let files: FileStore
    private let directory: String

    init(files: FileStore, directory: String = "library-analysis-evidence") {
        self.files = files
        self.directory = directory
    }

    /// Atomically persists one revision-keyed native-facts payload and returns
    /// its reference only after the write succeeds.
    func store(
        _ nativeImageFacts: PhotoAnalysis,
        assetFingerprint: AssetModificationFingerprint,
        revision: AnalysisCapabilityRevision
    ) async throws -> AnalysisEvidenceReference {
        try validate(
            assetID: nativeImageFacts.assetID,
            assetFingerprint: assetFingerprint,
            revision: revision,
            payload: nativeImageFacts
        )

        let reference = makeReference(
            assetID: nativeImageFacts.assetID,
            assetFingerprint: assetFingerprint,
            revision: revision
        )
        let record = LibraryAnalysisEvidenceRecord(
            reference: reference,
            nativeImageFacts: nativeImageFacts
        )
        try await files.save(record, to: path(for: reference))
        return reference
    }

    /// Compatibility spelling for callers that treat the boundary as a save.
    @discardableResult
    func save(
        _ nativeImageFacts: PhotoAnalysis,
        assetFingerprint: AssetModificationFingerprint,
        revision: AnalysisCapabilityRevision
    ) async throws -> AnalysisEvidenceReference {
        try await store(
            nativeImageFacts,
            assetFingerprint: assetFingerprint,
            revision: revision
        )
    }

    /// Loads facts only when both the stored reference and the requested
    /// revision agree. Missing rows are misses; malformed or mismatched rows
    /// are surfaced rather than being mistaken for completed work.
    func load(
        _ reference: AnalysisEvidenceReference,
        revision: AnalysisCapabilityRevision
    ) async throws -> PhotoAnalysis? {
        try validate(reference: reference, expectedRevision: revision)

        let record: LibraryAnalysisEvidenceRecord
        do {
            record = try await files.load(
                LibraryAnalysisEvidenceRecord.self,
                from: path(for: reference)
            )
        } catch {
            if Self.isMissingFile(error) {
                return nil
            }
            throw error
        }

        guard record.schemaVersion == LibraryAnalysisEvidenceRecord.schemaVersion,
              record.reference == reference,
              record.nativeImageFacts.assetID == reference.assetID,
              record.nativeImageFacts.analysisVersion == reference.revision.analysisRevision.rawValue
        else {
            throw LibraryAnalysisEvidenceStoreError.invalidReference
        }
        return record.nativeImageFacts
    }

    /// Uses the revision embedded in the reference. Callers that are checking
    /// current work should prefer `load(_:revision:)` so the current revision
    /// is independently supplied and compared.
    func load(_ reference: AnalysisEvidenceReference) async throws -> PhotoAnalysis? {
        try await load(reference, revision: reference.revision)
    }

    /// Revision-aware convenience lookup without manufacturing a reference
    /// from caller input. It is useful for resume probes and validates the
    /// asset fingerprint as well as the capability revision.
    func load(
        assetID: AssetID,
        assetFingerprint: AssetModificationFingerprint,
        revision: AnalysisCapabilityRevision
    ) async throws -> PhotoAnalysis? {
        guard assetFingerprint.isPresent else {
            throw LibraryAnalysisEvidenceStoreError.missingAssetFingerprint
        }
        let reference = makeReference(
            assetID: assetID,
            assetFingerprint: assetFingerprint,
            revision: revision
        )
        return try await load(reference, revision: revision)
    }

    /// Removes one immutable evidence row. Removing evidence never removes
    /// originals in Photos and does not write pixel data.
    func remove(_ reference: AnalysisEvidenceReference) async throws {
        try validate(reference: reference, expectedRevision: reference.revision)
        do {
            try await files.remove(relativePath: path(for: reference))
        } catch {
            if !Self.isMissingFile(error) {
                throw error
            }
        }
    }

    /// Removes all revision rows for one asset, allowing a changed asset to be
    /// requeued without touching any other asset's evidence.
    func remove(assetID: AssetID) async {
        await files.removeDirectory(relativePath: assetDirectory(for: assetID))
    }

    /// Reset Analysis: discard all derived evidence while leaving PhotoKit
    /// originals and compatibility stores untouched.
    func reset() async {
        await files.removeDirectory(relativePath: directory)
    }

    private func makeReference(
        assetID: AssetID,
        assetFingerprint: AssetModificationFingerprint,
        revision: AnalysisCapabilityRevision
    ) -> AnalysisEvidenceReference {
        AnalysisEvidenceReference(
            identifier: identifier(
                assetID: assetID,
                assetFingerprint: assetFingerprint,
                revision: revision
            ),
            assetID: assetID,
            capability: revision.capability,
            assetFingerprint: assetFingerprint,
            revision: revision
        )
    }

    private func validate(
        assetID: AssetID,
        assetFingerprint: AssetModificationFingerprint,
        revision: AnalysisCapabilityRevision,
        payload: PhotoAnalysis
    ) throws {
        guard revision.capability == .nativeImageFacts else {
            throw LibraryAnalysisEvidenceStoreError.unsupportedCapability
        }
        guard assetFingerprint.isPresent else {
            throw LibraryAnalysisEvidenceStoreError.missingAssetFingerprint
        }
        guard payload.assetID == assetID else {
            throw LibraryAnalysisEvidenceStoreError.assetMismatch
        }
        guard payload.analysisVersion == revision.analysisRevision.rawValue else {
            throw LibraryAnalysisEvidenceStoreError.revisionMismatch
        }
    }

    private func validate(
        reference: AnalysisEvidenceReference,
        expectedRevision: AnalysisCapabilityRevision
    ) throws {
        guard reference.capability == .nativeImageFacts,
              reference.revision.capability == .nativeImageFacts
        else {
            throw LibraryAnalysisEvidenceStoreError.unsupportedCapability
        }
        guard reference.assetFingerprint.isPresent else {
            throw LibraryAnalysisEvidenceStoreError.missingAssetFingerprint
        }
        guard reference.revision == expectedRevision else {
            throw LibraryAnalysisEvidenceStoreError.revisionMismatch
        }
        guard reference.identifier == identifier(
            assetID: reference.assetID,
            assetFingerprint: reference.assetFingerprint,
            revision: reference.revision
        ) else {
            throw LibraryAnalysisEvidenceStoreError.invalidReference
        }
    }

    private func assetDirectory(for assetID: AssetID) -> String {
        "\(directory)/\(component(assetID.rawValue))"
    }

    private func path(for reference: AnalysisEvidenceReference) -> String {
        "\(assetDirectory(for: reference.assetID))/\(component(reference.identifier)).json"
    }

    private func identifier(
        assetID: AssetID,
        assetFingerprint: AssetModificationFingerprint,
        revision: AnalysisCapabilityRevision
    ) -> String {
        let fingerprint = assetFingerprintKey(assetFingerprint)
        return [
            revision.capability.rawValue,
            component(assetID.rawValue),
            component(fingerprint),
            String(revision.analysisRevision.rawValue),
            component(revision.providerRuntimeRevision.rawValue)
        ].joined(separator: "-")
    }

    private func assetFingerprintKey(_ fingerprint: AssetModificationFingerprint) -> String {
        guard fingerprint.isPresent else { return "missing" }
        guard let date = fingerprint.modificationDate else { return "present-nil" }
        return "present-\(date.timeIntervalSince1970)"
    }

    /// Hex components keep IDs safe even when PhotoKit IDs or provider
    /// revisions contain path punctuation. The resulting key is deterministic
    /// and includes every revision component.
    private func component(_ value: String) -> String {
        value.utf8.map { String(format: "%02x", $0) }.joined()
    }

    private static func isMissingFile(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError
    }
}
