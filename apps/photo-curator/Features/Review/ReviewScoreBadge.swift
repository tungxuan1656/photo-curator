import SwiftUI

/// Fixed-height, non-interactive score footer for one visible review thumbnail.
/// The number and meter show the saved Technical score (sharpness + exposure),
/// not the final album decision or a confidence value.
struct ReviewScoreBadge: View {
    let assetID: AssetID
    let model: ReviewModel
    @State private var analysis: PhotoAnalysis?
    @State private var didLoadAnalysis = false

    var body: some View {
        Group {
            if let analysis {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Technical")
                        Spacer(minLength: 2)
                        Text("\(score(for: analysis))/100")
                            .monospacedDigit()
                    }
                    .font(.caption2.weight(.medium))

                    ProgressView(value: analysis.qualityScore)
                        .tint(.accentColor)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Technical score \(score(for: analysis)) out of 100")
            } else if didLoadAnalysis {
                Text("Analysis unavailable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Technical score unavailable")
            } else {
                Text("Loading score")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Loading technical score")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
        .padding(.horizontal, 4)
        .task(id: "\(model.sessionID.rawValue.uuidString)-\(assetID.rawValue)") {
            didLoadAnalysis = false
            analysis = nil
            analysis = await model.loadAnalysis(for: assetID)
            guard !Task.isCancelled else { return }
            didLoadAnalysis = true
        }
    }

    private func score(for analysis: PhotoAnalysis) -> Int {
        Int((analysis.qualityScore * 100).rounded())
    }
}
