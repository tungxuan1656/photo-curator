import SwiftUI

/// Needs Review queue (feat-026, S22): the bounded set of uncertain decisions
/// the user should look at first, with one actionable reason per photo.
///
/// Reads the session-owned ReviewModel queue (derived once at review entry).
/// Deterministic decisions keep S10/S12/S13; this surface only routes into
/// them. Empty queues render the same empty-state shape as S13 (never an
/// error). Copy avoids scores, Vision terms, and deletion vocabulary.
/// Destination selected by each S22 action. Detail stays a navigation destination;
/// collection actions append the existing review routes without touching selection.
enum NeedsReviewActionDestination: Equatable {
    case detail(assetID: AssetID, sessionID: SessionID, pagerIDs: [AssetID])
    case similar(sessionID: SessionID)
    case removed(sessionID: SessionID)

    init(item: NeedsReviewItem, sessionID: SessionID, pagerIDs: [AssetID]) {
        switch item.action {
        case .inspectDetail, .compareMoment:
            self = .detail(assetID: item.assetID, sessionID: sessionID, pagerIDs: pagerIDs)
        case .viewSimilar:
            self = .similar(sessionID: sessionID)
        case .considerAddBack:
            self = .removed(sessionID: sessionID)
        }
    }

    func apply(to path: inout [AppRoute]) {
        let route: AppRoute
        switch self {
        case .detail:
            return
        case let .similar(sessionID):
            route = .similarGroups(sessionID: sessionID)
        case let .removed(sessionID):
            route = .removedPhotos(sessionID: sessionID)
        }
        if path.last != route {
            path.append(route)
        }
    }
}

struct NeedsReview: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel
    @Environment(\.displayScale) private var displayScale

    private func thumbPixels(for width: CGFloat) -> CGSize {
        let side = (width / 3) * displayScale
        let clamped = min(max(side, 200), 500)
        return CGSize(width: clamped, height: clamped)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let model = appModel.reviewModel, model.sessionID == sessionID {
                    let items = model.needsReviewItems
                    if items.isEmpty {
                        VStack(spacing: 12) {
                            Text("Nothing needs review").font(.title2.bold())
                            Text("Every decision was clear. Your originals are unchanged.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button("Back to Review") { appModel.path.removeLast() }
                        }
                        .padding()
                    } else {
                        let resolved = model.resolvedUncertaintyCount()
                        VStack(spacing: 8) {
                            Text("A few photos could use your judgment. Your originals are unchanged.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            if resolved > 0 {
                                Text("\(resolved) of \(items.count) reviewed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ScrollView {
                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(items, id: \.assetID) { item in
                                        NeedsReviewCell(
                                            item: item,
                                            sessionID: sessionID,
                                            pagerIDs: items.map(\.assetID),
                                            targetSizePixels: thumbPixels(for: geometry.size.width)
                                        )
                                    }
                                }
                            }
                            Button("Back to Review") { appModel.path.removeLast() }
                                .padding(.vertical, 8)
                        }
                    }
                } else {
                    ProgressView("Loading your selection…")
                }
            }
        }
        .navigationTitle("Needs Review")
    }
}

private struct NeedsReviewCell: View {
    let item: NeedsReviewItem
    let sessionID: SessionID
    let pagerIDs: [AssetID]
    let targetSizePixels: CGSize
    @Environment(AppModel.self) private var appModel

    var body: some View {
        if let model = appModel.reviewModel, model.sessionID == sessionID {
            let destination = NeedsReviewActionDestination(
                item: item, sessionID: sessionID, pagerIDs: pagerIDs
            )
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    NavigationLink {
                        PhotoDetail(
                            assetID: item.assetID,
                            sessionID: sessionID,
                            pagerIDs: pagerIDs
                        )
                    } label: {
                        AsyncPhotoThumbnail(assetID: item.assetID, targetSizePixels: targetSizePixels)
                            .clipped()
                            .opacity(model.isSelected(item.assetID) ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    SelectionToggle(
                        isSelected: model.isSelected(item.assetID),
                        onToggle: { model.toggle(item.assetID) }
                    )
                }
                ReviewScoreBadge(assetID: item.assetID, model: model)
                Text(reasonText(for: item.reason))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Reason, \(reasonText(for: item.reason))")
                Text(suggestionState)
                    .font(.caption2.bold())
                    .foregroundStyle(suggestionAvailable ? Color.secondary : Color.orange)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Suggestion state, \(suggestionState)")
                if model.isUncertaintyResolved(item.assetID) {
                    Text("Reviewed")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Reviewed")
                } else {
                    switch destination {
                    case let .detail(assetID, targetSessionID, targetPagerIDs):
                        NavigationLink {
                            PhotoDetail(
                                assetID: assetID,
                                sessionID: targetSessionID,
                                pagerIDs: targetPagerIDs
                            )
                        } label: {
                            Text(actionText(for: item.action))
                        }
                        .font(.caption)
                        .accessibilityLabel(accessibilityText(for: item.action))
                    case .similar, .removed:
                        Button(actionText(for: item.action)) {
                            destination.apply(to: &appModel.path)
                        }
                        .font(.caption)
                        .accessibilityLabel(accessibilityText(for: item.action))
                    }
                }
            }
        }
    }

    private func reasonText(for reason: UncertaintyReason) -> LocalizedStringResource {
        switch reason {
        case .borderlineQuality:
            "Close to the quality floor — worth a look"
        case .faceTradeoff:
            "Group pick decided by face signals"
        case .similarAlternatives:
            "Similar photos were grouped — check the pick"
        case .secondMomentView:
            "A second view of this moment — keep both only if distinct"
        case .coverageCut:
            "Left out for variety — add back if it matters"
        }
    }

    private func actionText(for action: UncertaintyAction) -> LocalizedStringResource {
        switch action {
        case .inspectDetail:
            "Inspect"
        case .viewSimilar:
            "Compare similar"
        case .compareMoment:
            "Compare views"
        case .considerAddBack:
            "Add back"
        }
    }

    private func accessibilityText(for action: UncertaintyAction) -> LocalizedStringResource {
        switch action {
        case .inspectDetail:
            "Inspect photo"
        case .viewSimilar:
            "Compare similar photos"
        case .compareMoment:
            "Compare moment views"
        case .considerAddBack:
            "Add photo back to album"
        }
    }

    private var suggestionAvailable: Bool {
        suggestion != nil
    }

    private var suggestion: ReviewSuggestion? {
        guard let scopeID = appModel.reviewModel?.scopeID,
              let model = appModel.reviewModel,
              model.sessionID == sessionID else { return nil }
        return NativeReviewSuggestionAdapter.suggestions(
            scopeID: scopeID,
            result: model.result,
            groups: model.similarGroups
        ).first { $0.candidateIDs.contains(item.assetID) }
    }

    private var suggestionState: LocalizedStringResource {
        if suggestion != nil {
            return "Suggestion available — review the evidence"
        }
        return "No suggestion — not enough information"
    }
}
