import Foundation

/// The capability namespace is deliberately closed until a later feature adds
/// another persisted work-state contract.
enum AnalysisCapability: String, Codable, Hashable, Sendable, Equatable {
    case nativeImageFacts
}

struct AnalysisRevision: RawRepresentable, Codable, Hashable, Sendable, Equatable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    init(_ rawValue: Int) {
        self.init(rawValue: rawValue)
    }
}

struct AnalysisProviderRuntimeRevision: RawRepresentable, Codable, Hashable, Sendable, Equatable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }
}

typealias AnalysisProviderRevision = AnalysisProviderRuntimeRevision

/// The complete revision requested for one capability. A result is reusable
/// only when both revision components and the asset fingerprint match.
struct AnalysisCapabilityRevision: Codable, Hashable, Sendable, Equatable {
    let capability: AnalysisCapability
    let analysisRevision: AnalysisRevision
    let providerRuntimeRevision: AnalysisProviderRuntimeRevision

    init(
        capability: AnalysisCapability = .nativeImageFacts,
        analysisRevision: AnalysisRevision,
        providerRuntimeRevision: AnalysisProviderRuntimeRevision
    ) {
        self.capability = capability
        self.analysisRevision = analysisRevision
        self.providerRuntimeRevision = providerRuntimeRevision
    }

    init(
        capability: AnalysisCapability = .nativeImageFacts,
        analysisRevision: Int,
        providerRuntimeRevision: String
    ) {
        self.init(
            capability: capability,
            analysisRevision: AnalysisRevision(analysisRevision),
            providerRuntimeRevision: AnalysisProviderRuntimeRevision(providerRuntimeRevision)
        )
    }

    static var currentNativeImageFacts: Self {
        Self(
            capability: .nativeImageFacts,
            analysisRevision: PhotoAnalysis.currentVersion,
            providerRuntimeRevision: "native-image-facts-v1"
        )
    }
}

enum AnalysisWorkStatus: String, Codable, Hashable, Sendable, Equatable {
    case pending
    case running
    case available
    case unavailable
    case stale
}

/// Reasons are status metadata, not an implicit retry counter. `completedEmpty`
/// is included for typed result projection but is valid only with `.available`.
enum AnalysisWorkReason: String, Codable, Hashable, Sendable, Equatable {
    case accessRequired
    case iCloudWaiting
    case modelUnavailable
    case revisionStale
    case cancelled
    case transientFailure
    case unsupported
    case completedEmpty
}

enum AnalysisCommitOutcome: String, Codable, Hashable, Sendable, Equatable {
    case available
    case completedEmpty
}

/// A reference to evidence written by the evidence boundary. It contains no
/// pixels and does not make SwiftData the authority for analysis facts.
struct AnalysisEvidenceReference: Codable, Hashable, Sendable, Equatable {
    let identifier: String
    let assetID: AssetID
    let capability: AnalysisCapability
    let assetFingerprint: AssetModificationFingerprint
    let revision: AnalysisCapabilityRevision

    init(
        identifier: String,
        assetID: AssetID,
        capability: AnalysisCapability = .nativeImageFacts,
        assetFingerprint: AssetModificationFingerprint,
        revision: AnalysisCapabilityRevision
    ) {
        self.identifier = identifier
        self.assetID = assetID
        self.capability = capability
        self.assetFingerprint = assetFingerprint
        self.revision = revision
    }

    var evidenceID: String {
        identifier
    }
}

/// The only input accepted by the catalog commit boundary after evidence has
/// been durably written elsewhere.
struct AnalysisCommitCandidate: Codable, Hashable, Sendable, Equatable {
    let generationID: UUID
    let assetID: AssetID
    let assetFingerprint: AssetModificationFingerprint
    let revision: AnalysisCapabilityRevision
    let evidence: AnalysisEvidenceReference
    let outcome: AnalysisCommitOutcome

    init(
        generationID: UUID,
        assetID: AssetID,
        assetFingerprint: AssetModificationFingerprint,
        revision: AnalysisCapabilityRevision,
        evidence: AnalysisEvidenceReference,
        outcome: AnalysisCommitOutcome = .available
    ) {
        self.generationID = generationID
        self.assetID = assetID
        self.assetFingerprint = assetFingerprint
        self.revision = revision
        self.evidence = evidence
        self.outcome = outcome
    }
}

enum AnalysisCommitRejection: String, Codable, Hashable, Sendable, Equatable {
    case generationChanged
    case assetChanged
    case capabilityRevisionChanged
    case evidenceReferenceMismatch
    case workStateMissing
    case workNotRequested
    case workAlreadyCommitted
}

struct AnalysisCommitResult: Codable, Hashable, Sendable, Equatable {
    let committed: Bool
    let rejection: AnalysisCommitRejection?
    let state: AnalysisWorkStateSnapshot?

    static func committed(_ state: AnalysisWorkStateSnapshot) -> Self {
        Self(committed: true, rejection: nil, state: state)
    }

    static func rejected(_ reason: AnalysisCommitRejection) -> Self {
        Self(committed: false, rejection: reason, state: nil)
    }
}

struct AnalysisWorkStateSnapshot: Codable, Hashable, Sendable, Equatable {
    let assetID: AssetID
    let capability: AnalysisCapability
    let generationID: UUID?
    let requestedAssetFingerprint: AssetModificationFingerprint
    let requestedRevision: AnalysisCapabilityRevision
    let status: AnalysisWorkStatus
    let reason: AnalysisWorkReason?
    let completedAssetFingerprint: AssetModificationFingerprint?
    let completedRevision: AnalysisCapabilityRevision?
    let evidence: AnalysisEvidenceReference?
}

enum CatalogCommitEventKind: String, Codable, Hashable, Sendable, Equatable {
    case generationCommitted
    case analysisCommitted
}

/// Advisory events are yielded only after the corresponding SwiftData save
/// succeeds. Consumers must re-read the catalog rather than treat an event as
/// durable state.
struct CatalogCommitEvent: Codable, Hashable, Sendable, Equatable {
    let id: UUID
    let kind: CatalogCommitEventKind
    let generationID: UUID
    let assetID: AssetID?
    let capability: AnalysisCapability?
    let analysisResult: AnalysisCommitResult?
    let occurredAt: Date
}
