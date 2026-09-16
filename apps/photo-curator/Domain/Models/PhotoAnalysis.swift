import CoreGraphics
import Foundation

/// Pixel-derived sharpness/exposure facts. Higher score is better; higher probability is more defective.
struct TechnicalAnalysis: Codable, Sendable {
    let sharpnessScore: Double
    let exposureScore: Double
    let resolutionScore: Double
    let blurProbability: Double
    let underexposureProbability: Double
    let overexposureProbability: Double
}

/// Stored people facts: counts and summary scores only. Face boxes are session-temp and never persisted.
struct PeopleAnalysis: Codable, Sendable {
    let faceCount: Int
    let groupPhotoScore: Double?

    var containsPeople: Bool {
        faceCount > 0
    }
}

/// Composition signals. Absent (`nil`) means not run, distinct from middling (`0.5`).
struct CompositionAnalysis: Codable, Sendable {
    let aestheticScore: Double?
    let subjectPlacementScore: Double?
    let horizonScore: Double?
    let visualBalanceScore: Double?
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

struct ContentAnalysis: Codable, Sendable {
    let sceneType: SceneType
    let tags: [SemanticTag]
    let hasText: Bool?
    let screenshotProbability: Double?
}

/// Stored quality rollup. Weighting and tier cutoffs are owned by selection-rules; this file stores fields only.
struct QualityScoreBreakdown: Codable, Sendable {
    let technical: Double
    let people: Double?
    let composition: Double?
    let content: Double?
    let total: Double
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
struct AnalysisInput: @unchecked Sendable {
    let assetID: AssetID
    let image: CGImage
}

extension PhotoAnalysis {
    static var currentVersion: Int {
        AppConfiguration.default.analysis.analysisVersion
    }

    /// Single normalization rule. Internal so VisionAnalysisService shares it.
    static func clamped01(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }

    // swiftlint:disable function_parameter_count - factory assembles the version-2 universal facts in one call.
    /// Shared factory: clamps scores once and stamps the version.
    /// VisionAnalysisService calls this; it defines no clamp.
    /// `aestheticScore`/`tags`/`featurePrintAvailable` are the feat-018
    /// universal facts (frozen schema); unavailable arms are nil / [] / false.
    /// `sceneType` rule is unchanged (faces-based) in feat-018.
    static func make(
        assetID: AssetID,
        technical: TechnicalAnalysis,
        faceCount: Int,
        groupPhotoScore: Double?,
        subjectPlacementScore: Double?,
        sceneType: SceneType,
        aestheticScore: Double? = nil,
        tags: [SemanticTag] = [],
        featurePrintAvailable: Bool = false
    ) -> PhotoAnalysis {
        let sharp = clamped01(technical.sharpnessScore)
        let expo = clamped01(technical.exposureScore)
        let total = clamped01(0.6 * sharp + 0.4 * expo)
        return PhotoAnalysis(
            assetID: assetID,
            technical: technical,
            people: PeopleAnalysis(faceCount: max(0, faceCount), groupPhotoScore: groupPhotoScore.map(clamped01)),
            composition: CompositionAnalysis(
                aestheticScore: aestheticScore.map(clamped01),
                subjectPlacementScore: subjectPlacementScore.map(clamped01),
                horizonScore: nil,
                visualBalanceScore: nil
            ),
            content: ContentAnalysis(sceneType: sceneType, tags: tags, hasText: nil, screenshotProbability: nil),
            featurePrintAvailable: featurePrintAvailable,
            qualityScore: total,
            qualityBreakdown: QualityScoreBreakdown(
                technical: total, people: nil, composition: nil, content: nil, total: total
            ),
            analyzedAt: Date(),
            analysisVersion: currentVersion
        )
    }

    // swiftlint:enable function_parameter_count

    /// Version-tolerant decode: version-1 rows lack `featurePrintAvailable`;
    /// `decodeIfPresent` defaults them to `false` so the requeue rule holds by
    /// miss (version gate), not crash (decode throw). Encode stays symmetric.
    enum V2CodingKeys: String, CodingKey {
        case assetID, technical, people, composition, content, featurePrintAvailable
        case qualityScore, qualityBreakdown, analyzedAt, analysisVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: V2CodingKeys.self)
        assetID = try container.decode(AssetID.self, forKey: .assetID)
        technical = try container.decode(TechnicalAnalysis.self, forKey: .technical)
        people = try container.decode(PeopleAnalysis.self, forKey: .people)
        composition = try container.decode(CompositionAnalysis.self, forKey: .composition)
        content = try container.decode(ContentAnalysis.self, forKey: .content)
        featurePrintAvailable = try container.decodeIfPresent(Bool.self, forKey: .featurePrintAvailable) ?? false
        qualityScore = try container.decode(Double.self, forKey: .qualityScore)
        qualityBreakdown = try container.decodeIfPresent(QualityScoreBreakdown.self, forKey: .qualityBreakdown)
        analyzedAt = try container.decode(Date.self, forKey: .analyzedAt)
        analysisVersion = try container.decode(Int.self, forKey: .analysisVersion)
    }
}
