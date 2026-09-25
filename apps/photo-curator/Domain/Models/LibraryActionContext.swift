import CryptoKit
import Foundation
import SwiftData

enum LibraryActionKind: String, Codable, Sendable, Equatable {
    case album
    case deletion
}

enum LibraryActionStatus: String, Codable, Sendable, Equatable {
    case prepared
    case staged
    case executing
    case completed
    case partial
    case failed
    case needsReconciliation
    case cancelled
}

enum LibraryActionContextValidationError: Error, Sendable, Equatable {
    case emptyAssetSet
    case nonCanonicalAssetIDs
    case invalidAssetID
    case invalidDigest
    case invalidQueryIdentity
    case invalidStatus
    case invalidDestination
    case invalidDates
}

/// Stable destination identity used by the catalog action surface. Existing
/// albums use their PhotoKit local identifier; a new destination is resolved
/// once by the save service and then retained by its durable operation.
struct LibraryAlbumDestination: Codable, Sendable, Equatable, Hashable, Identifiable {
    let localIdentifier: String?
    let title: String

    var id: String {
        localIdentifier ?? "new:\(title.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    var isExisting: Bool {
        localIdentifier != nil
    }

    static func new(title: String) -> Self {
        Self(localIdentifier: nil, title: title)
    }
}

struct LibraryActionContextSnapshot: Sendable, Equatable {
    let actionID: UUID
    let kind: LibraryActionKind
    let assetIDs: [String]
    let queryIdentity: String
    let catalogGenerationID: UUID
    let labelProjectionRevision: Int64
    let digest: String
    let statusRawValue: String
    let destinationLocalIdentifier: String?
    let destinationTitle: String?
    let createdAt: Date
    let updatedAt: Date

    var status: LibraryActionStatus {
        LibraryActionStatus(rawValue: statusRawValue) ?? .failed
    }

    var typedAssetIDs: [AssetID] {
        assetIDs.map(AssetID.init(rawValue:))
    }

    func validated() throws -> Self {
        guard !assetIDs.isEmpty else { throw LibraryActionContextValidationError.emptyAssetSet }
        guard assetIDs.allSatisfy({ !$0.isEmpty && $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines) }) else {
            throw LibraryActionContextValidationError.invalidAssetID
        }
        guard assetIDs == Array(Set(assetIDs)).sorted() else {
            throw LibraryActionContextValidationError.nonCanonicalAssetIDs
        }
        let expectedDigest = kind == .deletion
            ? PhotoDeletionOperation.digest(for: assetIDs)
            : LibraryActionContext.digest(for: typedAssetIDs)
        guard digest == expectedDigest else { throw LibraryActionContextValidationError.invalidDigest }
        guard !queryIdentity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LibraryActionContextValidationError.invalidQueryIdentity
        }
        guard LibraryActionStatus(rawValue: statusRawValue) != nil else {
            throw LibraryActionContextValidationError.invalidStatus
        }
        guard updatedAt >= createdAt else { throw LibraryActionContextValidationError.invalidDates }
        if let localIdentifier = destinationLocalIdentifier {
            guard !localIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LibraryActionContextValidationError.invalidDestination
            }
        }
        switch kind {
        case .album:
            guard let title = destinationTitle,
                  !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw LibraryActionContextValidationError.invalidDestination }
        case .deletion:
            guard destinationLocalIdentifier == nil, destinationTitle == nil else {
                throw LibraryActionContextValidationError.invalidDestination
            }
        }
        return self
    }
}

@Model
final class LibraryActionContext {
    static let schemaVersion = 1

    @Attribute(.unique) var actionID: UUID
    var kindRawValue: String
    var assetIDs: [String]
    var queryIdentity: String
    var catalogGenerationID: UUID
    var labelProjectionRevision: Int64
    var digest: String
    var statusRawValue: String
    var destinationLocalIdentifier: String?
    var destinationTitle: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        actionID: UUID,
        kind: LibraryActionKind,
        assetIDs: [String],
        queryIdentity: String,
        catalogGenerationID: UUID,
        labelProjectionRevision: Int64,
        digest: String,
        status: LibraryActionStatus = .prepared,
        destinationLocalIdentifier: String? = nil,
        destinationTitle: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.actionID = actionID
        kindRawValue = kind.rawValue
        self.assetIDs = assetIDs
        self.queryIdentity = queryIdentity
        self.catalogGenerationID = catalogGenerationID
        self.labelProjectionRevision = labelProjectionRevision
        self.digest = digest
        statusRawValue = status.rawValue
        self.destinationLocalIdentifier = destinationLocalIdentifier
        self.destinationTitle = destinationTitle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var snapshot: LibraryActionContextSnapshot {
        LibraryActionContextSnapshot(
            actionID: actionID,
            kind: LibraryActionKind(rawValue: kindRawValue) ?? .album,
            assetIDs: assetIDs,
            queryIdentity: queryIdentity,
            catalogGenerationID: catalogGenerationID,
            labelProjectionRevision: labelProjectionRevision,
            digest: digest,
            statusRawValue: statusRawValue,
            destinationLocalIdentifier: destinationLocalIdentifier,
            destinationTitle: destinationTitle,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func digest(for assetIDs: [AssetID]) -> String {
        let material = (["library-action/v\(schemaVersion)"] + Array(Set(assetIDs.map(\.rawValue))).sorted())
            .joined(separator: "\n")
        return SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
