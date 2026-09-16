import SwiftUI

/// S21 explanation of one photo's locally cached analysis and original result.
/// It reads compact values only. The screen never reruns processing or changes
/// the user's current Selected/Removed state.
struct PhotoAnalysisDetail: View {
    let assetID: AssetID
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel
    @State private var analysis: PhotoAnalysis?
    @State private var didLoadAnalysis = false

    var body: some View {
        Group {
            if let model = appModel.reviewModel, model.sessionID == sessionID {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        AsyncPhotoThumbnail(
                            assetID: assetID,
                            targetSizePixels: CGSize(width: 1024, height: 1024)
                        )
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Photo being analyzed")

                        if let analysis {
                            AnalysisScoreCard(analysis: analysis)
                            AnalysisFactSection(title: "Technical details", facts: technicalFacts(for: analysis))

                            let people = peopleFacts(for: analysis)
                            if !people.isEmpty {
                                AnalysisFactSection(title: "People", facts: people)
                            }

                            let composition = compositionFacts(for: analysis)
                            if !composition.isEmpty {
                                AnalysisFactSection(title: "Composition", facts: composition)
                            }

                            AnalysisFactSection(title: "Content", facts: contentFacts(for: analysis))
                        } else if didLoadAnalysis {
                            ContentUnavailableView(
                                "Analysis unavailable",
                                systemImage: "chart.bar.xaxis",
                                description: Text("Detailed analysis is not available for this photo.")
                            )
                        } else {
                            ProgressView("Loading analysis…")
                                .frame(maxWidth: .infinity, minHeight: 120)
                        }

                        SelectionResultSection(
                            decision: model.decision(for: assetID),
                            isSelected: model.isSelected(assetID)
                        )
                    }
                    .padding()
                }
                .task(id: "\(sessionID.rawValue.uuidString)-\(assetID.rawValue)") {
                    didLoadAnalysis = false
                    analysis = nil
                    analysis = await model.loadAnalysis(for: assetID)
                    guard !Task.isCancelled else { return }
                    didLoadAnalysis = true
                }
            } else {
                ErrorStateView(
                    title: "We couldn't load this photo.",
                    message: "Your progress is saved.",
                    primaryTitle: "Back to Home",
                    primary: { appModel.goHome() }
                )
                .padding()
            }
        }
        .navigationTitle("Photo Analysis")
    }

    private func technicalFacts(for analysis: PhotoAnalysis) -> [AnalysisFact] {
        var facts = [AnalysisFact]()
        facts.append(AnalysisFact("Sharpness", score(analysis.technical.sharpnessScore)))
        facts.append(AnalysisFact("Exposure", score(analysis.technical.exposureScore)))
        facts.append(AnalysisFact("Resolution", score(analysis.technical.resolutionScore)))
        facts.append(AnalysisFact("Blur risk", risk(analysis.technical.blurProbability)))
        facts.append(AnalysisFact("Underexposure risk", risk(analysis.technical.underexposureProbability)))
        facts.append(AnalysisFact("Overexposure risk", risk(analysis.technical.overexposureProbability)))
        return facts
    }

    private func peopleFacts(for analysis: PhotoAnalysis) -> [AnalysisFact] {
        var facts = [AnalysisFact("People detected", "\(analysis.people.faceCount)")]
        if let groupScore = analysis.people.groupPhotoScore {
            facts.append(AnalysisFact("Group photo signal", score(groupScore)))
        } else {
            facts.append(AnalysisFact("Group photo signal", "Not analyzed"))
        }
        return facts
    }

    private func compositionFacts(for analysis: PhotoAnalysis) -> [AnalysisFact] {
        var facts = [AnalysisFact]()
        if let aestheticScore = analysis.composition.aestheticScore {
            facts.append(AnalysisFact("Aesthetic signal", score(aestheticScore)))
        } else {
            facts.append(AnalysisFact("Aesthetic signal", "Not analyzed"))
        }
        if let subjectPlacement = analysis.composition.subjectPlacementScore {
            facts.append(AnalysisFact("Subject placement", score(subjectPlacement)))
        } else {
            facts.append(AnalysisFact("Subject placement", "Not analyzed"))
        }
        if let horizonScore = analysis.composition.horizonScore {
            facts.append(AnalysisFact("Horizon", score(horizonScore)))
        } else {
            facts.append(AnalysisFact("Horizon", "Not analyzed"))
        }
        if let visualBalance = analysis.composition.visualBalanceScore {
            facts.append(AnalysisFact("Visual balance", score(visualBalance)))
        } else {
            facts.append(AnalysisFact("Visual balance", "Not analyzed"))
        }
        return facts
    }

    private func contentFacts(for analysis: PhotoAnalysis) -> [AnalysisFact] {
        var facts = [AnalysisFact("Scene", sceneName(analysis.content.sceneType))]
        if let hasText = analysis.content.hasText {
            facts.append(AnalysisFact("Text detected", hasText ? "Yes" : "No"))
        } else {
            facts.append(AnalysisFact("Text detected", "Not analyzed"))
        }
        if let screenshot = analysis.content.screenshotProbability {
            facts.append(AnalysisFact("Screenshot likelihood", risk(screenshot)))
        } else {
            facts.append(AnalysisFact("Screenshot likelihood", "Not analyzed"))
        }
        return facts
    }

    private func score(_ value: Double) -> String {
        "\(Int((value * 100).rounded())) / 100"
    }

    private func risk(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func sceneName(_ scene: SceneType) -> String {
        switch scene {
        case .people: "People"
        case .group: "Group"
        case .landscape: "Landscape"
        case .architecture: "Architecture"
        case .food: "Food"
        case .animal: "Animal"
        case .indoor: "Indoor"
        case .outdoor: "Outdoor"
        case .document: "Document"
        case .screenshot: "Screenshot"
        case .other: "Other"
        case .unknown: "Not classified"
        }
    }
}

private struct AnalysisScoreCard: View {
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

private struct AnalysisFact: Identifiable {
    let label: String
    let value: String

    var id: String {
        label
    }

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

private struct AnalysisFactSection: View {
    let title: String
    let facts: [AnalysisFact]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(facts) { fact in
                LabeledContent(fact.label) {
                    Text(fact.value)
                        .monospacedDigit()
                }
                .font(.body)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(fact.label), \(fact.value)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }
}

private struct SelectionResultSection: View {
    let decision: Decision?
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selection result")
                .font(.headline)
            LabeledContent("Current state") {
                Text(isSelected ? "Selected" : "Removed")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current state, \(isSelected ? "Selected" : "Removed")")
            if let decision {
                LabeledContent("Original result") {
                    Text(decision.status == .selected ? "Selected" : "Removed")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Original result, \(decision.status == .selected ? "Selected" : "Removed")"
                )
                if let score = decision.score {
                    LabeledContent("Selection score") {
                        Text("\(Int((score * 100).rounded())) / 100")
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Selection score, \(Int((score * 100).rounded())) out of 100")
                }
                ForEach(decision.reasons, id: \.self) { reason in
                    LabeledContent("Reason") {
                        Text(reasonText(for: reason))
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Reason, \(reasonText(for: reason))")
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

    private func reasonText(for reason: String) -> String {
        Self.reasonTextByCode[reason] ?? "A recorded selection rule applied"
    }

    private static let reasonTextByCode: [String: String] = {
        var textByCode: [String: String] = [:]
        textByCode["assetUnavailable"] = "Analysis was unavailable"
        textByCode["unsupportedAsset"] = "This item is not a supported photo"
        textByCode["corruptedAsset"] = "This photo could not be read"
        textByCode["severeBlur"] = "Technical quality was below the selection floor"
        textByCode["lowQuality"] = "Technical quality was below the selection floor"
        textByCode["severeUnderexposure"] = "The photo was too dark for the selection"
        textByCode["severeOverexposure"] = "The photo had too many bright areas"
        textByCode["accidentalFrame"] = "The photo looked accidental"
        textByCode["exactDuplicate"] = "An identical photo was preferred"
        textByCode["duplicateRepresentative"] = "This photo represents identical copies"
        textByCode["nearDuplicate"] = "A similar photo was preferred"
        textByCode["nearDuplicateRepresentative"] = "This photo represents similar photos"
        textByCode["burstRepresentative"] = "This photo represents a burst"
        textByCode["bestInMoment"] = "Best representative for this moment"
        textByCode["secondaryMomentRepresentative"] = "A distinct second view of this moment"
        textByCode["bestPortrait"] = "Preferred portrait in a similar group"
        textByCode["bestGroupPhoto"] = "Preferred group photo"
        textByCode["betterFaceQuality"] = "Stronger visible-face signal"
        textByCode["bestLandscape"] = "Preferred landscape view"
        textByCode["bestSceneRepresentative"] = "Preferred scene representative"
        textByCode["sceneDiversity"] = "Another scene added more variety"
        textByCode["peopleDiversity"] = "Other photos covered people more distinctly"
        textByCode["compositionDiversity"] = "Other photos added more composition variety"
        textByCode["temporalCoverage"] = "Other photos improved coverage of the session"
        textByCode["meaningfulVariation"] = "A different view added more information"
        textByCode["userSelected"] = "Added by your choice"
        textByCode["userExcluded"] = "Removed by your choice"
        textByCode["favoriteBoost"] = "Favorite status helped its rank"
        textByCode["editedVersionPreferred"] = "The edited version was preferred"
        return textByCode
    }()
}
