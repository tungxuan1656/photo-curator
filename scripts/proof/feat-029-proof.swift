import CoreGraphics
import Foundation

enum InspectionProofError: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case let .assertion(message): return message
        }
    }
}

@main
struct PhotoInspectionProof {
    static func main() {
        do {
            try run()
            print("RESULT PASS")
        } catch {
            print("RESULT FAIL \(error)")
            exit(1)
        }
    }

    static func run() throws {
        let viewport = CGSize(width: 390, height: 844)
        let rendered = CGSize(width: 390, height: 292.5)

        var scale = PhotoInspectionState()
        scale.applyMagnification(
            10,
            from: PhotoInspectionState.fitScale,
            viewportSize: viewport,
            renderedImageSize: rendered
        )
        try require(scale.scale == PhotoInspectionState.maximumScale, "scale did not clamp at maximum")
        print("SCALE-CLAMP PASS")

        scale.applyPan(
            CGSize(width: 900, height: -900),
            from: .zero,
            viewportSize: viewport,
            renderedImageSize: rendered
        )
        let horizontalLimit = (rendered.width * scale.scale - viewport.width) / 2
        let verticalLimit = max(0, rendered.height * scale.scale - viewport.height) / 2
        try require(scale.offset.width == horizontalLimit, "horizontal offset did not clamp")
        try require(scale.offset.height == -verticalLimit, "vertical offset did not clamp")
        print("OFFSET-CLAMP PASS")

        scale.reset()
        try require(scale.isAtFit && scale.offset == .zero, "reset did not restore Fit")
        print("RESET PASS")

        try require(
            PhotoInspectionState().pageDirection(for: CGSize(width: -80, height: 10)) == .next,
            "Fit swipe did not page forward"
        )
        try require(
            PhotoInspectionState().pageDirection(for: CGSize(width: 80, height: 10)) == .previous,
            "Fit swipe did not page backward"
        )
        print("FIT-PAGE PASS")

        var zoomed = PhotoInspectionState()
        zoomed.applyMagnification(
            2,
            from: PhotoInspectionState.fitScale,
            viewportSize: viewport,
            renderedImageSize: rendered
        )
        try require(
            zoomed.pageDirection(for: CGSize(width: -120, height: 0)) == nil,
            "zoomed drag incorrectly paged"
        )
        zoomed.applyPan(
            CGSize(width: 100, height: 0),
            from: .zero,
            viewportSize: viewport,
            renderedImageSize: rendered
        )
        try require(zoomed.offset.width > 0, "zoomed drag did not pan")
        print("ZOOM-PAN PASS")

        zoomed.toggleDoubleTap(viewportSize: viewport, renderedImageSize: rendered)
        try require(zoomed.isAtFit, "double tap did not return to Fit")
        print("ASSET-RESET PASS")
    }

    static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw InspectionProofError.assertion(message) }
    }
}
