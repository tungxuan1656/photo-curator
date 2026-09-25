import Foundation
import SwiftData

enum LibraryActionContextStoreError: Error, Sendable, Equatable {
    case actionAlreadyExists
    case actionMissing
    case immutableIdentityViolation
    case persistenceFailure
    case invalidContext
}

/// Durable owner for exact-set catalog actions. It stores only the frozen
/// action identity and lifecycle; album and deletion operation stores remain
/// independent mutation boundaries.
actor LibraryActionContextStore {
    private let context: ModelContext

    init(modelContainer: ModelContainer) {
        context = ModelContext(modelContainer)
    }

    func load(actionID: UUID) throws -> LibraryActionContextSnapshot? {
        guard let action = try context.fetch(FetchDescriptor<LibraryActionContext>(
            predicate: #Predicate { $0.actionID == actionID }
        )).first else { return nil }
        do {
            return try action.validatedSnapshot()
        } catch {
            throw LibraryActionContextStoreError.invalidContext
        }
    }

    func insertIfAbsent(_ snapshot: LibraryActionContextSnapshot) throws {
        do {
            _ = try snapshot.validated()
        } catch {
            throw LibraryActionContextStoreError.invalidContext
        }
        let actionID = snapshot.actionID
        guard try context.fetch(FetchDescriptor<LibraryActionContext>(
            predicate: #Predicate { $0.actionID == actionID }
        )).isEmpty else {
            throw LibraryActionContextStoreError.actionAlreadyExists
        }
        context.insert(LibraryActionContext(
            actionID: snapshot.actionID,
            kind: snapshot.kind,
            assetIDs: snapshot.assetIDs,
            queryIdentity: snapshot.queryIdentity,
            catalogGenerationID: snapshot.catalogGenerationID,
            labelProjectionRevision: snapshot.labelProjectionRevision,
            digest: snapshot.digest,
            status: snapshot.status,
            destinationLocalIdentifier: snapshot.destinationLocalIdentifier,
            destinationTitle: snapshot.destinationTitle,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt
        ))
        try save()
    }

    func update(
        actionID: UUID,
        status: LibraryActionStatus,
        destination: LibraryAlbumDestination? = nil
    ) throws -> LibraryActionContextSnapshot {
        guard let action = try fetch(actionID: actionID) else {
            throw LibraryActionContextStoreError.actionMissing
        }
        let current: LibraryActionContextSnapshot
        do {
            current = try action.validatedSnapshot()
        } catch {
            throw LibraryActionContextStoreError.invalidContext
        }
        if let destination {
            guard current.kind == .album else {
                throw LibraryActionContextStoreError.immutableIdentityViolation
            }
            if let currentID = current.destinationLocalIdentifier {
                guard destination.localIdentifier == currentID,
                      destination.title == current.destinationTitle
                else {
                    throw LibraryActionContextStoreError.immutableIdentityViolation
                }
            } else {
                guard destination.localIdentifier != nil || destination.title == current.destinationTitle else {
                    throw LibraryActionContextStoreError.immutableIdentityViolation
                }
            }
        }
        let candidate = LibraryActionContextSnapshot(
            actionID: current.actionID,
            kind: current.kind,
            assetIDs: current.assetIDs,
            queryIdentity: current.queryIdentity,
            catalogGenerationID: current.catalogGenerationID,
            labelProjectionRevision: current.labelProjectionRevision,
            digest: current.digest,
            statusRawValue: status.rawValue,
            destinationLocalIdentifier: destination?.localIdentifier ?? current.destinationLocalIdentifier,
            destinationTitle: destination?.title ?? current.destinationTitle,
            createdAt: current.createdAt,
            updatedAt: Date()
        )
        do {
            _ = try candidate.validated()
        } catch {
            throw LibraryActionContextStoreError.invalidContext
        }
        action.statusRawValue = status.rawValue
        if let destination {
            action.destinationLocalIdentifier = destination.localIdentifier
            action.destinationTitle = destination.title
        }
        action.updatedAt = Date()
        try save()
        return candidate
    }

    func listAll() throws -> [LibraryActionContextSnapshot] {
        try context.fetch(FetchDescriptor<LibraryActionContext>())
            .map { action in
                do {
                    return try action.validatedSnapshot()
                } catch {
                    throw LibraryActionContextStoreError.invalidContext
                }
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func listUnfinished() throws -> [LibraryActionContextSnapshot] {
        try listAll().filter { action in
            switch action.status {
            case .prepared, .staged, .executing, .partial, .needsReconciliation:
                true
            case .completed, .failed, .cancelled:
                false
            }
        }
    }

    private func fetch(actionID: UUID) throws -> LibraryActionContext? {
        try context.fetch(FetchDescriptor<LibraryActionContext>(
            predicate: #Predicate { $0.actionID == actionID }
        )).first
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw LibraryActionContextStoreError.persistenceFailure
        }
    }
}

private extension LibraryActionContext {
    func validatedSnapshot() throws -> LibraryActionContextSnapshot {
        guard LibraryActionKind(rawValue: kindRawValue) != nil else {
            throw LibraryActionContextValidationError.invalidStatus
        }
        let snapshot = self.snapshot
        return try snapshot.validated()
    }
}
