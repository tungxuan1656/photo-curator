import Foundation
import SwiftData

/// Concrete SwiftData owner for durable album-save operations (feat-035).
/// Shares the workspace `ModelContainer`; exposes value snapshots across
/// the actor boundary. Never touches deletion state.
actor AlbumSaveOperationStore {
    private let context: ModelContext

    init(modelContainer: ModelContainer) {
        context = ModelContext(modelContainer)
    }

    /// Current operation for one session, if any. Undecodable rows surface
    /// as nil so callers fall back to the file `SaveState` handoff.
    func load(sessionID: UUID) -> AlbumSaveOperationSnapshot? {
        guard let operation = try? context.fetch(FetchDescriptor<AlbumSaveOperation>(
            predicate: #Predicate { $0.sessionID == sessionID }
        )).first
        else { return nil }
        return operation.snapshot()
    }

    /// Returns operation rows that still have work an explicit retry can
    /// reconcile. This is read-only and does not claim a save or touch
    /// PhotoKit. Terminal rows with no remaining IDs are intentionally omitted.
    func recoverableOperations() -> [AlbumSaveOperationSnapshot] {
        guard let rows = try? context.fetch(FetchDescriptor<AlbumSaveOperation>()) else {
            return []
        }
        return rows
            .map { $0.snapshot() }
            .filter { !$0.remainingIDs.isEmpty }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Inserts or replaces the session row. Digest/status/outcomes are owned
    /// by `AlbumSaveService`; this store never invents them.
    func upsert(_ snapshot: AlbumSaveOperationSnapshot) {
        do {
            let sessionID = snapshot.sessionID
            let rows = try context.fetch(FetchDescriptor<AlbumSaveOperation>(
                predicate: #Predicate { $0.sessionID == sessionID }
            ))
            if let existing = rows.first {
                apply(snapshot, to: existing)
            } else {
                context.insert(AlbumSaveOperation(
                    sessionID: snapshot.sessionID,
                    scopeID: snapshot.scopeID,
                    draftIDs: snapshot.draftIDs,
                    digest: snapshot.digest,
                    status: snapshot.status,
                    albumLocalIdentifier: snapshot.albumLocalIdentifier,
                    albumTitle: snapshot.albumTitle,
                    addedIDs: snapshot.addedIDs,
                    missingIDs: snapshot.missingIDs,
                    createdAt: snapshot.createdAt,
                    updatedAt: snapshot.updatedAt,
                    schemaVersion: snapshot.schemaVersion
                ))
            }
            try context.save()
        } catch {
            // Durable save failed: the in-memory save flow continues and the
            // next mutation retries; no state is claimed as saved here.
        }
    }

    /// Applies one mutation under the caller's sequencing. Absent rows are
    /// a no-op so late writes cannot recreate deleted operations.
    func update(sessionID: UUID, _ mutation: (AlbumSaveOperation) -> Void) {
        do {
            let rows = try context.fetch(FetchDescriptor<AlbumSaveOperation>(
                predicate: #Predicate { $0.sessionID == sessionID }
            ))
            guard let existing = rows.first else { return }
            mutation(existing)
            existing.updatedAt = Date()
            try context.save()
        } catch {
            // Same rule as upsert: failure retries on the next mutation.
        }
    }

    /// Deletes the session row. Absent rows count as success (idempotent) so
    /// discard/finish/reset never leave orphaned operation rows.
    func delete(sessionID: UUID) {
        do {
            let rows = try context.fetch(FetchDescriptor<AlbumSaveOperation>(
                predicate: #Predicate { $0.sessionID == sessionID }
            ))
            guard let existing = rows.first else { return }
            context.delete(existing)
            try context.save()
        } catch {
            // Delete failure is observed by the caller via a re-read.
        }
    }

    private func apply(_ snapshot: AlbumSaveOperationSnapshot, to operation: AlbumSaveOperation) {
        operation.scopeID = snapshot.scopeID
        operation.draftIDs = snapshot.draftIDs
        operation.digest = snapshot.digest
        operation.statusRawValue = snapshot.statusRawValue
        operation.albumLocalIdentifier = snapshot.albumLocalIdentifier
        operation.albumTitle = snapshot.albumTitle
        operation.addedIDs = snapshot.addedIDs
        operation.missingIDs = snapshot.missingIDs
        operation.createdAt = snapshot.createdAt
        operation.updatedAt = snapshot.updatedAt
        operation.schemaVersion = snapshot.schemaVersion
    }
}
