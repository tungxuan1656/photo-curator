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
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    private var thumbPixels: CGSize {
        let scale = UIScreen.main.scale
        let side = (UIScreen.main.bounds.width / 3) * scale
        let clamped = min(max(side, 200), 500)
        return CGSize(width: clamped, height: clamped)
    }

    var body: some View {
        Group {
            if let model = appModel.reviewModel, model.sessionID == sessionID {
                VStack {
                    Text("\(model.selectedIDs.count) selected").font(.headline)
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(model.curatedDisplayIDs, id: \.self) { id in
                                ReviewCell(
                                    assetID: id,
                                    isSelected: model.isSelected(id),
                                    targetSizePixels: thumbPixels,
                                    onToggle: { model.toggle(id) }
                                )
                            }
                        }
                    }
                    if model.lastRemovedID != nil {
                        Button("Undo") { model.undoLastRemoval() }
                    }
                }
                .navigationDestination(for: AssetID.self) { id in
                    PhotoDetail(assetID: id, sessionID: sessionID)
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
    let isSelected: Bool
    let targetSizePixels: CGSize
    let onToggle: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(value: assetID) {
                AsyncPhotoThumbnail(assetID: assetID, targetSizePixels: targetSizePixels)
                    .aspectRatio(1, contentMode: .fill)
                    .opacity(isSelected ? 1 : 0.35)
            }
            .buttonStyle(.plain)
            Button(isSelected ? "Remove from album" : "Add to album", action: onToggle)
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
                .accessibilityLabel(isSelected ? "Remove photo from album" : "Add photo to album")
        }
    }
}
