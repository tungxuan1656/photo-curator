import SwiftUI

// swiftlint:disable type_body_length
/// Faceted discovery over the durable `LibraryQueryResultSnapshot` contract.
/// The view owns only query presentation and a frozen, non-mutating selection.
/// Parents provide query execution and all Photos/catalog side effects.
struct LibraryFacetedBrowsingView: View {
    let result: LibraryQueryResultSnapshot
    let observations: [CatalogAssetObservationSnapshot]
    let personalLabels: [CatalogPersonalLabelSnapshot]
    let onQueryChanged: (LibraryQuery) -> Void
    let onOpenPhoto: (AssetID, [AssetID]) -> Void
    let onOpenGroup: (LibraryQueryGroupContext) -> Void
    let onEditLabels: (AssetID) -> Void
    let onManagePersonalLabels: () -> Void
    let onSelectionChanged: (LibraryQuerySelectionSnapshot) -> Void

    @State private var mode: LibraryResultMode = .photos
    @State private var showingFilters = false
    @State private var query: LibraryQuery
    @State private var selection: LibrarySelectionState
    @State private var selectionInvalidated = false

    init(
        result: LibraryQueryResultSnapshot,
        observations: [CatalogAssetObservationSnapshot],
        personalLabels: [CatalogPersonalLabelSnapshot] = [],
        onQueryChanged: @escaping (LibraryQuery) -> Void,
        onOpenPhoto: @escaping (AssetID, [AssetID]) -> Void,
        onOpenGroup: @escaping (LibraryQueryGroupContext) -> Void,
        onEditLabels: @escaping (AssetID) -> Void,
        onManagePersonalLabels: @escaping () -> Void,
        onSelectionChanged: @escaping (LibraryQuerySelectionSnapshot) -> Void = { _ in }
    ) {
        self.result = result
        self.observations = observations
        self.personalLabels = personalLabels
        self.onQueryChanged = onQueryChanged
        self.onOpenPhoto = onOpenPhoto
        self.onOpenGroup = onOpenGroup
        self.onEditLabels = onEditLabels
        self.onManagePersonalLabels = onManagePersonalLabels
        self.onSelectionChanged = onSelectionChanged
        _query = State(initialValue: result.query)
        _selection = State(initialValue: LibrarySelectionState(snapshot: result.selection))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                activeFilters
                coverage
                modePicker
                if mode == .photos {
                    photoResults
                } else {
                    groupResults
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(LibraryCanvasBackground())
        .navigationTitle("library.browse.navigationTitle")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingFilters) {
            LibraryFilterSheet(
                query: query,
                counts: result.facetCounts,
                personalLabels: personalLabels,
                onApply: applyQuery,
                onManagePersonalLabels: onManagePersonalLabels
            )
        }
        .onChange(of: result.query) { _, newQuery in
            query = newQuery
            resetSelection(to: result.selection)
        }
        .onChange(of: result.snapshotID) { _, _ in
            guard result.query == query else { return }
            selectionInvalidated = selection.reconcile(
                with: result.selection,
                completeAssetIDs: result.completeAssetIDs
            )
            publishSelection()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("library.browse.title")
                        .font(.system(.largeTitle, design: .serif).weight(.medium))
                    Text(
                        "library.browse.subtitle"
                    )
                    .font(.body).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button { showingFilters = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.curatorAccent)
                .accessibilityLabel("library.browse.filter")
                .accessibilityHint("library.browse.filterHint")
            }
            if !query.filters.isEmpty {
                Text("library.browse.activeSummary")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.curatorAccent)
                    .accessibilityLabel("library.browse.activeSummaryAccessibility")
            }
        }
    }

    private var activeFilters: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(query.filters.isEmpty ? "library.browse.allPhotos" : "library.browse.activeFilters")
                    .font(.headline)
                Spacer()
                if !query.filters.isEmpty {
                    Button("library.browse.clearFilters") { applyQuery(LibraryQuery()) }
                        .font(.subheadline.weight(.semibold))
                }
            }
            if query.filters.isEmpty {
                Text("library.browse.noFilters")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(query.filters.flatMap { filter in
                        filter.labelIDs.map {
                            LibraryActiveFilter(facet: filter.facet, labelID: $0, personalLabelID: nil)
                        } + filter.personalLabelIDs.map {
                            LibraryActiveFilter(facet: filter.facet, labelID: nil, personalLabelID: $0)
                        }
                    }) { chip in
                        Button { remove(chip) } label: {
                            Label(
                                "\(chipName(chip)) · \(facetName(chip.facet))",
                                systemImage: "xmark.circle.fill"
                            )
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12).frame(minHeight: 44)
                            .background(Color.curatorAccent.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            Text(
                                String(
                                    localized: LocalizedStringResource(
                                        "library.browse.removeFilter",
                                        defaultValue: "Remove \(chipName(chip)) filter"
                                    )
                                )
                            )
                        )
                    }
                }
            }
        }
    }

    private var coverage: some View {
        let value = result.coverage
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: value.state == .complete ? "checkmark.seal.fill" : "waveform.path.ecg")
                .foregroundStyle(value.state == .complete ? Color.green : Color.curatorAccent)
            VStack(alignment: .leading, spacing: 4) {
                Text(value
                    .state == .complete ? "library.browse.coverageComplete" : "library.browse.coveragePartial")
                    .font(.subheadline.weight(.semibold))
                Text(
                    String(
                        localized: LocalizedStringResource(
                            "library.browse.coverageCounts",
                            defaultValue: "\(value.analyzedAssetCount) of \(value.totalAssetCount) accessible photos analyzed · \(result.completeAssetIDs.count) matching"
                        )
                    )
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(15).frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var modePicker: some View {
        Picker("library.browse.resultView", selection: $mode) {
            Text("library.browse.photos").tag(LibraryResultMode.photos)
            Text("library.browse.matchingGroups").tag(LibraryResultMode.groups)
        }
        .pickerStyle(.segmented)
        .accessibilityHint("library.browse.resultViewHint")
    }

    private var photoResults: some View {
        VStack(alignment: .leading, spacing: 14) {
            resultToolbar
            if result.pageAssetIDs.isEmpty {
                if result.coverage.state == .complete {
                    ContentUnavailableView(
                        "library.browse.noPhotoMatches",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("library.browse.noPhotoMatchesHint")
                    )
                } else {
                    ContentUnavailableView(
                        "library.browse.noAnalyzedMatches",
                        systemImage: "clock.badge.exclamationmark",
                        description: Text(
                            "library.browse.noAnalyzedMatchesHint"
                        )
                    )
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(
                        .flexible(),
                        spacing: 8
                    )],
                    spacing: 8
                ) {
                    ForEach(result.pageAssetIDs, id: \.self) { assetID in
                        LibrarySelectablePhotoCell(
                            assetID: assetID,
                            isSelected: selection.selectedAssetIDs.contains(assetID),
                            selecting: !selection.isEmpty,
                            onOpen: { onOpenPhoto(assetID, result.completeAssetIDs) },
                            onToggle: { toggle(assetID) },
                            onEditLabels: { onEditLabels(assetID) }
                        )
                    }
                }
            }
        }
    }

    private var groupResults: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("library.browse.matchingGroups").font(.title2.weight(.bold))
            if result.groups.isEmpty {
                ContentUnavailableView(
                    result.coverage.state == .complete
                        ? "library.browse.noSimilarGroups"
                        : "library.browse.noGroupsYet",
                    systemImage: result.coverage.state == .complete
                        ? "square.stack.3d.up.slash"
                        : "clock.badge.exclamationmark",
                    description: Text(
                        result.coverage.state == .complete
                            ? "library.browse.noSimilarGroupsHint"
                            : "library.browse.noGroupsYetHint"
                    )
                )
            } else {
                ForEach(result.groups, id: \.groupID) { group in
                    LibraryFilteredGroupCard(
                        group: group,
                        onOpen: { onOpenGroup(group) },
                        onOpenPhoto: { assetID in
                            onOpenPhoto(assetID, group.matchedAssetIDs + group.outsideFilterAssetIDs)
                        }
                    )
                }
            }
        }
    }

    private var resultToolbar: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(
                String(
                    localized: LocalizedStringResource(
                        "library.browse.matchingPhotos",
                        defaultValue: "\(result.completeAssetIDs.count) matching photos"
                    )
                )
            ).font(.title2.weight(.bold))
            Spacer()
            Button(selection.isEmpty ? "library.browse.selectPhotos" : "library.browse.deselectAll") {
                selection.apply(selection.isEmpty ? .selectAll : .clear, completeAssetIDs: result.completeAssetIDs)
                publishSelection()
            }
            .font(.subheadline.weight(.semibold))
            if selectionInvalidated {
                Text("library.browse.selectionCleared")
                    .font(.caption).foregroundStyle(.secondary)
                    .onAppear { selectionInvalidated = false }
            }
        }
    }

    private func applyQuery(_ newQuery: LibraryQuery) {
        query = newQuery
        selection.replace(with: result.selection)
        onQueryChanged(newQuery)
    }

    private func remove(_ chip: LibraryActiveFilter) {
        let filters = query.filters.compactMap { filter -> LibraryQueryFacetFilter? in
            guard filter.facet == chip.facet else { return filter }
            return LibraryQueryFacetFilter(
                facet: filter.facet,
                labelIDs: chip.labelID == nil ? filter.labelIDs : filter.labelIDs.filter { $0 != chip.labelID },
                personalLabelIDs: chip.personalLabelID == nil
                    ? filter.personalLabelIDs
                    : filter.personalLabelIDs.filter { $0 != chip.personalLabelID }
            )
        }
        applyQuery(LibraryQuery(filters: filters))
    }

    private func toggle(_ assetID: AssetID) {
        let action: LibraryQuerySelectionAction = selection.selectedAssetIDs
            .contains(assetID) ? .deselect([assetID]) : .select([assetID])
        selection.apply(action, completeAssetIDs: result.completeAssetIDs)
        publishSelection()
    }

    private func resetSelection(to snapshot: LibraryQuerySelectionSnapshot) {
        selection.replace(with: snapshot)
        publishSelection()
    }

    private func publishSelection() {
        onSelectionChanged(selection.snapshot)
    }

    private func labelName(_ labelID: PhotoLabelID) -> String {
        String(localized: localizedLabel(labelID))
    }

    private func chipName(_ chip: LibraryActiveFilter) -> String {
        if let labelID = chip.labelID {
            return labelName(labelID)
        }
        return personalLabels.first { $0.id == chip.personalLabelID }?.name
            ?? String(localized: "library.browse.personalLabel")
    }

    private func facetName(_ facet: PhotoLabelFacet) -> String {
        String(localized: localizedFacet(facet))
    }
}

// swiftlint:enable type_body_length

private enum LibraryResultMode: Hashable { case photos, groups }

private struct LibraryActiveFilter: Identifiable {
    let facet: PhotoLabelFacet
    let labelID: PhotoLabelID?
    let personalLabelID: UUID?
    var id: String {
        "\(facet.rawValue)-\(labelID?.rawValue ?? personalLabelID?.uuidString ?? "")"
    }
}

private struct LibrarySelectablePhotoCell: View {
    let assetID: AssetID
    let isSelected: Bool
    let selecting: Bool
    let onOpen: () -> Void
    let onToggle: () -> Void
    let onEditLabels: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) {
                AsyncPhotoThumbnail(assetID: assetID, targetSizePixels: CGSize(width: 480, height: 480))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text(
                    String(
                        localized: LocalizedStringResource(
                            "library.browse.photoAccessibility",
                            defaultValue: "Photo \(assetID.rawValue)"
                        )
                    )
                )
            )
            .accessibilityHint("library.browse.openPhotoHint")
            if selecting {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2).symbolRenderingMode(.palette)
                        .foregroundStyle(.white, isSelected ? Color.curatorAccent : Color.black.opacity(0.6))
                        .padding(8)
                }
                .accessibilityLabel(isSelected ? "library.browse.selectedPhoto" : "library.browse.selectPhoto")
                .frame(width: 50, height: 50)
            } else {
                Menu {
                    Button("library.browse.editLabels", action: onEditLabels)
                } label: {
                    Image(systemName: "ellipsis.circle.fill").font(.title3).foregroundStyle(.white).padding(8)
                }
                .accessibilityLabel("library.browse.photoActions")
            }
        }
    }
}

private struct LibraryFilteredGroupCard: View {
    let group: LibraryQueryGroupContext
    let onOpen: () -> Void
    let onOpenPhoto: (AssetID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Button(action: onOpen) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(group.relation == .retake ? "library.browse.retakes" : "library.browse.nearCopies")
                            .font(.headline)
                        Text(
                            String(
                                localized: LocalizedStringResource(
                                    "library.browse.groupMatchCounts",
                                    defaultValue: "\(group.matchedMemberCount) of \(group.totalMemberCount) photos match your filters"
                                )
                            )
                        )
                        .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(); Image(systemName: "arrow.up.right")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text(
                    String(
                        localized: LocalizedStringResource(
                            "library.browse.groupAccessibility",
                            defaultValue: "\(group.relation == .retake ? "Retakes" : "Near-copies"), \(group.matchedMemberCount) of \(group.totalMemberCount) photos match your filters"
                        )
                    )
                )
            )
            .accessibilityHint("library.browse.openCompleteGroupHint")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(group.matchedAssetIDs, id: \.self) { assetID in
                        Button { onOpenPhoto(assetID) } label: {
                            AsyncPhotoThumbnail(assetID: assetID, targetSizePixels: CGSize(width: 420, height: 420))
                                .frame(width: 116, height: 116).clipShape(RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                ))
                        }.buttonStyle(.plain).accessibilityLabel("library.browse.matchingPhoto")
                    }
                    ForEach(group.outsideFilterAssetIDs, id: \.self) { assetID in
                        Button { onOpenPhoto(assetID) } label: {
                            AsyncPhotoThumbnail(assetID: assetID, targetSizePixels: CGSize(width: 420, height: 420))
                                .frame(width: 116, height: 116).opacity(0.48)
                                .overlay(Text("library.browse.outsideFilters").font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(5).background(
                                        .black.opacity(0.58),
                                        in: Capsule()
                                    ))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }.buttonStyle(.plain).accessibilityLabel("library.browse.outsideFiltersAccessibility")
                    }
                }
            }
        }
        .padding(16).background(.background.opacity(0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.curatorAccent.opacity(0.16)))
    }
}
