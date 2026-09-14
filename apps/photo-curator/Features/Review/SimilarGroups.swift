import SwiftUI
import UIKit

/// S12 similar-group review over `ReviewModel.similarGroups`.
///
/// Each group shows the engine winner as `Recommended best pick`, per-photo
/// included state, `N selected from M similar photos`, and `Group i of N`
/// progress. Tapping an alternative invokes the replacement mutation; the
/// checkmark toggles inclusion so deliberate multi-selects and remove-all
/// stay possible. Ends with `Similar photos reviewed` plus Back to Review.
struct SimilarGroups: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel

    private var thumbPixels: CGSize {
        let scale = UIScreen.main.scale
        let side = (UIScreen.main.bounds.width / 3) * scale
        let clamped = min(max(side, 200), 500)
        return CGSize(width: clamped, height: clamped)
    }

    var body: some View {
        Group {
            if let model = appModel.reviewModel, model.sessionID == sessionID {
                let groups = model.similarGroups
                if groups.isEmpty {
                    VStack(spacing: 12) {
                        Text("No similar groups to review").font(.title2.bold())
                        Button("Back to Review") { appModel.path.removeLast() }
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                                SimilarGroupCard(
                                    group: group,
                                    index: index,
                                    total: groups.count,
                                    sessionID: sessionID,
                                    targetSizePixels: thumbPixels
                                )
                            }
                            VStack(spacing: 12) {
                                Text("Similar photos reviewed").font(.headline)
                                Button("Back to Review") { appModel.path.removeLast() }
                            }
                            .padding(.vertical)
                        }
                        .padding()
                    }
                    .navigationDestination(for: AssetID.self) { id in
                        PhotoDetail(assetID: id, sessionID: sessionID)
                    }
                }
            } else {
                ProgressView("Loading your selection…")
            }
        }
        .navigationTitle("Similar Photos")
    }
}

private struct SimilarGroupCard: View {
    let group: SimilarGroup
    let index: Int
    let total: Int
    let sessionID: SessionID
    let targetSizePixels: CGSize
    @Environment(AppModel.self) private var appModel
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        if let model = appModel.reviewModel, model.sessionID == sessionID {
            VStack(alignment: .leading, spacing: 8) {
                Text("Group \(index + 1) of \(total)").font(.headline)
                let selected = group.selectedCount(in: model.selectedIDs)
                Text("\(selected) selected from \(group.memberIDs.count) similar photos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(group.memberIDs, id: \.self) { id in
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                NavigationLink(value: id) {
                                    AsyncPhotoThumbnail(assetID: id, targetSizePixels: targetSizePixels)
                                        .aspectRatio(1, contentMode: .fill)
                                        .opacity(model.isSelected(id) ? 1 : 0.35)
                                }
                                .buttonStyle(.plain)
                                Button(model.isSelected(id) ? "Remove from album" : "Add to album") {
                                    model.toggle(id)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(model.isSelected(id) ? "Remove photo" : "Add photo")
                            }
                            let current = model.currentWinner(of: group)
                            if id == group.engineWinner {
                                Text("Recommended best pick").font(.caption).bold()
                            } else if id == current {
                                Text("Best pick").font(.caption).bold()
                            }
                            Text(model.isSelected(id) ? "In album" : "Removed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if id != current {
                                Button("Choose as best pick") {
                                    model.selectWinner(id, in: group)
                                }
                                .font(.caption)
                            } else if !model.isSelected(id) {
                                Button("Keep Best Pick") {
                                    model.selectWinner(id, in: group)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
        }
    }
}
