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

enum SceneType: String, Codable, Sendable {
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
struct PhotoAnalysis: Identifiable, Codable, Sendable {
    var id: AssetID {
        assetID
    }

    let assetID: AssetID
    let technical: TechnicalAnalysis
    let people: PeopleAnalysis
    let composition: CompositionAnalysis
    let content: ContentAnalysis
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

    // swiftlint:disable function_parameter_count - factory assembles the six analysis facts in one call.
    /// Shared factory: clamps scores once and stamps the version.
    /// VisionAnalysisService calls this; it defines no clamp.
    static func make(
        assetID: AssetID,
        technical: TechnicalAnalysis,
        faceCount: Int,
        groupPhotoScore: Double?,
        subjectPlacementScore: Double?,
        sceneType: SceneType
    ) -> PhotoAnalysis {
        let sharp = clamped01(technical.sharpnessScore)
        let expo = clamped01(technical.exposureScore)
        let total = clamped01(0.6 * sharp + 0.4 * expo)
        return PhotoAnalysis(
            assetID: assetID,
            technical: technical,
            people: PeopleAnalysis(faceCount: max(0, faceCount), groupPhotoScore: groupPhotoScore.map(clamped01)),
            composition: CompositionAnalysis(
                aestheticScore: nil,
                subjectPlacementScore: subjectPlacementScore.map(clamped01),
                horizonScore: nil,
                visualBalanceScore: nil
            ),
            content: ContentAnalysis(sceneType: sceneType, tags: [], hasText: nil, screenshotProbability: nil),
            qualityScore: total,
            qualityBreakdown: QualityScoreBreakdown(
                technical: total, people: nil, composition: nil, content: nil, total: total
            ),
            analyzedAt: Date(),
            analysisVersion: currentVersion
        )
    }
    // swiftlint:enable function_parameter_count
}
