import SwiftUI

/// S16 completion: what was saved, clean exit.
///
/// Reads the durable operation display state (album name + final count).
/// Partial completion stays truthful: remaining/missing counts name what
/// still needs an explicit retry from S15, and cleanup state is untouched.
/// `Done` clears the session claim and review state, returning Home with no
/// unfinished session card. No `View in Photos`: no reliable deep link
/// exists. Copy owners: `ui-copy.md` (album saved/save partial rows).
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
                    let added = state.addedIDs.count
                    if added == 1 {
                        Text("1 photo saved to \"\(state.albumTitle)\".")
                    } else {
                        Text("\(added) photos saved to \"\(state.albumTitle)\".")
                    }
                    if !state.remainingIDs.isEmpty || !state.missingIDs.isEmpty {
                        Text("Some photos weren't added to the album")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Text("Saving an album does not change your cleanup choices.")
                        .font(.footnote).foregroundStyle(.secondary)
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
