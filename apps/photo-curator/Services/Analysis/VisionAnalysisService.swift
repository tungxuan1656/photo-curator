import CoreGraphics
import Foundation
import Vision

/// On-device Vision analysis: one decode → all signals → release.
///
/// Pixels arrive upright from `ImageLoaderService` (`CGImage` only, orientation
/// already baked), so the handler always passes `.up` and no orientation
/// side-channel exists. Each Vision request runs independently: one request
/// failing degrades its own field only (nil results → zero-count with nil
/// quality, never a throw). Feature-print generation is deferred to feat-007;
/// no print request runs here. Normalization lives in `PhotoAnalysis.make`;
/// this file defines no clamp.
final class VisionAnalysisService: ImageAnalysisService, Sendable {
    func analyze(_ input: AnalysisInput) async throws -> PhotoAnalysis {
        // Structured execution: no Task{} wrapper, so the pipeline lane's
        // cancellation — and its userInitiated priority — propagate directly
        // into the Vision work. The do/catch translates every CancellationError
        // from the checks below so only SelectionError ever escapes.
        do {
            try Task.checkCancellation()
            // Pixels arrive upright from ImageLoaderService.normalizedCGImage;
            // always pass .up so no orientation side-channel exists.
            return try await performAll(input: input)
        } catch is CancellationError {
            throw SelectionError.cancelled
        }
    }
}

/// Sampled luma grid backing the CPU heuristics. Plain value box so the
/// heuristic helpers stay short without a 3-member tuple.
private struct LumaGrid: Sendable {
    let values: [Double]
    let cols: Int
    let rows: Int
}

private extension VisionAnalysisService {
    /// Runs every Vision request plus the CPU heuristic pass for one asset.
    /// Asset-level throws are limited to `.cancelled` and whole-decode
    /// `.internal` (loader owns ID resolution, so `.invalidInput` never
    /// originates here). Entry/exit cancellation checks are translated to
    /// `.cancelled` by the do/catch in `analyze`, so raw CancellationError
    /// never escapes this service.
    func performAll(input: AnalysisInput) async throws -> PhotoAnalysis {
        try Task.checkCancellation()
        // Each request runs independently: one request failing degrades its
        // own field only via try?.
        let handler = VNImageRequestHandler(cgImage: input.image, orientation: .up, options: [:])
        let faceRects = VNDetectFaceRectanglesRequest()
        let faceQuality = VNDetectFaceCaptureQualityRequest()

        // Synchronous Vision work only inside autoreleasepool (no await
        // inside). Cancellation is checked between requests, never inside
        // the pool. The do/catch carries the throwing cancellation checks so
        // CancellationError maps to .cancelled and anything else to .internal.
        do {
            try Task.checkCancellation()
            autoreleasepool {
                try? handler.perform([faceRects])
            }
            try Task.checkCancellation()
            autoreleasepool {
                try? handler.perform([faceQuality])
            }
        } catch is CancellationError {
            throw SelectionError.cancelled
        } catch {
            throw SelectionError.internal
        }
        if Task.isCancelled {
            throw SelectionError.cancelled
        }
        // Unknown-vs-zero: nil results degrade to zero-count with nil quality,
        // a valid analysis — not a throw. Nil face detection additionally
        // forces subjectPlacementScore nil even if the quality request
        // returned scores (unknown quality).
        let faceObservations = faceRects.results ?? []
        let faceCount = faceObservations.count
        var bestFaceQuality: Double?
        if faceCount > 0, let qualityResults = faceQuality.results {
            bestFaceQuality = qualityResults.compactMap(\.faceCaptureQuality).map { Double($0) }.max()
        }
        // faceQuality failing (nil results) leaves bestFaceQuality nil: per-field degrade.
        try Task.checkCancellation()
        let technical = Self.heuristics(on: input.image)
        // Shared factory owned by PhotoAnalysis.swift — no local clamp.
        let result = PhotoAnalysis.make(
            assetID: input.assetID,
            technical: technical,
            faceCount: faceCount,
            groupPhotoScore: faceCount >= 2 ? Double(faceCount) / 6.0 : nil,
            subjectPlacementScore: bestFaceQuality,
            sceneType: faceCount > 0 ? .people : .unknown
        )
        // Post-analysis cancel check: a cancel landing during the sync CPU
        // pass must not return success — map through .cancelled in analyze.
        try Task.checkCancellation()
        return result
    }

    /// Synchronous CPU pass on the 512 px `CGImage` returning a
    /// `TechnicalAnalysis`: Laplacian variance → sharpness/blur, luma-histogram
    /// tails → exposure/under/over, pixel dims vs the configured analysis edge
    /// → resolution. No await; `PhotoAnalysis.make` clamps once.
    static func heuristics(on image: CGImage) -> TechnicalAnalysis {
        let longEdge = max(image.width, image.height)
        let edge = Double(AppConfiguration.default.selection.analysisImageMaxDimension)
        let resolution = longEdge >= Int(edge) ? 1.0 : Double(longEdge) / edge
        guard longEdge > 0, let grid = lumaGrid(for: image) else {
            return TechnicalAnalysis(
                sharpnessScore: 0,
                exposureScore: 0.5,
                resolutionScore: resolution,
                blurProbability: 1,
                underexposureProbability: 0,
                overexposureProbability: 0
            )
        }
        return scores(luma: grid.values, cols: grid.cols, rows: grid.rows, resolution: resolution)
    }

    /// Samples luma (0...1) on a ~128 px stride grid in a caller-owned RGBA8
    /// buffer. Returns nil when the image cannot be decoded; the caller
    /// degrades to fallback technical facts.
    static func lumaGrid(for image: CGImage) -> LumaGrid? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        let step = max(1, min(width, height) / 128)
        let cols = (width + step - 1) / step
        let rows = (height + step - 1) / step
        guard cols >= 3, rows >= 3 else { return nil }
        let bytesPerRow = width * 4
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let base = context.data else { return nil }
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        var values = [Double]()
        values.reserveCapacity(cols * rows)
        for row in 0 ..< rows {
            for col in 0 ..< cols {
                let offset = row * step * bytesPerRow + col * step * 4
                let red = Double(pixels[offset])
                let green = Double(pixels[offset + 1])
                let blue = Double(pixels[offset + 2])
                values.append((0.299 * red + 0.587 * green + 0.114 * blue) / 255.0)
            }
        }
        return LumaGrid(values: values, cols: cols, rows: rows)
    }

    /// Maps a luma grid to technical facts. All outputs are naturally bounded
    /// (tail fractions of the sample count; variance ratio), so no clamp here.
    static func scores(luma values: [Double], cols: Int, rows: Int, resolution: Double) -> TechnicalAnalysis {
        let total = Double(values.count)
        var dark = 0.0
        var bright = 0.0
        for value in values {
            if value < 0.08 {
                dark += 1
            }
            if value > 0.92 {
                bright += 1
            }
        }
        let under = dark / total
        let over = bright / total
        let variance = laplacianVariance(values: values, cols: cols, rows: rows)
        let sharpness = variance / (variance + 0.01)
        return TechnicalAnalysis(
            sharpnessScore: sharpness,
            exposureScore: 1.0 - under - over,
            resolutionScore: resolution,
            blurProbability: 1.0 - sharpness,
            underexposureProbability: under,
            overexposureProbability: over
        )
    }

    /// Variance of the 4-neighbour Laplacian over the luma grid interior.
    static func laplacianVariance(values: [Double], cols: Int, rows: Int) -> Double {
        var sum = 0.0
        var sumSquares = 0.0
        var count = 0.0
        for row in 1 ..< rows - 1 {
            for col in 1 ..< cols - 1 {
                let center = values[row * cols + col]
                let laplacian = values[(row - 1) * cols + col]
                    + values[(row + 1) * cols + col]
                    + values[row * cols + col - 1]
                    + values[row * cols + col + 1]
                    - 4.0 * center
                sum += laplacian
                sumSquares += laplacian * laplacian
                count += 1
            }
        }
        guard count > 0 else { return 0 }
        let mean = sum / count
        let variance = sumSquares / count - mean * mean
        return variance > 0 ? variance : 0
    }
}
