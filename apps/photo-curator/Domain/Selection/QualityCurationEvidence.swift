import Foundation

enum QualityPairRelation: String, Codable, Sendable {
    case retake
    case meaningfulVariant
    case distinctContent
    case uncertain
}

enum QualityPairPreference: String, Codable, Sendable {
    case chooseA
    case chooseB
    case tie
    case abstain
}

enum QualityPairReason: String, Codable, Sendable {
    case composition
    case subjectVisibility
    case expression
    case action
    case framing
    case groupComposition
    case redundant
    case insufficientDetail
}

/// Request identity stays run-local and is never sent to the model.
struct QualityPairRequest: Sendable {
    let requestID: UUID
    let generation: Int
    let first: AssetID
    let second: AssetID
    let task: String
}

/// Validated model evidence. It contains no image, prompt, or raw-output data.
struct QualityPairJudgment: Sendable {
    let requestID: UUID
    let generation: Int
    let relation: QualityPairRelation
    let preference: QualityPairPreference
    let reasons: [QualityPairReason]
}

struct QualityComparisonCounts: Codable, Sendable {
    var planned: Int = 0
    var attempted: Int = 0
    var applied: Int = 0
    var skipped: Int = 0
    var failed: Int = 0
}

/// Compact result provenance. Raw comparisons and photo-linked evidence remain transient.
struct QualityExecutionMetadata: Codable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let requestedMode: QualityMode
    let executedMode: QualityMode
    let engineVersion: Int
    let configVersion: Int
    let groupingVersion: Int
    let promptVersion: String
    let modelID: String?
    let modelRevision: String?
    let modelManifestDigest: String?
    let runtimeRevision: String?
    let comparisonCounts: QualityComparisonCounts
    let degradationReason: QualityDegradationReason?

    init(
        requestedMode: QualityMode,
        executedMode: QualityMode,
        engineVersion: Int = 4,
        configVersion: Int = 2,
        groupingVersion: Int = 1,
        promptVersion: String = "compare-v1",
        modelID: String? = nil,
        modelRevision: String? = nil,
        modelManifestDigest: String? = nil,
        runtimeRevision: String? = nil,
        comparisonCounts: QualityComparisonCounts = .init(),
        degradationReason: QualityDegradationReason? = nil
    ) {
        schemaVersion = Self.schemaVersion
        self.requestedMode = requestedMode
        self.executedMode = executedMode
        self.engineVersion = engineVersion
        self.configVersion = configVersion
        self.groupingVersion = groupingVersion
        self.promptVersion = promptVersion
        self.modelID = modelID
        self.modelRevision = modelRevision
        self.modelManifestDigest = modelManifestDigest
        self.runtimeRevision = runtimeRevision
        self.comparisonCounts = comparisonCounts
        self.degradationReason = degradationReason
    }
}

enum QualityGroupOutcome: String, Codable, Sendable {
    case selected
    case unavailableOnly
    case unusableOnly
    case userExcluded
    case coveredBySelectedRepresentative
    case repaired
}

/// An auditable group outcome without retaining pixels or model responses.
struct QualityGroupAudit: Codable, Sendable {
    let groupID: UUID
    let memberCount: Int
    let selectedAssetCount: Int
    let outcome: QualityGroupOutcome
}

struct QualityCurationEvidence: Codable, Sendable {
    let metadata: QualityExecutionMetadata
    let groupAudits: [QualityGroupAudit]
}
