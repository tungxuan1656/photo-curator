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
                                Button("Continue to Save") {
                                    if appModel.path.last != .finalReview(sessionID: sessionID) {
                                        appModel.path.append(.finalReview(sessionID: sessionID))
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.vertical)
                        }
                        .padding()
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
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        if let model = appModel.reviewModel, model.sessionID == sessionID {
            VStack(alignment: .leading, spacing: 8) {
                Text("Group \(index + 1) of \(total)").font(.headline)
                let selected = group.memberIDs.reduce(into: 0) { count, id in
                    if case .included = model.albumMembership(for: id) {
                        count += 1
                    }
                }
                let totalMember = group.memberIDs.count
                Text("\(selected) selected from \(totalMember) similar photos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(group.memberIDs, id: \.self) { id in
                        VStack(spacing: 4) {
                            let membership = model.albumMembership(for: id)
                            ZStack(alignment: .topTrailing) {
                                NavigationLink {
                                    PhotoDetail(
                                        assetID: id,
                                        sessionID: sessionID,
                                        pagerIDs: group.memberIDs
                                    )
                                } label: {
                                    AsyncPhotoThumbnail(assetID: id, targetSizePixels: targetSizePixels)
                                        .clipped()
                                        .opacity(isIncluded(membership) ? 1 : 0.35)
                                }
                                .buttonStyle(.plain)
                                SelectionToggle(
                                    isSelected: isIncluded(membership),
                                    onToggle: { model.toggle(id) }
                                )
                            }
                            ReviewScoreBadge(assetID: id, model: model)
                            let current = model.currentWinner(of: group)
                            if id == group.engineWinner {
                                Text("Recommended best pick").font(.caption).bold()
                                    .accessibilityLabel("Recommended best pick")
                            } else if id == current {
                                Text("Best pick").font(.caption).bold()
                                    .accessibilityLabel("Best pick")
                            }
                            Text(albumStateLabel(for: id, model: model))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if id != current {
                                Button("Choose as best pick") {
                                    model.selectWinner(id, in: group)
                                }
                                .font(.caption)
                            } else if !isIncluded(membership) {
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

    private func albumStateLabel(for id: AssetID, model: ReviewModel) -> LocalizedStringResource {
        switch model.albumMembership(for: id) {
        case .unset: "Not chosen for album"
        case .included: "In album"
        case .excluded: "Excluded from album"
        }
    }

    private func isIncluded(_ membership: AlbumMembership) -> Bool {
        if case .included = membership {
            return true
        }
        return false
    }
}
