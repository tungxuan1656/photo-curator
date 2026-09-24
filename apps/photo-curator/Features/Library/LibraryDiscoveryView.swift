import SwiftUI

/// Session-independent entry point for the catalog. It only renders immutable
/// snapshots and reports navigation through closures; it never selects, saves,
/// stages, or mutates Photos.
struct LibraryDiscoveryView: View {
    let snapshot: ComparisonSnapshot?
    let observations: [CatalogAssetObservationSnapshot]
    let catalogState: CatalogStateSnapshot
    let loadFailed: Bool
    let onRefresh: () async -> Void
    let onOpenGroup: (ComparisonGroupSnapshot) -> Void
    let onOpenPhoto: (AssetID, [AssetID]) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                intro

                catalogStatus

                if let snapshot {
                    coverageBanner(snapshot.coverage)

                    if snapshot.groups.isEmpty {
                        emptyGroups
                    } else {
                        groupSection(snapshot.groups)
                    }
                } else {
                    pendingGroups
                }

                allPhotosSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(LibraryCanvasBackground())
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await onRefresh() }
    }

    @ViewBuilder
    private var catalogStatus: some View {
        switch catalogState.availability {
        case .accessRequired:
            LibraryMessageCard(
                icon: "lock.shield",
                title: "Photos access is required",
                message: "Restore Photos access to browse the catalog."
            )
        case .unavailable where loadFailed:
            LibraryMessageCard(
                icon: "exclamationmark.triangle",
                title: "Library catalog unavailable",
                message: "The saved catalog could not be loaded. Pull to retry."
            )
        case .unavailable:
            LibraryMessageCard(
                icon: "clock",
                title: "Preparing your library",
                message: "Browse all accessible photos while the catalog becomes available."
            )
        case .stale:
            LibraryMessageCard(
                icon: "clock.badge.exclamationmark",
                title: "Showing the last library snapshot",
                message: "New Photos and relationships will appear after refresh."
            )
        default:
            EmptyView()
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your library, with the patterns surfaced.")
                .font(.system(.largeTitle, design: .serif).weight(.medium))
                .foregroundStyle(.primary)
            Text(
                // swiftlint:disable:next line_length
                "Start with groups of near-copies and retakes, then browse every accessible photo. Nothing changes in Photos while you look around."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func groupSection(_ groups: [ComparisonGroupSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("Similar groups", detail: Text("\(groups.count) groups"))
            LazyVStack(spacing: 14) {
                ForEach(groups, id: \.id) { group in
                    LibraryGroupCard(group: group, coverage: snapshot?.coverage, onOpen: {
                        onOpenGroup(group)
                    }, onOpenPhoto: { assetID in
                        onOpenPhoto(assetID, group.members.sorted { $0.ordinal < $1.ordinal }.map(\.assetID))
                    })
                }
            }
        }
    }

    private var allPhotosSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("All photos", detail: Text("\(observations.count) accessible"))
            if observations.isEmpty {
                ContentUnavailableView(
                    "No accessible photos",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Photos will appear here after library access and metadata loading.")
                )
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(
                        .flexible(),
                        spacing: 8
                    )],
                    spacing: 8
                ) {
                    ForEach(observations, id: \.asset.id) { observation in
                        Button {
                            onOpenPhoto(observation.asset.id, observations.map { $0.asset.id })
                        } label: {
                            AsyncPhotoThumbnail(
                                assetID: observation.asset.id,
                                targetSizePixels: CGSize(width: 360, height: 360)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(alignment: .bottomLeading) {
                                if observation.asset.isFavorite {
                                    Image(systemName: "heart.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(7)
                                        .background(.black.opacity(0.42), in: Circle())
                                        .padding(7)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Photo \(observation.asset.id.rawValue)")
                        .accessibilityHint("Opens photo inspection.")
                        .frame(minHeight: 44)
                    }
                }
            }
        }
    }

    private func sectionHeading(_ title: LocalizedStringResource, detail: Text) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title2.weight(.bold))
            Spacer()
            detail.font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func coverageBanner(_ coverage: ComparisonCoverage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: coverage.status == .complete ? "checkmark.seal.fill" : "waveform.path.ecg")
                .font(.title3)
                .foregroundStyle(coverage.status == .complete ? Color.green : Color.curatorAccent)
            VStack(alignment: .leading, spacing: 4) {
                Text(coverageTitle(for: coverage))
                    .font(.subheadline.weight(.semibold))
                coverageDetail(coverage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.25)))
        .accessibilityElement(children: .combine)
    }

    private func coverageDetail(_ coverage: ComparisonCoverage) -> Text {
        Text(
            "\(coverage.groupedAssetCount) photos in groups · \(coverage.unavailableAssetCount) unavailable · \(coverage.successfulComparisonCount) comparisons checked"
        )
    }

    private func coverageTitle(for coverage: ComparisonCoverage) -> LocalizedStringResource {
        coverage.status == .complete ? "Library patterns are up to date" : "Patterns are still filling in"
    }

    private var pendingGroups: some View {
        LibraryMessageCard(
            icon: "sparkles",
            title: "Finding similar groups",
            message: "You can browse all accessible photos while grouping finishes."
        )
    }

    private var emptyGroups: some View {
        LibraryMessageCard(
            icon: "square.stack.3d.up.slash",
            title: "No similar groups yet",
            message: "Groups appear when analyzed photos contain a retake or near-copy relationship."
        )
    }
}

private struct LibraryGroupCard: View {
    let group: ComparisonGroupSnapshot
    let coverage: ComparisonCoverage?
    let onOpen: () -> Void
    let onOpenPhoto: (AssetID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onOpen) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(localizedRelationTitle).font(.headline)
                        (Text("\(group.members.count) photos · ") + Text(localizedReasonTitle))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.subheadline.weight(.bold))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text(localizedRelationTitle)
                    + Text(", ")
                    + Text("\(group.members.count) photos")
            )
            .accessibilityHint("Opens group details.")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(group.members.sorted { $0.ordinal < $1.ordinal }, id: \.assetID) { member in
                        Button { onOpenPhoto(member.assetID) } label: {
                            AsyncPhotoThumbnail(
                                assetID: member.assetID,
                                targetSizePixels: CGSize(width: 420, height: 420)
                            )
                            .frame(width: 116, height: 116)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Group photo \(member.ordinal + 1) of \(group.members.count)")
                        .accessibilityHint("Opens photo inspection.")
                    }
                }
            }
            if let coverage, coverage.status != .complete {
                Label("Some relationships may still be missing", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background.opacity(0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.curatorAccent.opacity(0.16)))
    }

    private var localizedRelationTitle: LocalizedStringResource {
        group.relation == .retake ? "Retakes" : "Near-copies"
    }

    private var localizedReasonTitle: LocalizedStringResource {
        switch group.reason {
        case .imageSimilarity: "visual similarity"
        case .crossDateImageSimilarity: "similar across dates"
        case .sameCaptureImageSimilarity: "same capture"
        }
    }
}

private struct LibraryMessageCard: View {
    let icon: String
    let title: LocalizedStringResource
    let message: LocalizedStringResource

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.curatorAccent)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct LibraryCanvasBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.curatorAccent.opacity(0.08), Color.clear, Color.orange.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
