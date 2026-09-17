import CoreGraphics
import CoreVideo
import Foundation
import Vision

/// Composition evidence adapter (mini-019a, feat-019).
///
/// Two phases with no pipeline wiring: phase 1 (`collect`) runs the three
/// frozen Tier-B composition requests on the 512 px analysis image with the
/// same handler pattern as `VisionAnalysisService.performAll` (one handler,
/// `.up`, independent `try?` per request, cancellation checks between
/// requests); phase 2 (`map`) pure-maps the collected observations to the
/// frozen fact triple (`horizonScore`, `visualBalanceScore`,
/// `salientRegionCount`) per features/feat-019.md (frozen 2026-09-17).
///
/// Frozen requests: attention saliency rev 2, horizon rev 1, person
/// segmentation rev 1 `.balanced`. Unavailable values are explicit: a thrown
/// request or empty results map to `nil`, never a fabricated default. No box,
/// mask, or pixel buffer crosses to the caller — only scalars and a count.
enum CompositionEvidenceAdapter {
    /// Phase-1 snapshot of the three composition observations. Pure data:
    /// nil marks the frozen unavailable arms, never a fabricated value.
    nonisolated struct Collected: Sendable {
        /// Attention-saliency salient-object count; nil when the request
        /// threw or returned no observation.
        let salientObjectCount: Int?
        /// First horizon observation `angle` in radians; nil when the
        /// request threw or returned no observation.
        let horizonAngle: Double?
        /// Person-segmentation foreground pixel fraction from the
        /// `OneComponent8` mask, computed inside phase 1 so the pixel buffer
        /// never crosses to the caller; nil when the request threw or the
        /// mask was missing or empty.
        let foregroundFraction: Double?
    }

    /// Phase-2 output: the frozen composition fact triple. Both scores are
    /// 0…1; the count is 0…10 capped.
    struct MappedFacts: Sendable {
        let horizonScore: Double?
        let visualBalanceScore: Double?
        let salientRegionCount: Int?
    }

    /// Phase 1: collects the three frozen composition observations beside
    /// the existing lane requests (parent Task 3 calls this from
    /// `performAll`).
    ///
    /// Same input as the existing lane: the 512 px analysis `CGImage`,
    /// orientation `.up`. Each request degrades independently (`try?` per
    /// request in its own `autoreleasepool`); only `CancellationError`
    /// escapes — every other failure lands in the unavailable arms of
    /// `Collected`, never a throw. Cancellation is checked on entry and
    /// between requests.
    nonisolated static func collect(from image: CGImage) throws -> Collected {
        try Task.checkCancellation()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        let saliency = VNGenerateAttentionBasedSaliencyImageRequest()
        saliency.revision = VNGenerateAttentionBasedSaliencyImageRequestRevision2
        let horizon = VNDetectHorizonRequest()
        horizon.revision = VNDetectHorizonRequestRevision1
        let personSegmentation = VNGeneratePersonSegmentationRequest()
        personSegmentation.qualityLevel = .balanced
        personSegmentation.revision = VNGeneratePersonSegmentationRequestRevision1
        try Task.checkCancellation()
        autoreleasepool {
            try? handler.perform([saliency])
        }
        try Task.checkCancellation()
        autoreleasepool {
            try? handler.perform([horizon])
        }
        try Task.checkCancellation()
        autoreleasepool {
            try? handler.perform([personSegmentation])
        }
        return Collected(
            salientObjectCount: saliency.results?.first.map { $0.salientObjects?.count ?? 0 },
            horizonAngle: horizon.results?.first.map { Double($0.angle) },
            foregroundFraction: personSegmentation.results?.first.flatMap { foregroundFraction(of: $0.pixelBuffer) }
        )
    }

    /// Phase 2: pure map from collected observations to the frozen facts.
    ///
    /// `horizonScore = clamped01(1 - abs(angle) / (π/6))` (nil when
    /// unavailable); `visualBalanceScore` is the snapshotted foreground
    /// fraction clamped to 0…1 (nil when unavailable); `salientRegionCount =
    /// min(10, count)` (nil when unavailable). Same inputs always give the
    /// same outputs: no Vision call, no I/O. MainActor like
    /// `PhotoAnalysis.make` (it clamps via the shared rule), so the
    /// nonisolated pipeline lane calls it with `await`.
    static func map(_ collected: Collected) -> MappedFacts {
        MappedFacts(
            horizonScore: collected.horizonAngle.map { PhotoAnalysis.clamped01(1.0 - abs($0) / (.pi / 6.0)) },
            visualBalanceScore: collected.foregroundFraction.map { PhotoAnalysis.clamped01($0) },
            salientRegionCount: collected.salientObjectCount.map { min(10, $0) }
        )
    }

    /// Foreground fraction of a person-segmentation `OneComponent8` mask:
    /// foreground-classified bytes over all pixels. Returns nil for
    /// a non-`OneComponent8`, undecodable, or empty mask (the frozen
    /// unavailable arm). Runs inside phase 1 so the buffer never crosses to
    /// the caller. Nonisolated: pure pixel math.
    private nonisolated static func foregroundFraction(of mask: CVPixelBuffer) -> Double? {
        guard CVPixelBufferGetPixelFormatType(mask) == kCVPixelFormatType_OneComponent8 else { return nil }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        guard width > 0, height > 0 else { return nil }
        guard CVPixelBufferLockBaseAddress(mask, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        var foreground = 0
        for row in 0 ..< height {
            let rowBase = base.advanced(by: row * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for col in 0 ..< width where rowBase[col] != 0 {
                foreground += 1
            }
        }
        let total = width * height
        guard total > 0 else { return nil }
        return Double(foreground) / Double(total)
    }
}
