import SwiftUI

/// S09 review overview: counts plus entries into all correction surfaces.
///
/// Reads the session-owned ReviewModel shared by every review surface.
/// The Similar entry hides when no group data exists (ux-flows §8.1).
/// Shows no raw scores, Vision terms, or deletion vocabulary.
struct ReviewOverview: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if let model = appModel.reviewModel, model.sessionID == sessionID {
                let total = model.result.selectedAssetIDs.count + model.result.rejectedAssetIDs.count
                VStack(spacing: 12) {
                    Text("Your curated album is ready").font(.title2.bold())
                    Text("\(model.selectedIDs.count) selected from \(total) photos")
                    Button("Review Selection") { appModel.path.append(.curatedGrid(sessionID: sessionID)) }
                        .buttonStyle(.borderedProminent)
                    if !model.similarGroups.isEmpty {
                        Button("Review Similar Photos") { appModel.path.append(.similarGroups(sessionID: sessionID)) }
                    }
                    Button("Review Removed") { appModel.path.append(.removedPhotos(sessionID: sessionID)) }
                    Button("Review & Save") { appModel.path.append(.finalReview(sessionID: sessionID)) }
                        .buttonStyle(.borderedProminent)
                }.padding()
            } else {
                ProgressView("Loading your selection…")
            }
        }
        .navigationTitle("Review")
    }
}

/// Recoverable result-load state for review routes without a matching model.
/// Never renders as an empty normal grid.
struct ReviewLoadFailedView: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 12) {
            Text("We couldn't load your selection.").font(.title2.bold())
            Text("Your progress is saved.").font(.footnote).foregroundStyle(.secondary)
            Button("Try Again") {
                Task { await appModel.beginReview(for: sessionID) }
            }
            .buttonStyle(.borderedProminent)
            Button("Back to Home") { appModel.goHome() }
        }
        .padding()
        .navigationTitle("Review")
    }
}
