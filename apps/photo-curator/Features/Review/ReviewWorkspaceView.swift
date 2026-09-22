import SwiftUI

// swiftlint:disable file_length - shared workspace shell owns header/filter/grid/group/compare/tray in one file per feat-034 plan; split in feat-035+.

/// Shared photo-first workspace shell (feat-034 owner). One grouped review
/// surface for both Clean Up Photos and Build an Album: a compact
/// intent/progress/filter header, one grid, group cards, compare route, and a
/// selection-only action tray. Reads and writes the same four independent
/// dimensions through `ReviewModel`; views call coordinator/service intents
/// only, never PhotoKit, Vision, or model APIs directly.
struct ReviewWorkspaceView: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel
    @State private var filter: ReviewWorkspaceFilter = .all
    @State private var previewSuggestion: ReviewSuggestion?
    @State private var previewRevisionMismatch = false

    var body: some View {
        Group {
            if let model = appModel.reviewModel, model.sessionID == sessionID {
                workspaceContent(model: model)
            } else if appModel.container.workspaceAvailability == .unavailable {
                ReviewWorkspaceUnavailableView()
            } else {
                ProgressView("Restoring your workspace")
            }
        }
        .navigationTitle("Review Photos")
        .sheet(item: $previewSuggestion) { suggestion in
            if let model = appModel.reviewModel, model.sessionID == sessionID {
                SuggestionPreviewSheet(
                    suggestion: suggestion,
                    revisionMismatch: previewRevisionMismatch,
                    currentAlbum: { model.isSelected($0) ? .included : .excluded },
                    onUse: { appModel.reviewModel?.applySuggestion($0) ?? false },
                    onKeepMine: {}
                )
            }
        }
        .onAppear {
            // review-rules: grid visibility never marks progress.
            // Only opening in the detail surface marks `unseen` → `inProgress`.
        }
    }

    private func workspaceContent(model: ReviewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                workspaceHeader(model: model)
                filterBar
                if let saveError = model.saveError {
                    saveFailureCard(saveError: saveError, model: model)
                }
                switch filter {
                case .all:
                    ReviewGridSection(
                        sessionID: sessionID,
                        model: model,
                        previewSuggestion: $previewSuggestion,
                        previewRevisionMismatch: $previewRevisionMismatch
                    )
                case .needsReview:
                    ReviewNeedsSection(sessionID: sessionID, model: model)
                case .albumDraft:
                    ReviewAlbumDraftSection(sessionID: sessionID, model: model)
                case .staged:
                    ReviewStagedSection(sessionID: sessionID, model: model, filter: $filter)
                }
                ReviewActionTray(sessionID: sessionID, model: model)
            }
            .padding(.vertical)
        }
    }

    private func workspaceHeader(model: ReviewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reviewIntentTitle(model: model))
                .font(.title2.bold())
            Text("\(model.selectedAssetIDs.count) in album · \(model.resolvedUncertaintyCount()) reviewed")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("The app suggested this. You decide.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(reviewIntentTitle(model: model))
    }

    private func reviewIntentTitle(model: ReviewModel) -> LocalizedStringResource {
        switch appModel.reviewIntent(for: model.sessionID) {
        case .cleanup:
            "Clean Up Photos"
        case .album:
            "Review Photos"
        }
    }

    private var filterBar: some View {
        Picker("Review Photos", selection: $filter) {
            ForEach(ReviewWorkspaceFilter.allCases, id: \.self) { value in
                Text(value.title).tag(value)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .accessibilityLabel("Review Photos")
    }

    private func saveFailureCard(saveError: ReviewChoiceSaveError, model: ReviewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Couldn't save this change. Your previous choices are unchanged.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Retry") {
                    model.retrySaveError()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!model.canRetrySaveError)
                Button("Done") {
                    model.clearSaveError()
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Couldn't save this change. Your previous choices are unchanged.")
    }
}

private struct ReviewGridSection: View {
    let sessionID: SessionID
    let model: ReviewModel
    @Binding var previewSuggestion: ReviewSuggestion?
    @Binding var previewRevisionMismatch: Bool
    @Environment(AppModel.self) private var appModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(model.displayIDs, id: \.self) { id in
                ReviewWorkspaceCell(
                    assetID: id,
                    sessionID: sessionID,
                    pagerIDs: model.displayIDs,
                    model: model
                )
            }
        }
        .padding(.horizontal)
        if model.displayIDs.isEmpty {
            ContentUnavailableView(
                "Nothing needs review",
                systemImage: "photo.on.rectangle.angled",
                description: Text("Every decision was clear. Your originals are unchanged.")
            )
            .padding()
        }
        ReviewSuggestionSection(
            sessionID: sessionID,
            model: model,
            previewSuggestion: $previewSuggestion,
            previewRevisionMismatch: $previewRevisionMismatch
        )
        ReviewGroupSection(sessionID: sessionID, model: model)
    }
}

private struct ReviewNeedsSection: View {
    let sessionID: SessionID
    let model: ReviewModel

    var body: some View {
        if model.needsReviewItems.isEmpty {
            ContentUnavailableView(
                "Nothing needs review",
                systemImage: "checkmark.circle",
                description: Text("Every decision was clear. Your originals are unchanged.")
            )
            .padding()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Needs Review")
                    .font(.headline)
                    .padding(.horizontal)
                Text("\(model.resolvedUncertaintyCount()) of \(model.needsReviewItems.count) reviewed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                NeedsReview(sessionID: sessionID)
            }
        }
    }
}

private struct ReviewAlbumDraftSection: View {
    let sessionID: SessionID
    let model: ReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Album Draft")
                .font(.headline)
                .padding(.horizontal)
            if model.selectedAssetIDs.isEmpty {
                ContentUnavailableView(
                    "No photos in this album draft",
                    systemImage: "photo.stack",
                    description: Text("No photos in this album draft")
                )
                .padding()
            } else {
                CuratedGrid(sessionID: sessionID)
            }
        }
    }
}

private struct ReviewStagedSection: View {
    let sessionID: SessionID
    let model: ReviewModel
    @Binding var filter: ReviewWorkspaceFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Review Staged Photos")
                .font(.headline)
                .padding(.horizontal)
            let staged = model.stagedCleanupIDs
            if staged.isEmpty {
                Text("Nothing staged for deletion")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                Text("\(staged.count) staged for deletion. Originals stay until you confirm deletion.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                    ForEach(staged, id: \.self) { id in
                        ReviewWorkspaceCell(
                            assetID: id,
                            sessionID: sessionID,
                            pagerIDs: staged,
                            model: model
                        )
                    }
                }
                .padding(.horizontal)
                Button("Remove all from staged") {
                    model.unstageDeletion(staged)
                }
                .font(.subheadline)
                .padding(.horizontal)
            }
            Button("Back to All Photos") {
                filter = .all
            }
            .padding(.horizontal)
        }
    }
}

private struct ReviewGroupSection: View {
    let sessionID: SessionID
    let model: ReviewModel
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Similar Photos")
                .font(.headline)
                .padding(.horizontal)
            if model.similarGroups.isEmpty {
                Text("No comparable photos")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(Array(model.similarGroups.prefix(3).enumerated()), id: \.element.id) { index, group in
                    Text("Group \(index + 1) of \(model.similarGroups.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    SimilarGroupPreviewCard(group: group, sessionID: sessionID, model: model)
                }
                Button("Compare similar") {
                    if appModel.path.last != .similarGroups(sessionID: sessionID) {
                        appModel.path.append(.similarGroups(sessionID: sessionID))
                    }
                }
                .font(.subheadline)
                .padding(.horizontal)
            }
        }
    }
}

private struct SimilarGroupPreviewCard: View {
    let group: SimilarGroup
    let sessionID: SessionID
    let model: ReviewModel

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 4) {
                ForEach(group.memberIDs, id: \.self) { id in
                    NavigationLink {
                        PhotoDetail(assetID: id, sessionID: sessionID, pagerIDs: group.memberIDs)
                    } label: {
                        AsyncPhotoThumbnail(
                            assetID: id,
                            targetSizePixels: CGSize(width: 300, height: 300)
                        )
                        .frame(width: 96, height: 96)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .opacity(model.isSelected(id) ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(model.isSelected(id) ? "In album" : "Removed")
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct ReviewSuggestionSection: View {
    let sessionID: SessionID
    let model: ReviewModel
    @Binding var previewSuggestion: ReviewSuggestion?
    @Binding var previewRevisionMismatch: Bool

    private var suggestions: [ReviewSuggestion] {
        guard let scopeID = model.scopeID else { return [] }
        return NativeReviewSuggestionAdapter.suggestions(
            scopeID: scopeID, result: model.result, groups: model.similarGroups
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggestion available")
                .font(.headline)
                .padding(.horizontal)
            if suggestions.isEmpty {
                Text("Not enough information for a suggestion")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(suggestions.prefix(3)) { suggestion in
                    Button("Use Suggestion") {
                        // review-rules: a changed proposal needs a new
                        // preview. Recompute staleness from the live
                        // source revision instead of blindly clearing.
                        previewRevisionMismatch = model.isSuggestionStale(suggestion)
                        previewSuggestion = suggestion
                    }
                    .font(.subheadline)
                    .padding(.horizontal)
                }
            }
        }
    }
}

private struct SuggestionPreviewSheet: View {
    let suggestion: ReviewSuggestion
    let revisionMismatch: Bool
    let currentAlbum: (AssetID) -> AlbumMembership
    let onUse: (ReviewSuggestion) -> Bool
    let onKeepMine: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var applied = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Review Suggested Changes")
                    .font(.title2.bold())
                Text("The app suggested this. You decide.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if revisionMismatch {
                    Text("This suggestion changed. Review it again.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(suggestion.previewRows(currentAlbum: currentAlbum), id: \.id) { row in
                    Text("\(row.dimension): \(row.oldValue) → \(row.newValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if applied {
                    Text("Reviewed")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    Button("Apply These Changes") {
                        applied = onUse(suggestion)
                        if applied {
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!suggestion.canUse || revisionMismatch)
                    Button("Keep My Choice") {
                        onKeepMine()
                        dismiss()
                    }
                }
            }
            .padding()
            .navigationTitle("Review Suggested Changes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct ReviewActionTray: View {
    let sessionID: SessionID
    let model: ReviewModel
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 10) {
            Button("Continue to Save") {
                if appModel.path.last != .finalReview(sessionID: sessionID) {
                    appModel.path.append(.finalReview(sessionID: sessionID))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button("Mark All Reviewed") {
                model.markReviewed(model.displayIDs)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }
}

private struct ReviewWorkspaceCell: View {
    let assetID: AssetID
    let sessionID: SessionID
    let pagerIDs: [AssetID]
    let model: ReviewModel

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                NavigationLink {
                    PhotoDetail(assetID: assetID, sessionID: sessionID, pagerIDs: pagerIDs)
                } label: {
                    AsyncPhotoThumbnail(
                        assetID: assetID,
                        targetSizePixels: CGSize(width: 300, height: 300)
                    )
                    .clipped()
                    .opacity(model.isSelected(assetID) ? 1 : 0.35)
                }
                .buttonStyle(.plain)
                SelectionToggle(isSelected: model.isSelected(assetID), onToggle: { model.toggle(assetID) })
            }
            Text(model.isSelected(assetID) ? "In album" : "Removed")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.isSelected(assetID) ? "In album" : "Removed")
    }
}

private struct ReviewWorkspaceUnavailableView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ContentUnavailableView(
            "Couldn't open your saved workspace. Your stored data has been kept.",
            systemImage: "exclamationmark.triangle",
            description: Text("Couldn't open your saved workspace. Your stored data has been kept.")
        )
        .padding()
        Button("Done") {
            appModel.goHome()
        }
        .buttonStyle(.borderedProminent)
    }
}
