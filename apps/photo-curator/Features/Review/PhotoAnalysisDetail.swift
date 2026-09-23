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

                        SuggestionEvidenceSection(assetID: assetID, model: model)

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
        facts.append(AnalysisFact(
            id: "technical.sharpness",
            label: "Sharpness",
            value: score(analysis.technical.sharpnessScore)
        ))
        facts.append(AnalysisFact(
            id: "technical.exposure",
            label: "Exposure",
            value: score(analysis.technical.exposureScore)
        ))
        facts.append(AnalysisFact(
            id: "technical.resolution",
            label: "Resolution",
            value: score(analysis.technical.resolutionScore)
        ))
        facts.append(AnalysisFact(
            id: "technical.blurRisk",
            label: "Blur risk",
            value: risk(analysis.technical.blurProbability)
        ))
        facts.append(
            AnalysisFact(
                id: "technical.underexposureRisk",
                label: "Underexposure risk",
                value: risk(analysis.technical.underexposureProbability)
            )
        )
        facts.append(
            AnalysisFact(
                id: "technical.overexposureRisk",
                label: "Overexposure risk",
                value: risk(analysis.technical.overexposureProbability)
            )
        )
        return facts
    }

    private func peopleFacts(for analysis: PhotoAnalysis) -> [AnalysisFact] {
        var facts = [AnalysisFact]()
        facts.append(
            AnalysisFact(
                id: "people.faceCount",
                label: "People detected",
                value: "\(analysis.people.faceCount)"
            )
        )
        facts.append(
            analysisFact(
                id: "people.groupPhotoSignal",
                label: "Group photo signal",
                value: analysis.people.groupPhotoScore.map { score($0) }
            )
        )
        return facts
    }

    private func compositionFacts(for analysis: PhotoAnalysis) -> [AnalysisFact] {
        var facts = [AnalysisFact]()
        facts.append(
            analysisFact(
                id: "composition.aestheticSignal",
                label: "Aesthetic signal",
                value: analysis.composition.aestheticScore.map { score($0) }
            )
        )
        facts.append(
            analysisFact(
                id: "composition.subjectPlacement",
                label: "Subject placement",
                value: analysis.composition.subjectPlacementScore.map { score($0) }
            )
        )
        facts.append(
            analysisFact(
                id: "composition.horizon",
                label: "Horizon",
                value: analysis.composition.horizonScore.map { score($0) }
            )
        )
        facts.append(
            analysisFact(
                id: "composition.visualBalance",
                label: "Visual balance",
                value: analysis.composition.visualBalanceScore.map { score($0) }
            )
        )
        return facts
    }

    private func contentFacts(for analysis: PhotoAnalysis) -> [AnalysisFact] {
        var facts = [AnalysisFact]()
        facts.append(
            analysisFact(
                id: "content.scene",
                label: "Scene",
                value: sceneName(analysis.content.sceneType)
            )
        )
        facts.append(
            analysisFact(
                id: "content.textDetected",
                label: "Text detected",
                value: analysis.content.hasText.map { $0 ? "Yes" : "No" }
            )
        )
        facts.append(
            analysisFact(
                id: "content.screenshotLikelihood",
                label: "Screenshot likelihood",
                value: analysis.content.screenshotProbability.map { risk($0) }
            )
        )
        return facts
    }

    private func analysisFact(
        id: String,
        label: LocalizedStringResource,
        value: LocalizedStringResource?
    ) -> AnalysisFact {
        AnalysisFact(id: id, label: label, value: value ?? "Not analyzed")
    }

    private func score(_ value: Double) -> LocalizedStringResource {
        "\(Int((value * 100).rounded())) / 100"
    }

    private func risk(_ value: Double) -> LocalizedStringResource {
        "\(Int((value * 100).rounded()))%"
    }

    private func sceneName(_ scene: SceneType) -> LocalizedStringResource {
        Self.sceneNames[scene] ?? "Not classified"
    }

    // swiftlint:disable trailing_comma
    private static let sceneNames: [SceneType: LocalizedStringResource] = [
        .people: "People",
        .group: "Group",
        .landscape: "Landscape",
        .architecture: "Architecture",
        .food: "Food",
        .animal: "Animal",
        .indoor: "Indoor",
        .outdoor: "Outdoor",
        .document: "Document",
        .screenshot: "Screenshot",
        .other: "Other",
        .unknown: "Not classified",
    ]
    // swiftlint:enable trailing_comma
}
