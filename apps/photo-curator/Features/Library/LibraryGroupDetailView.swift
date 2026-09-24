import SwiftUI

/// Detail for one immutable comparison group. Navigation and inspection are
/// delegated to the parent; this view intentionally has no session model.
struct LibraryGroupDetailView: View {
    let group: ComparisonGroupSnapshot
    let coverage: ComparisonCoverage
    let onOpenPhoto: (AssetID, [AssetID]) -> Void

    private var orderedMembers: [ComparisonMemberSnapshot] {
        group.members.sorted { $0.ordinal < $1.ordinal }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedRelationTitle).font(.system(.largeTitle, design: .serif).weight(.medium))
                    (Text("\(orderedMembers.count) photos · ") + Text(localizedReasonTitle))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if coverage.status != .complete {
                    Label(
                        // swiftlint:disable:next line_length
                        "This is a partial view of the library. More relationships may appear after analysis continues.",
                        systemImage: "clock.badge.exclamationmark"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .background(
                        Color.curatorAccent.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(orderedMembers, id: \.assetID) { member in
                        Button {
                            onOpenPhoto(member.assetID, orderedMembers.map(\.assetID))
                        } label: {
                            AsyncPhotoThumbnail(
                                assetID: member.assetID,
                                targetSizePixels: CGSize(width: 720, height: 720)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(alignment: .bottomLeading) {
                                Text("Photo \(member.ordinal + 1)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(.black.opacity(0.48), in: Capsule())
                                    .padding(10)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Photo \(member.ordinal + 1) of \(orderedMembers.count)")
                        .accessibilityHint("Opens zoomable photo inspection.")
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Why these are together").font(.headline)
                    (
                        Text("This group is based on ")
                            + Text(localizedReasonTitle)
                            +
                            Text(
                                // swiftlint:disable:next line_length
                                ". The comparison evidence is retained with this snapshot; no conclusion is added when evidence is unavailable."
                            )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .background(LibraryCanvasBackground())
        .navigationTitle("Group")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var localizedRelationTitle: LocalizedStringResource {
        group.relation == .retake ? "Retake set" : "Near-copy set"
    }

    private var localizedReasonTitle: LocalizedStringResource {
        switch group.reason {
        case .imageSimilarity: "visual similarity"
        case .crossDateImageSimilarity: "similar images captured on different dates"
        case .sameCaptureImageSimilarity: "similar images from the same capture"
        }
    }
}
