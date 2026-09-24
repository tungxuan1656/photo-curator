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
