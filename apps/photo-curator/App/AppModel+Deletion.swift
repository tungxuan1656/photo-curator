import Foundation

// MARK: - feat-036 original deletion user lane

extension AppModel {
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
    }

    /// Read-only reconciliation. It never calls `start`, retries, or submits
    /// PhotoKit changes; unresolved outcomes remain explicitly unresolved.
    func checkDeletionOutcomes(operationID: UUID) async {
        guard deletionFlight == nil, let service = container.deletionService else { return }
        deletionError = nil
        do {
            deletionOperation = try await service.reconcile(operationID: operationID)?.operation
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
