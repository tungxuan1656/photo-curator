import Foundation
import SwiftData

enum ReviewIntent: String, Codable, Sendable {
    case cleanup
    case album
}

enum CleanupDisposition: String, Codable, Sendable {
    case undecided
    case keep
    case stagedForDeletion
}

enum AlbumMembership: String, Codable, Sendable {
    case unset
    case included
    case excluded
}

enum ReviewProgress: String, Codable, Sendable {
    case unseen
    case inProgress
    case reviewed
}

/// One applied user choice for durable persistence. Scope names the exact
/// asset set; dimension mutations stay independent per review-rules.
struct ReviewWorkspaceChoice: Sendable {
    let scopeID: UUID
    let assetIDs: [AssetID]
    let albumMembership: AlbumMembership?
    let cleanupDisposition: CleanupDisposition?
    let reviewProgress: ReviewProgress?
    /// Heterogeneous bulk writes (for example a winner swap) stay one exact
    /// transaction instead of being split into several optimistic writes.
    let albumMemberships: [AssetID: AlbumMembership]
    let cleanupDispositions: [AssetID: CleanupDisposition]
    let reviewProgresses: [AssetID: ReviewProgress]
    let previousAlbumMemberships: [AssetID: AlbumMembership]
    let previousCleanupDispositions: [AssetID: CleanupDisposition]
    let previousReviewProgresses: [AssetID: ReviewProgress]
    /// Monotonic within a live review model. `issuedAt` is also used by the
    /// store so an older queued action cannot overwrite a newer one.
    let generation: UInt64
    let issuedAt: Date

    init(
        scopeID: UUID,
        assetIDs: [AssetID],
        albumMembership: AlbumMembership? = nil,
        cleanupDisposition: CleanupDisposition? = nil,
        reviewProgress: ReviewProgress? = nil,
        albumMemberships: [AssetID: AlbumMembership] = [:],
        cleanupDispositions: [AssetID: CleanupDisposition] = [:],
        reviewProgresses: [AssetID: ReviewProgress] = [:],
        previousAlbumMemberships: [AssetID: AlbumMembership] = [:],
        previousCleanupDispositions: [AssetID: CleanupDisposition] = [:],
        previousReviewProgresses: [AssetID: ReviewProgress] = [:],
        generation: UInt64 = 0,
        issuedAt: Date = Date()
    ) {
        self.scopeID = scopeID
        self.assetIDs = assetIDs
        self.albumMembership = albumMembership
        self.cleanupDisposition = cleanupDisposition
        self.reviewProgress = reviewProgress
        self.albumMemberships = albumMemberships
        self.cleanupDispositions = cleanupDispositions
        self.reviewProgresses = reviewProgresses
        self.previousAlbumMemberships = previousAlbumMemberships
        self.previousCleanupDispositions = previousCleanupDispositions
        self.previousReviewProgresses = previousReviewProgresses
        self.generation = generation
        self.issuedAt = issuedAt
    }

    var effectiveAlbumMemberships: [AssetID: AlbumMembership] {
        var values = albumMemberships
        if let albumMembership {
            for assetID in assetIDs {
                values[assetID] = albumMembership
            }
        }
        return values
    }

    var effectiveCleanupDispositions: [AssetID: CleanupDisposition] {
        var values = cleanupDispositions
        if let cleanupDisposition {
            for assetID in assetIDs {
                values[assetID] = cleanupDisposition
            }
        }
        return values
    }

    var effectiveReviewProgresses: [AssetID: ReviewProgress] {
        var values = reviewProgresses
        if let reviewProgress {
            for assetID in assetIDs {
                values[assetID] = reviewProgress
            }
        }
        return values
    }
}

/// Last durable write failure for one choice action. Views render explicit
/// retry and never claim saved state on this path. The payload carries the
/// exact failed dimension values so retry re-issues the same write instead
/// of dropping it.
struct ReviewChoiceSaveError: Sendable, Equatable {
    let scopeID: UUID
    let assetIDs: [AssetID]
    let albumMembership: AlbumMembership?
    let cleanupDisposition: CleanupDisposition?
    let reviewProgress: ReviewProgress?
    let albumMemberships: [AssetID: AlbumMembership]
    let cleanupDispositions: [AssetID: CleanupDisposition]
    let reviewProgresses: [AssetID: ReviewProgress]
    let generation: UInt64
    let issuedAt: Date

    init(
        scopeID: UUID,
        assetIDs: [AssetID],
        albumMembership: AlbumMembership? = nil,
        cleanupDisposition: CleanupDisposition? = nil,
        reviewProgress: ReviewProgress? = nil,
        albumMemberships: [AssetID: AlbumMembership] = [:],
        cleanupDispositions: [AssetID: CleanupDisposition] = [:],
        reviewProgresses: [AssetID: ReviewProgress] = [:],
        generation: UInt64 = 0,
        issuedAt: Date = Date()
    ) {
        self.scopeID = scopeID
        self.assetIDs = assetIDs
        self.albumMembership = albumMembership
        self.cleanupDisposition = cleanupDisposition
        self.reviewProgress = reviewProgress
        self.albumMemberships = albumMemberships
        self.cleanupDispositions = cleanupDispositions
        self.reviewProgresses = reviewProgresses
        self.generation = generation
        self.issuedAt = issuedAt
    }
}

enum WorkspaceAvailability: Sendable {
    case available
    case unavailable
}

/// The durable intent and asset set for one review workspace.
@Model
final class ReviewScope {
    @Attribute(.unique) var id: UUID
    var intentRawValue: String
    var sourceAssetIDs: [String]
    var createdAt: Date
    var updatedAt: Date
    var schemaVersion: Int
    var migrationVersion: Int

    init(
        id: UUID,
        intent: ReviewIntent,
        sourceAssetIDs: [String],
        createdAt: Date,
        updatedAt: Date,
        schemaVersion: Int = 1,
        migrationVersion: Int = 1
    ) {
        self.id = id
        intentRawValue = intent.rawValue
        self.sourceAssetIDs = sourceAssetIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
        self.migrationVersion = migrationVersion
    }

    var intent: ReviewIntent {
        ReviewIntent(rawValue: intentRawValue) ?? .album
    }
}

/// One asset's independent durable workspace dimensions.
@Model
final class WorkspaceItem {
    @Attribute(.unique) var identity: String
    var scopeID: UUID
    var assetID: String
    var cleanupDispositionRawValue: String
    var albumMembershipRawValue: String
    var reviewProgressRawValue: String
    var analysisRef: String?
    var analysisAvailable: Bool
    var analysisVersion: Int?
    var createdAt: Date
    var updatedAt: Date

    init(
        scopeID: UUID,
        assetID: String,
        cleanupDisposition: CleanupDisposition = .undecided,
        albumMembership: AlbumMembership = .unset,
        reviewProgress: ReviewProgress = .unseen,
        analysisRef: String? = nil,
        analysisAvailable: Bool = false,
        analysisVersion: Int? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        identity = Self.identity(scopeID: scopeID, assetID: assetID)
        self.scopeID = scopeID
        self.assetID = assetID
        cleanupDispositionRawValue = cleanupDisposition.rawValue
        albumMembershipRawValue = albumMembership.rawValue
        reviewProgressRawValue = reviewProgress.rawValue
        self.analysisRef = analysisRef
        self.analysisAvailable = analysisAvailable
        self.analysisVersion = analysisVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func identity(scopeID: UUID, assetID: String) -> String {
        "\(scopeID.uuidString)::\(assetID)"
    }

    var cleanupDisposition: CleanupDisposition {
        CleanupDisposition(rawValue: cleanupDispositionRawValue) ?? .undecided
    }

    var albumMembership: AlbumMembership {
        AlbumMembership(rawValue: albumMembershipRawValue) ?? .unset
    }

    var reviewProgress: ReviewProgress {
        ReviewProgress(rawValue: reviewProgressRawValue) ?? .unseen
    }
}

/// Durable completion marker for the one-way legacy import.
@Model
final class WorkspaceMigrationMarker {
    @Attribute(.unique) var key: String
    var version: Int
    var committedAt: Date

    init(key: String, version: Int, committedAt: Date) {
        self.key = key
        self.version = version
        self.committedAt = committedAt
    }
}
