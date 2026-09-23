import Foundation
import SwiftData

/// Durable owner for original-deletion operations. The store only persists
/// caller-supplied state; it never resolves assets or dispatches PhotoKit.
actor DeletionOperationStore {
    private let context: ModelContext

    init(modelContainer: ModelContainer) {
        context = ModelContext(modelContainer)
    }

    func load(operationID: UUID) throws -> PhotoDeletionOperationSnapshot? {
        let rows = try context.fetch(FetchDescriptor<PhotoDeletionOperation>(
            predicate: #Predicate { $0.operationID == operationID }
        ))
        return rows.first?.snapshot()
    }

    func upsert(_ snapshot: PhotoDeletionOperationSnapshot) throws {
        let operationID = snapshot.operationID
        let rows = try context.fetch(FetchDescriptor<PhotoDeletionOperation>(
            predicate: #Predicate { $0.operationID == operationID }
        ))
        if let existing = rows.first {
            apply(snapshot, to: existing)
        } else {
            context.insert(PhotoDeletionOperation(
                operationID: snapshot.operationID,
                scopeID: snapshot.scopeID,
                stagedIDs: snapshot.stagedIDs,
                digest: snapshot.digest,
                confirmedAt: snapshot.confirmedAt,
                authorizationSnapshot: PhotoDeletionAuthorizationSnapshot(
                    rawValue: snapshot.authorizationRawValue
                ) ?? .authorized,
                status: PhotoDeletionStatus(rawValue: snapshot.statusRawValue) ?? .needsReconciliation,
                pendingIDs: snapshot.pendingIDs,
                deletedIDs: snapshot.deletedIDs,
                accessUnknownIDs: snapshot.accessUnknownIDs,
                failedIDs: snapshot.failedIDs,
                unresolvedIDs: snapshot.unresolvedIDs,
                submittedIDs: snapshot.submittedIDs,
                createdAt: snapshot.createdAt,
                updatedAt: snapshot.updatedAt,
                schemaVersion: snapshot.schemaVersion
            ))
        }
        try context.save()
    }

    func update(operationID: UUID, _ mutation: (PhotoDeletionOperation) -> Void) throws {
        let rows = try context.fetch(FetchDescriptor<PhotoDeletionOperation>(
            predicate: #Predicate { $0.operationID == operationID }
        ))
        guard let existing = rows.first else { return }
        mutation(existing)
        existing.updatedAt = Date()
        try context.save()
    }

    private func apply(
        _ snapshot: PhotoDeletionOperationSnapshot,
        to operation: PhotoDeletionOperation
    ) {
        operation.scopeID = snapshot.scopeID
        operation.stagedIDs = snapshot.stagedIDs
        operation.digest = snapshot.digest
        operation.confirmedAt = snapshot.confirmedAt
        operation.authorizationRawValue = snapshot.authorizationRawValue
        operation.statusRawValue = snapshot.statusRawValue
        operation.pendingIDs = snapshot.pendingIDs
        operation.deletedIDs = snapshot.deletedIDs
        operation.accessUnknownIDs = snapshot.accessUnknownIDs
        operation.failedIDs = snapshot.failedIDs
        operation.unresolvedIDs = snapshot.unresolvedIDs
        operation.submittedIDs = snapshot.submittedIDs
        operation.createdAt = snapshot.createdAt
        operation.updatedAt = snapshot.updatedAt
        operation.schemaVersion = snapshot.schemaVersion
    }
}
