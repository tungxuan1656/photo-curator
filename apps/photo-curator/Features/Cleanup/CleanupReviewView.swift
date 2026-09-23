import SwiftUI

/// Relaunch recovery for durable deletion operations. It is separate from
/// Cleanup Review because the curation workspace may not be restored yet.
struct DeletionRecoveryView: View {
    @Environment(AppModel.self) private var appModel
    @State private var preparedConfirmation: PhotoDeletionOperationSnapshot?

    var body: some View {
        List {
            Section {
                Text("Deletion was not restarted automatically. Review each saved operation before taking action.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(appModel.deletionRecoveryOperations, id: \.operationID) { operation in
                recoveryRow(operation)
            }
        }
        .navigationTitle("Deletion Recovery")
        .confirmationDialog(
            "Confirm this exact set again?",
            isPresented: Binding(
                get: { preparedConfirmation != nil },
                set: {
                    if !$0 {
                        preparedConfirmation = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let operation = preparedConfirmation {
                Button("Start Deletion", role: .destructive) {
                    preparedConfirmation = nil
                    Task { await appModel.startRecoveredDeletion(operation) }
                }
            }
            Button("Cancel", role: .cancel) { preparedConfirmation = nil }
        } message: {
            if let operation = preparedConfirmation {
                Text(
                    "No deletion was dispatched for this prepared operation. A fresh confirmation is required for its "
                        + "exact \(operation.stagedIDs.count)-photo set."
                )
            }
        }
        .task { await appModel.refreshDeletionRecovery() }
    }

    private func recoveryRow(_ operation: PhotoDeletionOperationSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(operation.stagedIDs.count) photos · \(statusTitle(operation))")
                .font(.headline)
            Text(recoveryExplanation(operation))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if operation.status == .prepared {
                Button("Review exact set and confirm") {
                    preparedConfirmation = operation
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
            } else if needsReadOnlyCheck(operation) {
                Button("Check Outcomes") {
                    Task { await appModel.checkDeletionOutcomes(operationID: operation.operationID) }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .disabled(appModel.deletionFlight != nil)
                Text("Read-only check. This never retries deletion.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }

    private func needsReadOnlyCheck(_ operation: PhotoDeletionOperationSnapshot) -> Bool {
        operation.status == .needsReconciliation
            || (operation.status == .executing && !operation.submittedIDs.isEmpty)
    }

    private func statusTitle(_ operation: PhotoDeletionOperationSnapshot) -> String {
        switch operation.status {
        case .prepared: "Prepared"
        case .executing: "Interrupted"
        case .needsReconciliation: "Needs outcome check"
        case .completed: "Completed"
        case .partial: "Partial"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    private func recoveryExplanation(_ operation: PhotoDeletionOperationSnapshot) -> String {
        switch operation.status {
        case .prepared: "No deletion was dispatched. This set must be confirmed again."
        case .executing: "Deletion was interrupted. Submitted members need a read-only outcome check."
        case .needsReconciliation: "Some outcomes are unknown or unresolved. Check Outcomes only."
        default: "Saved deletion outcomes are available for review."
        }
    }
}

/// The final, deliberately boring checkpoint before originals are deleted.
/// It renders the exact staged IDs, not a recomputed suggestion or a count.
struct CleanupReviewView: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel
    @State private var confirmationPresented = false
    @State private var accessSheetPresented = false

    private var model: ReviewModel? {
        guard let model = appModel.reviewModel, model.sessionID == sessionID else { return nil }
        return model
    }

    var body: some View {
        Group {
            if let model {
                content(model: model)
            } else {
                ProgressView("Loading cleanup review…")
            }
        }
        .navigationTitle("Cleanup Review")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete these exact photos?",
            isPresented: $confirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Photos", role: .destructive) {
                guard let model else { return }
                Task { await appModel.startDeletion(for: sessionID, stagedIDs: model.stagedCleanupIDs) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Photos require full access. Deleted items may remain in iCloud and Recently Deleted, "
                    + "and storage space may not be freed immediately. If this set changes, confirmation is invalid."
            )
        }
        .sheet(isPresented: $accessSheetPresented) {
            AccessGuidanceSheet()
        }
    }

    @ViewBuilder
    private func content(model: ReviewModel) -> some View {
        let staged = model.stagedCleanupIDs
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                exactSetHeader(count: staged.count)
                if staged.isEmpty {
                    ContentUnavailableView(
                        "Nothing staged for deletion",
                        systemImage: "checkmark.circle",
                        description: Text("Return to Review Photos to stage photos explicitly.")
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(staged, id: \.self) { id in
                            AsyncPhotoThumbnail(assetID: id, targetSizePixels: CGSize(width: 320, height: 320))
                                .frame(height: 150)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .accessibilityLabel("Staged photo")
                        }
                    }
                    warningCard
                    startButton(staged: staged)
                }
                if let operation = appModel.deletionOperation {
                    outcomeCard(operation)
                }
                if let error = appModel.deletionError {
                    errorCard(error)
                }
            }
            .padding()
        }
        .onChange(of: staged) { _, _ in
            // A changed exact set must be confirmed again, even if the old
            // confirmation sheet was already visible.
            confirmationPresented = false
        }
    }

    private func exactSetHeader(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Exact set")
                .font(.title2.bold())
            Text("\(count) photos staged for deletion")
                .font(.headline)
            Text("Nothing is deleted until you confirm this set.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var warningCard: some View {
        Label {
            Text(
                "Full Photos access is required. Items may remain in iCloud or Recently Deleted, "
                    + "and available space may update later."
            )
            .font(.footnote)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private func startButton(staged: [AssetID]) -> some View {
        Button {
            guard appModel.authorization == .authorized else {
                accessSheetPresented = true
                return
            }
            confirmationPresented = true
        } label: {
            HStack {
                if appModel.deletionFlight != nil {
                    ProgressView().tint(.white)
                }
                Text(appModel.deletionFlight == nil ? "Delete Staged Photos" : "Deleting…")
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(staged.isEmpty || appModel.deletionFlight != nil)
        .accessibilityHint("Deletes only the exact staged set after confirmation")
    }

    private func outcomeCard(_ operation: PhotoDeletionOperationSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Deletion outcomes").font(.headline)
            outcomeRow("Deleted", operation.deletedIDs.count, .green)
            outcomeRow("Failed", operation.failedIDs.count, .red)
            outcomeRow("Access unknown", operation.accessUnknownIDs.count, .orange)
            outcomeRow("Unresolved", operation.unresolvedIDs.count, .secondary)
            if !operation.accessUnknownIDs.isEmpty || !operation.unresolvedIDs.isEmpty {
                Button("Check Outcomes") {
                    Task { await appModel.checkDeletionOutcomes(operationID: operation.operationID) }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .disabled(appModel.deletionFlight != nil)
                Text("This checks the saved result only. It never retries deletion.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func outcomeRow(_ title: LocalizedStringKey, _ count: Int, _ color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
            Spacer()
            Text("\(count)").bold()
        }
        .frame(minHeight: 30)
    }

    private func errorCard(_ error: PhotoDeletionServiceError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(error == .fullReadWriteAccessRequired ? "Full Photos access is required to start deletion." :
                "Deletion could not be started.")
                .font(.footnote)
            if error == .fullReadWriteAccessRequired {
                Button("Fix Access") { accessSheetPresented = true }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}
