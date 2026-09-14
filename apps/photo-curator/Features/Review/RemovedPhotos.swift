import SwiftUI
import UIKit

/// S13 removed photos: every photo left out of the album, with add-back.
///
/// Lazy thumbnails over `ReviewModel.removedAssetIDs`; `Add` restores
/// immediately via the shared model (count updates at once, grid position
/// kept). A failed thumbnail is a neutral placeholder (never a blocked
/// grid). Uses removed/add-back copy, never deletion vocabulary.
struct RemovedPhotos: View {
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
                let removed = model.removedAssetIDs
                if removed.isEmpty {
                    VStack(spacing: 12) {
                        Text("Nothing removed").font(.title2.bold())
                        Text("Every photo is in your curated album.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Back to Review") { appModel.path.removeLast() }
                    }
                    .padding()
                } else {
                    VStack {
                        Text("These photos are not in your curated album. Your originals are unchanged.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(removed, id: \.self) { id in
                                    VStack(spacing: 4) {
                                        NavigationLink(value: id) {
                                            AsyncPhotoThumbnail(assetID: id, targetSizePixels: thumbPixels)
                                                .aspectRatio(1, contentMode: .fill)
                                        }
                                        .buttonStyle(.plain)
                                        Button("Add") { model.restore(id) }
                                            .font(.caption)
                                            .accessibilityLabel("Add photo to album")
                                    }
                                }
                            }
                        }
                        Button("Back to Review") { appModel.path.removeLast() }
                            .padding(.vertical, 8)
                    }
                    .navigationDestination(for: AssetID.self) { id in
                        PhotoDetail(assetID: id, sessionID: sessionID)
                    }
                }
            } else {
                ProgressView("Loading your selection…")
            }
        }
        .navigationTitle("Removed Photos")
    }
}
