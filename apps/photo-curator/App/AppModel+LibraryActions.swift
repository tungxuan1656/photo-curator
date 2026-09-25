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
