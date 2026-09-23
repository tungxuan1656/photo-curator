import Foundation

// MARK: - feat-036 original deletion user lane

extension AppModel {
    /// Loads interrupted deletion operations without dispatching PhotoKit work
    /// or changing any durable operation state. The existing outcome card can
    /// then offer its explicit, read-only Check Outcomes action.
    func refreshDeletionRecovery() async {
        guard let service = container.deletionService else {
            deletionRecoveryOperations = []
            return
        }
        do {
            let operations = try await service.recoverableOperations()
            deletionRecoveryOperations = operations
            if deletionOperation == nil {
                deletionOperation = operations.first
            }
            if let currentID = deletionOperation?.operationID {
                if let refreshed = operations.first(where: { $0.operationID == currentID }) {
                    deletionOperation = refreshed
                }
            }
        } catch {
            deletionError = .persistenceFailure
        }
    }

    func deletionDigest(for ids: [AssetID]) -> String {
        PhotoDeletionOperation.digest(for: ids.map(\.rawValue))
    }

    var canStartDeletion: Bool {
        authorization == .authorized && deletionFlight == nil
    }

    /// Starts only the exact set currently shown by Cleanup Review. The core
    /// service repeats the authorization, digest, and set checks immediately
    /// before dispatch; this method never edits cleanup dispositions.
    func startDeletion(for sessionID: SessionID, stagedIDs: [AssetID]) async {
        guard deletionFlight == nil else { return }
        guard authorization == .authorized else {
            deletionError = .fullReadWriteAccessRequired
            return
        }
        guard !stagedIDs.isEmpty, let service = container.deletionService else {
            deletionError = .invalidExactSet
            return
        }
        let scopeID = reviewModel?.scopeID ?? sessionID.rawValue
        let request = PhotoDeletionRequest(
            scopeID: scopeID,
            stagedIDs: stagedIDs,
            confirmation: PhotoDeletionConfirmation(exactSetDigest: deletionDigest(for: stagedIDs))
        )
        deletionError = nil
        let flight = Task { [service] in
            try? await service.start(request)
        }
        deletionFlight = (session: sessionID, task: flight)
        let result = await flight.value
        if deletionFlight?.session == sessionID {
            deletionFlight = nil
        }
        deletionOperation = result?.operation
        if result == nil {
            deletionError = .persistenceFailure
        }
        await refreshDeletionRecovery()
    }

    /// A prepared row is never resumed. Starting recovery mints a new
    /// operation and requires the recovery UI to provide a fresh confirmation.
    func startRecoveredDeletion(_ operation: PhotoDeletionOperationSnapshot) async {
        guard operation.status == .prepared, operation.submittedIDs.isEmpty else { return }
        let ids = operation.stagedIDs.map(AssetID.init(rawValue:))
        await startDeletion(for: SessionID(rawValue: operation.scopeID), stagedIDs: ids)
    }

    /// Read-only reconciliation. It never calls `start`, retries, or submits
    /// PhotoKit changes; unresolved outcomes remain explicitly unresolved.
    func checkDeletionOutcomes(operationID: UUID) async {
        guard deletionFlight == nil, let service = container.deletionService else { return }
        deletionError = nil
        do {
            deletionOperation = try await service.reconcile(operationID: operationID)?.operation
            await refreshDeletionRecovery()
        } catch let error as PhotoDeletionServiceError {
            deletionError = error
        } catch {
            deletionError = .persistenceFailure
        }
    }

    func clearDeletionState() {
        deletionOperation = nil
        deletionError = nil
    }
}
