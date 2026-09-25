import SwiftUI

/// Exact-set action preview. It owns only transient presentation state; the
/// parent owns validation, durable contexts, PhotoKit writes, and recovery.
struct LibraryActionTray: View {
    let selectedAssetIDs: [AssetID]
    let context: LibraryActionContextSnapshot?
    let destinations: [LibraryAlbumDestination]
    let busy: Bool
    let error: String?
    let onReloadDestinations: () -> Void
    let onAlbum: (LibraryAlbumDestination) async throws -> Void
    let onRetryAlbum: () async throws -> Void
    let onStageDeletion: () async throws -> Void
    let onConfirmDeletion: () async throws -> Void
    let onCancelDeletion: () async throws -> Void
    let onReconcileDeletion: () async throws -> Void

    @State private var newAlbumName = ""
    @State private var localError: String?

    var body: some View {
        List {
            Section(String(localized: "library.actions.selectedPhotos")) {
                Label(
                    String.localizedStringWithFormat(
                        String(localized: "library.actions.selectedCount"), selectedAssetIDs.count
                    ),
                    systemImage: "checkmark.circle"
                )
                Text(String(localized: "library.actions.frozenSet"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let context {
                contextSection(context)
            } else {
                albumSection
                deletionSection
            }
            if let message = error ?? localError {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle(String(localized: "library.actions.title"))
        .navigationBarTitleDisplayMode(.inline)
        .disabled(busy)
    }

    private var albumSection: some View {
        Section(String(localized: "library.actions.addToAlbum")) {
            TextField(String(localized: "library.actions.newAlbumName"), text: $newAlbumName)
            Button(String(localized: "library.actions.createAlbum")) {
                let title = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
                if title.isEmpty {
                    localError = String(localized: "library.actions.error.enterAlbumName")
                } else {
                    perform { try await onAlbum(.new(title: title)) }
                }
            }
            ForEach(destinations) { destination in
                Button {
                    perform { try await onAlbum(destination) }
                } label: {
                    Label(destination.title, systemImage: "rectangle.stack")
                }
            }
            Button(String(localized: "library.actions.refreshAlbums"), action: onReloadDestinations)
                .font(.footnote)
        }
    }

    private var deletionSection: some View {
        Section(String(localized: "library.actions.cleanup")) {
            Text(String(localized: "library.actions.deletionRequirement"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(String(localized: "library.actions.stageDeletion"), role: .destructive) {
                perform { try await onStageDeletion() }
            }
        }
    }

    private func contextSection(_ context: LibraryActionContextSnapshot) -> some View {
        Section(String(localized: "library.actions.status")) {
            Text(statusText(context.status))
            let canRetryAlbum = context.kind == .album
                && (context.status == .partial || context.status == .needsReconciliation)
            if canRetryAlbum {
                Button(String(localized: "library.actions.retryAlbum")) {
                    perform { try await onRetryAlbum() }
                }
            }
            if context.kind == .deletion, context.status == .staged {
                Button(String(localized: "library.actions.deletePermanently"), role: .destructive) {
                    perform { try await onConfirmDeletion() }
                }
                Button(String(localized: "library.actions.cancelStaging")) {
                    perform { try await onCancelDeletion() }
                }
            }
            if shouldReconcile(context) {
                Button(String(localized: "library.actions.checkDeletionOutcomes")) {
                    perform { try await onReconcileDeletion() }
                }
                Text(String(localized: "library.actions.readOnlyReconcile"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func perform(_ operation: @escaping () async throws -> Void) {
        localError = nil
        Task {
            do {
                try await operation()
            } catch {
                localError = String(localized: "library.actions.error.preserved")
            }
        }
    }

    private func statusText(_ status: LibraryActionStatus) -> String {
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

    private func shouldReconcile(_ context: LibraryActionContextSnapshot) -> Bool {
        context.kind == .deletion
            && (context.status == .partial || context.status == .needsReconciliation || context.status == .executing)
    }
}
