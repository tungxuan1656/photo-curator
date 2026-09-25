// swiftlint:disable file_length - Saved Work recovery actions share this lane with catalog actions.
import Foundation

enum LibraryActionError: Error, Sendable, Equatable {
    case unavailable
    case selectionChanged
    case accessRequired
    case fullAccessRequired
    case assetsUnavailable
    case busy
    case operationUnavailable
    case invalidContext
}

// MARK: - feat-046 exact-set catalog actions

extension AppModel {
    /// Reads every Saved Work source without creating migrations or changing
    /// any persisted state. Each source remains independent so old workspace
    /// choices cannot become catalog actions or inferred deletion sets.
    func refreshSavedWorkRecovery() async -> SavedWorkRecoverySnapshot {
        var items: [SavedWorkRecoveryItem] = []
        var storage: [SavedWorkStorageStatus] = []

        // SwiftFormat wraps multi-clause conditions before the brace.
        // swiftlint:disable opening_brace
        if let actionContexts = container.actionContexts,
           let contexts = try? await actionContexts.listAll()
        {
            storage.append(.init(storage: .catalogActions, isAvailable: true))
            items.append(contentsOf: contexts.map(SavedWorkRecoveryItem.catalogAction))
        } else {
            storage.append(.init(storage: .catalogActions, isAvailable: false))
        }

        if let workspaceStore = container.workspaceStore,
           let scopes = try? await workspaceStore.listScopes()
        {
            storage.append(.init(storage: .workspaceScopes, isAvailable: true))
            items.append(contentsOf: scopes.map(SavedWorkRecoveryItem.workspaceScope))
        } else {
            storage.append(.init(storage: .workspaceScopes, isAvailable: false))
        }

        if let albumOperations = container.albumOperations {
            storage.append(.init(storage: .albumSaves, isAvailable: true))
            let operations = await albumOperations.recoverableOperations()
            items.append(contentsOf: operations.map(SavedWorkRecoveryItem.albumSave))
        } else {
            storage.append(.init(storage: .albumSaves, isAvailable: false))
        }

        if let deletionOperations = container.deletionOperations,
           let operations = try? await deletionOperations.recoverableOperations()
        {
            storage.append(.init(storage: .deletions, isAvailable: true))
            items.append(contentsOf: operations.map(SavedWorkRecoveryItem.deletion))
        } else {
            storage.append(.init(storage: .deletions, isAvailable: false))
        }
        // swiftlint:enable opening_brace

        let legacy = await container.checkpointStore.legacySessionArtifactsWithAvailability()
        storage.append(.init(storage: .legacyCheckpoints, isAvailable: legacy.isAvailable))
        if legacy.isAvailable == false {
            items.append(.unavailableLegacyStorage(.legacyCheckpoints))
        }
        items.append(contentsOf: legacySavedWorkItems(from: legacy.artifacts))
        return SavedWorkRecoverySnapshot(items: items, storage: storage)
    }

    private func legacySavedWorkItems(
        from artifacts: [SessionCheckpointStore.LegacySessionArtifacts]
    ) -> [SavedWorkRecoveryItem] {
        var items: [SavedWorkRecoveryItem] = []
        for session in artifacts {
            if let record = session.checkpoint {
                items.append(.legacy(SavedWorkLegacyArtifact(
                    sessionID: session.sessionID, kind: record.kind, state: record.state,
                    checkpoint: session.decodedCheckpoint, result: nil, feedback: nil
                )))
            }
            if let record = session.result {
                items.append(.legacy(SavedWorkLegacyArtifact(
                    sessionID: session.sessionID, kind: record.kind, state: record.state,
                    checkpoint: nil, result: session.decodedResult, feedback: nil
                )))
            }
            if let record = session.feedback {
                items.append(.legacy(SavedWorkLegacyArtifact(
                    sessionID: session.sessionID, kind: record.kind, state: record.state,
                    checkpoint: nil, result: nil, feedback: session.decodedFeedback
                )))
            }
        }
        return items
    }

    /// Alias for callers that treat Saved Work as a read operation rather
    /// than a refresh. Both paths use the same non-persistent aggregation.
    func loadSavedWorkRecovery() async -> SavedWorkRecoverySnapshot {
        await refreshSavedWorkRecovery()
    }

    /// Opens an item through the existing recovery entry points. No query is
    /// rerun, no operation is dispatched, and a legacy payload is never
    /// translated into a catalog action or a deletion request.
    @discardableResult
    func openLibrarySavedWork(_ item: SavedWorkRecoveryItem) async -> Bool {
        guard item.availability.isAvailable else { return false }
        switch item {
        case let .catalogAction(context):
            openLibrarySavedAction(context)
            return true
        case let .workspaceScope(scope):
            pendingReviewIntent = scope.intent
            return await openSavedReviewSession(scope.id)
        case let .albumSave(operation):
            return await openSavedReviewSession(operation.sessionID)
        case let .deletion(operation):
            deletionOperation = operation
            if operation.status == .prepared {
                await openPreparedDeletionReview(operation)
            } else {
                await checkDeletionOutcomes(operationID: operation.operationID)
            }
            return true
        case let .legacy(artifact):
            return await openSavedReviewSession(artifact.sessionID.rawValue)
        }
    }

    private func openSavedReviewSession(_ sessionID: UUID) async -> Bool {
        let session = SessionID(rawValue: sessionID)
        activeSessionID = session
        lastSessionID = session
        return await beginReview(for: session)
    }

    /// Enters S15 without turning a recovered album operation into an
    /// implicit PhotoKit retry. A fresh Final Review entry has no persisted
    /// operation and retains the normal explicit Save Album behavior; a saved
    /// operation is inspected until the user taps its existing retry action.
    func loadAlbumSaveEntry(for sessionID: SessionID) async -> SaveOutcome {
        if let flight = saveFlight, flight.session == sessionID {
            return await flight.task.value
        }
        let operation = await container.albumOperations?.load(sessionID: sessionID.rawValue)
        let hasLegacyState = await container.checkpointStore.loadSaveState(sessionID: sessionID) != nil
        guard operation != nil || hasLegacyState else {
            return .failed(.assetsUnavailable)
        }
        let state: SaveState?
        if let operation {
            state = SaveState(
                sessionID: SessionID(rawValue: operation.sessionID),
                albumLocalIdentifier: operation.albumLocalIdentifier ?? "",
                albumTitle: operation.albumTitle,
                requestedIDs: operation.draftIDs.map(AssetID.init(rawValue:)),
                addedIDs: operation.addedIDs.map(AssetID.init(rawValue:)),
                missingIDs: operation.missingIDs.map(AssetID.init(rawValue:))
            )
        } else {
            state = await savedAlbum(for: sessionID)
        }
        guard let state else {
            return .failed(.assetsUnavailable)
        }
        if !state.addedIDs.isEmpty, state.remainingIDs.isEmpty, state.missingIDs.isEmpty {
            return .saved(state: state)
        }
        if !state.addedIDs.isEmpty {
            return .partial(state: state)
        }
        return .failed(.assetsUnavailable)
    }

    func refreshLibraryActionRecovery() async {
        guard let actionContexts = container.actionContexts,
              var contexts = try? await actionContexts.listAll()
        else {
            libraryActionContexts = []
            return
        }
        for context in contexts {
            await refreshLibraryActionContext(context)
        }
        contexts = (try? await actionContexts.listAll()) ?? []
        libraryActionContexts = contexts
        if let context = contexts.first, libraryActionContext == nil {
            selectLibraryActionContext(context)
        }
    }

    private func refreshLibraryActionContext(_ context: LibraryActionContextSnapshot) async {
        let status: LibraryActionStatus?
        if context.kind == .album {
            await reconcileAlbumActionContext(context)
            return
        } else if context.kind == .deletion {
            status = await deletionActionStatus(for: context)
        } else {
            status = nil
        }
        if let status, status != context.status {
            _ = try? await updateLibraryAction(context.actionID, status: status)
        }
    }

    private func reconcileAlbumActionContext(_ context: LibraryActionContextSnapshot) async {
        guard let albumSave = container.albumSaveService,
              let operation = await albumSave.operation(sessionID: SessionID(rawValue: context.actionID))
        else { return }
        let status = Self.libraryActionStatus(for: operation.status)
        let destination = operation.albumLocalIdentifier.map {
            LibraryAlbumDestination(localIdentifier: $0, title: operation.albumTitle)
        }
        let destinationChanged = destination.map {
            $0.localIdentifier != context.destinationLocalIdentifier || $0.title != context.destinationTitle
        } ?? false
        guard status != context.status || destinationChanged else { return }
        _ = try? await updateLibraryAction(context.actionID, status: status, destination: destination)
    }

    private func deletionActionStatus(for context: LibraryActionContextSnapshot) async -> LibraryActionStatus? {
        guard let deletionService = container.deletionService,
              let operation = try? await deletionService.operation(operationID: context.actionID) else { return nil }
        return Self.libraryActionStatus(for: operation.operation.status)
    }

    private static func libraryActionStatus(for status: AlbumSaveStatus) -> LibraryActionStatus {
        switch status {
        case .completed: .completed
        case .partial: .partial
        case .failed: .failed
        case .needsReconciliation, .executing, .prepared: .needsReconciliation
        }
    }

    private static func libraryActionStatus(for status: PhotoDeletionStatus) -> LibraryActionStatus {
        switch status {
        case .completed: .completed
        case .partial: .partial
        case .failed, .cancelled: .failed
        case .prepared, .executing, .needsReconciliation: .needsReconciliation
        }
    }

    func openLibrarySavedWork() {
        if path.last != .librarySavedWork {
            path.append(.librarySavedWork)
        }
    }

    func openLibrarySavedAction(_ context: LibraryActionContextSnapshot) {
        selectLibraryActionContext(context)
        if path.last != .libraryActionPreview {
            path.append(.libraryActionPreview)
        }
    }

    private func selectLibraryActionContext(_ context: LibraryActionContextSnapshot) {
        libraryActionContext = context
        libraryActionSelection = LibraryQuerySelectionSnapshot(
            selectionID: UUID(),
            queryIdentity: context.queryIdentity,
            catalogGenerationID: context.catalogGenerationID,
            labelProjectionRevision: context.labelProjectionRevision,
            selectedAssetIDs: context.typedAssetIDs
        )
    }

    func loadLibraryAlbumDestinations() async {
        do {
            libraryAlbumDestinations = try await container.exporter.writableAlbums()
            libraryActionError = nil
        } catch let error as ExportError {
            libraryAlbumDestinations = []
            if error == .permissionLost {
                libraryActionError = String(localized: "library.actions.error.photosAccess")
            }
        } catch {
            libraryAlbumDestinations = []
            libraryActionError = String(localized: "library.actions.error.albumsUnavailable")
        }
    }

    func runLibraryAlbumAction(destination: LibraryAlbumDestination) async throws {
        guard !libraryActionBusy else { throw LibraryActionError.busy }
        guard let albumSave = container.albumSaveService else {
            throw LibraryActionError.operationUnavailable
        }
        libraryActionBusy = true
        libraryActionError = nil
        defer { libraryActionBusy = false }

        let context = try await prepareLibraryAction(
            kind: .album,
            status: .prepared,
            destination: destination
        )
        let executing = try await updateLibraryAction(
            context.actionID,
            status: .executing,
            destination: destination
        )
        libraryActionContext = executing
        let result = await albumSave.save(
            sessionID: SessionID(rawValue: context.actionID),
            scopeID: context.actionID,
            intent: .freshDestination(draftIDs: context.typedAssetIDs, destination: destination)
        )
        let status: LibraryActionStatus
        switch result.outcome {
        case .saved:
            status = .completed
        case .partial:
            status = .partial
        case .permissionLost:
            status = .needsReconciliation
        case .failed:
            status = .failed
        }
        libraryActionContext = try await updateLibraryAction(
            context.actionID,
            status: status,
            destination: LibraryAlbumDestination(
                localIdentifier: result.state.albumLocalIdentifier.isEmpty
                    ? destination.localIdentifier
                    : result.state.albumLocalIdentifier,
                title: result.state.albumTitle.isEmpty ? destination.title : result.state.albumTitle
            )
        )
    }

    func retryLibraryAlbumAction() async throws {
        guard !libraryActionBusy else { throw LibraryActionError.busy }
        guard let context = libraryActionContext,
              context.kind == .album,
              context.status == .partial || context.status == .needsReconciliation,
              let albumSave = container.albumSaveService
        else { throw LibraryActionError.operationUnavailable }
        guard let actionContexts = container.actionContexts,
              let persisted = try await actionContexts.load(actionID: context.actionID),
              persisted == context,
              try persisted.validated() == persisted
        else { throw LibraryActionError.invalidContext }
        libraryActionBusy = true
        defer { libraryActionBusy = false }
        libraryActionContext = try await updateLibraryAction(context.actionID, status: .executing)
        let result = await albumSave.save(
            sessionID: SessionID(rawValue: context.actionID),
            scopeID: context.actionID,
            intent: .retryRemaining
        )
        let status: LibraryActionStatus
        switch result.outcome {
        case .saved: status = .completed
        case .partial: status = .partial
        case .permissionLost: status = .needsReconciliation
        case .failed: status = .failed
        }
        libraryActionContext = try await updateLibraryAction(context.actionID, status: status)
    }

    func stageLibraryDeletion() async throws {
        guard !libraryActionBusy else { throw LibraryActionError.busy }
        guard container.deletionService != nil else {
            throw LibraryActionError.operationUnavailable
        }
        libraryActionBusy = true
        defer { libraryActionBusy = false }
        libraryActionContext = try await prepareLibraryAction(
            kind: .deletion,
            status: .staged,
            destination: nil
        )
    }

    func cancelLibraryDeletionStage() async throws {
        guard let context = libraryActionContext, context.kind == .deletion else { return }
        guard let actionContexts = container.actionContexts,
              let persisted = try await actionContexts.load(actionID: context.actionID),
              persisted == context,
              try persisted.validated() == persisted
        else { throw LibraryActionError.invalidContext }
        libraryActionContext = try await updateLibraryAction(context.actionID, status: .cancelled)
    }

    /// Read-only deletion reconciliation. It never retries or submits a
    /// further PhotoKit mutation.
    func reconcileLibraryDeletion() async throws {
        guard !libraryActionBusy,
              let context = libraryActionContext,
              context.kind == .deletion,
              context.status == .partial || context.status == .needsReconciliation || context.status == .executing,
              let service = container.deletionService
        else { throw LibraryActionError.operationUnavailable }
        guard let actionContexts = container.actionContexts,
              let persisted = try await actionContexts.load(actionID: context.actionID),
              persisted == context,
              try persisted.validated() == persisted
        else { throw LibraryActionError.invalidContext }
        libraryActionBusy = true
        defer { libraryActionBusy = false }
        guard let result = try await service.reconcile(operationID: context.actionID) else {
            throw LibraryActionError.operationUnavailable
        }
        let status: LibraryActionStatus
        switch result.operation.status {
        case .completed: status = .completed
        case .partial: status = .partial
        case .failed, .cancelled: status = .failed
        case .prepared, .executing, .needsReconciliation: status = .needsReconciliation
        }
        libraryActionContext = try await updateLibraryAction(context.actionID, status: status)
        await refreshDeletionRecovery()
    }

    /// Fresh confirmation and full-access validation happen immediately before
    /// the existing deletion service receives the immutable exact set. This
    /// method never retries a failed or unresolved deletion operation.
    func confirmLibraryDeletion() async throws {
        guard !libraryActionBusy else { throw LibraryActionError.busy }
        guard let context = libraryActionContext,
              context.kind == .deletion,
              context.status == .staged,
              let service = container.deletionService,
              let selection = libraryActionSelection
        else { throw LibraryActionError.operationUnavailable }
        guard let actionContexts = container.actionContexts,
              let persisted = try await actionContexts.load(actionID: context.actionID),
              persisted == context,
              try persisted.validated() == persisted
        else { throw LibraryActionError.invalidContext }
        libraryActionBusy = true
        defer { libraryActionBusy = false }
        try await validateLibraryActionSelection(selection, kind: .deletion)
        let executing = try await updateLibraryAction(context.actionID, status: .executing)
        libraryActionContext = executing
        let request = PhotoDeletionRequest(
            operationID: context.actionID,
            scopeID: context.actionID,
            stagedIDs: context.typedAssetIDs,
            confirmation: PhotoDeletionConfirmation(
                exactSetDigest: context.digest,
                confirmedAt: Date()
            )
        )
        do {
            let result = try await service.start(request)
            let status: LibraryActionStatus
            switch result.operation.status {
            case .completed: status = .completed
            case .partial: status = .partial
            case .needsReconciliation, .executing, .prepared: status = .needsReconciliation
            case .failed, .cancelled: status = .failed
            }
            libraryActionContext = try await updateLibraryAction(context.actionID, status: status)
            await refreshDeletionRecovery()
        } catch let error as PhotoDeletionServiceError {
            let status: LibraryActionStatus = error == .fullReadWriteAccessRequired || error == .exactSetChanged
                ? .staged
                : .needsReconciliation
            libraryActionContext = try await updateLibraryAction(context.actionID, status: status)
            await refreshDeletionRecovery()
            throw error
        }
    }

    private func prepareLibraryAction(
        kind: LibraryActionKind,
        status: LibraryActionStatus,
        destination: LibraryAlbumDestination?
    ) async throws -> LibraryActionContextSnapshot {
        guard let selection = libraryActionSelection,
              let result = libraryQueryResult,
              selection.catalogGenerationID == result.catalogGenerationID,
              selection.labelProjectionRevision == result.labelProjectionRevision,
              selection.queryIdentity == result.query.identity,
              !selection.selectedAssetIDs.isEmpty,
              Set(selection.selectedAssetIDs).isSubset(of: result.completeAssetIDs)
        else { throw LibraryActionError.selectionChanged }
        try await validateLibraryActionSelection(selection, kind: kind)
        guard let actionContexts = container.actionContexts else {
            throw LibraryActionError.unavailable
        }
        let assetIDs = Array(Set(selection.selectedAssetIDs)).sorted { $0.rawValue < $1.rawValue }
        let digest = kind == .deletion
            ? PhotoDeletionOperation.digest(for: assetIDs.map(\.rawValue))
            : LibraryActionContext.digest(for: assetIDs)
        let snapshot = LibraryActionContextSnapshot(
            actionID: UUID(),
            kind: kind,
            assetIDs: assetIDs.map(\.rawValue),
            queryIdentity: selection.queryIdentity,
            catalogGenerationID: selection.catalogGenerationID,
            labelProjectionRevision: selection.labelProjectionRevision,
            digest: digest,
            statusRawValue: status.rawValue,
            destinationLocalIdentifier: destination?.localIdentifier,
            destinationTitle: destination?.title,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await actionContexts.insertIfAbsent(snapshot)
        return snapshot
    }

    private func validateLibraryActionSelection(
        _ selection: LibraryQuerySelectionSnapshot,
        kind: LibraryActionKind
    ) async throws {
        guard let catalogStore = container.catalogStore else {
            throw LibraryActionError.unavailable
        }
        do {
            try await catalogStore.validateFrozenSelection(selection)
        } catch LibraryCatalogStoreError.actionSelectionRevisionMismatch {
            throw LibraryActionError.selectionChanged
        } catch LibraryCatalogStoreError.actionSelectionUnavailable {
            throw LibraryActionError.assetsUnavailable
        }
        let authorization = await container.photoLibrary.authorizationStatus()
        guard authorization == .authorized || authorization == .limited else {
            throw LibraryActionError.accessRequired
        }
        if kind == .deletion, authorization != .authorized {
            throw LibraryActionError.fullAccessRequired
        }
        let liveAssets = try await container.photoLibrary.fetchAssets()
        guard Set(selection.selectedAssetIDs).isSubset(of: Set(liveAssets.map(\.id))) else {
            throw LibraryActionError.assetsUnavailable
        }
    }

    private func updateLibraryAction(
        _ actionID: UUID,
        status: LibraryActionStatus,
        destination: LibraryAlbumDestination? = nil
    ) async throws -> LibraryActionContextSnapshot {
        guard let actionContexts = container.actionContexts else {
            throw LibraryActionError.unavailable
        }
        return try await actionContexts.update(
            actionID: actionID,
            status: status,
            destination: destination
        )
    }
}
