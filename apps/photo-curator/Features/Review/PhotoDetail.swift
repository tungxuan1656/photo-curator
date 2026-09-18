import CoreGraphics
import SwiftUI

/// S11 photo detail with a local pager over the review display order.
///
/// `pagerIDs` scopes Previous/Next to the entry grid: the S10 curated order,
/// the S13 removed order, or a single group on S12 — never the full result
/// set. Keeps only one bounded preview `CGImage` at a time and delegates all
/// selection changes to the shared `ReviewModel`.
struct PhotoDetail: View {
    let assetID: AssetID
    let sessionID: SessionID
    /// Scoped pager order from the entry grid (`[assetID]` freeforms to this).
    var pagerIDs: [AssetID]?
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentAssetID: AssetID
    @State private var cgImage: CGImage?
    @State private var inspectionState = PhotoInspectionState()
    @State private var loadFailed = false
    @State private var retryToken = 0
    @State private var beginFailed = false
    @State private var showingAnalysis = false

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
                    PhotoInspectionCanvas(
                        currentAssetID: currentAssetID,
                        image: cgImage,
                        inspectionState: $inspectionState,
                        isLoading: cgImage == nil && !loadFailed,
                        loadFailed: loadFailed,
                        position: index + 1,
                        total: order.count,
                        isSelected: model.isSelected(currentAssetID),
                        canGoPrevious: index > 0,
                        canGoNext: index < order.count - 1,
                        back: { dismiss() },
                        previous: {
                            guard index > 0 else { return }
                            currentAssetID = order[index - 1]
                        },
                        next: {
                            guard index < order.count - 1 else { return }
                            currentAssetID = order[index + 1]
                        },
                        toggleSelection: { model.toggle(currentAssetID) },
                        showAnalysis: { showingAnalysis = true },
                        retry: retryCurrentAsset
                    )
                    .task(id: "\(currentAssetID.rawValue)-\(retryToken)") {
                        let requested = currentAssetID
                        inspectionState.reset()
                        cgImage = nil
                        loadFailed = false
                        do {
                            try Task.checkCancellation()
                            let image = try await appModel.imageLoader.preview(
                                for: requested,
                                targetSize: CGSize(width: 2048, height: 2048)
                            )
                            try Task.checkCancellation()
                            guard requested == currentAssetID else { return }
                            cgImage = image
                        } catch {
                            guard !Task.isCancelled else { return }
                            guard requested == currentAssetID else { return }
                            if case SelectionError.cancelled = error {
                                return
                            }
                            cgImage = nil
                            loadFailed = true
                        }
                    }
                    .onChange(of: currentAssetID) {
                        inspectionState.reset()
                        loadFailed = false
                        cgImage = nil
                    }
                    .onDisappear {
                        cgImage = nil
                        inspectionState.reset()
                    }
                    .navigationDestination(isPresented: $showingAnalysis) {
                        PhotoAnalysisDetail(assetID: currentAssetID, sessionID: sessionID)
                    }
                } else {
                    ErrorStateView(
                        title: "We couldn't load this photo.",
                        message: "Your progress is saved.",
                        primaryTitle: "Back",
                        primary: { dismiss() }
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
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private func retryCurrentAsset() {
        inspectionState.reset()
        retryToken += 1
        loadFailed = false
        cgImage = nil
    }
}
