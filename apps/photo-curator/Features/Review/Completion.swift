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

    var body: some View {
        Group {
            if let state {
                VStack(spacing: 12) {
                    Text("Album Saved").font(.title2.bold())
                    Text("\(state.addedIDs.count) photos saved to \"\(state.albumTitle)\".")
                    Button("Done") { appModel.finishSave(for: sessionID) }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ProgressView("Loading saved album…")
                    .task {
                        state = await appModel.savedAlbum(for: sessionID)
                    }
            }
        }
        .navigationTitle("Saved")
        .navigationBarBackButtonHidden(true)
    }
}
