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
                    VStack(spacing: 12) {
                        Text("Album partially saved").font(.title2.bold())
                        Text("\(state.addedIDs.count) of \(state.requestedIDs.count) photos were added.")
                        Button("Retry Remaining") {
                            Task {
                                self.outcome = nil
                                self.outcome = await appModel.retryRemainingSave(for: sessionID)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Finish Anyway") {
                            appModel.path.append(.completion(sessionID: sessionID))
                        }
                    }
                    .padding()
                case .permissionLost:
                    VStack(spacing: 12) {
                        Text("Can't Save Album").font(.title2.bold())
                        Text("Photos access changed before the album could be saved.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Open Settings") { appModel.openSettingsURL() }
                            .buttonStyle(.borderedProminent)
                        Button("Back to Review") { appModel.path.removeLast() }
                    }
                    .padding()
                case .failed:
                    VStack(spacing: 12) {
                        Text("Couldn't Save Album").font(.title2.bold())
                        Text("Your selection is kept. Try again when ready.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Try Again") {
                            Task {
                                self.outcome = nil
                                self.outcome = await appModel.saveAlbum(for: sessionID)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Back to Review") { appModel.path.removeLast() }
                    }
                    .padding()
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
