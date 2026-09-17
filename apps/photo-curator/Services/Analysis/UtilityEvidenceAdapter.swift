import CoreGraphics
import Foundation
import Vision

/// Utility (screenshot/document) evidence adapter (mini-019b, feat-019).
///
/// Two phases with no pipeline wiring: phase 1 (`collect`) runs the two frozen
/// Tier-B utility requests on the 512 px analysis image with the same handler
/// pattern as `VisionAnalysisService.performAll` (one handler, `.up`,
/// independent `try?` per request, cancellation checks between requests);
/// phase 2 (`map`) pure-maps the collected observations plus the Tier-A
/// screenshot-subtype flag to the frozen utility fact quadruple (`hasText`,
/// `textLineCount`, `screenshotProbability`, `isDocument`)
/// (features/feat-019.md, frozen 2026-09-17).
///
/// Eligibility arrives as a flag: the caller evaluates the frozen predicate
/// (screenshot `mediaSubtypes` or transient `isUtility`, plus technically
/// usable) and only calls this adapter for eligible assets. This adapter never
/// touches PhotoKit.
///
/// Unavailable values are explicit: an OCR throw maps `hasText` /
/// `textLineCount` to `nil`, a doc-seg throw maps `isDocument` to `nil`, and a
/// skipped asset (Tier-B not run) stays `nil` at the caller. No raw text, box,
/// or confidence pair crosses the boundary — only Booleans, a capped count,
/// and a probability.
enum UtilityEvidenceAdapter {
    /// Phase-1 snapshot of the two utility observations. Pure data: nil marks
    /// the frozen unavailable arms, never a fabricated value. Recognized
    /// strings are never stored here — only the top-1 confidences that phase 2
    /// thresholds, so raw text cannot cross into phase 2.
    nonisolated struct Collected: Sendable {
        /// Top-1 confidence per OCR text observation; nil when the OCR request
        /// threw. Empty (non-nil) means the request ran with no results.
        let textTopConfidences: [Double]?
        /// Doc-seg rectangle count; nil when the doc-seg request threw.
        let documentRectangleCount: Int?
    }

    /// Phase-2 output: the frozen utility fact quadruple. All Optional so the
    /// caller keeps the not-run arm as nil; `map` fills every field it has
    /// evidence for (`screenshotProbability` always: the subtype flag is a
    /// Tier-A fact that survives a Tier-B request failure).
    struct MappedFacts: Sendable {
        let hasText: Bool?
        let textLineCount: Int?
        let screenshotProbability: Double?
        let isDocument: Bool?
    }

    /// Phase 1: collects the two utility observations (parent Task 3 calls this
    /// from `performAll` for eligible assets only).
    ///
    /// Same input as the existing lane: the 512 px analysis `CGImage`,
    /// orientation `.up`. OCR runs rev 3, `.accurate`, language correction on
    /// (frozen contract; revision pinned so a future SDK default cannot move
    /// it); doc-seg runs rev 1. Each request degrades independently (`try?`
    /// per request in its own `autoreleasepool`); only `CancellationError`
    /// escapes — every other failure lands in the unavailable arms of
    /// `Collected`, never a throw. Cancellation is checked on entry and
    /// between requests.
    nonisolated static func collect(from image: CGImage) throws -> Collected {
        try Task.checkCancellation()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        let ocr = VNRecognizeTextRequest()
        ocr.revision = VNRecognizeTextRequestRevision3
        ocr.recognitionLevel = .accurate
        ocr.usesLanguageCorrection = true
        let docSeg = VNDetectDocumentSegmentationRequest()
        docSeg.revision = VNDetectDocumentSegmentationRequestRevision1
        try Task.checkCancellation()
        let ocrRan: Bool = autoreleasepool {
            (try? handler.perform([ocr])) != nil
        }
        try Task.checkCancellation()
        let docRan: Bool = autoreleasepool {
            (try? handler.perform([docSeg])) != nil
        }
        let confidences: [Double]? = ocrRan ? (ocr.results ?? []).map { observation in
            observation.topCandidates(1).first.map { Double($0.confidence) } ?? 0.0
        } : nil
        let rectangles: Int? = docRan ? (docSeg.results ?? []).count : nil
        return Collected(textTopConfidences: confidences, documentRectangleCount: rectangles)
    }

    /// Phase 2: pure map from collected observations plus the Tier-A
    /// screenshot-subtype flag to the frozen facts.
    ///
    /// `hasText` = any top-1 confidence ≥ 0.5 (nil when OCR unavailable);
    /// `textLineCount = min(50, count)` (nil when OCR unavailable);
    /// `isDocument` = any rectangle (nil when doc-seg unavailable);
    /// `screenshotProbability` = 1.0 screenshot subtype, else 0.7 document,
    /// else 0.2 text, else 0.0 (always filled when Tier-B ran: the subtype
    /// flag is Tier-A evidence, and unknown doc/text degrade to the else arm
    /// per the frozen rule — the caller keeps nil for never-run assets).
    /// Same inputs always give the same outputs: no Vision call, no I/O.
    /// Nonisolated: builds scalars only, so the off-main lane calls it
    /// without hopping back to the MainActor.
    nonisolated static func map(_ collected: Collected, isScreenshotSubtype: Bool) -> MappedFacts {
        // Frozen schema thresholds as locals (not statics) so this nonisolated
        // map touches no static — and no main-actor-isolated — state.
        let textConfidenceFloor = 0.5
        let textLineCountCap = 50

        let hasText = collected.textTopConfidences.map { $0.contains { $0 >= textConfidenceFloor } }
        let textLineCount = collected.textTopConfidences.map { min(textLineCountCap, $0.count) }
        let isDocument = collected.documentRectangleCount.map { $0 > 0 }
        let screenshotProbability: Double?
        if isScreenshotSubtype {
            screenshotProbability = 1.0
        } else if isDocument ?? false {
            screenshotProbability = 0.7
        } else if hasText ?? false {
            screenshotProbability = 0.2
        } else {
            screenshotProbability = 0.0
        }
        return MappedFacts(
            hasText: hasText,
            textLineCount: textLineCount,
            screenshotProbability: screenshotProbability,
            isDocument: isDocument
        )
    }
}
