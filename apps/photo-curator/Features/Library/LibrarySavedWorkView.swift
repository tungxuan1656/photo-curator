import SwiftUI

struct LibrarySavedWorkView: View {
    let contexts: [LibraryActionContextSnapshot]
    let onOpen: (LibraryActionContextSnapshot) -> Void

    var body: some View {
        List {
            Section {
                Text(String(localized: "library.savedWork.description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if contexts.isEmpty {
                ContentUnavailableView(
                    String(localized: "library.savedWork.empty"),
                    systemImage: "tray",
                    description: Text(String(localized: "library.savedWork.emptyDescription"))
                )
            } else {
                ForEach(contexts, id: \.actionID) { context in
                    Button { onOpen(context) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: context.kind == .album
                                    ? "library.savedWork.album"
                                    : "library.savedWork.deletion"))
                                .font(.headline)
                            Text(String.localizedStringWithFormat(
                                String(localized: "library.savedWork.item"),
                                context.assetIDs.count,
                                statusText(context.status)
                            ))
                            .font(.subheadline)
                            Text(context.updatedAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "library.savedWork.title"))
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
}
