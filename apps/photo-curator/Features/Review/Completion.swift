import SwiftUI

/// S16 completion: what was saved, clean exit.
///
/// Reads the persisted save state (album name + final count). `Done` clears
/// the session claim and review state, returning Home with no unfinished
/// session card. No `View in Photos`: no reliable deep link exists.
struct Completion: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel
    @State private var state: SaveState?
    @State private var didLoad = false

    var body: some View {
        Group {
            if let state {
                VStack(spacing: 12) {
                    Text("Album Saved").font(.title2.bold())
                    Text("\(state.addedIDs.count) photos saved to \"\(state.albumTitle)\".")
                    if !state.remainingIDs.isEmpty {
                        Text("Some photos could not be added. Your originals are unchanged.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Done") { appModel.finishSave(for: sessionID) }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if didLoad {
                ErrorStateView(
                    title: "Couldn't load your saved album.",
                    message: "Your photos are saved in Photos. Your progress is safe.",
                    primaryTitle: "Try Again",
                    primary: {
                        didLoad = false
                        state = nil
                    },
                    secondaryTitle: "Back to Home",
                    secondary: { appModel.goHome() }
                )
            } else {
                ProgressView("Loading saved album…")
                    .task {
                        state = await appModel.savedAlbum(for: sessionID)
                        didLoad = true
                    }
            }
        }
        .navigationTitle("Saved")
        .navigationBarBackButtonHidden(true)
    }
}
