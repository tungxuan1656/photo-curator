import CryptoKit
import Foundation
import SwiftData

/// Album-save operation status. Terminal states never auto-retry;
/// `needsReconciliation` waits for an explicit user retry. `completed`,
/// `partial`, and `failed` are informational (reconciliation keys off
/// `remainingIDs`); they exist so later tooling and feat-036's deletion
/// work can distinguish outcomes without re-deriving them.
enum AlbumSaveStatus: String, Codable, Sendable {
    case prepared
    case executing
    case needsReconciliation
    case completed
    case partial
    case failed
}

/// Value snapshot crossing the store actor boundary.
struct AlbumSaveOperationSnapshot: Sendable, Equatable {
    let sessionID: UUID
    let scopeID: UUID
    let draftIDs: [String]
    let digest: String
    let statusRawValue: String
    let albumLocalIdentifier: String?
    let albumTitle: String
    let addedIDs: [String]
    let missingIDs: [String]
    let createdAt: Date
    let updatedAt: Date
    let schemaVersion: Int

    var status: AlbumSaveStatus {
        AlbumSaveStatus(rawValue: statusRawValue) ?? .failed
    }

    /// IDs neither recorded as added nor missing. PhotoKit `performChanges`
    /// is atomic per add call, so a throw leaves the whole attempted set
    /// remaining for explicit retry; per-call failure needs no separate
    /// failed bucket.
    var remainingIDs: [String] {
        let done = Set(addedIDs).union(missingIDs)
        return draftIDs.filter { !done.contains($0) }
    }
}

/// Durable album-save operation (feat-035 owner).
///
/// Stores the exact album draft plus a canonical digest before any PhotoKit
/// mutation so resume/retry can reconcile without duplicate albums. Added by
/// feat-035's explicit SwiftData schema migration: `AppContainer` opens the
/// workspace store with this model alongside the feat-033 models. Rollback
/// removes this model from the container list; pre-existing scope/item rows
/// reopen untouched while unresolved operations fall back to the file
/// `SaveState` handoff and route to recoverable review.
@Model
final class AlbumSaveOperation {
    static let schemaVersion = 1

    @Attribute(.unique) var sessionID: UUID
    var scopeID: UUID
    var draftIDs: [String]
    var digest: String
    var statusRawValue: String
    var albumLocalIdentifier: String?
    var albumTitle: String
    var addedIDs: [String]
    var missingIDs: [String]
    var createdAt: Date
    var updatedAt: Date
    var schemaVersion: Int

    init(
        sessionID: UUID,
        scopeID: UUID,
        draftIDs: [String],
        digest: String,
        status: AlbumSaveStatus = .prepared,
        albumLocalIdentifier: String? = nil,
        albumTitle: String,
        addedIDs: [String] = [],
        missingIDs: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        schemaVersion: Int = AlbumSaveOperation.schemaVersion
    ) {
        self.sessionID = sessionID
        self.scopeID = scopeID
        self.draftIDs = draftIDs
        self.digest = digest
        statusRawValue = status.rawValue
        self.albumLocalIdentifier = albumLocalIdentifier
        self.albumTitle = albumTitle
        self.addedIDs = addedIDs
        self.missingIDs = missingIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
    }

    var status: AlbumSaveStatus {
        get { AlbumSaveStatus(rawValue: statusRawValue) ?? .failed }
        set { statusRawValue = newValue.rawValue }
    }

    /// Canonical digest: sorted IDs plus the operation schema version.
    /// Checked before mutation; a changed draft never resumes an old album.
    /// Takes raw IDs so the digest stays computable from the persisted row.
    static func digest(for rawIDs: [String]) -> String {
        let material = (["album-save/v\(schemaVersion)"] + rawIDs.sorted())
            .joined(separator: "\n")
        return SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    func snapshot() -> AlbumSaveOperationSnapshot {
        AlbumSaveOperationSnapshot(
            sessionID: sessionID,
            scopeID: scopeID,
            draftIDs: draftIDs,
            digest: digest,
            statusRawValue: statusRawValue,
            albumLocalIdentifier: albumLocalIdentifier,
            albumTitle: albumTitle,
            addedIDs: addedIDs,
            missingIDs: missingIDs,
            createdAt: createdAt,
            updatedAt: updatedAt,
            schemaVersion: schemaVersion
        )
    }
}
