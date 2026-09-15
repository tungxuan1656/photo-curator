import CoreGraphics
import SwiftUI

/// S11 photo detail with a local pager over the review display order.
///
/// `pagerIDs` scopes Previous/Next to the entry grid: the S10 curated order,
/// the S13 removed order, or a single group on S12 — never the full result
/// set. Keeps only one bounded preview `CGImage` at a time (cleared on ID
/// change and disappearance; neutral placeholder on failure). The toggle
/// mutates only ReviewModel; no scores, trash icon, custom gestures,
/// persistence, or engine rerun.
struct PhotoDetail: View {
    let assetID: AssetID
    let sessionID: SessionID
    /// Scoped pager order from the entry grid (`[assetID]` freeforms to this).
    var pagerIDs: [AssetID]?
    @Environment(AppModel.self) private var appModel
    @State private var currentAssetID: AssetID
    @State private var loadFailed = false
    @State private var retryToken = 0
    @State private var beginFailed = false
    init(assetID: AssetID, sessionID: SessionID, pagerIDs: [AssetID]? = nil) {
        self.assetID = assetID
        self.sessionID = sessionID
        self.pagerIDs = pagerIDs
        _currentAssetID = State(initialValue: assetID)
    }

    var body: some View {
        Group {
            if let model = appModel.reviewModel, model.sessionID == sessionID {
                let order = pagerIDs ?? [currentAssetID]
                if let index = order.firstIndex(of: currentAssetID) {
                    VStack(spacing: 12) {
                        Group {
                            if let cgImage {
                                Image(decorative: cgImage, scale: 1, orientation: .up)
                                    .resizable()
                                    .scaledToFit()
                            } else if loadFailed {
                                ErrorStateView(
                                    title: "We couldn't load this photo.",
                                    message: "Your progress is saved.",
                                    primaryTitle: "Try Again",
                                    primary: { retryToken += 1; loadFailed = false; cgImage = nil },
                                    secondaryTitle: "Back",
                                    secondary: { appModel.path.removeLast() }
                                )
                            } else {
                                Rectangle().fill(.quaternary)
                                    .frame(minHeight: 200)
                            }
                        }
                        .accessibilityLabel(
                            "Photo \(index + 1) of \(order.count), \(model.isSelected(currentAssetID) ? "selected" : "removed")"
                        )
                        Button(model.isSelected(currentAssetID) ? "In Album" : "Removed") {
                            model.toggle(currentAssetID)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityValue(model.isSelected(currentAssetID) ? "In album" : "Removed")
                        HStack {
                            Button("Previous") { currentAssetID = order[max(0, index - 1)] }
                                .disabled(index == 0)
                            Button("Next") {
                                currentAssetID = order[min(order.count - 1, index + 1)]
                            }
                            .disabled(index == order.count - 1)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Photo \(index + 1) of \(order.count)")
                        if let date = model.sourceByID[currentAssetID]?.creationDate {
                            Text(date, style: .date).font(.footnote).foregroundStyle(.secondary)
                                .accessibilityLabel(Text(date, style: .date))
                        }
                    }
                    .padding()
                    .task(id: "\(currentAssetID.rawValue)-\(retryToken)") {
                        let requested = currentAssetID
                        cgImage = nil
                        loadFailed = false
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
                            loadFailed = true
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 40, coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.width < -40 {
                                    currentAssetID = order[min(order.count - 1, index + 1)]
                                } else if value.translation.width > 40 {
                                    currentAssetID = order[max(0, index - 1)]
                                }
                            }
                    )
                    .onDisappear {
                        cgImage = nil
                    }
                } else {
                    ErrorStateView(
                        title: "We couldn't load this photo.",
                        message: "Your progress is saved.",
                        primaryTitle: "Back",
                        primary: { appModel.path.removeLast() }
                    )
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
