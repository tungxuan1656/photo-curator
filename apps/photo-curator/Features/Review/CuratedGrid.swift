import SwiftUI
import UIKit

/// S10 curated grid over the session ReviewModel.
///
/// Iterates `curatedDisplayIDs` (engine picks plus currently selected) so
/// removed items dim in place (never vanish or shift layout). Rejected
/// non-selected photos never enter this grid; they live on S13. The
/// thumbnail navigates to detail; the overlaid checkmark button toggles
/// inclusion without navigating. Cells receive only ID + selection state.
struct CuratedGrid: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    private var thumbPixels: CGSize {
        let scale = UIScreen.main.scale
        let side = (UIScreen.main.bounds.width / 3) * scale
        let clamped = min(max(side, 200), 500)
        return CGSize(width: clamped, height: clamped)
    }

    var body: some View {
        Group {
            if let model = appModel.reviewModel, model.sessionID == sessionID {
                VStack(spacing: 8) {
                    HStack {
                        Text("\(model.selectedIDs.count) selected")
                            .font(.headline)
                        Spacer()
                        Text("Tap circle to toggle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(model.curatedDisplayIDs, id: \.self) { id in
                                ReviewCell(
                                    assetID: id,
                                    sessionID: sessionID,
                                    pagerIDs: model.curatedDisplayIDs,
                                    isSelected: model.isSelected(id),
                                    targetSizePixels: thumbPixels,
                                    model: model,
                                    onToggle: { model.toggle(id) }
                                )
                            }
                        }

                        if model.curatedDisplayIDs.count < 15 {
                            VStack(spacing: 6) {
                                Image(systemName: "checkmark.shield")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text("Only selected photos will be saved to your new album.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text("Originals in your library stay completely unchanged.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                    }

                    if model.lastRemovedID != nil {
                        Button("Removed from album — Undo") { model.undoLastRemoval() }
                            .font(.subheadline)
                    }

                    Button("Continue to Save") {
                        if appModel.path.last != .finalReview(sessionID: sessionID) {
                            appModel.path.append(.finalReview(sessionID: sessionID))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            } else {
                ProgressView("Loading your selection…")
            }
        }
        .navigationTitle("Selection")
    }
}

private struct ReviewCell: View {
    let assetID: AssetID
    let sessionID: SessionID
    let pagerIDs: [AssetID]
    let isSelected: Bool
    let targetSizePixels: CGSize
    let model: ReviewModel
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                NavigationLink {
                    PhotoDetail(assetID: assetID, sessionID: sessionID, pagerIDs: pagerIDs)
                } label: {
                    AsyncPhotoThumbnail(assetID: assetID, targetSizePixels: targetSizePixels)
                        .clipped()
                        .opacity(isSelected ? 1 : 0.35)
                }
                .buttonStyle(.plain)
                SelectionToggle(isSelected: isSelected, onToggle: onToggle)
            }
            ReviewScoreBadge(assetID: assetID, model: model)
        }
        .clipped()
    }
}
