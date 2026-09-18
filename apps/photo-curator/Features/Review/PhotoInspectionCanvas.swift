import SwiftUI

/// Fullscreen S11 image inspection surface.
///
/// The canvas owns only transient gesture bookkeeping. Photo loading and
/// selection remain in `PhotoDetail` and `ReviewModel`, respectively.
struct PhotoInspectionCanvas: View {
    let currentAssetID: AssetID
    let image: CGImage?
    @Binding var inspectionState: PhotoInspectionState
    let isLoading: Bool
    let loadFailed: Bool
    let position: Int
    let total: Int
    let isSelected: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let back: () -> Void
    let previous: () -> Void
    let next: () -> Void
    let toggleSelection: () -> Void
    let showAnalysis: () -> Void
    let retry: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controlsVisible = true
    @State private var magnificationStartScale: CGFloat?
    @State private var dragStartOffset: CGSize?
    @State private var dragStartedZoomed = false

    var body: some View {
        GeometryReader { geometry in
            let viewportSize = geometry.size
            let renderedImageSize = fittedImageSize(in: viewportSize)

            ZStack {
                Color.black
                    .ignoresSafeArea()

                imageSurface(
                    viewportSize: viewportSize,
                    renderedImageSize: renderedImageSize
                )

                chrome
                    .opacity(controlsVisible || loadFailed ? 1 : 0)
                    .accessibilityHidden(false)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        guard image != nil else { return }
                        if magnificationStartScale == nil {
                            magnificationStartScale = inspectionState.scale
                        }
                        inspectionState.applyMagnification(
                            value.magnification,
                            from: magnificationStartScale ?? PhotoInspectionState.fitScale,
                            viewportSize: viewportSize,
                            renderedImageSize: renderedImageSize
                        )
                    }
                    .onEnded { _ in
                        magnificationStartScale = nil
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onChanged { value in
                        guard image != nil else { return }
                        if dragStartOffset == nil {
                            dragStartOffset = inspectionState.offset
                            dragStartedZoomed = !inspectionState.isAtFit
                        }
                        if dragStartedZoomed {
                            inspectionState.applyPan(
                                value.translation,
                                from: dragStartOffset ?? .zero,
                                viewportSize: viewportSize,
                                renderedImageSize: renderedImageSize
                            )
                        }
                    }
                    .onEnded { value in
                        defer {
                            dragStartOffset = nil
                            dragStartedZoomed = false
                        }
                        guard image != nil, !dragStartedZoomed else { return }
                        if inspectionState.canDismissVertically(for: value.translation) {
                            back()
                            return
                        }
                        guard let direction = inspectionState.pageDirection(for: value.translation) else { return }
                        switch direction {
                        case .previous:
                            previous()
                        case .next:
                            next()
                        }
                    }
            )
            .onTapGesture {
                controlsVisible.toggle()
            }
            .onTapGesture(count: 2) {
                guard image != nil else { return }
                animate {
                    inspectionState.toggleDoubleTap(
                        viewportSize: viewportSize,
                        renderedImageSize: renderedImageSize
                    )
                }
            }
            .onChange(of: currentAssetID) {
                inspectionState.reset()
                magnificationStartScale = nil
                dragStartOffset = nil
                dragStartedZoomed = false
                controlsVisible = true
            }
        }
        .background(.black)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Photo \(position) of \(total)")
        .accessibilityValue(isSelected ? "In album" : "Removed")
        .accessibilityHint("Double tap to inspect. Swipe left or right at Fit to change photos.")
    }

    @ViewBuilder
    private func imageSurface(viewportSize: CGSize, renderedImageSize: CGSize) -> some View {
        if let image {
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .scaledToFit()
                .frame(width: viewportSize.width, height: viewportSize.height)
                .scaleEffect(inspectionState.scale)
                .offset(inspectionState.offset)
                .clipped()
                .accessibilityLabel("Photo \(position) of \(total)")
                .accessibilityValue(
                    isSelected
                        ? "In album, \(zoomValue)"
                        : "Removed, \(zoomValue)"
                )
                .accessibilityAction(named: "Zoom in") {
                    animate {
                        inspectionState.applyMagnification(
                            PhotoInspectionState.doubleTapScale / max(inspectionState.scale, 1),
                            from: inspectionState.scale,
                            viewportSize: viewportSize,
                            renderedImageSize: renderedImageSize
                        )
                    }
                }
                .accessibilityAction(named: "Fit") {
                    animate { inspectionState.reset() }
                }
        } else if isLoading {
            ProgressView()
                .tint(.white)
                .accessibilityLabel("Loading photo")
        } else if loadFailed {
            VStack(spacing: 12) {
                Text("We couldn't load this photo.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityHint("Loads this photo again.")
                Button("Back", action: back)
                    .buttonStyle(.bordered)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .foregroundStyle(.white)
            .padding()
            .accessibilityElement(children: .contain)
        } else {
            ProgressView()
                .tint(.white)
                .accessibilityLabel("Loading photo")
        }
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button("Back", systemImage: "chevron.left", action: back)
                    .labelStyle(.titleAndIcon)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityHint("Returns to the review surface.")
                Spacer(minLength: 12)
                Text("\(position) of \(total)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .accessibilityLabel("Photo position, \(position) of \(total)")
            }
            .padding(12)
            .background(.black.opacity(0.65), in: Capsule())
            .padding(.top, 12)

            Spacer()

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(isSelected ? "In Album" : "Removed", action: toggleSelection)
                        .buttonStyle(.borderedProminent)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityValue(isSelected ? "In album" : "Removed")
                        .accessibilityHint("Changes whether this photo is in the album.")

                    Button("View Analysis", systemImage: "chart.bar.xaxis", action: showAnalysis)
                        .buttonStyle(.bordered)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityHint("Shows the saved analysis for this photo.")

                    if !inspectionState.isAtFit {
                        Button("Fit", systemImage: "arrow.up.left.and.arrow.down.right") {
                            animate { inspectionState.reset() }
                        }
                        .buttonStyle(.bordered)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityValue("Zoomed")
                        .accessibilityHint("Restores the full photo and centers it.")
                    }
                }
                .frame(maxWidth: .infinity)

                HStack {
                    Button("Previous", systemImage: "chevron.left", action: previous)
                        .labelStyle(.titleAndIcon)
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(!canGoPrevious)
                        .accessibilityHint("Shows the previous photo in this review set.")
                    Spacer()
                    Button("Next", systemImage: "chevron.right", action: next)
                        .labelStyle(.titleAndIcon)
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(!canGoNext)
                        .accessibilityHint("Shows the next photo in this review set.")
                }
                .padding(.horizontal, 12)
            }
            .padding(12)
            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
            .padding(.bottom, 12)
        }
        .foregroundStyle(.white)
        .buttonStyle(.bordered)
        .safeAreaPadding(.horizontal, 12)
    }

    private var zoomValue: String {
        inspectionState.isAtFit ? "Fit" : "Zoomed to \(inspectionState.scale) times"
    }

    private func fittedImageSize(in viewportSize: CGSize) -> CGSize {
        guard let image else { return .zero }
        return PhotoInspectionState.aspectFitSize(
            imageSize: CGSize(width: image.width, height: image.height),
            in: viewportSize
        )
    }

    private func animate(_ action: () -> Void) {
        if reduceMotion {
            action()
        } else {
            withAnimation(.easeOut(duration: 0.2), action)
        }
    }
}
