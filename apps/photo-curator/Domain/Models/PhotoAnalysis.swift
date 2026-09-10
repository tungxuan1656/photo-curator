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
