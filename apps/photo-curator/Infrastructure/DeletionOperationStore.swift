import Foundation
import OSLog
import SwiftData

enum DeletionOperationStoreError: Error, Sendable, Equatable {
    case operationAlreadyExists
    case operationMissing
    case transitionConflict
    case immutableIdentityViolation
    case persistenceFailure
}

/// Durable owner for original-deletion operations. The store only persists
/// caller-supplied state; it never resolves assets or dispatches PhotoKit.
actor DeletionOperationStore {
    private static let logger = Logger(subsystem: "photo-curator", category: "deletion")

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

    /// Atomic insert-if-absent. The unique operation ID and the explicit
    /// conflict check make a second start unable to create another dispatch.
    func insertIfAbsent(_ snapshot: PhotoDeletionOperationSnapshot) throws {
        let operationID = snapshot.operationID
        let rows = try context.fetch(FetchDescriptor<PhotoDeletionOperation>(
            predicate: #Predicate { $0.operationID == operationID }
        ))
        guard rows.isEmpty else { throw DeletionOperationStoreError.operationAlreadyExists }

        context.insert(PhotoDeletionOperation(
            operationID: snapshot.operationID,
            scopeID: snapshot.scopeID,
            stagedIDs: snapshot.stagedIDs,
            digest: snapshot.digest,
            confirmedAt: snapshot.confirmedAt,
            authorizationSnapshot: PhotoDeletionAuthorizationSnapshot(
                rawValue: snapshot.authorizationRawValue
            ) ?? .restricted,
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
        try save()
    }

    /// Compare-and-set for the only mutation-dispatch transition. The row
    /// must still be the exact prepared identity supplied by the caller.
    @discardableResult
    func transitionPreparedToExecuting(
        operationID: UUID,
        expected: PhotoDeletionOperationSnapshot,
        submittedIDs: [String],
        unresolvedIDs: [String]
    ) throws -> PhotoDeletionOperationSnapshot {
        guard let operation = try fetch(operationID: operationID) else {
            throw DeletionOperationStoreError.operationMissing
        }
        guard isSameIdentity(operation, as: expected),
              operation.statusRawValue == PhotoDeletionStatus.prepared.rawValue,
              operation.pendingIDs == expected.stagedIDs,
              operation.deletedIDs.isEmpty,
              operation.accessUnknownIDs.isEmpty,
              operation.failedIDs.isEmpty,
              operation.unresolvedIDs.isEmpty,
              operation.submittedIDs.isEmpty
        else {
            throw DeletionOperationStoreError.transitionConflict
        }

        let staged = Set(operation.stagedIDs)
        let submitted = Set(submittedIDs)
        let unresolved = Set(unresolvedIDs)
        guard submitted.isDisjoint(with: unresolved), submitted.union(unresolved) == staged else {
            throw DeletionOperationStoreError.transitionConflict
        }

        operation.pendingIDs = []
        operation.submittedIDs = submittedIDs.sorted()
        operation.unresolvedIDs = unresolvedIDs.sorted()
        operation.statusRawValue = PhotoDeletionStatus.executing.rawValue
        operation.updatedAt = Date()
        try save()
        return operation.snapshot()
    }

    /// Compare-and-set cancellation. A cancellation that loses to execution
    /// is a conflict and cannot turn an executing row back into cancellable.
    @discardableResult
    func transitionPreparedToCancelled(
        operationID: UUID,
        expected: PhotoDeletionOperationSnapshot
    ) throws -> PhotoDeletionOperationSnapshot {
        guard let operation = try fetch(operationID: operationID) else {
            throw DeletionOperationStoreError.operationMissing
        }
        guard isSameIdentity(operation, as: expected),
              operation.statusRawValue == PhotoDeletionStatus.prepared.rawValue,
              operation.submittedIDs.isEmpty
        else {
            throw DeletionOperationStoreError.transitionConflict
        }
        operation.statusRawValue = PhotoDeletionStatus.cancelled.rawValue
        operation.updatedAt = Date()
        try save()
        return operation.snapshot()
    }

    /// Updates outcomes/status only. Missing rows and attempts to rewrite
    /// immutable identity are hard failures, never silent no-ops.
    func update(operationID: UUID, _ mutation: (PhotoDeletionOperation) -> Void) throws {
        guard let existing = try fetch(operationID: operationID) else {
            throw DeletionOperationStoreError.operationMissing
        }
        let identity = Identity(of: existing)
        mutation(existing)
        guard Identity(of: existing) == identity else {
            context.rollback()
            throw DeletionOperationStoreError.immutableIdentityViolation
        }
        existing.updatedAt = Date()
        try save()
    }

    private func fetch(operationID: UUID) throws -> PhotoDeletionOperation? {
        try context.fetch(FetchDescriptor<PhotoDeletionOperation>(
            predicate: #Predicate { $0.operationID == operationID }
        )).first
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            // SwiftData retains pending changes after a failed save. Roll them
            // back before any later state transition can reuse this context.
            context.rollback()
            Self.logger.error("Deletion operation write failed. Failure category: durable_save.")
            throw DeletionOperationStoreError.persistenceFailure
        }
    }

    private func isSameIdentity(
        _ operation: PhotoDeletionOperation,
        as snapshot: PhotoDeletionOperationSnapshot
    ) -> Bool {
        Identity(of: operation) == Identity(of: snapshot)
    }

    private struct Identity: Equatable {
        let operationID: UUID
        let scopeID: UUID
        let stagedIDs: [String]
        let digest: String
        let confirmedAt: Date
        let createdAt: Date
        let schemaVersion: Int

        init(of operation: PhotoDeletionOperation) {
            operationID = operation.operationID
            scopeID = operation.scopeID
            stagedIDs = operation.stagedIDs
            digest = operation.digest
            confirmedAt = operation.confirmedAt
            createdAt = operation.createdAt
            schemaVersion = operation.schemaVersion
        }

        init(of snapshot: PhotoDeletionOperationSnapshot) {
            operationID = snapshot.operationID
            scopeID = snapshot.scopeID
            stagedIDs = snapshot.stagedIDs
            digest = snapshot.digest
            confirmedAt = snapshot.confirmedAt
            createdAt = snapshot.createdAt
            schemaVersion = snapshot.schemaVersion
        }
    }
}
