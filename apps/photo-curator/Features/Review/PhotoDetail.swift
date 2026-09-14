import CoreGraphics
import SwiftUI

/// S11 photo detail with a local pager over the review display order.
///
/// Keeps only one bounded preview `CGImage` at a time (cleared on ID change
/// and disappearance; neutral placeholder on failure). Previous/next moves
/// within `ReviewModel.displayIDs` without touching global navigation. The
/// toggle mutates only ReviewModel; no scores, trash icon, custom gestures,
/// persistence, or engine rerun.
struct PhotoDetail: View {
    let assetID: AssetID
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel
    @State private var currentAssetID: AssetID
    @State private var cgImage: CGImage?
    @State private var beginFailed = false

    init(assetID: AssetID, sessionID: SessionID) {
        self.assetID = assetID
        self.sessionID = sessionID
        _currentAssetID = State(initialValue: assetID)
    }

    var body: some View {
        Group {
            if let model = appModel.reviewModel, model.sessionID == sessionID {
                if let index = model.displayIDs.firstIndex(of: currentAssetID) {
                    VStack(spacing: 12) {
                        Group {
                            if let cgImage {
                                Image(decorative: cgImage, scale: 1, orientation: .up)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Rectangle().fill(.quaternary)
                                    .frame(minHeight: 200)
                            }
                        }
                        .accessibilityLabel(model.isSelected(currentAssetID) ? "Photo, in album" : "Photo, removed")
                        Button(model.isSelected(currentAssetID) ? "In Album" : "Removed") {
                            model.toggle(currentAssetID)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityValue(model.isSelected(currentAssetID) ? "In album" : "Removed")
                        HStack {
                            Button("Previous") { currentAssetID = model.displayIDs[max(0, index - 1)] }
                                .disabled(index == 0)
                            Button("Next") {
                                currentAssetID = model.displayIDs[min(model.displayIDs.count - 1, index + 1)]
                            }
                            .disabled(index == model.displayIDs.count - 1)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Photo \(index + 1) of \(model.displayIDs.count)")
                        if let date = model.sourceByID[currentAssetID]?.creationDate {
                            Text(date, style: .date).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .task(id: currentAssetID) {
                        let requested = currentAssetID
                        cgImage = nil
                        do {
                            let image = try await appModel.imageLoader.preview(
                                for: requested,
                                targetSize: CGSize(width: 2048, height: 2048)
                            )
                            // A cancelled predecessor must never overwrite the
                            // successor: apply only when still on the same photo.
                            guard requested == currentAssetID else { return }
                            cgImage = image
                        } catch {
                            guard requested == currentAssetID else { return }
                            cgImage = nil
                        }
                    }
                    .onDisappear {
                        cgImage = nil
                    }
                } else {
                    ProgressView("Loading photo…")
                }
            } else {
                ErrorStateView(
                    title: "We couldn't load this photo.",
                    message: beginFailed
                        ? "Reload didn't work. Your progress is saved."
                        : "Your progress is saved.",
                    primaryTitle: "Try Again",
                    primary: {
                        Task {
                            beginFailed = false
                            beginFailed = await !appModel.beginReview(for: sessionID)
                        }
                    },
                    secondaryTitle: "Back to Home",
                    secondary: { appModel.goHome() }
                )
                .padding()
            }
        }
        .navigationTitle("Photo")
    }
}
