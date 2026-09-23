import CryptoKit
import Foundation
import SwiftData

enum PhotoDeletionStatus: String, Codable, Sendable {
    case prepared
    case executing
    case needsReconciliation
    case completed
    case partial
    case failed
    case cancelled
}

enum PhotoDeletionOutcome: String, Codable, Sendable {
    case pending
    case deleted
    case accessUnknown
    case failed
    case unresolved
}

enum PhotoDeletionAuthorizationSnapshot: String, Codable, Sendable {
    case notDetermined
    case limited
    case authorized
    case denied
    case restricted
}

/// Value representation used when a deletion operation crosses the store
/// actor boundary. Outcome arrays are deliberately explicit so an interrupted
/// write cannot be mistaken for successful deletion.
struct PhotoDeletionOperationSnapshot: Sendable, Equatable {
    let operationID: UUID
    let scopeID: UUID
    let stagedIDs: [String]
    let digest: String
    let confirmedAt: Date
    let authorizationRawValue: String
    let statusRawValue: String
    let pendingIDs: [String]
    let deletedIDs: [String]
    let accessUnknownIDs: [String]
    let failedIDs: [String]
    let unresolvedIDs: [String]
    let submittedIDs: [String]
    let createdAt: Date
    let updatedAt: Date
    let schemaVersion: Int

    var status: PhotoDeletionStatus {
        PhotoDeletionStatus(rawValue: statusRawValue) ?? .needsReconciliation
    }

    /// Malformed persisted authorization is treated as restricted. A decode
    /// failure must never become evidence of full access.
    var authorizationSnapshot: PhotoDeletionAuthorizationSnapshot {
        PhotoDeletionAuthorizationSnapshot(rawValue: authorizationRawValue) ?? .restricted
    }

    func outcome(for id: String) -> PhotoDeletionOutcome? {
        if deletedIDs.contains(id) {
            return .deleted
        }
        if accessUnknownIDs.contains(id) {
            return .accessUnknown
        }
        if failedIDs.contains(id) {
            return .failed
        }
        if unresolvedIDs.contains(id) {
            return .unresolved
        }
        if pendingIDs.contains(id) {
            return .pending
        }
        return nil
    }

    var outcomes: [String: PhotoDeletionOutcome] {
        Dictionary(uniqueKeysWithValues: stagedIDs.compactMap { id in
            guard let outcome = outcome(for: id) else { return nil }
            return (id, outcome)
        })
    }
}

/// Durable original-deletion operation. It is independent from album saving:
/// no album fields or cleanup dispositions are stored here.
@Model
final class PhotoDeletionOperation {
    static let schemaVersion = 1

    @Attribute(.unique) var operationID: UUID
    var scopeID: UUID
    var stagedIDs: [String]
    var digest: String
    var confirmedAt: Date
    var authorizationRawValue: String
    var statusRawValue: String
    var pendingIDs: [String]
    var deletedIDs: [String]
    var accessUnknownIDs: [String]
    var failedIDs: [String]
    var unresolvedIDs: [String]
    var submittedIDs: [String]
    var createdAt: Date
    var updatedAt: Date
    var schemaVersion: Int

    init(
        operationID: UUID,
        scopeID: UUID,
        stagedIDs: [String],
        digest: String,
        confirmedAt: Date,
        authorizationSnapshot: PhotoDeletionAuthorizationSnapshot,
        status: PhotoDeletionStatus = .prepared,
        pendingIDs: [String]? = nil,
        deletedIDs: [String] = [],
        accessUnknownIDs: [String] = [],
        failedIDs: [String] = [],
        unresolvedIDs: [String] = [],
        submittedIDs: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        schemaVersion: Int = PhotoDeletionOperation.schemaVersion
    ) {
        self.operationID = operationID
        self.scopeID = scopeID
        self.stagedIDs = stagedIDs
        self.digest = digest
        self.confirmedAt = confirmedAt
        authorizationRawValue = authorizationSnapshot.rawValue
        statusRawValue = status.rawValue
        self.pendingIDs = pendingIDs ?? stagedIDs
        self.deletedIDs = deletedIDs
        self.accessUnknownIDs = accessUnknownIDs
        self.failedIDs = failedIDs
        self.unresolvedIDs = unresolvedIDs
        self.submittedIDs = submittedIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
    }

    var status: PhotoDeletionStatus {
        get { PhotoDeletionStatus(rawValue: statusRawValue) ?? .needsReconciliation }
        set { statusRawValue = newValue.rawValue }
    }

    /// Canonical digest of the exact set. Duplicate input IDs are normalized
    /// because the operation represents a set, never an ordered list.
    static func digest(for rawIDs: [String]) -> String {
        let material = (["photo-deletion/v\(schemaVersion)"] + canonicalIDs(rawIDs))
            .joined(separator: "\n")
        return SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func canonicalIDs(_ rawIDs: [String]) -> [String] {
        Array(Set(rawIDs)).sorted()
    }

    func snapshot() -> PhotoDeletionOperationSnapshot {
        PhotoDeletionOperationSnapshot(
            operationID: operationID,
            scopeID: scopeID,
            stagedIDs: stagedIDs,
            digest: digest,
            confirmedAt: confirmedAt,
            authorizationRawValue: authorizationRawValue,
            statusRawValue: statusRawValue,
            pendingIDs: pendingIDs,
            deletedIDs: deletedIDs,
            accessUnknownIDs: accessUnknownIDs,
            failedIDs: failedIDs,
            unresolvedIDs: unresolvedIDs,
            submittedIDs: submittedIDs,
            createdAt: createdAt,
            updatedAt: updatedAt,
            schemaVersion: schemaVersion
        )
    }
}

typealias DeletionOperation = PhotoDeletionOperation
