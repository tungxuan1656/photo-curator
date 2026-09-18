import Foundation

/// Analysis knobs. Version bumps on incompatible Vision/reading changes (performance §5).
struct AnalysisConfiguration: Codable, Sendable {
    var analysisVersion: Int
}

/// Run budgets. Values: performance §1. Tune after profiling on the oldest supported device.
struct PerformanceConfiguration: Codable, Sendable {
    var analysisBatchSize: Int
    var maxConcurrentImageRequests: Int
    var heavyVisionConcurrency: Int
    var checkpointEveryAssets: Int
    var checkpointEverySeconds: TimeInterval
    var progressMaxHertz: Double
}

/// Derived-analysis cache policy. Holds compact values only, never image blobs (performance §5).
struct CacheConfiguration: Codable, Sendable {
    var enabled: Bool
    var schemaVersion: Int
}

/// All selection knobs in one place. Key names are canonical per selection-engine §12.
/// Policy meaning: selection-rules; mechanics: selection-engine; budgets: performance.
struct SelectionConfiguration: Codable, Sendable {
    var analysisImageMaxDimension: Int
    var duplicateTimeWindow: TimeInterval
    var duplicateSimilarityThreshold: Double
    var nearDuplicateSimilarityThreshold: Double
    var momentSoftGap: TimeInterval
    var momentHardGap: TimeInterval
    var maxPhotosPerMoment: Int
    var targetSelectionRatio: Double
    var minimumFinalCount: Int
    var maximumFinalCount: Int
    var shortlistMultiplier: Double
    var technicalQualityWeight: Double
    var humanImportanceWeight: Double
    var representativenessWeight: Double
    var uniquenessWeight: Double
    var diversityWeight: Double
    var coverageWeight: Double
    var redundancyPenaltyWeight: Double
    var favoriteBonus: Double
    var editedBonus: Double
    var lowQualityThreshold: Double
    var hardRejectThreshold: Double
}

/// Centralized knobs; scatter no constants through views or services.
struct AppConfiguration: Codable, Sendable {
    var analysis: AnalysisConfiguration
    var selection: SelectionConfiguration
    var performance: PerformanceConfiguration
    var cache: CacheConfiguration
    var quality: QualityCurationPolicy
    var configVersion: Int

    private enum CodingKeys: String, CodingKey {
        case analysis, selection, performance, cache, quality, configVersion
    }

    init(
        analysis: AnalysisConfiguration,
        selection: SelectionConfiguration,
        performance: PerformanceConfiguration,
        cache: CacheConfiguration,
        quality: QualityCurationPolicy = .default,
        configVersion: Int
    ) {
        self.analysis = analysis
        self.selection = selection
        self.performance = performance
        self.cache = cache
        self.quality = quality
        self.configVersion = configVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        analysis = try container.decode(AnalysisConfiguration.self, forKey: .analysis)
        selection = try container.decode(SelectionConfiguration.self, forKey: .selection)
        performance = try container.decode(PerformanceConfiguration.self, forKey: .performance)
        cache = try container.decode(CacheConfiguration.self, forKey: .cache)
        quality = try container.decodeIfPresent(QualityCurationPolicy.self, forKey: .quality) ?? .default
        configVersion = try container.decode(Int.self, forKey: .configVersion)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(analysis, forKey: .analysis)
        try container.encode(selection, forKey: .selection)
        try container.encode(performance, forKey: .performance)
        try container.encode(cache, forKey: .cache)
        try container.encode(quality, forKey: .quality)
        try container.encode(configVersion, forKey: .configVersion)
    }

    static var `default`: Self {
        Self(
            analysis: AnalysisConfiguration(analysisVersion: 4),
            selection: SelectionConfiguration(
                analysisImageMaxDimension: 512,
                duplicateTimeWindow: 90,
                duplicateSimilarityThreshold: 0.5,
                nearDuplicateSimilarityThreshold: 0.5,
                momentSoftGap: 180,
                momentHardGap: 900,
                maxPhotosPerMoment: 3,
                targetSelectionRatio: 0.10,
                minimumFinalCount: 30,
                maximumFinalCount: 150,
                shortlistMultiplier: 2.0,
                technicalQualityWeight: 1.0,
                humanImportanceWeight: 1.0,
                representativenessWeight: 1.0,
                uniquenessWeight: 1.0,
                diversityWeight: 1.0,
                coverageWeight: 1.0,
                redundancyPenaltyWeight: 1.0,
                favoriteBonus: 0.0,
                editedBonus: 0.0,
                lowQualityThreshold: 0.5,
                hardRejectThreshold: 0.25
            ),
            performance: PerformanceConfiguration(
                analysisBatchSize: 32,
                maxConcurrentImageRequests: 2,
                heavyVisionConcurrency: 2,
                checkpointEveryAssets: 25,
                checkpointEverySeconds: 10,
                progressMaxHertz: 4
            ),
            cache: CacheConfiguration(enabled: true, schemaVersion: 1),
            quality: .default,
            configVersion: 1
        )
    }
}
