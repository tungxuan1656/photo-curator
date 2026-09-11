import CoreGraphics
import SwiftUI

struct AsyncPhotoThumbnail: View {
    let assetID: AssetID
    let targetSizePixels: CGSize

    @Environment(AppModel.self) private var appModel
    @State private var cgImage: CGImage?

    var body: some View {
        Group {
            if let cgImage {
                Image(decorative: cgImage, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .clipped()
        .task(id: assetID) {
            do {
                let cg = try await appModel.imageLoader.thumbnail(for: assetID, targetSize: targetSizePixels)
                self.cgImage = cg
            } catch {
                self.cgImage = nil
            }
        }
        .onDisappear {
            cgImage = nil
        }
    }
}
