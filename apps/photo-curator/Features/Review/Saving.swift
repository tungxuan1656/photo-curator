import SwiftUI

/// S15 saving screen: waiting state while the claimed save runs, then the
/// terminal outcome mapped to copy.
///
/// The save is claimed in `AppModel.saveAlbum` before this route appears;
/// this view only awaits the joined outcome. Progress copy names the album
/// being saved; no determinate fraction is shown because PhotoKit `performChanges`
/// reports success atomically per call (a fake percentage would be dishonest).
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
                    ErrorStateView(
                        title: "Album partially saved",
                        message: "\(state.addedIDs.count) of \(state.requestedIDs.count) photos were added.",
                        primaryTitle: "Retry Remaining",
                        primary: {
                            Task {
                                self.outcome = nil
                                self.outcome = await appModel.retryRemainingSave(for: sessionID)
                            }
                        },
                        secondaryTitle: "Finish Anyway",
                        secondary: { appModel.path.append(.completion(sessionID: sessionID)) }
                    )
                case .permissionLost:
                    ErrorStateView(
                        title: "Can't Save Album",
                        message: "Photos access changed before the album could be saved.",
                        primaryTitle: "Open Settings",
                        primary: { appModel.openSettingsURL() },
                        secondaryTitle: "Back to Review",
                        secondary: { appModel.path.removeLast() }
                    )
                case .failed:
                    ErrorStateView(
                        title: "Couldn't Save Album",
                        message: "Your selection is kept. Try again when ready.",
                        primaryTitle: "Try Again",
                        primary: {
                            Task {
                                self.outcome = nil
                                self.outcome = await appModel.saveAlbum(for: sessionID)
                            }
                        },
                        secondaryTitle: "Back to Review",
                        secondary: { appModel.path.removeLast() }
                    )
                }
            } else {
                VStack(spacing: 12) {
                    Text("Saving your album").font(.title2.bold())
                    ProgressView()
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
