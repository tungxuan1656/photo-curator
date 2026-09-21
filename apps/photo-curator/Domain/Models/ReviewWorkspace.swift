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
