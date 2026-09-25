import Foundation
import OSLog
import Photos

struct PhotoDeletionConfirmation: Sendable {
    let exactSetDigest: String
    let confirmedAt: Date

    init(exactSetDigest: String, confirmedAt: Date = Date()) {
        self.exactSetDigest = exactSetDigest
        self.confirmedAt = confirmedAt
    }
}

struct PhotoDeletionRequest: Sendable {
    let operationID: UUID
    let scopeID: UUID
    let stagedIDs: [AssetID]
    let confirmation: PhotoDeletionConfirmation

    init(
        operationID: UUID = UUID(),
        scopeID: UUID,
        stagedIDs: [AssetID],
        confirmation: PhotoDeletionConfirmation
    ) {
        self.operationID = operationID
        self.scopeID = scopeID
        self.stagedIDs = stagedIDs
        self.confirmation = confirmation
    }
}

enum PhotoDeletionServiceError: Error, Sendable, Equatable {
    case fullReadWriteAccessRequired
    case invalidExactSet
    case invalidConfirmation
    case exactSetChanged
    case operationAlreadyExists
    case operationMissing
    case transitionConflict
    case invalidOperationState
    case persistenceFailure
}

/// Result of a start or read-only reconciliation. The snapshot is the only
/// source of truth for per-asset deletion state.
struct PhotoDeletionResult: Sendable {
    let operation: PhotoDeletionOperationSnapshot
}

protocol PhotoDeletionServiceProtocol: Sendable {
    func start(_ request: PhotoDeletionRequest) async throws -> PhotoDeletionResult
    func recoverableOperations() async throws -> [PhotoDeletionOperationSnapshot]
    func reconcile(operationID: UUID) async throws -> PhotoDeletionResult?
    func cancelPrepared(operationID: UUID) async throws -> PhotoDeletionResult?
    func operation(operationID: UUID) async throws -> PhotoDeletionResult?
}

// swiftlint:disable type_body_length
/// The sole original-deletion PhotoKit boundary. Resolution is read-only and
/// always precedes an atomic delete request. This actor deliberately has no
/// retry or resume path: interrupted work is reconciled by reads only.
actor PhotoDeletionService: PhotoDeletionServiceProtocol {
    private nonisolated static let logger = Logger(subsystem: "photo-curator", category: "deletion")

    private let operations: DeletionOperationStore
    private let photoLibrary: any PhotoLibraryService

    init(operations: DeletionOperationStore, photoLibrary: any PhotoLibraryService) {
        self.operations = operations
        self.photoLibrary = photoLibrary
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func start(_ request: PhotoDeletionRequest) async throws -> PhotoDeletionResult {
        let ids = request.stagedIDs.map(\.rawValue)
        let orderedIDs = try Self.validate(request: request, rawIDs: ids)

        // The first gate is before durable operation creation. Limited access
        // can retain staging but can never create a deletion dispatch.
        guard case .authorized = await photoLibrary.authorizationStatus() else {
            throw PhotoDeletionServiceError.fullReadWriteAccessRequired
        }

        let now = Date()
        let prepared = PhotoDeletionOperationSnapshot(
            operationID: request.operationID,
            scopeID: request.scopeID,
            stagedIDs: orderedIDs,
            digest: request.confirmation.exactSetDigest,
            confirmedAt: request.confirmation.confirmedAt,
            authorizationRawValue: PhotoDeletionAuthorizationSnapshot.authorized.rawValue,
            statusRawValue: PhotoDeletionStatus.prepared.rawValue,
            pendingIDs: orderedIDs,
            deletedIDs: [],
            accessUnknownIDs: [],
            failedIDs: [],
            unresolvedIDs: [],
            submittedIDs: [],
            createdAt: now,
            updatedAt: now,
            schemaVersion: PhotoDeletionOperation.schemaVersion
        )

        do {
            if try await operations.resetCancelledToPrepared(prepared) == false {
                try await operations.insertIfAbsent(prepared)
            }
        } catch {
            Self.logCriticalWriteFailure()
            throw Self.mapStoreError(error)
        }

        var executing = false
        do {
            try Task.checkCancellation()
            let resolved = Self.resolve(orderedIDs)

            // A full-access check immediately before dispatch prevents a
            // permission change during resolution from becoming a mutation.
            guard case .authorized = await photoLibrary.authorizationStatus() else {
                throw PhotoDeletionServiceError.fullReadWriteAccessRequired
            }

            // PhotoKit can change between the initial resolution and the
            // mutation boundary. Resolve the complete canonical set again
            // immediately before transitioning to executing; any difference
            // aborts without dispatching deletion or shrinking the set.
            try Task.checkCancellation()
            let dispatchResolution = Self.resolve(orderedIDs)
            guard dispatchResolution.foundIDs == resolved.foundIDs,
                  dispatchResolution.missingIDs == resolved.missingIDs,
                  dispatchResolution.foundIDs == orderedIDs,
                  dispatchResolution.missingIDs.isEmpty
            else {
                throw PhotoDeletionServiceError.exactSetChanged
            }

            try Task.checkCancellation()
            do {
                _ = try await operations.transitionPreparedToExecuting(
                    operationID: request.operationID,
                    expected: prepared,
                    submittedIDs: resolved.foundIDs,
                    unresolvedIDs: resolved.missingIDs
                )
            } catch {
                Self.logCriticalWriteFailure()
                throw Self.mapStoreError(error)
            }
            executing = true

            try Task.checkCancellation()
            do {
                try await Self.delete(resolved.assets)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                do {
                    try await operations.update(operationID: request.operationID) { operation in
                        Self.setOutcome(.failed, for: operation.submittedIDs, on: operation)
                        operation.statusRawValue = Self.terminalStatus(for: operation).rawValue
                    }
                } catch {
                    await markUncertain(operationID: request.operationID, ids: orderedIDs)
                    Self.logCriticalWriteFailure()
                    throw Self.mapStoreError(error)
                }
                return try await requiredResult(operationID: request.operationID)
            }

            do {
                try await operations.update(operationID: request.operationID) { operation in
                    Self.setOutcome(.deleted, for: resolved.foundIDs, on: operation)
                    operation.statusRawValue = Self.terminalStatus(for: operation).rawValue
                }
            } catch {
                await markUncertain(operationID: request.operationID, ids: orderedIDs)
                Self.logCriticalWriteFailure()
                throw Self.mapStoreError(error)
            }
            return try await requiredResult(operationID: request.operationID)
        } catch is CancellationError {
            if executing {
                await markUncertain(operationID: request.operationID, ids: orderedIDs)
            } else {
                await markCancelled(operationID: request.operationID, expected: prepared)
            }
            throw CancellationError()
        } catch let error as PhotoDeletionServiceError {
            if error == .fullReadWriteAccessRequired, !executing {
                throw error
            }
            if error == .exactSetChanged, !executing {
                await markCancelled(operationID: request.operationID, expected: prepared)
                throw error
            }
            if executing {
                await markUncertain(operationID: request.operationID, ids: orderedIDs)
            }
            throw error
        } catch {
            if executing {
                await markUncertain(operationID: request.operationID, ids: orderedIDs)
            }
            throw PhotoDeletionServiceError.persistenceFailure
        }
    }

    func reconcile(operationID: UUID) async throws -> PhotoDeletionResult? {
        guard var operation = try await load(operationID: operationID) else {
            throw PhotoDeletionServiceError.operationMissing
        }
        switch PhotoDeletionStatus(rawValue: operation.statusRawValue) ?? .needsReconciliation {
        case .prepared, .completed, .partial, .failed, .cancelled:
            return PhotoDeletionResult(operation: operation)
        case .executing:
            do {
                try await operations.update(operationID: operationID) { row in
                    let resolvedIDs = Set(row.deletedIDs)
                        .union(row.accessUnknownIDs)
                        .union(row.failedIDs)
                        .union(row.unresolvedIDs)
                    let submittedUnresolved = row.submittedIDs.filter { !resolvedIDs.contains($0) }
                    Self.setOutcome(.unresolved, for: submittedUnresolved, on: row)
                    row.statusRawValue = PhotoDeletionStatus.needsReconciliation.rawValue
                }
            } catch {
                Self.logCriticalWriteFailure()
                throw Self.mapStoreError(error)
            }
            guard let updated = try await load(operationID: operationID) else {
                throw PhotoDeletionServiceError.operationMissing
            }
            operation = updated
        case .needsReconciliation:
            break
        }

        let authorization = await photoLibrary.authorizationStatus()
        switch authorization {
        case .authorized:
            // Resolution is evidence only. Neither presence nor absence can
            // establish deletion without a persisted successful callback.
            _ = Self.resolve(operation.stagedIDs)
            do {
                try await operations.update(operationID: operationID) { row in
                    Self.setOutcome(.unresolved, for: row.accessUnknownIDs, on: row)
                    row.statusRawValue = PhotoDeletionStatus.needsReconciliation.rawValue
                }
            } catch {
                Self.logCriticalWriteFailure()
                throw Self.mapStoreError(error)
            }
        case .limited, .denied, .restricted, .notDetermined:
            do {
                try await operations.update(operationID: operationID) { row in
                    Self.setOutcome(.accessUnknown, for: row.unresolvedIDs, on: row)
                    row.statusRawValue = PhotoDeletionStatus.needsReconciliation.rawValue
                }
            } catch {
                Self.logCriticalWriteFailure()
                throw Self.mapStoreError(error)
            }
        }
        return try await requiredResult(operationID: operationID)
    }

    func recoverableOperations() async throws -> [PhotoDeletionOperationSnapshot] {
        do {
            return try await operations.recoverableOperations()
        } catch {
            throw Self.mapStoreError(error)
        }
    }

    func cancelPrepared(operationID: UUID) async throws -> PhotoDeletionResult? {
        guard let operation = try await load(operationID: operationID) else {
            throw PhotoDeletionServiceError.operationMissing
        }
        do {
            _ = try await operations.transitionPreparedToCancelled(
                operationID: operationID, expected: operation
            )
        } catch {
            Self.logCriticalWriteFailure()
            throw Self.mapStoreError(error)
        }
        return try await requiredResult(operationID: operationID)
    }

    func operation(operationID: UUID) async throws -> PhotoDeletionResult? {
        guard let operation = try await load(operationID: operationID) else { return nil }
        return PhotoDeletionResult(operation: operation)
    }

    private func load(operationID: UUID) async throws -> PhotoDeletionOperationSnapshot? {
        do {
            return try await operations.load(operationID: operationID)
        } catch {
            throw PhotoDeletionServiceError.persistenceFailure
        }
    }

    private func requiredResult(operationID: UUID) async throws -> PhotoDeletionResult {
        guard let result = try await operation(operationID: operationID) else {
            throw PhotoDeletionServiceError.operationMissing
        }
        return result
    }

    private func markCancelled(
        operationID: UUID,
        expected: PhotoDeletionOperationSnapshot
    ) async {
        do {
            _ = try await operations.transitionPreparedToCancelled(
                operationID: operationID, expected: expected
            )
        } catch {
            Self.logCriticalWriteFailure()
        }
    }

    private func markUncertain(operationID: UUID, ids: [String]) async {
        do {
            try await operations.update(operationID: operationID) { operation in
                let submitted = operation.submittedIDs.isEmpty ? ids : operation.submittedIDs
                Self.setOutcome(.unresolved, for: submitted, on: operation)
                operation.statusRawValue = PhotoDeletionStatus.needsReconciliation.rawValue
            }
        } catch {
            Self.logCriticalWriteFailure()
        }
    }

    private nonisolated static func mapStoreError(_ error: Error) -> PhotoDeletionServiceError {
        switch error as? DeletionOperationStoreError {
        case .operationAlreadyExists:
            .operationAlreadyExists
        case .operationMissing:
            .operationMissing
        case .transitionConflict, .immutableIdentityViolation:
            .transitionConflict
        case .persistenceFailure:
            .persistenceFailure
        case nil:
            .persistenceFailure
        }
    }

    private nonisolated static func logCriticalWriteFailure() {
        logger.error("Deletion operation state could not be durably recorded. Failure category: safety_state.")
    }

    private nonisolated static func validate(
        request: PhotoDeletionRequest,
        rawIDs: [String]
    ) throws -> [String] {
        guard !rawIDs.isEmpty, rawIDs.allSatisfy({ !$0.isEmpty }) else {
            throw PhotoDeletionServiceError.invalidExactSet
        }
        let ordered = PhotoDeletionOperation.canonicalIDs(rawIDs)
        guard !ordered.isEmpty else { throw PhotoDeletionServiceError.invalidExactSet }
        guard request.confirmation.exactSetDigest == PhotoDeletionOperation.digest(for: ordered) else {
            throw PhotoDeletionServiceError.invalidConfirmation
        }
        return ordered
    }

    private struct Resolution {
        let assets: [PHAsset]
        let foundIDs: [String]
        let missingIDs: [String]
    }

    private nonisolated static func resolve(_ ids: [String]) -> Resolution {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var byID: [String: PHAsset] = [:]
        fetch.enumerateObjects { asset, _, _ in
            byID[asset.localIdentifier] = asset
        }
        var assets: [PHAsset] = []
        var foundIDs: [String] = []
        var missingIDs: [String] = []
        for id in ids {
            if let asset = byID[id] {
                assets.append(asset)
                foundIDs.append(id)
            } else {
                missingIDs.append(id)
            }
        }
        return Resolution(assets: assets, foundIDs: foundIDs, missingIDs: missingIDs)
    }

    private static func delete(_ assets: [PHAsset]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
    }

    private nonisolated static func setOutcome(
        _ outcome: PhotoDeletionOutcome,
        for ids: [String],
        on operation: PhotoDeletionOperation
    ) {
        let target = Set(ids)
        operation.pendingIDs.removeAll { target.contains($0) }
        operation.deletedIDs.removeAll { target.contains($0) }
        operation.accessUnknownIDs.removeAll { target.contains($0) }
        operation.failedIDs.removeAll { target.contains($0) }
        operation.unresolvedIDs.removeAll { target.contains($0) }
        switch outcome {
        case .pending:
            operation.pendingIDs.append(contentsOf: ids)
        case .deleted:
            operation.deletedIDs.append(contentsOf: ids)
        case .accessUnknown:
            operation.accessUnknownIDs.append(contentsOf: ids)
        case .failed:
            operation.failedIDs.append(contentsOf: ids)
        case .unresolved:
            operation.unresolvedIDs.append(contentsOf: ids)
        }
        operation.pendingIDs.sort()
        operation.deletedIDs.sort()
        operation.accessUnknownIDs.sort()
        operation.failedIDs.sort()
        operation.unresolvedIDs.sort()
    }

    private nonisolated static func terminalStatus(for operation: PhotoDeletionOperation) -> PhotoDeletionStatus {
        let staged = Set(operation.stagedIDs)
        let deleted = Set(operation.deletedIDs)
        let failed = Set(operation.failedIDs)
        guard operation.pendingIDs.isEmpty,
              operation.accessUnknownIDs.isEmpty,
              operation.unresolvedIDs.isEmpty
        else { return .needsReconciliation }
        if deleted == staged {
            return .completed
        }
        if deleted.isEmpty, failed == staged {
            return .failed
        }
        if !deleted.isEmpty, !failed.isEmpty, deleted.union(failed) == staged {
            return .partial
        }
        return .needsReconciliation
    }
}

// swiftlint:enable type_body_length
