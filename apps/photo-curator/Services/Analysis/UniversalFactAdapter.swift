import CoreGraphics
import Foundation
import Vision

/// Universal aesthetics + classification adapter (mini-018a, feat-018).
///
/// Two phases with no pipeline wiring: phase 1 (`collect`) runs the two new
/// Vision requests on the 512 px analysis image with the same handler pattern
/// as `VisionAnalysisService.performAll` (one handler, `.up`, independent
/// `try?` per request, cancellation checks between requests); phase 2 (`map`)
/// pure-maps the collected observations to the frozen fact triple
/// (`aestheticScore`, conservative semantic facts, `featurePrintAvailable`)
/// plus the transient `isUtility` flag (features/feat-018.md, frozen
/// 2026-09-16). Classification is deliberately narrower than Vision's raw
/// taxonomy: only the explicit allowlist below can produce a scene or tag.
///
/// Unavailable values are explicit: aesthetics throw/empty results map to
/// `nil`, classify throw/empty results map to `[]`, and no feature print maps
/// to `false`. No tier-B request, model, or dependency; no blob, box, or
/// location is read or persisted — only scalars cross the boundary.
enum UniversalFactAdapter {
    /// Durable revision for the exact identifier allowlist and confidence
    /// policy. Changing either requires a new value so cached facts do not
    /// masquerade as facts produced by the current mapper.
    static let semanticMappingRevision = "vision-scene-map-v1"

    /// Phase-1 snapshot of the two new observations. Pure data: nil/empty
    /// marks the frozen unavailable arms, never a fabricated value.
    nonisolated struct Collected: Sendable {
        /// First aesthetics observation `overallScore` ([-1, 1]); nil when the
        /// request threw or returned no results.
        let overallScore: Float?
        /// First aesthetics observation `isUtility`; false when unavailable.
        /// Transient utility-policy input only, never persisted.
        let isUtility: Bool
        /// Classify results in returned order; empty when the request threw
        /// or returned no results. Phase 2 sorts and takes the top 3.
        let classifications: [Classification]
        /// Availability is separate from an empty successful result.
        let classificationAvailability: FactAvailability
        /// Availability of the aesthetics observation.
        let aestheticAvailability: FactAvailability
    }

    /// One classify result: `VNClassificationObservation` identifier plus
    /// confidence, snapshotted off-main so phase 2 stays a pure map.
    nonisolated struct Classification: Sendable {
        let identifier: String
        let confidence: Double
    }

    /// Phase-2 output: the frozen fact triple plus transient `isUtility`.
    /// `isUtility` is utility-policy input only and is never persisted.
    struct MappedFacts: Sendable {
        let aestheticScore: Double?
        let tags: [SemanticTag]
        let sceneType: SceneType
        let classificationAvailability: FactAvailability
        let semanticMappingRevision: String
        let aestheticAvailability: FactAvailability
        let featurePrintAvailable: Bool
        let isUtility: Bool
    }

    /// Phase 1: collects the two new observations beside the existing
    /// face/print requests (parent Task 3 calls this from `performAll`).
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
        let aesthetics = VNCalculateImageAestheticsScoresRequest()
        let classify = VNClassifyImageRequest()
        try Task.checkCancellation()
        let aestheticsRan: Bool = autoreleasepool {
            (try? handler.perform([aesthetics])) != nil
        }
        try Task.checkCancellation()
        let classifyRan: Bool = autoreleasepool {
            (try? handler.perform([classify])) != nil
        }
        let scores = aesthetics.results?.first
        let snapshots = classifyRan ? (classify.results ?? []).map {
            Classification(identifier: $0.identifier, confidence: Double($0.confidence))
        } : []
        return Collected(
            overallScore: scores?.overallScore,
            isUtility: scores?.isUtility ?? false,
            classifications: snapshots,
            classificationAvailability: classifyRan ? .available : .unavailable,
            aestheticAvailability: aestheticsRan && scores != nil ? .available : .unavailable
        )
    }

    /// Phase 2: pure map from collected observations to the frozen facts.
    ///
    /// `aestheticScore = clamped01((overall + 1) / 2)` (nil when unavailable);
    /// `tags` is the top 3 supported classifications by confidence as
    /// `SemanticTag` ([] when unavailable). Scene mapping requires a supported
    /// identifier, a confidence of at least 0.75, and a 0.10 lead over a
    /// competing supported scene. Ties or unsupported ambiguity remain
    /// `.unknown` rather than being guessed. `featurePrintAvailable` passes
    /// through the existing first-print-or-nil signal (`hasPrint` false means
    /// false);
    /// `isUtility` passes through transient-only. Same inputs always give
    /// the same outputs: no Vision call, no I/O. MainActor like
    /// `PhotoAnalysis.make` (it constructs model values), so the
    /// nonisolated pipeline lane calls it with `await`.
    static func map(_ collected: Collected, hasPrint: Bool) -> MappedFacts {
        let confidenceFloor = 0.75
        let ambiguityMargin = 0.10
        let aestheticScore = collected.overallScore.map { PhotoAnalysis.clamped01((Double($0) + 1.0) / 2.0) }
        let supported = collected.classifications.compactMap { classification -> (Classification, SceneType)? in
            guard let scene = Self.sceneType(for: classification.identifier) else { return nil }
            return (classification, scene)
        }
        let ranked = supported.sorted {
            if $0.0.confidence != $1.0.confidence {
                return $0.0.confidence > $1.0.confidence
            }
            return $0.0.identifier < $1.0.identifier
        }
        let tags = ranked
            .prefix(3)
            .filter { $0.0.confidence >= confidenceFloor }
            .map { SemanticTag(name: $0.0.identifier, confidence: $0.0.confidence) }
        let sceneType: SceneType
        if let first = ranked.first, first.0.confidence >= confidenceFloor {
            let competing = ranked.dropFirst().first { $0.1 != first.1 }
            sceneType = competing == nil || first.0.confidence - competing!.0.confidence >= ambiguityMargin
                ? first.1
                : .unknown
        } else {
            sceneType = .unknown
        }
        return MappedFacts(
            aestheticScore: aestheticScore,
            tags: tags,
            sceneType: sceneType,
            classificationAvailability: collected.classificationAvailability,
            semanticMappingRevision: semanticMappingRevision,
            aestheticAvailability: collected.aestheticAvailability,
            featurePrintAvailable: hasPrint,
            isUtility: collected.isUtility
        )
    }

    /// Exact native identifiers intentionally supported by this revision.
    /// Related labels such as `beach`, `party`, or `restaurant` are not
    /// silently promoted to a broader scene category.
    private static func sceneType(for identifier: String) -> SceneType? {
        switch identifier {
        case "people": .people
        case "group": .group
        case "landscape": .landscape
        case "architecture": .architecture
        case "food": .food
        case "animal": .animal
        case "indoor": .indoor
        case "outdoor": .outdoor
        case "document": .document
        case "screenshot": .screenshot
        default: nil
        }
    }
}
