import SwiftUI

struct LibrarySavedWorkView: View {
    let snapshot: SavedWorkRecoverySnapshot
    let onOpen: (SavedWorkRecoveryItem) async -> Bool

    @State private var openingID: String?
    @State private var openFailed = false

    var body: some View {
        List {
            Section {
                Text("library.savedWork.unifiedDescription")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            unavailableStorageSection

            if snapshot.items.isEmpty {
                ContentUnavailableView(
                    "library.savedWork.empty",
                    systemImage: "tray",
                    description: Text("library.savedWork.emptyDescription")
                )
            } else {
                ForEach(snapshot.items) { item in
                    recoveryRow(item)
                }
            }
        }
        .navigationTitle("library.savedWork.title")
        .alert("library.savedWork.openFailed", isPresented: $openFailed) {
            Button("library.savedWork.done", role: .cancel) {}
        } message: {
            Text("library.savedWork.openFailedMessage")
        }
    }

    @ViewBuilder
    private var unavailableStorageSection: some View {
        let unavailable = snapshot.storage.filter { !$0.isAvailable }
        if !unavailable.isEmpty {
            Section("library.savedWork.unavailableStorage") {
                ForEach(unavailable, id: \.storage) { status in
                    Label(storageTitle(status.storage), systemImage: "externaldrive.badge.xmark")
                        .foregroundStyle(.secondary)
                }
                Text("library.savedWork.unavailableStorageMessage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func recoveryRow(_ item: SavedWorkRecoveryItem) -> some View {
        let available = item.availability.isAvailable
        return Group {
            if available {
                Button {
                    open(item)
                } label: {
                    rowContent(item, available: true)
                }
                .disabled(openingID != nil)
            } else {
                rowContent(item, available: false)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func rowContent(_ item: SavedWorkRecoveryItem, available: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(item))
                .foregroundStyle(available ? Color.curatorAccent : .secondary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title(item)).font(.headline)
                    Spacer()
                    Text(availabilityTitle(item))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(available ? Color.curatorAccent : .secondary)
                }
                Text(detail(item))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(item.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }

    private func open(_ item: SavedWorkRecoveryItem) {
        openingID = item.stableID
        Task {
            let opened = await onOpen(item)
            openingID = nil
            if !opened {
                openFailed = true
            }
        }
    }

    private func title(_ item: SavedWorkRecoveryItem) -> String {
        switch item {
        case .catalogAction: return String(localized: "library.savedWork.catalogAction")
        case let .workspaceScope(scope):
            if scope.intent == .cleanup {
                return String(localized: "library.savedWork.legacyCleanup")
            }
            return String(localized: "library.savedWork.legacyAlbum")
        case .albumSave: return String(localized: "library.savedWork.albumSave")
        case .deletion: return String(localized: "library.savedWork.deletion")
        case let .legacy(artifact): return legacyTitle(artifact.kind)
        }
    }

    private func detail(_ item: SavedWorkRecoveryItem) -> String {
        switch item {
        case let .catalogAction(context):
            return String.localizedStringWithFormat(
                String(localized: "library.savedWork.photosStatus"),
                context.assetIDs.count,
                catalogStatus(context.status)
            )
        case let .workspaceScope(scope):
            return String.localizedStringWithFormat(
                String(localized: "library.savedWork.photosStatus"),
                scope.sourceAssetIDs.count,
                String(localized: "library.savedWork.continue")
            )
        case let .albumSave(operation):
            return String.localizedStringWithFormat(
                String(localized: "library.savedWork.photosStatus"),
                operation.draftIDs.count,
                albumStatus(operation.status)
            )
        case let .deletion(operation):
            return String.localizedStringWithFormat(
                String(localized: "library.savedWork.photosStatus"),
                operation.stagedIDs.count,
                deletionStatus(operation.status)
            )
        case let .legacy(artifact):
            if artifact.availability.isAvailable {
                return String(localized: "library.savedWork.inspectLegacy")
            }
            return String(localized: "library.savedWork.unavailableArtifact")
        }
    }

    private func availabilityTitle(_ item: SavedWorkRecoveryItem) -> String {
        guard item.availability.isAvailable else {
            return String(localized: "library.savedWork.inspectOnly")
        }
        switch item {
        case .catalogAction: return String(localized: "library.savedWork.openAction")
        case .workspaceScope, .albumSave: return String(localized: "library.savedWork.continueRecovery")
        case let .deletion(operation):
            if operation.status == .completed || operation.status == .failed {
                return String(localized: "library.savedWork.inspectOutcome")
            }
            return String(localized: "library.savedWork.reconcile")
        case .legacy: return String(localized: "library.savedWork.openRecovery")
        }
    }

    private func icon(_ item: SavedWorkRecoveryItem) -> String {
        switch item {
        case .catalogAction: "square.stack.3d.up"
        case .workspaceScope, .legacy: "clock.arrow.circlepath"
        case .albumSave: "rectangle.stack"
        case .deletion: "trash"
        }
    }

    private func legacyTitle(_ kind: SessionCheckpointStore.LegacyArtifactKind) -> String {
        switch kind {
        case .checkpoint: String(localized: "library.savedWork.legacyCheckpoint")
        case .result: String(localized: "library.savedWork.legacyResult")
        case .feedback: String(localized: "library.savedWork.legacyFeedback")
        }
    }

    private func storageTitle(_ storage: SavedWorkStorage) -> String {
        switch storage {
        case .catalogActions: String(localized: "library.savedWork.storage.catalog")
        case .workspaceScopes: String(localized: "library.savedWork.storage.workspace")
        case .albumSaves: String(localized: "library.savedWork.storage.albums")
        case .deletions: String(localized: "library.savedWork.storage.deletions")
        case .legacyCheckpoints: String(localized: "library.savedWork.storage.legacy")
        }
    }

    private func catalogStatus(_ status: LibraryActionStatus) -> String {
        switch status {
        case .prepared: String(localized: "library.actions.status.prepared")
        case .staged: String(localized: "library.actions.status.staged")
        case .executing: String(localized: "library.actions.status.executing")
        case .completed: String(localized: "library.actions.status.completed")
        case .partial: String(localized: "library.actions.status.partial")
        case .failed: String(localized: "library.actions.status.failed")
        case .needsReconciliation: String(localized: "library.actions.status.reconcile")
        case .cancelled: String(localized: "library.actions.status.cancelled")
        }
    }

    private func albumStatus(_ status: AlbumSaveStatus) -> String {
        switch status {
        case .prepared, .executing, .needsReconciliation: String(localized: "library.savedWork.reconcile")
        case .completed: String(localized: "library.actions.status.completed")
        case .partial: String(localized: "library.actions.status.partial")
        case .failed: String(localized: "library.actions.status.failed")
        }
    }

    private func deletionStatus(_ status: PhotoDeletionStatus) -> String {
        switch status {
        case .prepared, .executing, .needsReconciliation: String(localized: "library.savedWork.reconcile")
        case .completed: String(localized: "library.actions.status.completed")
        case .partial: String(localized: "library.actions.status.partial")
        case .failed, .cancelled: String(localized: "library.actions.status.failed")
        }
    }
}
