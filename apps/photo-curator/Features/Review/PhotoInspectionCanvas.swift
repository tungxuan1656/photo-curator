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

                imageInteractionSurface(
                    viewportSize: viewportSize,
                    renderedImageSize: renderedImageSize
                )

                PhotoInspectionChrome(
                    controlsVisible: controlsVisible,
                    loadFailed: loadFailed,
                    position: position,
                    total: total,
                    isSelected: isSelected,
                    isZoomed: !inspectionState.isAtFit,
                    canGoPrevious: canGoPrevious,
                    canGoNext: canGoNext,
                    inspectionState: $inspectionState,
                    back: back,
                    previous: previous,
                    next: next,
                    toggleSelection: toggleSelection,
                    showAnalysis: showAnalysis
                )
                .accessibilityHidden(false)
            }
            .onChange(of: currentAssetID) {
                inspectionState.reset()
                magnificationStartScale = nil
                dragStartOffset = nil
                dragStartedZoomed = false
                controlsVisible = true
            }
        }
        .onAppear {
            controlsVisible = true
        }
        .onDisappear {
            controlsVisible = true
            magnificationStartScale = nil
            dragStartOffset = nil
            dragStartedZoomed = false
        }
        .background(.black)
    }

    @ViewBuilder
    private func imageInteractionSurface(viewportSize: CGSize, renderedImageSize: CGSize) -> some View {
        if image != nil {
            interactiveImageSurface(viewportSize: viewportSize, renderedImageSize: renderedImageSize)
        } else {
            imageSurface(viewportSize: viewportSize, renderedImageSize: renderedImageSize)
        }
    }

    private func interactiveImageSurface(viewportSize: CGSize, renderedImageSize: CGSize) -> some View {
        imageSurface(viewportSize: viewportSize, renderedImageSize: renderedImageSize)
            .contentShape(Rectangle())
            .simultaneousGesture(magnificationGesture(viewportSize: viewportSize, renderedImageSize: renderedImageSize))
            .simultaneousGesture(dragGesture(viewportSize: viewportSize, renderedImageSize: renderedImageSize))
            .gesture(tapGesture(viewportSize: viewportSize, renderedImageSize: renderedImageSize))
    }

    private func tapGesture(viewportSize: CGSize, renderedImageSize: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture(count: 1))
            .onEnded { result in
                switch result {
                case .first:
                    animate {
                        inspectionState.toggleDoubleTap(
                            viewportSize: viewportSize,
                            renderedImageSize: renderedImageSize
                        )
                    }
                case .second:
                    controlsVisible.toggle()
                }
            }
    }

    private func magnificationGesture(viewportSize: CGSize, renderedImageSize: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
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
    }

    private func dragGesture(viewportSize: CGSize, renderedImageSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
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
                guard !dragStartedZoomed else { return }
                if inspectionState.canDismissVertically(for: value.translation) {
                    back()
                    return
                }
                guard let direction = inspectionState.pageDirection(for: value.translation) else { return }
                switch direction {
                case .previous:
                    animate(previous)
                case .next:
                    animate(next)
                }
            }
    }

    private func imageSurface(viewportSize: CGSize, renderedImageSize: CGSize) -> some View {
        ZStack {
            if let image {
                inspectionImage(
                    image,
                    viewportSize: viewportSize,
                    renderedImageSize: renderedImageSize
                )
            } else if isLoading {
                loadingSurface
            } else if loadFailed {
                loadFailureSurface
            } else {
                loadingSurface
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: image != nil)
    }

    private func inspectionImage(
        _ image: CGImage,
        viewportSize: CGSize,
        renderedImageSize: CGSize
    ) -> some View {
        Image(
            image,
            scale: 1,
            orientation: .up,
            label: Text("Photo \(position) of \(total)")
        )
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
        .accessibilityHint("Double tap to inspect. Swipe left or right at Fit to change photos.")
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
        .transition(reduceMotion ? .identity : .opacity)
    }

    private var loadingSurface: some View {
        ProgressView()
            .tint(.white)
            .accessibilityLabel("Loading photo")
            .transition(reduceMotion ? .identity : .opacity)
    }

    private var loadFailureSurface: some View {
        VStack(spacing: 14) {
            Text("We couldn't load this photo.")
                .font(.headline)
                .multilineTextAlignment(.center)

            Button("Try Again", action: retry)
                .buttonStyle(InspectionButtonStyle(kind: .primary, reduceMotion: reduceMotion))
                .accessibilityHint("Loads this photo again.")

            Button("Back", action: back)
                .buttonStyle(InspectionButtonStyle(kind: .secondary, reduceMotion: reduceMotion))
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .transition(reduceMotion ? .identity : .opacity)
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
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86), action)
        }
    }

    private var zoomValue: String {
        inspectionState.isAtFit ? "Fit" : "Zoomed to \(inspectionState.scale) times"
    }
}

private struct PhotoInspectionChrome: View {
    let controlsVisible: Bool
    let loadFailed: Bool
    let position: Int
    let total: Int
    let isSelected: Bool
    let isZoomed: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    @Binding var inspectionState: PhotoInspectionState
    let back: () -> Void
    let previous: () -> Void
    let next: () -> Void
    let toggleSelection: () -> Void
    let showAnalysis: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feedbackTrigger = 0

    var body: some View {
        let isVisible = controlsVisible || loadFailed

        return ZStack(alignment: .top) {
            topChrome
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : -18)
                .allowsHitTesting(isVisible)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            topPagerChrome
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : -18)
                .allowsHitTesting(isVisible)
                .frame(maxWidth: .infinity, alignment: .topTrailing)

            VStack {
                Spacer()
                bottomChrome
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 24)
                    .allowsHitTesting(isVisible)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: isVisible)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    private var topChrome: some View {
        HStack(spacing: 8) {
            Button(action: back) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(InspectionButtonStyle(kind: .secondary, reduceMotion: reduceMotion))
            .frame(width: 48, height: 48)
            .accessibilityLabel("Back")
            .accessibilityHint("Returns to the review surface.")

            Text("\(position) / \(total)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .modifier(InspectionGlassLabelStyle())
                .accessibilityLabel("Photo position, \(position) of \(total)")
        }
        .inspectionGlassGroup()
        .padding(.leading, 16)
        .padding(.top, 10)
    }

    private var topPagerChrome: some View {
        HStack(spacing: 8) {
            Button {
                changePage(previous)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(InspectionButtonStyle(kind: .navigation, reduceMotion: reduceMotion))
            .frame(width: 48, height: 48)
            .opacity(canGoPrevious ? 1 : 0.42)
            .disabled(!canGoPrevious)
            .accessibilityLabel("Previous photo")
            .accessibilityHint("Shows the previous photo in this review set.")

            Button {
                changePage(next)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(InspectionButtonStyle(kind: .navigation, reduceMotion: reduceMotion))
            .frame(width: 48, height: 48)
            .opacity(canGoNext ? 1 : 0.42)
            .disabled(!canGoNext)
            .accessibilityLabel("Next photo")
            .accessibilityHint("Shows the next photo in this review set.")
        }
        .inspectionGlassGroup()
        .padding(.trailing, 16)
        .padding(.top, 10)
    }

    private var bottomChrome: some View {
        HStack(spacing: 8) {
            Button {
                feedbackTrigger += 1
                toggleSelection()
            } label: {
                Label(
                    isSelected ? "In Album" : "Removed",
                    systemImage: isSelected ? "checkmark.circle.fill" : "circle"
                )
            }
            .buttonStyle(
                InspectionButtonStyle(
                    kind: isSelected ? .primary : .secondary,
                    reduceMotion: reduceMotion
                )
            )
            .accessibilityValue(isSelected ? "In album" : "Removed")
            .accessibilityHint("Changes whether this photo is in the album.")

            Button(action: showAnalysis) {
                Image(systemName: "chart.bar.xaxis")
            }
            .buttonStyle(InspectionButtonStyle(kind: .secondary, reduceMotion: reduceMotion))
            .frame(width: 48, height: 48)
            .accessibilityLabel("View Analysis")
            .accessibilityHint("Shows the saved analysis for this photo.")

            if isZoomed {
                Button {
                    animate { inspectionState.reset() }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(InspectionButtonStyle(kind: .secondary, reduceMotion: reduceMotion))
                .frame(width: 48, height: 48)
                .accessibilityLabel("Fit")
                .accessibilityValue("Zoomed")
                .accessibilityHint("Restores the full photo and centers it.")
            }
        }
        .inspectionGlassGroup()
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func changePage(_ action: () -> Void) {
        feedbackTrigger += 1
        animate(action)
    }

    private func animate(_ action: () -> Void) {
        if reduceMotion {
            action()
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86), action)
        }
    }
}
