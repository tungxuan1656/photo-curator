import SwiftUI
import UIKit

/// S14 final review: count, bounded preview, editable album name, save.
///
/// Reads the shared `ReviewModel` (same counts as S10/S12/S13). Save pushes
/// S15, which joins the atomically claimed session save; repeated taps land
/// on the same in-flight save, never a second export. Save stays disabled on
/// an empty selection with the exact guidance copy.
struct FinalReview: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel

    private var thumbPixels: CGSize {
        let scale = UIScreen.main.scale
        let side = (UIScreen.main.bounds.width / 4) * scale
        let clamped = min(max(side, 200), 500)
        return CGSize(width: clamped, height: clamped)
    }

    var body: some View {
        Group {
            if let model = appModel.reviewModel, model.sessionID == sessionID {
                let selected = model.selectedAssetIDs
                VStack(spacing: 12) {
                    Text("\(selected.count) photos ready").font(.title2.bold())
                    if selected.isEmpty {
                        Text("Add at least one photo to save this album.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 4) {
                                ForEach(Array(selected.prefix(4)), id: \.self) { id in
                                    AsyncPhotoThumbnail(assetID: id, targetSizePixels: thumbPixels)
                                        .frame(width: 80, height: 80)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .frame(height: 80)
                    }
                    TextField("Album name", text: Binding(
                        get: { model.albumName },
                        set: { model.albumName = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Album name")
                    Text("Saves to a new album in Photos.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Your original photos will not be changed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if model.albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Name your album to save it.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Save Album") {
                        // Claim-once: a second tap before S15 appears must not
                        // push a duplicate saving route onto the same flight.
                        if appModel.path.last != .saving(sessionID: sessionID) {
                            appModel.path.append(.saving(sessionID: sessionID))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        model.albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || selected.isEmpty || appModel.isSaving(sessionID: sessionID)
                    )
                    Button("Back to Review") { appModel.path.removeLast() }
                }
                .padding()
            } else {
                ProgressView("Loading your selection…")
            }
        }
        .navigationTitle("Final Review")
    }
}
