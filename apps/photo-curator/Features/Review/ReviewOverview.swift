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
                let unavailable = appModel.processing.progress.unavailableCount
                VStack(spacing: 12) {
                    Text("Your curated album is ready").font(.title2.bold())
                    Text("\(model.selectedIDs.count) selected from \(total) photos")
                    Text("\(model.removedAssetIDs.count) not selected · \(model.similarGroups.count) groups to review")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if unavailable > 0 {
                        Text("\(unavailable) photos were unavailable and could not be analyzed.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Review Selection") { appModel.path.append(.curatedGrid(sessionID: sessionID)) }
                        .buttonStyle(.borderedProminent)
                    if !model.similarGroups.isEmpty {
                        Button("Review Similar Photos") { appModel.path.append(.similarGroups(sessionID: sessionID)) }
                    }
                    Button("Review Removed") { appModel.path.append(.removedPhotos(sessionID: sessionID)) }
                    Button("Discard Curation", role: .destructive) { confirmingDiscard = true }
                }.padding()
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
            message: "Your progress is saved.",
            primaryTitle: "Try Again",
            primary: { appModel.showReview(for: sessionID) },
            secondaryTitle: "Back to Home",
            secondary: { appModel.goHome() }
        )
        .navigationTitle("Review")
    }
}
