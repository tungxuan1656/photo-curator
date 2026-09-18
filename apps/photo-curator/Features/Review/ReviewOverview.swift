import SwiftUI

/// S09 review overview: counts plus entries into all correction surfaces.
///
/// Reads the session-owned ReviewModel shared by every review surface.
/// The Similar entry hides when no group data exists (ux-flows §8.1).
/// Shows no raw scores, Vision terms, or deletion vocabulary.
struct ReviewOverview: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel
    @State private var confirmingDiscard = false

    var body: some View {
        Group {
            if let model = appModel.reviewModel, model.sessionID == sessionID {
                let total = model.result.selectedAssetIDs.count + model.result.rejectedAssetIDs.count
                // Persisted bucket first (survives relaunch); live progress only
                // fills the gap while the run's in-memory counter is fresh.
                let unavailable = max(
                    model.persistedUnavailableCount, appModel.processing.progress.unavailableCount
                )
                let topPickID = model.selectedAssetIDs.first

                ScrollView {
                    VStack(spacing: 20) {
                        if let topPickID {
                            ZStack(alignment: .bottomLeading) {
                                AsyncPhotoThumbnail(
                                    assetID: topPickID,
                                    targetSizePixels: CGSize(width: 600, height: 400)
                                )
                                .frame(height: 190)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .overlay(
                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.75)],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("CURATED ALBUM")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white.opacity(0.85))
                                    Text("Your curated album is ready")
                                        .font(.title3.bold())
                                        .foregroundStyle(.white)
                                    Text("\(model.selectedIDs.count) selected from \(total) photos")
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                .padding(16)
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                        } else {
                            VStack(spacing: 6) {
                                Text("Your curated album is ready")
                                    .font(.title2.bold())
                                Text("\(model.selectedIDs.count) selected from \(total) photos")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 8)
                        }

                        // Bento Stats Grid
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                            spacing: 10
                        ) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Curated", systemImage: "sparkles")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.accentColor)
                                Text("\(model.selectedIDs.count)")
                                    .font(.title2.bold())
                                Text("Best quality & moments")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                            VStack(alignment: .leading, spacing: 4) {
                                Label("Similar Groups", systemImage: "square.2.layers.3d")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.accentColor)
                                Text("\(model.similarGroups.count)")
                                    .font(.title2.bold())
                                Text(model.similarGroups.isEmpty ? "No duplicates found" : "Best picks chosen")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                            VStack(alignment: .leading, spacing: 4) {
                                Label("Removed", systemImage: "minus.circle")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Text("\(model.removedAssetIDs.count)")
                                    .font(.title2.bold())
                                Text("Can add back anytime")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                            VStack(alignment: .leading, spacing: 4) {
                                Label("Originals", systemImage: "lock.shield")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                Text("Safe")
                                    .font(.title2.bold())
                                Text("Never modified or deleted")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)

                        if unavailable > 0 {
                            Text("\(unavailable) photos were unavailable and could not be analyzed.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        }

                        // Action Queue
                        VStack(spacing: 10) {
                            Button {
                                if appModel.path.last != .curatedGrid(sessionID: sessionID) {
                                    appModel.path.append(.curatedGrid(sessionID: sessionID))
                                }
                            } label: {
                                HStack {
                                    Label("Review Selection", systemImage: "photo.on.rectangle.angled")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(.headline)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)

                            if !model.similarGroups.isEmpty {
                                Button {
                                    if appModel.path.last != .similarGroups(sessionID: sessionID) {
                                        appModel.path.append(.similarGroups(sessionID: sessionID))
                                    }
                                } label: {
                                    HStack {
                                        Label("Review Similar Photos", systemImage: "square.2.layers.3d")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }

                            if !model.needsReviewItems.isEmpty {
                                Button {
                                    if appModel.path.last != .needsReview(sessionID: sessionID) {
                                        appModel.path.append(.needsReview(sessionID: sessionID))
                                    }
                                } label: {
                                    HStack {
                                        Label("Needs Review", systemImage: "eye.trianglebadge.exclamationmark")
                                        Spacer()
                                        Text("\(model.needsReviewItems.count)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "chevron.right")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }
                            if !model.removedAssetIDs.isEmpty {
                                Button {
                                    if appModel.path.last != .removedPhotos(sessionID: sessionID) {
                                        appModel.path.append(.removedPhotos(sessionID: sessionID))
                                    }
                                } label: {
                                    HStack {
                                        Label("Review Removed", systemImage: "arrow.uturn.backward.circle")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }

                            Button("Discard Curation", role: .destructive) { confirmingDiscard = true }
                                .font(.subheadline)
                                .padding(.top, 4)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            } else {
                ProgressView("Loading your selection…")
            }
        }
        .navigationTitle("Review")
        .alert(
            "Discard this curation?",
            isPresented: $confirmingDiscard,
            actions: {
                Button("Keep Curation", role: .cancel) {}
                Button("Discard Curation", role: .destructive) { appModel.discardCuration() }
            },
            message: {
                Text("Your original photos will stay unchanged. The current analysis and selection will be removed.")
            }
        )
    }
}

/// Recoverable result-load state for review routes without a matching model.
/// Never renders as an empty normal grid.
struct ReviewLoadFailedView: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ErrorStateView(
            title: "We couldn't load your selection.",
            message: appModel.reviewLoadRetryFailed
                ? "That didn't work either. Your progress is saved — try again or go home."
                : "Your progress is saved.",
            primaryTitle: "Try Again",
            primary: { appModel.showReview(for: sessionID) },
            secondaryTitle: "Back to Home",
            secondary: { appModel.goHome() }
        )
        .navigationTitle("Review")
    }
}
