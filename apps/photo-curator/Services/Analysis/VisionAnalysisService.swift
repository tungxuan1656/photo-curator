import CoreGraphics
import Foundation
import Vision

/// On-device Vision analysis: one decode → all signals → release.
///
/// Pixels arrive upright from `ImageLoaderService` (`CGImage` only, orientation
/// already baked), so the handler always passes `.up` and no orientation
/// side-channel exists. Each Vision request runs independently: one request
/// failing degrades its own field only (nil results → zero-count with nil
/// quality, never a throw). Feature prints are transient run-local evidence:
/// never persisted, cached, or logged; released after edge computation.
/// Normalization lives in `PhotoAnalysis.make`; this file defines no clamp.
final class VisionAnalysisService: ImageAnalysisService, Sendable {
    /// Off-main boundary: nonisolated, so the synchronous Vision + CPU work in
    /// `performAll` runs on the cooperative pool, never blocking SwiftUI on
    /// 100-asset runs. No shared mutable state crosses here (`AnalysisInput`
    /// is a value snapshot; everything else is a local).
    nonisolated func analyze(_ input: AnalysisInput) async throws -> ImageAnalysisOutput {
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

    /// Cache-hit path: rebuilds only the deliberately non-persisted feature
    /// print. Non-cancellation Vision failure degrades to nil (singleton in
    /// grouping), never a throw.
    nonisolated func similarityArtifact(for input: AnalysisInput) async throws -> ImageSimilarityArtifact? {
        do {
            try Task.checkCancellation()
            let handler = VNImageRequestHandler(cgImage: input.image, orientation: .up, options: [:])
            let request = VNGenerateImageFeaturePrintRequest()
            try handler.perform([request])
            guard let observation = request.results?.first as? VNFeaturePrintObservation else { return nil }
            return ImageSimilarityArtifact(observation: observation)
        } catch is CancellationError {
            throw SelectionError.cancelled
        } catch {
            return nil
        }
    }
}

/// Sampled luma grid backing the CPU heuristics. Plain value box so the
/// heuristic helpers stay short without a 3-member tuple. Nonisolated so the
/// off-main CPU pass can use it without hopping back to the MainActor.
private nonisolated struct LumaGrid: Sendable {
    let values: [Double]
    let cols: Int
    let rows: Int
}

/// Component scores from the luma pass. Plain value box so the nonisolated
/// helpers never construct MainActor-isolated model values off-main; the
/// single `TechnicalAnalysis` hop happens once at the async boundary.
private nonisolated struct LumaScores: Sendable {
    let sharpness: Double
    let exposure: Double
    let resolution: Double
    let blur: Double
    let under: Double
    let over: Double
}

private extension VisionAnalysisService {
    /// Runs every Vision request plus the CPU heuristic pass for one asset.
    /// Asset-level throws are limited to `.cancelled` and whole-decode
    /// `.internal` (loader owns ID resolution, so `.invalidInput` never
    /// originates here). Entry/exit cancellation checks are translated to
    /// `.cancelled` by the do/catch in `analyze`, so raw CancellationError
    /// never escapes this service.
    /// Nonisolated: the synchronous Vision + CPU work executes off the main
    /// actor. Hops back happen only for isolated value construction
    /// (`TechnicalAnalysis`, `PhotoAnalysis.make`, config reads).
    nonisolated func performAll(input: AnalysisInput) async throws -> ImageAnalysisOutput {
        try Task.checkCancellation()
        // Snapshot the sendable input once: the image + ID are locals from
        // here on, so no shared state crosses executors below.
        let assetID = input.assetID
        let image = input.image
        // Each request runs independently: one request failing degrades its
        // own field only via try?.
        let tierA = try await tierABaseline(image: image)
        let faceCount = tierA.faceCount
        // feat-020 pass-through: the existing Tier-A face observations map to
        // the transient per-face distribution (no new Vision request). Only
        // scalars cross; boxes/landmarks/pixels never leave Tier-A locals.
        let groupFacts = GroupEvidenceCalculator.map(faceCount: faceCount, faceQualities: tierA.faceQualities)
        // Frozen max restored: subjectPlacementScore keeps the pre-Task-3 Tier-A
        // per-face quality max exactly; only the people-term min/mean fold is new.
        let bestFaceQuality = tierA.bestFaceQuality
        let similarity = tierA.similarity
        // Universal facts (feat-018): adapter phase 1 collects the aesthetics +
        // classify observations beside the face/print requests above, with the
        // same 512 px `.up` input, independent degrade, and cancellation
        // checks. Its `try` carries only CancellationError (every other
        // failure lands in the unavailable arms of `Collected`); that error
        // maps to `.cancelled` via the do/catch at the top of `analyze`.
        try Task.checkCancellation()
        let universal = try UniversalFactAdapter.collect(from: image)
        let maxEdge = await AppConfiguration.default.selection.analysisImageMaxDimension
        let technical = await Self.heuristics(on: image, edge: Double(maxEdge))
        // Shared factory owned by PhotoAnalysis.swift — no local clamp.
        // Phase 2 is a pure map to the frozen fact triple; `hasPrint` passes
        // the existing first-print-or-nil signal for `featurePrintAvailable`.
        let facts = await UniversalFactAdapter.map(universal, hasPrint: similarity != nil)
        let tierB = try await tierBFacts(input: TierBInput(
            image: image,
            assetID: assetID,
            faceCount: faceCount,
            technical: technical,
            universalIsUtility: facts.isUtility,
            isScreenshotSubtype: input.isScreenshotSubtype
        ))
        let analysis = await PhotoAnalysis.make(
            assetID: assetID,
            technical: technical,
            faceCount: faceCount,
            groupPhotoScore: faceCount >= 2 ? Double(faceCount) / 6.0 : nil,
            subjectPlacementScore: bestFaceQuality,
            sceneType: faceCount > 0 ? .people : .unknown,
            aestheticScore: facts.aestheticScore,
            tags: facts.tags,
            featurePrintAvailable: facts.featurePrintAvailable,
            horizonScore: tierB.horizonScore,
            visualBalanceScore: tierB.visualBalanceScore,
            salientRegionCount: tierB.salientRegionCount,
            hasText: tierB.hasText,
            textLineCount: tierB.textLineCount,
            screenshotProbability: tierB.screenshotProbability,
            isDocument: tierB.isDocument,
            minFaceQuality: groupFacts.minFaceQuality,
            meanFaceQuality: groupFacts.meanFaceQuality
        )
        // Post-analysis cancel check: a cancel landing during the sync CPU
        // pass must not return success — map through .cancelled in analyze.
        try Task.checkCancellation()
        return ImageAnalysisOutput(analysis: analysis, similarity: similarity)
    }

    /// Tier-A baseline requests (faces, face quality, feature print): the
    /// pre-feat-019 lane, unchanged. Each request degrades independently via
    /// `try?`; only cancellation escapes. Returns the face facts plus the
    /// transient similarity artifact (nil when the print request degrades).
    private nonisolated func tierABaseline(image: CGImage) async throws -> TierABaseline {
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        let faceRects = VNDetectFaceRectanglesRequest()
        let faceQuality = VNDetectFaceCaptureQualityRequest()
        let printRequest = VNGenerateImageFeaturePrintRequest()
        do {
            try Task.checkCancellation()
            autoreleasepool {
                try? handler.perform([faceRects])
            }
            try Task.checkCancellation()
            autoreleasepool {
                try? handler.perform([faceQuality])
            }
            try Task.checkCancellation()
            autoreleasepool {
                try? handler.perform([printRequest])
            }
        } catch is CancellationError {
            throw SelectionError.cancelled
        } catch {
            throw SelectionError.internal
        }
        if Task.isCancelled {
            throw SelectionError.cancelled
        }
        let faceObservations = faceRects.results ?? []
        let faceCount = faceObservations.count
        let faceQualities: [Double]? = faceCount > 0 ? (faceQuality.results.map { results in
            results.compactMap(\.faceCaptureQuality).map { Double($0) }
        }) : nil
        // Frozen max (pre-Task-3 behavior, byte-identical): the per-face quality
        // max feeds subjectPlacementScore; min/mean ride separately via faceQualities.
        var bestFaceQuality: Double?
        if faceCount > 0, let qualities = faceQualities, !qualities.isEmpty {
            bestFaceQuality = qualities.max()
        }
        let similarity = (printRequest.results?.first as? VNFeaturePrintObservation)
            .map(ImageSimilarityArtifact.init(observation:))
        return TierABaseline(
            faceCount: faceCount, bestFaceQuality: bestFaceQuality, faceQualities: faceQualities,
            similarity: similarity
        )
    }

    /// Tier-B contextual pass (feat-019 frozen routing). Tier-A facts from the
    /// same pass only. `technicallyUsable` mirrors the scorer floor
    /// (`lowQualityThreshold`) so Tier-B never runs on a photo the scorer
    /// already rejects — Tier-B cannot rescue a bad photo. Gated facts stay
    /// nil for ineligible assets even when an observation exists.
    /// Nonisolated: same cooperative-pool lane as `performAll`.
    private nonisolated func tierBFacts(input: TierBInput) async throws -> TierBCollected {
        let qualityProbe = await PhotoAnalysis.make(
            assetID: input.assetID,
            technical: input.technical,
            faceCount: input.faceCount,
            groupPhotoScore: nil,
            subjectPlacementScore: nil,
            sceneType: .unknown
        )
        let lowFloor = await AppConfiguration.default.selection.lowQualityThreshold
        let technicallyUsable = qualityProbe.qualityScore >= lowFloor
        let saliencyEligible = technicallyUsable && input.faceCount == 0
        // Horizon eligibility needs the asset shape: landscape input only.
        // performAll sees pixels only (AnalysisInput carries no PhotoAsset),
        // so it gates on the image dims — the same comparison, no new data.
        let horizonEligible = saliencyEligible && input.image.width >= input.image.height
        let personSegEligible = technicallyUsable && input.faceCount >= 1
        let utilityEligible = technicallyUsable && (input.isScreenshotSubtype || input.universalIsUtility)
        let composition = try await gatedCompositionFacts(
            image: input.image,
            saliency: saliencyEligible,
            horizon: horizonEligible,
            personSeg: personSegEligible
        )
        var utility: UtilityEvidenceAdapter.MappedFacts?
        var utilityRan = false
        if utilityEligible {
            try Task.checkCancellation()
            do {
                let collected = try UtilityEvidenceAdapter.collect(from: input.image)
                utility = UtilityEvidenceAdapter.map(collected, isScreenshotSubtype: input.isScreenshotSubtype)
                utilityRan = true
            } catch is CancellationError {
                throw SelectionError.cancelled
            } catch {
                utility = nil
            }
        }
        return TierBCollected(
            horizonScore: horizonEligible ? composition.horizonScore : nil,
            visualBalanceScore: personSegEligible ? composition.visualBalanceScore : nil,
            salientRegionCount: saliencyEligible ? composition.salientRegionCount : nil,
            hasText: utilityRan ? utility?.hasText : nil,
            textLineCount: utilityRan ? utility?.textLineCount : nil,
            screenshotProbability: utilityRan ? utility?.screenshotProbability : nil,
            isDocument: utilityRan ? utility?.isDocument : nil
        )
    }

    /// Per-request composition gating (frozen contract: each eligible request
    /// ONLY). Saliency runs iff faceless-usable, horizon iff saliency-eligible
    /// AND landscape, person-seg iff has-faces-usable. No ineligible inference.
    /// Each entry degrades to its nil arm; only cancellation escapes.
    private nonisolated func gatedCompositionFacts(
        image: CGImage,
        saliency: Bool,
        horizon: Bool,
        personSeg: Bool
    ) async throws -> CompositionEvidenceAdapter.MappedFacts {
        var salientCount: Int?
        var horizonAngle: Double?
        var foregroundFraction: Double?
        do {
            if saliency {
                try Task.checkCancellation()
                salientCount = try CompositionEvidenceAdapter.collectSaliency(from: image).salientObjectCount
            }
            if horizon {
                try Task.checkCancellation()
                horizonAngle = try CompositionEvidenceAdapter.collectHorizon(from: image).horizonAngle
            }
            if personSeg {
                try Task.checkCancellation()
                foregroundFraction = try CompositionEvidenceAdapter.collectPersonSegmentation(from: image)
                    .foregroundFraction
            }
        } catch is CancellationError {
            throw SelectionError.cancelled
        } catch {
            throw SelectionError.internal
        }
        return await CompositionEvidenceAdapter.map(CompositionEvidenceAdapter.Collected(
            salientObjectCount: saliency ? salientCount : nil,
            horizonAngle: horizon ? horizonAngle : nil,
            foregroundFraction: personSeg ? foregroundFraction : nil
        ))
    }

    private nonisolated struct TierABaseline: Sendable {
        let faceCount: Int
        let bestFaceQuality: Double?
        let faceQualities: [Double]?
        let similarity: ImageSimilarityArtifact?
    }

    /// Tier-B pass input: Tier-A facts plus the pixels they gate. One struct
    /// so the helper takes a single parameter. All Sendable values; the image
    /// is the same 512 px `.up` input the lane already holds.
    private nonisolated struct TierBInput: Sendable {
        let image: CGImage
        let assetID: AssetID
        let faceCount: Int
        let technical: TechnicalAnalysis
        let universalIsUtility: Bool
        let isScreenshotSubtype: Bool
    }

    /// Gated Tier-B facts for one asset: every field nil when its predicate
    /// is false or its request degrades. Plain value box so the off-main lane
    /// carries results without hopping back to the MainActor.
    private nonisolated struct TierBCollected: Sendable {
        let horizonScore: Double?
        let visualBalanceScore: Double?
        let salientRegionCount: Int?
        let hasText: Bool?
        let textLineCount: Int?
        let screenshotProbability: Double?
        let isDocument: Bool?
    }

    /// Synchronous CPU pass on the 512 px `CGImage` returning a
    /// `TechnicalAnalysis`: Laplacian variance → sharpness/blur, luma-histogram
    /// tails → exposure/under/over, pixel dims vs the configured analysis edge
    /// → resolution. No await inside the pixel loop; `PhotoAnalysis.make`
    /// clamps once. The model hop is isolated to the two construction sites.
    nonisolated static func heuristics(on image: CGImage, edge: Double) async -> TechnicalAnalysis {
        let longEdge = max(image.width, image.height)
        let resolution = longEdge >= Int(edge) ? 1.0 : Double(longEdge) / edge
        guard longEdge > 0, let grid = lumaGrid(for: image) else {
            return await TechnicalAnalysis(
                sharpnessScore: 0,
                exposureScore: 0.5,
                resolutionScore: resolution,
                blurProbability: 1,
                underexposureProbability: 0,
                overexposureProbability: 0
            )
        }
        let scored = scores(luma: grid.values, cols: grid.cols, rows: grid.rows, resolution: resolution)
        return await TechnicalAnalysis(
            sharpnessScore: scored.sharpness,
            exposureScore: scored.exposure,
            resolutionScore: scored.resolution,
            blurProbability: scored.blur,
            underexposureProbability: scored.under,
            overexposureProbability: scored.over
        )
    }

    /// Samples luma (0...1) on a ~128 px stride grid in a caller-owned RGBA8
    /// buffer. Returns nil when the image cannot be decoded; the caller
    /// degrades to fallback technical facts. Nonisolated: pure pixel math.
    nonisolated static func lumaGrid(for image: CGImage) -> LumaGrid? {
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

    /// Maps a luma grid to component scores. All outputs are naturally bounded
    /// (tail fractions of the sample count; variance ratio), so no clamp here.
    /// Returns components (not the model value) to stay off-main.
    nonisolated static func scores(
        luma values: [Double],
        cols: Int,
        rows: Int,
        resolution: Double
    ) -> LumaScores {
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
        return LumaScores(
            sharpness: sharpness,
            exposure: 1.0 - under - over,
            resolution: resolution,
            blur: 1.0 - sharpness,
            under: under,
            over: over
        )
    }

    /// Variance of the 4-neighbour Laplacian over the luma grid interior.
    /// Nonisolated: pure arithmetic.
    nonisolated static func laplacianVariance(values: [Double], cols: Int, rows: Int) -> Double {
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
