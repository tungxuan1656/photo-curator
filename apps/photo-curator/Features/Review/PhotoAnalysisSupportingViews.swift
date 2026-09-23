import SwiftUI

struct SuggestionEvidenceSection: View {
    let assetID: AssetID
    let model: ReviewModel

    private var suggestion: ReviewSuggestion? {
        guard let scopeID = model.scopeID else { return nil }
        return NativeReviewSuggestionAdapter.suggestions(
            scopeID: scopeID, result: model.result, groups: model.similarGroups
        ).first { $0.candidateIDs.contains(assetID) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggestion evidence")
                .font(.headline)
            if let suggestion {
                LabeledContent("Status") { Text(evidenceText(for: suggestion)) }
                LabeledContent("Source") { Text(provenanceText(for: suggestion)) }
                LabeledContent("Versions") {
                    Text("Analysis v\(suggestion.analysisVersion ?? 0) · Engine v\(suggestion.engineVersion)")
                }
                Text("This suggestion is advisory. You decide whether to use it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("No suggestion — not enough information")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                Text("The app abstained rather than making a choice without enough evidence.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    private func evidenceText(for suggestion: ReviewSuggestion) -> LocalizedStringResource {
        switch suggestion.evidence {
        case .available: "Evidence available"
        case .insufficient: "Not enough information for a suggestion"
        case .unavailable: "Analysis unavailable"
        }
    }

    private func provenanceText(for suggestion: ReviewSuggestion) -> LocalizedStringResource {
        switch suggestion.provenance {
        case .native: "Native analysis"
        case .legacyNativeAdapter: "Legacy native adapter"
        }
    }
}

struct AnalysisScoreCard: View {
    let analysis: PhotoAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Technical score")
                .font(.headline)
            Text("\(Int((analysis.qualityScore * 100).rounded())) / 100")
                .font(.largeTitle.bold())
                .monospacedDigit()
            ProgressView(value: analysis.qualityScore)
                .tint(.accentColor)
            Text("Combines sharpness and exposure. It helps compare photos, but it does not decide the album.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

struct AnalysisFact: Identifiable {
    let id: String
    let label: LocalizedStringResource
    let value: LocalizedStringResource
}

struct AnalysisFactSection: View {
    let title: LocalizedStringResource
    let facts: [AnalysisFact]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(facts) { fact in
                LabeledContent {
                    Text(fact.value)
                        .monospacedDigit()
                } label: {
                    Text(fact.label)
                }
                .font(.body)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }
}

struct SelectionResultSection: View {
    let decision: Decision?
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selection result")
                .font(.headline)
            LabeledContent("Current state") { Text(currentState) }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(currentStateAccessibilityLabel)
            if let decision {
                LabeledContent("Original result") { Text(originalState(for: decision)) }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(originalStateAccessibilityLabel(for: decision))
                if let score = decision.score {
                    LabeledContent("Selection score") {
                        Text("\(Int((score * 100).rounded())) / 100")
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Selection score, \(Int((score * 100).rounded())) out of 100")
                }
                ForEach(decision.reasons, id: \.self) { reason in
                    LabeledContent("Reason") { Text(reasonText(for: reason)) }
                        .multilineTextAlignment(.trailing)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(reasonText(for: reason))
                }
            } else {
                Text("The original automatic result is unavailable.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    private var currentState: LocalizedStringResource {
        isSelected ? "Selected" : "Removed"
    }

    private var currentStateAccessibilityLabel: LocalizedStringResource {
        isSelected ? "Current state, Selected" : "Current state, Removed"
    }

    private func originalState(for decision: Decision) -> LocalizedStringResource {
        decision.status == .selected ? "Selected" : "Removed"
    }

    private func originalStateAccessibilityLabel(for decision: Decision) -> LocalizedStringResource {
        decision.status == .selected ? "Original result, Selected" : "Original result, Removed"
    }

    private func reasonText(for reason: String) -> LocalizedStringResource {
        Self.reasonTextByCode[reason] ?? "A recorded selection rule applied"
    }

    // swiftlint:disable trailing_comma
    private static let reasonTextByCode: [String: LocalizedStringResource] = [
        "assetUnavailable": "Analysis was unavailable",
        "unsupportedAsset": "This item is not a supported photo",
        "corruptedAsset": "This photo could not be read",
        "severeBlur": "Technical quality was below the selection floor",
        "lowQuality": "Technical quality was below the selection floor",
        "severeUnderexposure": "The photo was too dark for the selection",
        "severeOverexposure": "The photo had too many bright areas",
        "accidentalFrame": "The photo looked accidental",
        "exactDuplicate": "An identical photo was preferred",
        "duplicateRepresentative": "This photo represents identical copies",
        "nearDuplicate": "A similar photo was preferred",
        "nearDuplicateRepresentative": "This photo represents similar photos",
        "burstRepresentative": "This photo represents a burst",
        "bestInMoment": "Best representative for this moment",
        "secondaryMomentRepresentative": "A distinct second view of this moment",
        "bestPortrait": "Preferred portrait in a similar group",
        "bestGroupPhoto": "Preferred group photo",
        "betterFaceQuality": "Stronger visible-face signal",
        "bestLandscape": "Preferred landscape view",
        "bestSceneRepresentative": "Preferred scene representative",
        "sceneDiversity": "Another scene added more variety",
        "peopleDiversity": "Other photos covered people more distinctly",
        "compositionDiversity": "Other photos added more composition variety",
        "temporalCoverage": "Other photos improved coverage of the session",
        "meaningfulVariation": "A different view added more information",
        "userSelected": "Added by your choice",
        "userExcluded": "Removed by your choice",
        "favoriteBoost": "Favorite status helped its rank",
        "editedVersionPreferred": "The edited version was preferred",
    ]
    // swiftlint:enable trailing_comma
}
