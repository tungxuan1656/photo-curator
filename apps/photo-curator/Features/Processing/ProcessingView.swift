import SwiftUI

/// S07 processing screen. Reads the live run via `AppModel.processing` and
/// calls ONLY AppModel intents — never the coordinator directly. The explicit
/// Continue-to-Review button calls `showReview(for:)`; there is no
/// auto-routing (feat-012 owns automatic result-present routing).
struct ProcessingView: View {
    @Environment(AppModel.self) private var appModel
    @State private var confirmingDiscard = false

    var body: some View {
        Group {
            switch appModel.processing.state {
            case .idle, .preparing:
                ProgressView("Preparing photos")
            case let .running(progress):
                VStack(spacing: 16) {
                    Text("Curating your photos").font(.title2.bold())
                    Text(progress.stage.userPhase).font(.headline)
                    if progress.totalUnits > 0 {
                        ProgressView(value: progress.overallFraction)
                        Text("\(progress.analyzedCount) of \(progress.totalUnits) analyzed")
                            .font(.subheadline).monospacedDigit()
                    } else {
                        ProgressView().accessibilityLabel("Working") // indeterminate: loading/select/final
                    }
                    if progress.downloadingCount > 0 {
                        Text("Waiting for \(progress.downloadingCount) photos from iCloud")
                            .font(.subheadline)
                        Text("Keep this iPhone connected to the internet.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if progress.unavailableCount > 0 {
                        Text("\(progress.unavailableCount) photos were unavailable and could not be analyzed.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Text("You can leave this screen. We'll keep your progress and resume if needed.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Stop Processing") { appModel.cancelProcessing() }
                    Button("Discard Curation", role: .destructive) { confirmingDiscard = true }
                }.padding()
            case let .completed(id, analyzed, unavailable):
                VStack(spacing: 12) {
                    Text("Analysis complete").font(.title2.bold())
                    Text("\(analyzed) photos analyzed")
                    if unavailable > 0 {
                        Text("\(unavailable) photos were unavailable and could not be analyzed.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Continue to Review") { appModel.showReview(for: id) }
                }.padding()
            case let .failed(error):
                AttentionView(error: error)
            case .cancelled:
                VStack(spacing: 12) {
                    Text("Processing stopped. Your progress is saved.")
                    Button("Resume Processing") { appModel.retryProcessing() }
                    Button("Return Home") { appModel.goHome() }
                }.padding()
            case .cancelling:
                ProgressView("Stopping…")
            case let .paused(reason):
                VStack(spacing: 12) {
                    Text(reason)
                    Button("Resume Processing") { appModel.retryProcessing() }
                    Button("Return Home") { appModel.goHome() }
                }.padding()
            }
        }
        .navigationTitle("Curating")
        .navigationBarBackButtonHidden(true)
        .alert(
            "Discard this curation?",
            isPresented: $confirmingDiscard,
            actions: {
                Button("Keep Curation", role: .cancel) {}
                Button("Discard Curation", role: .destructive) { appModel.discardCuration() }
            },
            message: {
                Text("Your original photos will stay unchanged. The current analysis and selection will be removed.")
            }
        )
    }
}

/// S08 attention screen. Typed recovery mapping only (5 RecoveryActions, real
/// actions, no string dispatch, no error codes in copy).
struct AttentionView: View {
    let error: UserFacingError
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ErrorStateView(
            title: error.title,
            message: error.message,
            primaryTitle: label(for: error.primary),
            primary: { perform(error.primary) },
            secondaryTitle: label(for: error.secondary),
            secondary: { perform(error.secondary) }
        )
    }

    private func label(for action: RecoveryAction) -> String {
        switch action {
        case .retry: return "Try Again"
        case .openSettings: return "Open Settings"
        case .continueWithoutUnavailable: return "Continue Without Them"
        case .discard: return "Discard Curation"
        case .goHome: return "Return Home"
        }
    }

    private func perform(_ action: RecoveryAction) {
        switch action {
        case .retry: appModel.retryProcessing()
        case .openSettings: appModel.openSettingsURL()
        case .continueWithoutUnavailable:
            Task { await appModel.continueWithoutUnavailable() }
        case .discard: appModel.discardCuration()
        case .goHome: appModel.goHome()
        }
    }
}

/// Review-ready transition/count screen ONLY. Loads the persisted
/// SelectionResult via `appModel.loadResult` (checkpointStore seam); shows the
/// selected count + unavailable line + Continue guarded until the result is
/// present. Full grid/detail/groups arrive in feat-009 and reuse
/// AppRoute.reviewReady unchanged.
struct ReviewReadyView: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel
    @State private var result: SelectionResult?
    @State private var didLoad = false
    @State private var beginFailed = false
    var body: some View {
        Group {
            if let result, result.selectedAssetIDs.isEmpty {
                ErrorStateView(
                    title: "We couldn't build a selection",
                    message: "Try processing this set again or choose different photos.",
                    primaryTitle: "Try Again",
                    primary: { appModel.retryProcessing() },
                    secondaryTitle: "Choose Different Photos",
                    secondary: { appModel.goHome() }
                )
            } else if let result {
                let total = result.selectedAssetIDs.count + result.rejectedAssetIDs.count
                VStack(spacing: 12) {
                    Text("Your curated album is ready").font(.title2.bold())
                    Text("\(result.selectedAssetIDs.count) selected from \(total) photos")
                    if unavailable > 0 {
                        Text("\(unavailable) photos were unavailable and could not be analyzed.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if beginFailed {
                        Text("We couldn't open your selection. Try again.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Continue") {
                        Task {
                            beginFailed = false
                            beginFailed = await !appModel.beginReview(for: sessionID)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }.padding()
            } else if didLoad {
                ErrorStateView(
                    title: "We couldn't load your selection.",
                    message: "Your progress is saved.",
                    primaryTitle: "Try Again",
                    primary: {
                        // Retry-from-checkpoint: resume via the pipeline resume
                        // path (never a bare reload); the state change below
                        // reloads the result when the run completes.
                        didLoad = false
                        result = nil
                        appModel.retryProcessing()
                    },
                    secondaryTitle: "Back to Home",
                    secondary: { appModel.goHome() }
                )
            } else {
                ProgressView("Loading your selection…")
            }
        }
        .navigationTitle("Review")
        .task {
            result = await appModel.loadResult(for: sessionID)
            didLoad = true
        }
        .onChange(of: appModel.processing.state) { _, newState in
            if case let .completed(id, _, _) = newState, id == sessionID {
                Task {
                    result = await appModel.loadResult(for: sessionID)
                    didLoad = true
                }
            } else if case .failed = newState {
                didLoad = true
            }
        }
    }

    /// Unavailable bucket from this session's terminal processing state;
    /// fallback is the last known progress count, never a literal.
    private var unavailable: Int {
        if case let .completed(id, _, count) = appModel.processing.state, id == sessionID {
            return count
        }
        return appModel.processing.progress.unavailableCount
    }
}
