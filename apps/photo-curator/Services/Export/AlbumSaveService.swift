import Foundation
import Photos

/// Independent album-save boundary (feat-035 owner).
///
/// Owns `AlbumSaveOperation` reconciliation and is the only caller of album
/// mutation APIs (`createAlbum`/`addToAlbum` on `AlbumExportService`, backed by
/// `PHAssetCollectionChangeRequest` + `performChanges`). Never calls a
/// deletion API and never touches cleanup disposition, review progress, or
/// the file-backed `SaveState` legacy path except as a read-only interrupt
/// handoff (unreadable SwiftData falls back to it).
///
/// Sequencing per scope is serialized inside one actor; cross-session calls
/// run on separate service instances. Every mutation is explicit: partial or
/// interrupted outcomes wait for an explicit retry, never an automatic one.
actor AlbumSaveService {
    enum SaveIntent: Sendable {
        case fresh(draftIDs: [AssetID], albumName: String)
        case retryRemaining
    }

    struct SaveResult: Sendable {
        let state: SaveState
        let outcome: SaveOutcome
    }

    private let exporter: any AlbumExportService
    private let operations: AlbumSaveOperationStore
    private let photoLibrary: (any PhotoLibraryService)?

    init(
        exporter: any AlbumExportService,
        operations: AlbumSaveOperationStore,
        photoLibrary: (any PhotoLibraryService)? = nil
    ) {
        self.exporter = exporter
        self.operations = operations
        self.photoLibrary = photoLibrary
    }

    /// S15/S14 entry: explicit save or explicit retry of the same session.
    /// `scopeID` binds the draft read to the durable workspace scope; a
    /// changed draft starts a fresh album, never a resume of the old one.
    func save(
        sessionID: SessionID,
        scopeID: UUID,
        intent: SaveIntent,
        resolveDraft: @Sendable ([AssetID]) -> [AssetID] = { $0 }
    ) async -> SaveResult {
        let status = await photoLibrary?.authorizationStatus()
        if status != .authorized, status != .limited {
            let fallback = await operations.load(sessionID: sessionID.rawValue)
            let state = Self.displayState(
                sessionID: sessionID, operation: fallback, intent: intent, resolveDraft: resolveDraft
            )
            return SaveResult(state: state, outcome: .permissionLost)
        }
        do {
            return try await runSave(
                sessionID: sessionID, scopeID: scopeID, intent: intent, resolveDraft: resolveDraft
            )
        } catch let error as ExportError {
            let fallback = await operations.load(sessionID: sessionID.rawValue)
            let state = Self.displayState(
                sessionID: sessionID, operation: fallback, intent: intent, resolveDraft: resolveDraft
            )
            return SaveResult(state: state, outcome: mapped(error))
        } catch {
            let fallback = await operations.load(sessionID: sessionID.rawValue)
            let state = Self.displayState(
                sessionID: sessionID, operation: fallback, intent: intent, resolveDraft: resolveDraft
            )
            return SaveResult(state: state, outcome: .failed(.creationFailed))
        }
    }

    /// Interrupted-save reconciliation: a durable operation with remaining
    /// IDs names the same album for explicit retry, never a duplicate album.
    func pendingOperation(sessionID: SessionID) async -> AlbumSaveOperationSnapshot? {
        guard let operation = await operations.load(sessionID: sessionID.rawValue),
              !operation.remainingIDs.isEmpty
        else { return nil }
        return operation
    }

    /// Display state for `Saving`/`Completion`: durable operation first, then
    /// the file `SaveState` legacy handoff when SwiftData is unavailable.
    func displayState(
        sessionID: SessionID, legacy: SaveState?, intent: SaveIntent,
        resolveDraft: @Sendable ([AssetID]) -> [AssetID] = { $0 }
    ) async -> SaveState {
        if let operation = await operations.load(sessionID: sessionID.rawValue) {
            return Self.state(from: operation, sessionID: sessionID)
        }
        if let legacy {
            return legacy
        }
        return Self.displayState(
            sessionID: sessionID, operation: nil, intent: intent, resolveDraft: resolveDraft
        )
    }

    // MARK: - Run

    private func runSave(
        sessionID: SessionID,
        scopeID: UUID,
        intent: SaveIntent,
        resolveDraft: @Sendable ([AssetID]) -> [AssetID]
    ) async throws -> SaveResult {
        let retryExisting = await operations.load(sessionID: sessionID.rawValue)
        let retryResumable: (AlbumSaveOperationSnapshot, String)? = {
            guard case .retryRemaining = intent, let existing = retryExisting else { return nil }
            guard let albumID = existing.albumLocalIdentifier else { return nil }
            return (existing, albumID)
        }()
        if let (existing, albumID) = retryResumable {
            return try await resumeOperation(existing, albumID: albumID, sessionID: sessionID)
        }
        let draft = try await freshDraft(
            sessionID: sessionID,
            scopeID: scopeID,
            intent: intent,
            resolveDraft: resolveDraft
        )
        let savedExisting = await operations.load(sessionID: sessionID.rawValue)
        let resumable = savedExisting.flatMap { existing in
            existing.scopeID == scopeID && existing.digest == draft.digest ? existing : nil
        }
        if let existing = resumable, let albumID = existing.albumLocalIdentifier {
            return try await resumeOperation(existing, albumID: albumID, sessionID: sessionID)
        }
        await operations.upsert(draft.prepared)
        return try await createAndFill(
            sessionID: sessionID, albumName: draft.albumName, ordered: draft.ordered
        )
    }

    /// Prepared fresh draft with its canonical digest. `FreshDraft` keeps
    /// the snapshot, ordered IDs, and digest together without a large tuple.
    private struct FreshDraft {
        let prepared: AlbumSaveOperationSnapshot
        let ordered: [AssetID]
        let digest: String
        let albumName: String
    }

    private func freshDraft(
        sessionID: SessionID,
        scopeID: UUID,
        intent: SaveIntent,
        resolveDraft: @Sendable ([AssetID]) -> [AssetID]
    ) async throws -> FreshDraft {
        let draft: [AssetID]
        let albumName: String
        switch intent {
        case let .fresh(ids, name):
            draft = ids
            albumName = name
        case .retryRemaining:
            if let existing = await operations.load(sessionID: sessionID.rawValue) {
                draft = existing.draftIDs.map { AssetID(rawValue: $0) }
                albumName = existing.albumTitle
            } else {
                throw ExportError.assetsUnavailable
            }
        }
        let ordered = Self.canonicalOrder(resolveDraft(draft))
        guard !ordered.isEmpty, !albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExportError.assetsUnavailable
        }
        let rawIDs = ordered.map(\.rawValue)
        let prepared = AlbumSaveOperationSnapshot(
            sessionID: sessionID.rawValue,
            scopeID: scopeID,
            draftIDs: rawIDs,
            digest: AlbumSaveOperation.digest(for: rawIDs),
            statusRawValue: AlbumSaveStatus.prepared.rawValue,
            albumLocalIdentifier: nil,
            albumTitle: albumName,
            addedIDs: [],
            missingIDs: [],
            createdAt: Date(),
            updatedAt: Date(),
            schemaVersion: AlbumSaveOperation.schemaVersion
        )
        return FreshDraft(prepared: prepared, ordered: ordered, digest: prepared.digest, albumName: albumName)
    }

    private func createAndFill(
        sessionID: SessionID, albumName: String, ordered: [AssetID]
    ) async throws -> SaveResult {
        do {
            let created = try await exporter.createAlbum(name: albumName)
            await operations.update(sessionID: sessionID.rawValue) { operation in
                operation.albumLocalIdentifier = created.localIdentifier
                operation.albumTitle = created.title
                operation.statusRawValue = AlbumSaveStatus.executing.rawValue
            }
            let result = try await exporter.addToAlbum(
                albumLocalIdentifier: created.localIdentifier, assetIDs: ordered
            )
            await operations.update(sessionID: sessionID.rawValue) { operation in
                operation.addedIDs = Self.union(operation.addedIDs, result.addedIDs.map(\.rawValue))
                operation.missingIDs = Self.union(operation.missingIDs, result.missingIDs.map(\.rawValue))
            }
            return try await finishOperation(sessionID: sessionID)
        } catch {
            await markInterrupted(sessionID: sessionID, error: error)
            throw error
        }
    }

    private func resumeOperation(
        _ existing: AlbumSaveOperationSnapshot, albumID: String, sessionID: SessionID
    ) async throws -> SaveResult {
        let remaining = existing.remainingIDs.map { AssetID(rawValue: $0) }
        guard !remaining.isEmpty else {
            let state = Self.state(from: existing, sessionID: sessionID)
            return SaveResult(state: state, outcome: Self.outcome(for: state))
        }
        await operations.update(sessionID: sessionID.rawValue) { operation in
            operation.statusRawValue = AlbumSaveStatus.executing.rawValue
        }
        do {
            let result = try await exporter.addToAlbum(albumLocalIdentifier: albumID, assetIDs: remaining)
            await operations.update(sessionID: sessionID.rawValue) { operation in
                operation.addedIDs = Self.union(operation.addedIDs, result.addedIDs.map(\.rawValue))
                operation.missingIDs = Self.union(operation.missingIDs, result.missingIDs.map(\.rawValue))
            }
            return try await finishOperation(sessionID: sessionID)
        } catch {
            await markInterrupted(sessionID: sessionID, error: error)
            throw error
        }
    }

    private func finishOperation(sessionID: SessionID) async throws -> SaveResult {
        guard let finished = await operations.load(sessionID: sessionID.rawValue) else {
            throw ExportError.creationFailed
        }
        let state = Self.state(from: finished, sessionID: sessionID)
        await operations.update(sessionID: sessionID.rawValue) { operation in
            operation.statusRawValue = Self.terminalStatus(for: finished).rawValue
        }
        return SaveResult(state: state, outcome: Self.outcome(for: state))
    }

    private func markInterrupted(sessionID: SessionID, error: Error) async {
        if error is CancellationError || Task.isCancelled {
            await operations.update(sessionID: sessionID.rawValue) { operation in
                operation.statusRawValue = AlbumSaveStatus.needsReconciliation.rawValue
            }
            return
        }
        if error as? ExportError == nil {
            await operations.update(sessionID: sessionID.rawValue) { operation in
                operation.statusRawValue = AlbumSaveStatus.failed.rawValue
            }
            return
        }
        if await operations.load(sessionID: sessionID.rawValue)?.albumLocalIdentifier != nil {
            await operations.update(sessionID: sessionID.rawValue) { operation in
                operation.statusRawValue = AlbumSaveStatus.needsReconciliation.rawValue
            }
        }
    }

    // MARK: - Mapping

    private static func outcome(for state: SaveState) -> SaveOutcome {
        // Truthful terminal mapping: empty adds fail; a clean full draft
        // saves; anything else is partial and waits for explicit retry.
        if state.addedIDs.isEmpty {
            return .failed(.assetsUnavailable)
        }
        if state.remainingIDs.isEmpty, state.missingIDs.isEmpty {
            return .saved(state: state)
        }
        return .partial(state: state)
    }

    private static func terminalStatus(for operation: AlbumSaveOperationSnapshot) -> AlbumSaveStatus {
        if !operation.addedIDs.isEmpty, operation.remainingIDs.isEmpty, operation.missingIDs.isEmpty {
            return .completed
        }
        if !operation.addedIDs.isEmpty {
            return .partial
        }
        return .failed
    }

    private static func state(from operation: AlbumSaveOperationSnapshot, sessionID: SessionID) -> SaveState {
        SaveState(
            sessionID: sessionID,
            albumLocalIdentifier: operation.albumLocalIdentifier ?? "",
            albumTitle: operation.albumTitle,
            requestedIDs: operation.draftIDs.map { AssetID(rawValue: $0) },
            addedIDs: operation.addedIDs.map { AssetID(rawValue: $0) },
            missingIDs: operation.missingIDs.map { AssetID(rawValue: $0) }
        )
    }

    private static func displayState(
        sessionID: SessionID,
        operation: AlbumSaveOperationSnapshot?,
        intent: SaveIntent,
        resolveDraft: @Sendable ([AssetID]) -> [AssetID]
    ) -> SaveState {
        if let operation {
            return state(from: operation, sessionID: sessionID)
        }
        switch intent {
        case let .fresh(ids, name):
            let ordered = canonicalOrder(resolveDraft(ids))
            return SaveState(
                sessionID: sessionID,
                albumLocalIdentifier: "",
                albumTitle: name,
                requestedIDs: ordered,
                addedIDs: [],
                missingIDs: []
            )
        case .retryRemaining:
            return SaveState(
                sessionID: sessionID,
                albumLocalIdentifier: "",
                albumTitle: "Curated Photos",
                requestedIDs: [],
                addedIDs: [],
                missingIDs: []
            )
        }
    }

    private static func canonicalOrder(_ ids: [AssetID]) -> [AssetID] {
        var seen = Set<String>()
        return ids.sorted { $0.rawValue < $1.rawValue }.filter { seen.insert($0.rawValue).inserted }
    }

    private static func union(_ base: [String], _ next: [String]) -> [String] {
        var seen = Set(base)
        var merged = base
        for id in next where seen.insert(id).inserted {
            merged.append(id)
        }
        return merged.sorted()
    }
}

private func mapped(_ error: ExportError) -> SaveOutcome {
    switch error {
    case .permissionLost:
        .permissionLost
    case .creationFailed:
        .failed(.creationFailed)
    case .assetsUnavailable:
        .failed(.assetsUnavailable)
    }
}
