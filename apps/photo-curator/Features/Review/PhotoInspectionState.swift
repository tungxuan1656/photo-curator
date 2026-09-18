import CoreGraphics

/// Pure interaction state for the S11 inspection canvas.
///
/// The state stores only a bounded transform. It does not own image pixels,
/// PhotoKit requests, or review selection.
struct PhotoInspectionState: Equatable {
    static let fitScale: CGFloat = 1
    static let doubleTapScale: CGFloat = 2
    static let maximumScale: CGFloat = 6
    static let minimumPageTranslation: CGFloat = 40
    static let minimumDismissTranslation: CGFloat = 120

    enum PageDirection: Equatable {
        case previous
        case next
    }

    private(set) var scale = Self.fitScale
    private(set) var offset = CGSize.zero

    var isAtFit: Bool {
        scale == Self.fitScale && offset == .zero
    }

    mutating func reset() {
        scale = Self.fitScale
        offset = .zero
    }

    mutating func toggleDoubleTap(viewportSize: CGSize, renderedImageSize: CGSize) {
        if isAtFit {
            scale = Self.doubleTapScale
            offset = clampedOffset(
                offset,
                scale: scale,
                viewportSize: viewportSize,
                renderedImageSize: renderedImageSize
            )
        } else {
            reset()
        }
    }

    mutating func applyMagnification(
        _ magnification: CGFloat,
        from startScale: CGFloat,
        viewportSize: CGSize,
        renderedImageSize: CGSize
    ) {
        let proposedScale = startScale * magnification
        scale = min(max(proposedScale, Self.fitScale), Self.maximumScale)
        offset = clampedOffset(
            offset,
            scale: scale,
            viewportSize: viewportSize,
            renderedImageSize: renderedImageSize
        )
    }

    mutating func applyPan(
        _ translation: CGSize,
        from startOffset: CGSize,
        viewportSize: CGSize,
        renderedImageSize: CGSize
    ) {
        guard !isAtFit || scale > Self.fitScale else {
            offset = .zero
            return
        }
        offset = clampedOffset(
            CGSize(width: startOffset.width + translation.width, height: startOffset.height + translation.height),
            scale: scale,
            viewportSize: viewportSize,
            renderedImageSize: renderedImageSize
        )
    }

    func canPageHorizontally(for translation: CGSize) -> Bool {
        scale == Self.fitScale
            && offset == .zero
            && abs(translation.width) >= Self.minimumPageTranslation
            && abs(translation.width) > abs(translation.height)
    }

    func pageDirection(for translation: CGSize) -> PageDirection? {
        guard canPageHorizontally(for: translation) else { return nil }
        return translation.width < 0 ? .next : .previous
    }

    func canDismissVertically(for translation: CGSize) -> Bool {
        isAtFit
            && translation.height >= Self.minimumDismissTranslation
            && translation.height > abs(translation.width)
    }

    static func aspectFitSize(imageSize: CGSize, in viewportSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0,
              viewportSize.width > 0, viewportSize.height > 0
        else { return .zero }
        let ratio = min(viewportSize.width / imageSize.width, viewportSize.height / imageSize.height)
        return CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
    }

    private func clampedOffset(
        _ proposed: CGSize,
        scale: CGFloat,
        viewportSize: CGSize,
        renderedImageSize: CGSize
    ) -> CGSize {
        let horizontalExcess = max(0, renderedImageSize.width * scale - viewportSize.width) / 2
        let verticalExcess = max(0, renderedImageSize.height * scale - viewportSize.height) / 2
        return CGSize(
            width: min(max(proposed.width, -horizontalExcess), horizontalExcess),
            height: min(max(proposed.height, -verticalExcess), verticalExcess)
        )
    }
}
