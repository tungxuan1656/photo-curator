import CoreGraphics
import SwiftUI

/// Bounded, read-only photo inspection for catalog results. The loader is
/// injected so a parent can supply its existing PhotoKit-backed service. No
/// album or deletion state is displayed or changed on this surface.
struct LibraryPhotoInspector: View {
    let assetID: AssetID
    let pagerIDs: [AssetID]
    let imageLoader: any PhotoImageLoader
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: CGImage?
    @State private var loading = true
    @State private var failed = false
    @State private var currentID: AssetID
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var loadToken = 0

    init(assetID: AssetID, pagerIDs: [AssetID], imageLoader: any PhotoImageLoader, onDismiss: @escaping () -> Void) {
        self.assetID = assetID
        self.pagerIDs = pagerIDs.isEmpty ? [assetID] : pagerIDs
        self.imageLoader = imageLoader
        self.onDismiss = onDismiss
        _currentID = State(initialValue: assetID)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable().scaledToFit()
                    .scaleEffect(scale)
                    .gesture(MagnifyGesture().onChanged { value in
                        scale = max(1, min(4, lastScale * value.magnification))
                    }.onEnded { _ in lastScale = scale })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Photo \(position) of \(pagerIDs.count)")
                    .accessibilityValue(Text(zoomAccessibilityValue))
                    .accessibilityHint("Pinch to zoom. Use the Previous photo and Next photo actions to browse.")
                    .accessibilityAction(named: "Fit") { scale = 1; lastScale = 1 }
                    .accessibilityAction(named: "Previous photo") {
                        guard position > 1 else { return }
                        change(by: -1)
                    }
                    .accessibilityAction(named: "Next photo") {
                        guard position < pagerIDs.count else { return }
                        change(by: 1)
                    }
            } else if loading {
                ProgressView("Loading photo…").tint(.white).foregroundStyle(.white)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "photo.badge.exclamationmark").font(.largeTitle)
                    Text("This photo isn't available right now.").font(.headline)
                    Button("Try Again", action: retry)
                        .buttonStyle(.borderedProminent)
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(24)
            }

            VStack {
                HStack {
                    Button(action: onDismiss) { Image(systemName: "xmark") }
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.14), in: Circle())
                        .foregroundStyle(.white)
                        .accessibilityLabel("Close photo inspection")
                    Spacer()
                    Text("\(position) / \(pagerIDs.count)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(minHeight: 44)
                        .background(.white.opacity(0.14), in: Capsule())
                        .accessibilityLabel("Photo position, \(position) of \(pagerIDs.count)")
                }
                .padding(.horizontal, 16).padding(.top, 12)
                Spacer()
                HStack(spacing: 18) {
                    inspectorButton("chevron.left", label: "Previous photo", enabled: position > 1) { change(by: -1) }
                    inspectorButton("arrow.up.left.and.arrow.down.right", label: "Fit photo", enabled: scale > 1) {
                        scale = 1; lastScale = 1
                    }
                    inspectorButton("chevron.right", label: "Next photo", enabled: position < pagerIDs.count) {
                        change(by: 1)
                    }
                }
                .padding(.bottom, 14)
            }
        }
        .task(id: "\(currentID.rawValue)-\(loadToken)") {
            await load(for: currentID, token: loadToken)
        }
    }

    private var position: Int {
        (pagerIDs.firstIndex(of: currentID) ?? 0) + 1
    }

    private var zoomAccessibilityValue: LocalizedStringResource {
        scale > 1 ? "Zoomed" : "Fit"
    }

    private func inspectorButton(
        _ icon: String,
        label: LocalizedStringResource,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { Image(systemName: icon).frame(width: 44, height: 44) }
            .foregroundStyle(.white).background(.white.opacity(0.14), in: Circle())
            .disabled(!enabled).opacity(enabled ? 1 : 0.35)
            .accessibilityLabel(label)
    }

    private func change(by offset: Int) {
        guard let index = pagerIDs.firstIndex(of: currentID) else { return }
        let next = index + offset
        guard pagerIDs.indices.contains(next) else { return }
        if reduceMotion {
            currentID = pagerIDs[next]
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { currentID = pagerIDs[next] }
        }
        scale = 1; lastScale = 1
    }

    private func retry() {
        loadToken += 1
    }

    private func load(for requestedID: AssetID, token: Int) async {
        guard requestedID == currentID, token == loadToken else { return }
        loading = true; failed = false; image = nil
        do {
            let loaded = try await imageLoader.preview(
                for: requestedID,
                targetSize: CGSize(width: 2048, height: 2048)
            )
            guard !Task.isCancelled, requestedID == currentID, token == loadToken else { return }
            image = loaded; loading = false
        } catch {
            guard !Task.isCancelled, requestedID == currentID, token == loadToken else { return }
            loading = false; failed = true
        }
    }
}
