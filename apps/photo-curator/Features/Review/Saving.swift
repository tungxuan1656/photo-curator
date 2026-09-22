import SwiftUI

/// S15 saving screen: waiting state while the claimed save runs, then the
/// terminal outcome mapped to copy.
///
/// The save is claimed in `AppModel.saveAlbum` before this route appears;
/// this view only awaits the joined outcome. Progress copy names the album
/// being saved; no determinate fraction is shown because PhotoKit `performChanges`
/// reports success atomically per call (a fake percentage would be dishonest).
/// Copy owners: `ui-copy.md` (save preparation/progress/partial/failed/
/// interrupted/retry/access-check rows). Limited access reports the recovery
/// path (Choose More Photos / Get Full Photos Access) per review-rules;
/// denied/restricted routes to Settings. Retry is explicit and adds only
/// missing IDs to the same album; save never clears workspace state.
struct Saving: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel
    @State private var outcome: SaveOutcome?
    var body: some View {
        Group {
            if let outcome {
                switch outcome {
                case let .saved(state):
                    SavedRedirect(state: state, sessionID: sessionID)
                case let .partial(state):
                    savingOutcome(
                        title: "Some photos weren't added to the album",
                        message: "\(state.addedIDs.count) of \(state.requestedIDs.count) photos were added.",
                        primary: ("Retry Missing Photos", {
                            Task {
                                self.outcome = nil
                                self.outcome = await appModel.retryRemainingSave(for: sessionID)
                            }
                        }),
                        secondary: ("Finish Anyway", { appModel.path.append(.completion(sessionID: sessionID)) })
                    )
                case .permissionLost:
                    savingOutcome(
                        title: "Can't Save Album",
                        message: limitedAccessCopy,
                        primary: ("Get Full Photos Access to Save", { appModel.openSettingsURL() }),
                        secondary: ("Back to Review", { appModel.path.removeLast() })
                    )
                case .failed:
                    savingOutcome(
                        title: "Couldn't save the album",
                        message: "Album save was interrupted. Check the result before retrying.",
                        primary: ("Try Again", {
                            Task {
                                self.outcome = nil
                                self.outcome = await appModel.saveAlbum(for: sessionID)
                            }
                        }),
                        secondary: ("Back to Review", { appModel.path.removeLast() })
                    )
                }
            } else {
                VStack(spacing: 12) {
                    Text("Saving album").font(.title2.bold())
                    Text("Checking Photos access")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ProgressView()
                    Text("Saving an album does not change your cleanup choices.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .task {
                    outcome = await appModel.saveAlbum(for: sessionID)
                }
            }
        }
        .navigationTitle("Saving")
        .navigationBarBackButtonHidden(true)
    }

    private var limitedAccessCopy: LocalizedStringResource {
        "Photos access changed before the album could be saved."
    }

    private func savingOutcome(
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        primary: (LocalizedStringResource, () -> Void),
        secondary: (LocalizedStringResource, () -> Void)
    ) -> some View {
        VStack(spacing: 12) {
            ErrorStateView(
                title: title,
                message: message,
                primaryTitle: primary.0,
                primary: primary.1,
                secondaryTitle: secondary.0,
                secondary: secondary.1
            )
            if appModel.authorization == .limited {
                Button("Choose More Photos") {
                    appModel.presentPicker()
                }
                .font(.footnote)
            }
        }
    }
}

/// A full save lands here via the outcome switch: forward to S16 once, with
/// no extra save call. Rendered as nothing while the navigation appends.
private struct SavedRedirect: View {
    let state: SaveState
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ProgressView("Album saved…")
            .onAppear {
                appModel.path.append(.completion(sessionID: sessionID))
            }
    }
}
