import CoreGraphics
import Foundation

/// Pixel-derived sharpness/exposure facts. Higher score is better; higher probability is more defective.
struct TechnicalAnalysis: Codable, Sendable {
    let sharpnessScore: Double
    let exposureScore: Double
    /// Score of the bounded analysis image, not the asset's original pixels.
    /// Kept separate from source-resolution facts so a resized Vision input is
    /// never presented as the original photo resolution.
    let analysisImageResolutionScore: Double?
    /// Legacy compatibility projection. New writers also populate the explicit
    /// `analysisImageResolutionScore`; consumers should migrate before using
    /// this value as a user-facing resolution fact.
    let resolutionScore: Double
    let blurProbability: Double
    let underexposureProbability: Double
    let overexposureProbability: Double
}

/// Stored people facts: counts and summary scores only. Face boxes are session-temp and never persisted.
/// feat-020 adds `minFaceQuality`/`meanFaceQuality` (per-face distribution min/mean, 0…1, nil when
/// no faces or quality unavailable): derived scalars only, computed transiently by
/// `GroupEvidenceCalculator` from the Tier-A face observations, never boxes/landmarks/pixels.
struct PeopleAnalysis: Codable, Sendable {
    let faceCount: Int
    /// Distinguishes a successful zero-face result from a failed or skipped
    /// detector. Nil is retained for legacy rows that predate this fact.
    let faceDetectionStatus: FaceDetectionStatus?
    /// Maximum per-face capture-quality observation. This is not subject
    /// placement and is not a calibrated group-quality score.
    let bestFaceCaptureQuality: Double?
    let faceQualityAvailability: FactAvailability?
    /// Legacy field retained for decoding. New native analyses do not claim a
    /// calibrated group-quality score from face count alone.
    let groupPhotoScore: Double?
    let minFaceQuality: Double?
    let meanFaceQuality: Double?

    var containsPeople: Bool {
        switch faceDetectionStatus {
        case .facesDetected:
            return true
        case .noFaces, .unavailable, .notRun:
            return false
        case nil:
            return faceCount > 0
        }
    }
}

/// Durable status for the face detector. `.noFaces` is a confirmed result;
/// `.unavailable` and `.notRun` must not be treated as negative evidence.
enum FaceDetectionStatus: String, Codable, Sendable {
    case notRun
    case unavailable
    case noFaces
    case facesDetected
}

/// Availability of an analysis fact. Optional fields in older rows decode to
/// nil; new rows use this status where a missing value affects interpretation.
enum FactAvailability: String, Codable, Sendable {
    case notRun
    case unavailable
    case available
}

/// Composition signals. Absent (`nil`) means not run, distinct from middling (`0.5`).
/// feat-019 adds `salientRegionCount` (Tier-B attention saliency, 0…10 capped);
/// `horizonScore`/`visualBalanceScore` are now populated by Tier-B, nil when not run.
struct CompositionAnalysis: Codable, Sendable {
    let aestheticScore: Double?
    let aestheticAvailability: FactAvailability?
    /// Legacy field retained for decoding. New native analyses store face
    /// capture quality under `PeopleAnalysis.bestFaceCaptureQuality`.
    let subjectPlacementScore: Double?
    let horizonScore: Double?
    let visualBalanceScore: Double?
    let salientRegionCount: Int?
}

/// One semantic tag with confidence. Keep few, high-value tags only.
struct SemanticTag: Codable, Sendable {
    let name: String
    let confidence: Double
}

enum SceneType: String, Codable, Sendable, Hashable {
    case people, group, landscape, architecture, food, animal
    case indoor, outdoor, document, screenshot, other, unknown
}

/// feat-019 adds `textLineCount` (0…50 capped) and `isDocument` (Tier-B
/// document segmentation); `hasText`/`screenshotProbability` are now populated
/// by Tier-B, nil when utility Tier-B never ran. Raw strings are never stored.
struct ContentAnalysis: Codable, Sendable {
    let sceneType: SceneType
    let tags: [SemanticTag]
    let classificationAvailability: FactAvailability?
    let semanticMappingRevision: String?
    let hasText: Bool?
    let textLineCount: Int?
    let screenshotProbability: Double?
    let isDocument: Bool?
}

/// Stored quality rollup. Weighting and tier cutoffs are owned by selection-rules; this file stores fields only.
struct QualityScoreBreakdown: Codable, Sendable {
    let technical: Double
    let people: Double?
    let composition: Double?
    let content: Double?
    let total: Double
    /// The native factory currently records the technical gate only; the
    /// selection scorer owns the later ranked score and weights.
    let scoreKind: QualityScoreKind?
}

enum QualityScoreKind: String, Codable, Sendable {
    case technicalGate
    case finalSelection
}

/// Derived facts about one photo. Facts live here; choices live in `Decision`.
/// `featurePrintAvailable` records that a transient Vision feature print was
/// produced for this analysis (feat-018 universal schema, version 2).
/// Availability only: the print blob itself stays run-local and is never
/// persisted, per the data-model §4 invariant.
struct PhotoAnalysis: Identifiable, Codable, Sendable {
    var id: AssetID {
        assetID
    }

    let assetID: AssetID
    let technical: TechnicalAnalysis
    let people: PeopleAnalysis
    let composition: CompositionAnalysis
    let content: ContentAnalysis
    /// True when a feature print was produced transiently for this analysis.
    /// False means no print (nil request result); the asset groups as a
    /// singleton. Version-1 rows (no key) decode to `false` via `init(from:)`.
    let featurePrintAvailable: Bool
    let qualityScore: Double
    let qualityBreakdown: QualityScoreBreakdown?
    let analyzedAt: Date
    let analysisVersion: Int
}

/// Ephemeral analysis input. Never persisted; the image is released after analysis.
/// `isScreenshotSubtype` is the Tier-A PhotoKit subtype flag (no pixels, no EXIF);
/// the pipeline sets it from `PhotoAsset.mediaSubtype` so performAll needs no asset.
struct AnalysisInput: @unchecked Sendable {
    let assetID: AssetID
    let image: CGImage
    let isScreenshotSubtype: Bool
}

extension PhotoAnalysis {
    static var currentVersion: Int {
        AppConfiguration.default.analysis.analysisVersion
    }

    /// Single normalization rule. Internal so VisionAnalysisService shares it.
    static func clamped01(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }

    // swiftlint:disable function_parameter_count - factory assembles the version-4 facts in one call.
    /// Shared factory: clamps scores once and stamps the version.
    /// VisionAnalysisService calls this; it defines no clamp.
    /// `aestheticScore`/`tags`/`featurePrintAvailable` are the feat-018
    /// universal facts (frozen schema); `horizonScore`/`visualBalanceScore`/
    /// `salientRegionCount` (feat-019a) and `hasText`/`textLineCount`/
    /// `screenshotProbability`/`isDocument` (feat-019b) are the Tier-B facts
    /// (frozen routing); `minFaceQuality`/`meanFaceQuality` (feat-020) are the
    /// transient per-face distribution scalars. Unavailable arms are nil / [] / false.
    static func make(
        assetID: AssetID,
        technical: TechnicalAnalysis,
        faceCount: Int,
        faceDetectionStatus: FaceDetectionStatus? = nil,
        groupPhotoScore _: Double?,
        subjectPlacementScore _: Double?,
        bestFaceCaptureQuality: Double? = nil,
        faceQualityAvailability: FactAvailability? = nil,
        sceneType: SceneType,
        aestheticScore: Double? = nil,
        aestheticAvailability: FactAvailability? = nil,
        tags: [SemanticTag] = [],
        classificationAvailability: FactAvailability? = nil,
        semanticMappingRevision: String? = nil,
        featurePrintAvailable: Bool = false,
        horizonScore: Double? = nil,
        visualBalanceScore: Double? = nil,
        salientRegionCount: Int? = nil,
        hasText: Bool? = nil,
        textLineCount: Int? = nil,
        screenshotProbability: Double? = nil,
        isDocument: Bool? = nil,
        minFaceQuality: Double? = nil,
        meanFaceQuality: Double? = nil
    ) -> PhotoAnalysis {
        let sharp = clamped01(technical.sharpnessScore)
        let expo = clamped01(technical.exposureScore)
        let total = clamped01(0.6 * sharp + 0.4 * expo)
        return PhotoAnalysis(
            assetID: assetID,
            technical: technical,
            people: PeopleAnalysis(
                faceCount: max(0, faceCount),
                faceDetectionStatus: faceDetectionStatus,
                bestFaceCaptureQuality: bestFaceCaptureQuality.map(clamped01),
                faceQualityAvailability: faceQualityAvailability,
                // A count alone is evidence of detections, not calibrated
                // group quality. New native rows leave this legacy field nil.
                groupPhotoScore: nil,
                minFaceQuality: minFaceQuality.map(clamped01),
                meanFaceQuality: meanFaceQuality.map(clamped01)
            ),
            composition: CompositionAnalysis(
                aestheticScore: aestheticScore.map(clamped01),
                aestheticAvailability: aestheticAvailability,
                subjectPlacementScore: nil,
                horizonScore: horizonScore.map(clamped01),
                visualBalanceScore: visualBalanceScore.map(clamped01),
                salientRegionCount: salientRegionCount.map { min(10, max(0, $0)) }
            ),
            content: ContentAnalysis(
                sceneType: sceneType,
                tags: tags,
                classificationAvailability: classificationAvailability,
                semanticMappingRevision: semanticMappingRevision,
                hasText: hasText,
                textLineCount: textLineCount.map { min(50, max(0, $0)) },
                screenshotProbability: screenshotProbability.map(clamped01),
                isDocument: isDocument
            ),
            featurePrintAvailable: featurePrintAvailable,
            qualityScore: total,
            qualityBreakdown: QualityScoreBreakdown(
                technical: total,
                people: nil,
                composition: nil,
                content: nil,
                total: total,
                scoreKind: .technicalGate
            ),
            analyzedAt: Date(),
            analysisVersion: currentVersion
        )
    }

    // swiftlint:enable function_parameter_count

    /// Version-tolerant decode: version-1 rows lack `featurePrintAvailable`;
    /// version-2 rows lack the three feat-019 fields. The new fields are all
    /// Optional, so whole-struct decode defaults them to nil; the only
    /// hand-written arm is the non-Optional `featurePrintAvailable` default.
    /// The requeue rule holds by miss (version gate), not crash (decode
    /// throw). Encode stays symmetric.
    enum V2CodingKeys: String, CodingKey {
        case assetID, technical, people, composition, content, featurePrintAvailable
        case qualityScore, qualityBreakdown, analyzedAt, analysisVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: V2CodingKeys.self)
        assetID = try container.decode(AssetID.self, forKey: .assetID)
        technical = try container.decode(TechnicalAnalysis.self, forKey: .technical)
        people = try container.decode(PeopleAnalysis.self, forKey: .people)
        composition = (try? container.decode(CompositionAnalysis.self, forKey: .composition))
            ?? CompositionAnalysis(
                aestheticScore: nil,
                aestheticAvailability: nil,
                subjectPlacementScore: nil,
                horizonScore: nil,
                visualBalanceScore: nil,
                salientRegionCount: nil
            )
        content = (try? container.decode(ContentAnalysis.self, forKey: .content))
            ?? ContentAnalysis(
                sceneType: .unknown,
                tags: [],
                classificationAvailability: nil,
                semanticMappingRevision: nil,
                hasText: nil,
                textLineCount: nil,
                screenshotProbability: nil,
                isDocument: nil
            )
        featurePrintAvailable = try container.decodeIfPresent(Bool.self, forKey: .featurePrintAvailable) ?? false
        qualityScore = try container.decode(Double.self, forKey: .qualityScore)
        qualityBreakdown = try container.decodeIfPresent(QualityScoreBreakdown.self, forKey: .qualityBreakdown)
        analyzedAt = try container.decode(Date.self, forKey: .analyzedAt)
        analysisVersion = try container.decode(Int.self, forKey: .analysisVersion)
    }
}
