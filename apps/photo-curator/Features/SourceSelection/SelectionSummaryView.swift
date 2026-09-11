import SwiftUI

struct SelectionSummaryView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Ready to curate \(appModel.summary.selectedCount) photos")
                .font(.title2)
            Text(
                "We'll group similar shots, evaluate photo quality, and build a smaller selection for you to review. "
                    + "Analysis happens on this iPhone. Some photos may need to download from iCloud. "
                    + "This may take a while for large libraries."
            )
            .font(.body)
            if appModel.summary.unavailableCount > 0 {
                Text("\(appModel.summary.unavailableCount) photos were unavailable and could not be analyzed.")
                    .font(.footnote)
            }
            Button("Start Curation") {
                appModel.startCuration()
            }
            .buttonStyle(.borderedProminent)
            .disabled(appModel.summary.selectedCount == 0)
            Button("Change Photos") { dismiss() }
        }
        .padding()
        .navigationTitle("Summary")
    }
}
