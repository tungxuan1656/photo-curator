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

    /// Returns only operations that need an explicit user-visible recovery
    /// decision. This is a read-only query; it never changes operation state.
    func recoverableOperations() throws -> [PhotoDeletionOperationSnapshot] {
        try context.fetch(FetchDescriptor<PhotoDeletionOperation>())
            .compactMap { operation in
                switch PhotoDeletionStatus(rawValue: operation.statusRawValue) {
                case .prepared, .executing, .needsReconciliation:
                    operation.snapshot()
                default:
                    nil
                }
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Atomic insert-if-absent. The unique operation ID and the durable exact
    /// set check make a second start unable to create another dispatch for the
    /// same review scope and digest, even after relaunch.
    func insertIfAbsent(_ snapshot: PhotoDeletionOperationSnapshot) throws {
        let operationID = snapshot.operationID
        let rows = try context.fetch(FetchDescriptor<PhotoDeletionOperation>(
            predicate: #Predicate { $0.operationID == operationID }
        ))
        guard rows.isEmpty else { throw DeletionOperationStoreError.operationAlreadyExists }

        let scopeID = snapshot.scopeID
        let digest = snapshot.digest
        let matchingSetRows = try context.fetch(FetchDescriptor<PhotoDeletionOperation>(
            predicate: #Predicate { $0.scopeID == scopeID && $0.digest == digest }
        ))
        guard matchingSetRows.allSatisfy({
            PhotoDeletionStatus(rawValue: $0.statusRawValue) == .cancelled
        }) else {
            throw DeletionOperationStoreError.operationAlreadyExists
        }

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

    /// Reopens a cancelled, pre-dispatch row for a new explicit confirmation
    /// of the same exact set. Executing or outcome-bearing rows are never
    /// reusable.
    func resetCancelledToPrepared(_ snapshot: PhotoDeletionOperationSnapshot) throws -> Bool {
        guard let operation = try fetch(operationID: snapshot.operationID) else { return false }
        guard operation.statusRawValue == PhotoDeletionStatus.cancelled.rawValue,
              operation.scopeID == snapshot.scopeID,
              operation.stagedIDs == snapshot.stagedIDs,
              operation.digest == snapshot.digest,
              operation.schemaVersion == snapshot.schemaVersion,
              operation.submittedIDs.isEmpty,
              operation.deletedIDs.isEmpty,
              operation.accessUnknownIDs.isEmpty,
              operation.failedIDs.isEmpty,
              operation.unresolvedIDs.isEmpty
        else { throw DeletionOperationStoreError.transitionConflict }
        operation.confirmedAt = snapshot.confirmedAt
        operation.createdAt = snapshot.createdAt
        operation.pendingIDs = snapshot.stagedIDs
        operation.statusRawValue = PhotoDeletionStatus.prepared.rawValue
        operation.updatedAt = Date()
        try save()
        return true
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

        // Keep pending membership until each submitted ID receives a durable
        // outcome. `submittedIDs` plus this pending set lets relaunch recovery
        // identify every submitted item even if the callback was interrupted.
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
