import SwiftUI

struct LibraryFilterSheet: View {
    let query: LibraryQuery
    let counts: [LibraryQueryFacetCount]
    let personalLabels: [CatalogPersonalLabelSnapshot]
    let onApply: (LibraryQuery) -> Void
    let onManagePersonalLabels: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LibraryQuery

    init(
        query: LibraryQuery,
        counts: [LibraryQueryFacetCount],
        personalLabels: [CatalogPersonalLabelSnapshot],
        onApply: @escaping (LibraryQuery) -> Void,
        onManagePersonalLabels: @escaping () -> Void
    ) {
        self.query = query
        self.counts = counts
        self.personalLabels = personalLabels
        self.onApply = onApply
        self.onManagePersonalLabels = onManagePersonalLabels
        _draft = State(initialValue: query)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    explanation
                    if draft.filters.isEmpty == false {
                        activeSummary
                    }
                    ForEach(PhotoLabelFacet.allCases.filter { $0 != .personal }, id: \.self) { facet in
                        facetSection(facet)
                    }
                    personalSection
                }
                .padding(20)
            }
            .background(LibraryCanvasBackground())
            .navigationTitle("library.filter.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("library.filter.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("library.filter.apply") {
                        onApply(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("library.filter.buildFocusedView").font(.system(.title, design: .serif).weight(.medium))
            Text("library.filter.combinationHelp")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var activeSummary: some View {
        Text("library.filter.activeSummary")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.curatorAccent)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.curatorAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func facetSection(_ facet: PhotoLabelFacet) -> some View {
        let definitions = PhotoLabelTaxonomy.supportedLabels.filter { $0.facet == facet }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(localizedFacet(facet)).font(.headline)
                Spacer()
                Text("library.filter.or").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
            Text("library.filter.matchAnyInCategory")
                .font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 1) {
                ForEach(definitions, id: \.id) { definition in
                    labelRow(definition.id, facet: facet)
                }
            }
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func labelRow(_ labelID: PhotoLabelID, facet: PhotoLabelFacet) -> some View {
        let selected = draft.filter(for: facet)?.labelIDs.contains(labelID) == true
        let count = counts.first { $0.facet == facet && $0.labelID == labelID }?.contextualMatchCount ?? 0
        return Button { toggle(labelID, facet: facet) } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(selected ? Color.curatorAccent : .secondary)
                Text(localizedLabel(labelID)).font(.body)
                Spacer()
                Text("\(count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                String(
                    localized: LocalizedStringResource(
                        "library.filter.labelAccessibility",
                        defaultValue: "\(String(localized: localizedLabel(labelID))), \(count) matching photos"
                    )
                )
            )
        )
        .accessibilityValue(selected ? "library.filter.selected" : "library.filter.notSelected")
        .accessibilityHint("library.filter.toggleHint")
    }

    private var personalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("library.filter.personalLabels").font(.headline)
                Spacer()
                Button("library.filter.manage") { onManagePersonalLabels() }
                    .font(.subheadline.weight(.semibold))
            }
            if personalLabels.isEmpty {
                Text("library.filter.personalHelp")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 1) {
                    ForEach(personalLabels) { label in
                        personalLabelRow(label)
                    }
                }
                .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(15)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func personalLabelRow(_ label: CatalogPersonalLabelSnapshot) -> some View {
        let selected = draft.filter(for: .personal)?.personalLabelIDs.contains(label.id) == true
        let count = counts.first { $0.facet == .personal && $0.personalLabelID == label.id }?.contextualMatchCount ?? 0
        return Button { togglePersonalLabel(label.id) } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(selected ? Color.curatorAccent : .secondary)
                Text(label.name)
                Spacer()
                Text("\(count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).frame(minHeight: 52)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                String(
                    localized: LocalizedStringResource(
                        "library.filter.personalLabelAccessibility",
                        defaultValue: "\(label.name), \(count) matching photos"
                    )
                )
            )
        )
        .accessibilityValue(selected ? "library.filter.selected" : "library.filter.notSelected")
        .accessibilityHint("library.filter.togglePersonalHint")
    }

    private func toggle(_ labelID: PhotoLabelID, facet: PhotoLabelFacet) {
        var labels = draft.filter(for: facet)?.labelIDs ?? []
        if labels.contains(labelID) {
            labels.removeAll { $0 == labelID }
        } else {
            labels.append(labelID)
        }
        let personal = draft.filter(for: facet)?.personalLabelIDs ?? []
        let filters = draft.filters
            .filter { $0.facet != facet } + (labels.isEmpty && personal.isEmpty ? [] : [LibraryQueryFacetFilter(
                facet: facet,
                labelIDs: labels,
                personalLabelIDs: personal
            )])
        draft = LibraryQuery(filters: filters, page: draft.page)
    }

    private func togglePersonalLabel(_ id: UUID) {
        let filter = draft.filter(for: .personal)
        var personal = filter?.personalLabelIDs ?? []
        if personal.contains(id) {
            personal.removeAll { $0 == id }
        } else {
            personal.append(id)
        }
        let filters = draft.filters.filter { $0.facet != .personal }
            + (personal.isEmpty ? [] : [LibraryQueryFacetFilter(facet: .personal, personalLabelIDs: personal)])
        draft = LibraryQuery(filters: filters, page: draft.page)
    }
}

func localizedFacet(_ facet: PhotoLabelFacet) -> LocalizedStringResource {
    switch facet {
    case .imageKind: "facet.imageKind"
    case .content: "facet.content"
    case .setting: "facet.setting"
    case .personal: "facet.personal"
    }
}

func localizedLabel(_ labelID: PhotoLabelID) -> LocalizedStringResource {
    switch labelID {
    case .people: "label.people"
    case .group: "label.group"
    case .landscape: "label.landscape"
    case .architecture: "label.architecture"
    case .food: "label.food"
    case .animal: "label.animal"
    case .indoor: "label.indoor"
    case .outdoor: "label.outdoor"
    case .document: "label.document"
    case .screenshot: "label.screenshot"
    }
}
