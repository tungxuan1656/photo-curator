import SwiftUI

/// S07 processing screen. Reads the live run via `AppModel.processing` and
/// calls ONLY AppModel intents — never the coordinator directly. The
/// Continue-to-Review button calls `showReview(for:)`, which builds the
/// ReviewModel then routes directly to S09 (or S15 on an interrupted save).
struct ProcessingView: View {
    @Environment(AppModel.self) private var appModel
    @State private var confirmingDiscard = false

    var body: some View {
        Group {
            switch appModel.processing.state {
            case .idle, .preparing:
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Preparing photos…")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .running(progress):
                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44))
                            .foregroundStyle(LinearGradient.curatorSunset)

                        Text("Curating your photos")
                            .font(.title2.bold())

                        Text(progress.stage.userPhase)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        if progress.totalUnits > 0 {
                            ProgressView(value: progress.overallFraction)
                            Text("\(progress.analyzedCount) of \(progress.totalUnits) analyzed")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                                .accessibilityLabel("Working")
                        }

                        if progress.downloadingCount > 0 {
                            let downloading = progress.downloadingCount
                            Text(downloading == 1
                                ? "Waiting for 1 photo from iCloud"
                                : "Waiting for \(downloading) photos from iCloud")
                                .font(.subheadline)
                            Text("Keep this iPhone connected to the internet.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        if progress.unavailableCount > 0 {
                            let unavail = progress.unavailableCount
                            Text(unavail == 1
                                ? "1 photo was unavailable and could not be analyzed."
                                : "\(unavail) photos were unavailable and could not be analyzed.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    Text("You can leave this screen. We'll keep your progress and resume if needed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()

                    VStack(spacing: 10) {
                        Button("Stop Processing") { appModel.cancelProcessing() }
                        Button("Discard Curation", role: .destructive) { confirmingDiscard = true }
                            .font(.subheadline)
                    }
                    .padding(.bottom, 16)
                }
                .padding()
            case let .completed(id, analyzed, unavailable):
                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)

                        VStack(spacing: 6) {
                            Text("Analysis complete")
                                .font(.title.bold())
                            Text(analyzed == 1 ? "1 photo analyzed" : "\(analyzed) photos analyzed")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Quality, smiles & sharpness evaluated", systemImage: "sparkles")
                            .font(.subheadline)
                        Label("Burst & similar shots grouped", systemImage: "square.2.layers.3d")
                            .font(.subheadline)
                        Label("Curated album ready for your review", systemImage: "photo.on.rectangle.angled")
                            .font(.subheadline)

                        if unavailable > 0 {
                            Text(unavailable == 1
                                ? "1 photo was unavailable and could not be analyzed."
                                : "\(unavailable) photos were unavailable and could not be analyzed.")
                                .font(.footnote).foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    Spacer()

                    Button("Continue to Review") { appModel.showReview(for: id) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.bottom, 24)
                }
                .padding()
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
