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

    /// Prepared recovery never reuses its persisted IDs. Retire the prepared
    /// row through the service's safe non-mutation API, restore the live
    /// workspace, and let Cleanup Review obtain fresh confirmation.
    func openPreparedDeletionReview(_ operation: PhotoDeletionOperationSnapshot) async {
        guard operation.status == .prepared, operation.submittedIDs.isEmpty,
              let service = container.deletionService
        else { return }
        do {
            _ = try await service.cancelPrepared(operationID: operation.operationID)
        } catch {
            deletionError = .persistenceFailure
            return
        }
        clearDeletionState()
        await refreshDeletionRecovery()
        let sessionID = SessionID(rawValue: operation.scopeID)
        pendingReviewIntent = .cleanup
        activeSessionID = sessionID
        lastSessionID = sessionID
        do {
            let checkpoint = try await container.checkpointStore.load(sessionID: sessionID)
            allAssets = try await container.photoLibrary.fetchAssets()
            confirmedSourceIDs = checkpoint.sourceAssetIDs
            guard await beginReview(for: sessionID) else {
                deletionError = .invalidExactSet
                return
            }
            if path.last == .reviewWorkspace(sessionID: sessionID) {
                path.removeLast()
            }
            if path.last != .cleanupReview(sessionID: sessionID) {
                path.append(.cleanupReview(sessionID: sessionID))
            }
        } catch {
            deletionError = .persistenceFailure
        }
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
