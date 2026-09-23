import Foundation
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
    case operationAlreadyExists
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
    func reconcile(operationID: UUID) async throws -> PhotoDeletionResult?
    func cancelPrepared(operationID: UUID) async throws -> PhotoDeletionResult?
    func operation(operationID: UUID) async throws -> PhotoDeletionResult?
}

/// The sole original-deletion PhotoKit boundary. Resolution is read-only and
/// always precedes an atomic delete request. This actor deliberately has no
/// retry or resume path: interrupted work is reconciled by reads only.
actor PhotoDeletionService: PhotoDeletionServiceProtocol {
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

        if try await operations.load(operationID: request.operationID) != nil {
            throw PhotoDeletionServiceError.operationAlreadyExists
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
            try await operations.upsert(prepared)
        } catch {
            throw PhotoDeletionServiceError.persistenceFailure
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

            if resolved.foundIDs.isEmpty {
                do {
                    try await operations.update(operationID: request.operationID) { operation in
                        Self.setOutcome(.unresolved, for: resolved.missingIDs, on: operation)
                        operation.statusRawValue = PhotoDeletionStatus.needsReconciliation.rawValue
                    }
                } catch {
                    throw PhotoDeletionServiceError.persistenceFailure
                }
                return try await requiredResult(operationID: request.operationID)
            }

            try Task.checkCancellation()
            do {
                try await operations.update(operationID: request.operationID) { operation in
                    Self.setOutcome(.unresolved, for: resolved.missingIDs, on: operation)
                    operation.submittedIDs = resolved.foundIDs
                    operation.statusRawValue = PhotoDeletionStatus.executing.rawValue
                }
            } catch {
                throw PhotoDeletionServiceError.persistenceFailure
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
                    return try await requiredResult(operationID: request.operationID)
                } catch {
                    await markUncertain(operationID: request.operationID, ids: orderedIDs)
                    throw PhotoDeletionServiceError.persistenceFailure
                }
            }

            do {
                try await operations.update(operationID: request.operationID) { operation in
                    Self.setOutcome(.deleted, for: resolved.foundIDs, on: operation)
                    operation.statusRawValue = Self.terminalStatus(for: operation).rawValue
                }
            } catch {
                await markUncertain(operationID: request.operationID, ids: orderedIDs)
                throw PhotoDeletionServiceError.persistenceFailure
            }
            return try await requiredResult(operationID: request.operationID)
        } catch is CancellationError {
            if executing {
                await markUncertain(operationID: request.operationID, ids: orderedIDs)
            } else {
                await markCancelled(operationID: request.operationID)
            }
            throw CancellationError()
        } catch let error as PhotoDeletionServiceError {
            if error == .fullReadWriteAccessRequired, !executing {
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
        guard var operation = try await load(operationID: operationID) else { return nil }
        switch PhotoDeletionStatus(rawValue: operation.statusRawValue) ?? .needsReconciliation {
        case .prepared, .completed, .partial, .failed, .cancelled:
            return PhotoDeletionResult(operation: operation)
        case .executing:
            do {
                try await operations.update(operationID: operationID) { row in
                    let submittedPending = row.submittedIDs.filter { row.pendingIDs.contains($0) }
                    Self.setOutcome(.unresolved, for: submittedPending, on: row)
                    row.statusRawValue = PhotoDeletionStatus.needsReconciliation.rawValue
                }
            } catch {
                throw PhotoDeletionServiceError.persistenceFailure
            }
            guard let updated = try await load(operationID: operationID) else { return nil }
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
                throw PhotoDeletionServiceError.persistenceFailure
            }
        case .limited, .denied, .restricted, .notDetermined:
            do {
                try await operations.update(operationID: operationID) { row in
                    Self.setOutcome(.accessUnknown, for: row.unresolvedIDs, on: row)
                    row.statusRawValue = PhotoDeletionStatus.needsReconciliation.rawValue
                }
            } catch {
                throw PhotoDeletionServiceError.persistenceFailure
            }
        }
        return try await self.operation(operationID: operationID)
    }

    func cancelPrepared(operationID: UUID) async throws -> PhotoDeletionResult? {
        guard let operation = try await load(operationID: operationID) else { return nil }
        guard PhotoDeletionStatus(rawValue: operation.statusRawValue) == .prepared,
              operation.submittedIDs.isEmpty
        else {
            throw PhotoDeletionServiceError.invalidOperationState
        }
        do {
            try await operations.update(operationID: operationID) { row in
                row.statusRawValue = PhotoDeletionStatus.cancelled.rawValue
            }
        } catch {
            throw PhotoDeletionServiceError.persistenceFailure
        }
        return try await self.operation(operationID: operationID)
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
            throw PhotoDeletionServiceError.persistenceFailure
        }
        return result
    }

    private func markCancelled(operationID: UUID) async {
        try? await operations.update(operationID: operationID) { operation in
            guard PhotoDeletionStatus(rawValue: operation.statusRawValue) == .prepared,
                  operation.submittedIDs.isEmpty
            else { return }
            operation.statusRawValue = PhotoDeletionStatus.cancelled.rawValue
        }
    }

    private func markUncertain(operationID: UUID, ids: [String]) async {
        try? await operations.update(operationID: operationID) { operation in
            let submitted = operation.submittedIDs.isEmpty ? ids : operation.submittedIDs
            Self.setOutcome(.unresolved, for: submitted, on: operation)
            operation.statusRawValue = PhotoDeletionStatus.needsReconciliation.rawValue
        }
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
