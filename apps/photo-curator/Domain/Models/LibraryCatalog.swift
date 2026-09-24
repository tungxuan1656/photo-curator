// swiftlint:disable file_length
import Foundation
import SwiftData

/// Availability of the durable catalog/reconciliation boundary. A missing
/// catalog store in `AppContainer` means the V3 container could not open;
/// these values describe the state after the container has opened.
enum CatalogAvailability: String, Codable, Sendable, Equatable {
    case available
    case stale
    case accessRequired
    case unavailable
}

enum CatalogStorageAvailability: String, Codable, Sendable, Equatable {
    case available
    case unavailable
}

enum CatalogAuthorizationSnapshot: String, Codable, Sendable, Equatable {
    case notDetermined
    case limited
    case authorized
    case denied
    case restricted
}

enum CatalogGenerationStatus: String, Codable, Sendable, Equatable {
    case building
    case committed
    case abandoned
}

/// Persisted failure categories are deliberately coarse and contain no
/// framework error text or asset identifiers.
enum CatalogFailureCategory: String, Codable, Sendable, Equatable {
    case accessRequired
    case authorizationChanged
    case cancelled
    case interrupted
    case duplicateAssetID
    case fetchFailed
    case incomplete
    case persistenceFailed
}

/// The durable relationship asserted by a comparison group. These values are
/// deliberately narrower than a general similarity label: a shared topic or
/// timestamp is not enough to create a group.
enum ComparisonGroupRelation: String, Codable, Sendable, Equatable {
    case retake
    case nearCopy
}

/// Compact, human-readable provenance for a comparison group. The evidence
/// itself remains outside SwiftData; only its stable references are stored.
enum ComparisonGroupReason: String, Codable, Sendable, Equatable {
    case imageSimilarity
    case crossDateImageSimilarity
    case sameCaptureImageSimilarity
}

enum ComparisonCoverageStatus: String, Codable, Sendable, Equatable {
    case complete
    case incomplete
    case unavailable
}

/// Coverage is explicit so a bounded candidate run cannot be presented as a
/// whole-library recall or accuracy claim.
struct ComparisonCoverage: Codable, Sendable, Equatable {
    let status: ComparisonCoverageStatus
    let assetCount: Int
    let eligibleAssetCount: Int
    let candidateCount: Int
    let attemptedComparisonCount: Int
    let successfulComparisonCount: Int
    let validatedCandidateCount: Int
    let acceptedEdgeCount: Int
    let groupedAssetCount: Int
    let unavailableAssetCount: Int
    let overflowedCandidateCount: Int

    init(
        status: ComparisonCoverageStatus,
        assetCount: Int,
        eligibleAssetCount: Int,
        candidateCount: Int,
        validatedCandidateCount: Int,
        groupedAssetCount: Int,
        unavailableAssetCount: Int,
        overflowedCandidateCount: Int,
        attemptedComparisonCount: Int? = nil,
        successfulComparisonCount: Int? = nil,
        acceptedEdgeCount: Int? = nil
    ) {
        self.status = status
        self.assetCount = assetCount
        self.eligibleAssetCount = eligibleAssetCount
        self.candidateCount = candidateCount
        self.attemptedComparisonCount = attemptedComparisonCount ?? candidateCount
        self.successfulComparisonCount = successfulComparisonCount ?? validatedCandidateCount
        self.validatedCandidateCount = validatedCandidateCount
        self.acceptedEdgeCount = acceptedEdgeCount ?? validatedCandidateCount
        self.groupedAssetCount = groupedAssetCount
        self.unavailableAssetCount = unavailableAssetCount
        self.overflowedCandidateCount = overflowedCandidateCount
    }

    private enum CodingKeys: String, CodingKey {
        case status, assetCount, eligibleAssetCount, candidateCount
        case attemptedComparisonCount, successfulComparisonCount, validatedCandidateCount
        case acceptedEdgeCount, groupedAssetCount, unavailableAssetCount, overflowedCandidateCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            status: container.decode(ComparisonCoverageStatus.self, forKey: .status),
            assetCount: container.decode(Int.self, forKey: .assetCount),
            eligibleAssetCount: container.decode(Int.self, forKey: .eligibleAssetCount),
            candidateCount: container.decode(Int.self, forKey: .candidateCount),
            validatedCandidateCount: container.decode(Int.self, forKey: .validatedCandidateCount),
            groupedAssetCount: container.decode(Int.self, forKey: .groupedAssetCount),
            unavailableAssetCount: container.decode(Int.self, forKey: .unavailableAssetCount),
            overflowedCandidateCount: container.decode(Int.self, forKey: .overflowedCandidateCount),
            attemptedComparisonCount: container.decodeIfPresent(Int.self, forKey: .attemptedComparisonCount),
            successfulComparisonCount: container.decodeIfPresent(Int.self, forKey: .successfulComparisonCount),
            acceptedEdgeCount: container.decodeIfPresent(Int.self, forKey: .acceptedEdgeCount)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encode(assetCount, forKey: .assetCount)
        try container.encode(eligibleAssetCount, forKey: .eligibleAssetCount)
        try container.encode(candidateCount, forKey: .candidateCount)
        try container.encode(attemptedComparisonCount, forKey: .attemptedComparisonCount)
        try container.encode(successfulComparisonCount, forKey: .successfulComparisonCount)
        try container.encode(validatedCandidateCount, forKey: .validatedCandidateCount)
        try container.encode(acceptedEdgeCount, forKey: .acceptedEdgeCount)
        try container.encode(groupedAssetCount, forKey: .groupedAssetCount)
        try container.encode(unavailableAssetCount, forKey: .unavailableAssetCount)
        try container.encode(overflowedCandidateCount, forKey: .overflowedCandidateCount)
    }
}

struct ComparisonMemberInput: Codable, Sendable, Equatable {
    let assetID: AssetID
    let evidenceReferenceID: String?

    init(assetID: AssetID, evidenceReferenceID: String? = nil) {
        self.assetID = assetID
        self.evidenceReferenceID = evidenceReferenceID
    }
}

/// A resolvable comparison claim. It names the source generation and both
/// asset revisions; the feature-print bytes themselves remain transient.
struct ComparisonEvidenceReferenceInput: Codable, Sendable, Equatable {
    let identifier: String
    let sourceGenerationID: UUID
    let firstAssetID: AssetID
    let firstAssetFingerprint: AssetModificationFingerprint
    let secondAssetID: AssetID
    let secondAssetFingerprint: AssetModificationFingerprint
    let analysisRevision: Int
    let providerRevision: String
}

struct ComparisonGroupInput: Codable, Sendable, Equatable {
    let id: UUID
    let relation: ComparisonGroupRelation
    let reason: ComparisonGroupReason
    let representativeAssetID: AssetID?
    let groupingRevision: String
    let providerRevision: String
    let evidenceReferenceIDs: [String]
    let evidenceReferences: [ComparisonEvidenceReferenceInput]
    let members: [ComparisonMemberInput]

    init(
        id: UUID,
        relation: ComparisonGroupRelation,
        reason: ComparisonGroupReason,
        representativeAssetID: AssetID? = nil,
        groupingRevision: String,
        providerRevision: String,
        evidenceReferenceIDs: [String],
        evidenceReferences: [ComparisonEvidenceReferenceInput] = [],
        members: [ComparisonMemberInput]
    ) {
        self.id = id
        self.relation = relation
        self.reason = reason
        self.representativeAssetID = representativeAssetID
        self.groupingRevision = groupingRevision
        self.providerRevision = providerRevision
        self.evidenceReferenceIDs = evidenceReferenceIDs
        self.evidenceReferences = evidenceReferences
        self.members = members
    }
}

struct ComparisonSnapshotInput: Codable, Sendable, Equatable {
    let id: UUID
    let catalogGenerationID: UUID
    let groupingRevision: String
    let providerRevision: String
    let coverage: ComparisonCoverage
    let groups: [ComparisonGroupInput]

    init(
        id: UUID = UUID(),
        catalogGenerationID: UUID,
        groupingRevision: String,
        providerRevision: String,
        coverage: ComparisonCoverage,
        groups: [ComparisonGroupInput]
    ) {
        self.id = id
        self.catalogGenerationID = catalogGenerationID
        self.groupingRevision = groupingRevision
        self.providerRevision = providerRevision
        self.coverage = coverage
        self.groups = groups
    }
}

struct ComparisonMemberSnapshot: Codable, Sendable, Equatable {
    let assetID: AssetID
    let ordinal: Int
    let evidenceReferenceID: String?
}

struct ComparisonGroupSnapshot: Codable, Sendable, Equatable {
    let id: UUID
    let ordinal: Int
    let relation: ComparisonGroupRelation
    let reason: ComparisonGroupReason
    let representativeAssetID: AssetID?
    let groupingRevision: String
    let providerRevision: String
    let evidenceReferenceIDs: [String]
    let evidenceReferences: [ComparisonEvidenceReferenceInput]
    let members: [ComparisonMemberSnapshot]
}

struct ComparisonSnapshot: Codable, Sendable, Equatable {
    let id: UUID
    let catalogGenerationID: UUID
    let groupingRevision: String
    let providerRevision: String
    let coverage: ComparisonCoverage
    let createdAt: Date
    let groups: [ComparisonGroupSnapshot]
}

typealias CatalogComparisonCoverage = ComparisonCoverage
typealias CatalogComparisonSnapshotInput = ComparisonSnapshotInput
typealias CatalogComparisonGroupInput = ComparisonGroupInput
typealias CatalogComparisonMemberInput = ComparisonMemberInput
typealias CatalogComparisonSnapshot = ComparisonSnapshot
typealias CatalogComparisonGroupSnapshot = ComparisonGroupSnapshot
typealias CatalogComparisonMemberSnapshot = ComparisonMemberSnapshot

/// Stable attachment point for future user-owned catalog records. The row is
/// bookkeeping only; scan-specific metadata belongs to immutable observations.
@Model
final class LibraryAsset {
    @Attribute(.unique) var assetID: String
    var lastObservedGenerationID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        assetID: String,
        lastObservedGenerationID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.assetID = assetID
        self.lastObservedGenerationID = lastObservedGenerationID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// One immutable, scan-specific metadata observation. `modificationDate ==
/// nil` is distinct from a missing fingerprint through the explicit presence
/// marker, matching `AssetModificationFingerprint`'s representation.
@Model
final class CatalogAssetObservation {
    @Attribute(.unique) var identity: String
    var generationID: UUID
    var assetID: String
    var creationDate: Date?
    var pixelWidth: Int
    var pixelHeight: Int
    var mediaSubtypeRawValue: String
    var isFavorite: Bool
    var isEdited: Bool
    var sourceRawValue: String
    var modificationDate: Date?
    var modificationFingerprintIsPresent: Bool

    init(generationID: UUID, asset: PhotoAsset) {
        identity = Self.identity(generationID: generationID, assetID: asset.id.rawValue)
        self.generationID = generationID
        assetID = asset.id.rawValue
        creationDate = asset.creationDate
        pixelWidth = asset.pixelWidth
        pixelHeight = asset.pixelHeight
        mediaSubtypeRawValue = asset.mediaSubtype.rawValue
        isFavorite = asset.isFavorite
        isEdited = asset.isEdited
        sourceRawValue = asset.source.rawValue
        modificationDate = asset.modificationFingerprint.modificationDate
        modificationFingerprintIsPresent = asset.modificationFingerprint.isPresent
    }

    static func identity(generationID: UUID, assetID: String) -> String {
        "\(generationID.uuidString)::\(assetID)"
    }

    var modificationFingerprint: AssetModificationFingerprint {
        if modificationFingerprintIsPresent {
            return AssetModificationFingerprint(modificationDate: modificationDate)
        }
        return .missing
    }

    var photoAsset: PhotoAsset {
        PhotoAsset(
            id: AssetID(rawValue: assetID),
            creationDate: creationDate,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            mediaSubtype: PhotoMediaSubtype(rawValue: mediaSubtypeRawValue) ?? .unknown,
            isFavorite: isFavorite,
            isEdited: isEdited,
            source: AssetSource(rawValue: sourceRawValue) ?? .unknown,
            modificationFingerprint: modificationFingerprint
        )
    }
}

@Model
final class CatalogGeneration {
    @Attribute(.unique) var id: UUID
    var statusRawValue: String
    var authorizationRawValue: String
    var startedAt: Date
    var completedAt: Date?
    var assetCount: Int
    var failureCategoryRawValue: String?

    init(
        id: UUID = UUID(),
        authorization: CatalogAuthorizationSnapshot,
        status: CatalogGenerationStatus = .building,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        assetCount: Int = 0,
        failureCategory: CatalogFailureCategory? = nil
    ) {
        self.id = id
        statusRawValue = status.rawValue
        authorizationRawValue = authorization.rawValue
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.assetCount = assetCount
        failureCategoryRawValue = failureCategory?.rawValue
    }

    var status: CatalogGenerationStatus {
        get { CatalogGenerationStatus(rawValue: statusRawValue) ?? .abandoned }
        set { statusRawValue = newValue.rawValue }
    }

    var authorization: CatalogAuthorizationSnapshot {
        CatalogAuthorizationSnapshot(rawValue: authorizationRawValue) ?? .restricted
    }

    var failureCategory: CatalogFailureCategory? {
        get {
            guard let failureCategoryRawValue else { return nil }
            return CatalogFailureCategory(rawValue: failureCategoryRawValue)
        }
        set { failureCategoryRawValue = newValue?.rawValue }
    }
}

/// Singleton publication state. `currentGenerationID` is the only pointer a
/// reader should use for a browseable snapshot.
@Model
final class CatalogState {
    static let singletonID = "catalog-state"

    @Attribute(.unique) var singletonKey: String
    var currentGenerationID: UUID?
    var latestAttemptID: UUID?
    var availabilityRawValue: String
    var updatedAt: Date

    init(
        currentGenerationID: UUID? = nil,
        latestAttemptID: UUID? = nil,
        availability: CatalogAvailability = .unavailable,
        updatedAt: Date = Date()
    ) {
        singletonKey = Self.singletonID
        self.currentGenerationID = currentGenerationID
        self.latestAttemptID = latestAttemptID
        availabilityRawValue = availability.rawValue
        self.updatedAt = updatedAt
    }

    var availability: CatalogAvailability {
        get { CatalogAvailability(rawValue: availabilityRawValue) ?? .unavailable }
        set { availabilityRawValue = newValue.rawValue }
    }
}

/// Additive V5 pointer for the comparison projection. Keeping this separate
/// from CatalogState leaves the V1-V4 model history unchanged.
@Model
final class CatalogComparisonState {
    static let singletonID = "catalog-comparison-state"

    @Attribute(.unique) var singletonKey: String
    var currentSnapshotID: UUID?
    var updatedAt: Date

    init(currentSnapshotID: UUID? = nil, updatedAt: Date = Date()) {
        singletonKey = Self.singletonID
        self.currentSnapshotID = currentSnapshotID
        self.updatedAt = updatedAt
    }
}

/// Immutable comparison snapshot projection. The current pointer lives on
/// CatalogComparisonState; a bounded history preserves already-open values
/// without allowing abandoned child projections to accumulate.
@Model
final class CatalogComparisonSnapshotProjection {
    @Attribute(.unique) var id: UUID
    var catalogGenerationID: UUID
    var groupingRevision: String
    var providerRevision: String
    var coverageStatusRawValue: String
    var assetCount: Int
    var eligibleAssetCount: Int
    var candidateCount: Int
    var attemptedComparisonCount: Int = 0
    var successfulComparisonCount: Int = 0
    var validatedCandidateCount: Int
    var acceptedEdgeCount: Int = 0
    var groupedAssetCount: Int
    var unavailableAssetCount: Int
    var overflowedCandidateCount: Int
    var createdAt: Date

    init(
        id: UUID,
        catalogGenerationID: UUID,
        groupingRevision: String,
        providerRevision: String,
        coverage: ComparisonCoverage,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.catalogGenerationID = catalogGenerationID
        self.groupingRevision = groupingRevision
        self.providerRevision = providerRevision
        coverageStatusRawValue = coverage.status.rawValue
        assetCount = coverage.assetCount
        eligibleAssetCount = coverage.eligibleAssetCount
        candidateCount = coverage.candidateCount
        attemptedComparisonCount = coverage.attemptedComparisonCount
        successfulComparisonCount = coverage.successfulComparisonCount
        validatedCandidateCount = coverage.validatedCandidateCount
        acceptedEdgeCount = coverage.acceptedEdgeCount
        groupedAssetCount = coverage.groupedAssetCount
        unavailableAssetCount = coverage.unavailableAssetCount
        overflowedCandidateCount = coverage.overflowedCandidateCount
        self.createdAt = createdAt
    }

    var coverage: ComparisonCoverage {
        ComparisonCoverage(
            status: ComparisonCoverageStatus(rawValue: coverageStatusRawValue) ?? .unavailable,
            assetCount: assetCount,
            eligibleAssetCount: eligibleAssetCount,
            candidateCount: candidateCount,
            validatedCandidateCount: validatedCandidateCount,
            groupedAssetCount: groupedAssetCount,
            unavailableAssetCount: unavailableAssetCount,
            overflowedCandidateCount: overflowedCandidateCount,
            attemptedComparisonCount: attemptedComparisonCount,
            successfulComparisonCount: successfulComparisonCount,
            acceptedEdgeCount: acceptedEdgeCount
        )
    }
}

/// Revision-bound provenance for one transiently measured pair. The row is
/// resolvable against catalog observations, never a persisted feature print.
@Model
final class CatalogComparisonEvidenceProjection {
    @Attribute(.unique) var identity: String
    var snapshotID: UUID
    var groupID: UUID
    var identifier: String
    var sourceGenerationID: UUID
    var firstAssetID: String
    var firstModificationDate: Date?
    var firstFingerprintIsPresent: Bool
    var secondAssetID: String
    var secondModificationDate: Date?
    var secondFingerprintIsPresent: Bool
    var analysisRevision: Int
    var providerRevision: String

    init(
        snapshotID: UUID,
        groupID: UUID,
        reference: ComparisonEvidenceReferenceInput
    ) {
        identity = Self.identity(snapshotID: snapshotID, groupID: groupID, identifier: reference.identifier)
        self.snapshotID = snapshotID
        self.groupID = groupID
        identifier = reference.identifier
        sourceGenerationID = reference.sourceGenerationID
        firstAssetID = reference.firstAssetID.rawValue
        firstModificationDate = reference.firstAssetFingerprint.modificationDate
        firstFingerprintIsPresent = reference.firstAssetFingerprint.isPresent
        secondAssetID = reference.secondAssetID.rawValue
        secondModificationDate = reference.secondAssetFingerprint.modificationDate
        secondFingerprintIsPresent = reference.secondAssetFingerprint.isPresent
        analysisRevision = reference.analysisRevision
        providerRevision = reference.providerRevision
    }

    static func identity(snapshotID: UUID, groupID: UUID, identifier: String) -> String {
        "\(snapshotID.uuidString)::\(groupID.uuidString)::\(identifier)"
    }

    var input: ComparisonEvidenceReferenceInput {
        ComparisonEvidenceReferenceInput(
            identifier: identifier,
            sourceGenerationID: sourceGenerationID,
            firstAssetID: AssetID(rawValue: firstAssetID),
            firstAssetFingerprint: firstFingerprintIsPresent
                ? AssetModificationFingerprint(modificationDate: firstModificationDate)
                : .missing,
            secondAssetID: AssetID(rawValue: secondAssetID),
            secondAssetFingerprint: secondFingerprintIsPresent
                ? AssetModificationFingerprint(modificationDate: secondModificationDate)
                : .missing,
            analysisRevision: analysisRevision,
            providerRevision: providerRevision
        )
    }
}

@Model
final class CatalogComparisonGroupProjection {
    @Attribute(.unique) var identity: String
    var snapshotID: UUID
    var groupID: UUID
    var ordinal: Int
    var relationRawValue: String
    var reasonRawValue: String
    var representativeAssetID: String?
    var groupingRevision: String
    var providerRevision: String
    var evidenceReferenceIDs: [String]
    var memberCount: Int

    init(
        snapshotID: UUID,
        groupID: UUID,
        ordinal: Int,
        relation: ComparisonGroupRelation,
        reason: ComparisonGroupReason,
        representativeAssetID: AssetID?,
        groupingRevision: String,
        providerRevision: String,
        evidenceReferenceIDs: [String],
        memberCount: Int
    ) {
        identity = Self.identity(snapshotID: snapshotID, groupID: groupID)
        self.snapshotID = snapshotID
        self.groupID = groupID
        self.ordinal = ordinal
        relationRawValue = relation.rawValue
        reasonRawValue = reason.rawValue
        self.representativeAssetID = representativeAssetID?.rawValue
        self.groupingRevision = groupingRevision
        self.providerRevision = providerRevision
        self.evidenceReferenceIDs = evidenceReferenceIDs
        self.memberCount = memberCount
    }

    static func identity(snapshotID: UUID, groupID: UUID) -> String {
        "\(snapshotID.uuidString)::\(groupID.uuidString)"
    }
}

@Model
final class CatalogComparisonMemberProjection {
    @Attribute(.unique) var identity: String
    var snapshotID: UUID
    var groupID: UUID
    var assetID: String
    var ordinal: Int
    var evidenceReferenceID: String?

    init(
        snapshotID: UUID,
        groupID: UUID,
        assetID: AssetID,
        ordinal: Int,
        evidenceReferenceID: String?
    ) {
        identity = Self.identity(snapshotID: snapshotID, groupID: groupID, assetID: assetID)
        self.snapshotID = snapshotID
        self.groupID = groupID
        self.assetID = assetID.rawValue
        self.ordinal = ordinal
        self.evidenceReferenceID = evidenceReferenceID
    }

    static func identity(snapshotID: UUID, groupID: UUID, assetID: AssetID) -> String {
        "\(snapshotID.uuidString)::\(groupID.uuidString)::\(assetID.rawValue)"
    }
}

/// Current work projection for one catalog asset and capability. Analysis
/// facts remain in the evidence boundary; this row stores only revisions,
/// status, and a reference to matching evidence.
@Model
final class AnalysisWorkState {
    @Attribute(.unique) var identity: String
    var assetID: String
    var capabilityRawValue: String
    var generationID: UUID?

    var requestedModificationDate: Date?
    var requestedFingerprintIsPresent: Bool
    var requestedAnalysisRevision: Int
    var requestedProviderRuntimeRevision: String

    var statusRawValue: String
    var reasonRawValue: String?

    var completedModificationDate: Date?
    var completedFingerprintIsPresent: Bool
    var completedAnalysisRevision: Int?
    var completedProviderRuntimeRevision: String?
    var evidenceIdentifier: String?

    init(
        assetID: String,
        generationID: UUID?,
        fingerprint: AssetModificationFingerprint,
        revision: AnalysisCapabilityRevision,
        status: AnalysisWorkStatus = .pending,
        reason: AnalysisWorkReason? = nil
    ) {
        identity = AnalysisWorkState.identity(assetID: assetID, capability: revision.capability)
        self.assetID = assetID
        capabilityRawValue = revision.capability.rawValue
        self.generationID = generationID
        requestedModificationDate = fingerprint.modificationDate
        requestedFingerprintIsPresent = fingerprint.isPresent
        requestedAnalysisRevision = revision.analysisRevision.rawValue
        requestedProviderRuntimeRevision = revision.providerRuntimeRevision.rawValue
        statusRawValue = status.rawValue
        reasonRawValue = reason?.rawValue
        completedModificationDate = nil
        completedFingerprintIsPresent = false
        completedAnalysisRevision = nil
        completedProviderRuntimeRevision = nil
        evidenceIdentifier = nil
    }

    static func identity(assetID: String, capability: AnalysisCapability) -> String {
        "\(capability.rawValue)::\(assetID)"
    }

    var capability: AnalysisCapability {
        AnalysisCapability(rawValue: capabilityRawValue) ?? .nativeImageFacts
    }

    var requestedAssetFingerprint: AssetModificationFingerprint {
        requestedFingerprintIsPresent
            ? AssetModificationFingerprint(modificationDate: requestedModificationDate)
            : .missing
    }

    var requestedRevision: AnalysisCapabilityRevision {
        AnalysisCapabilityRevision(
            capability: capability,
            analysisRevision: requestedAnalysisRevision,
            providerRuntimeRevision: requestedProviderRuntimeRevision
        )
    }

    var status: AnalysisWorkStatus {
        get { AnalysisWorkStatus(rawValue: statusRawValue) ?? .stale }
        set { statusRawValue = newValue.rawValue }
    }

    var reason: AnalysisWorkReason? {
        get { reasonRawValue.flatMap(AnalysisWorkReason.init(rawValue:)) }
        set { reasonRawValue = newValue?.rawValue }
    }

    var retryEligibility: AnalysisRetryEligibility {
        switch status {
        case .pending, .unavailable, .stale:
            reason?.retryEligibility ?? .automatic
        case .running, .available:
            .never
        }
    }

    var retryPolicy: AnalysisRetryPolicy {
        switch status {
        case .pending, .unavailable, .stale:
            reason?.retryPolicy ?? .automatic
        case .running, .available:
            .doNotRetry
        }
    }

    var completedAssetFingerprint: AssetModificationFingerprint? {
        guard completedAnalysisRevision != nil,
              completedProviderRuntimeRevision != nil
        else { return nil }
        return completedFingerprintIsPresent
            ? AssetModificationFingerprint(modificationDate: completedModificationDate)
            : .missing
    }

    var completedRevision: AnalysisCapabilityRevision? {
        guard let completedAnalysisRevision,
              let completedProviderRuntimeRevision
        else { return nil }
        return AnalysisCapabilityRevision(
            capability: capability,
            analysisRevision: completedAnalysisRevision,
            providerRuntimeRevision: completedProviderRuntimeRevision
        )
    }

    var evidence: AnalysisEvidenceReference? {
        guard let evidenceIdentifier,
              let completedAssetFingerprint,
              let completedRevision
        else { return nil }
        return AnalysisEvidenceReference(
            identifier: evidenceIdentifier,
            assetID: AssetID(rawValue: assetID),
            capability: capability,
            assetFingerprint: completedAssetFingerprint,
            revision: completedRevision
        )
    }

    func snapshot() -> AnalysisWorkStateSnapshot {
        AnalysisWorkStateSnapshot(
            assetID: AssetID(rawValue: assetID),
            capability: capability,
            generationID: generationID,
            requestedAssetFingerprint: requestedAssetFingerprint,
            requestedRevision: requestedRevision,
            status: status,
            reason: reason,
            completedAssetFingerprint: completedAssetFingerprint,
            completedRevision: completedRevision,
            evidence: evidence
        )
    }
}

// swiftlint:enable file_length
