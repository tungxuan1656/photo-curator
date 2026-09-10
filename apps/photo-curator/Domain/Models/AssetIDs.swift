import Foundation

/// Stable identity for one photo in the Photos library.
/// Wraps `PHAsset.localIdentifier`. PhotoKit is authoritative: a stored id may no longer resolve.
struct AssetID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String
}

/// Identity for one curation session.
struct SessionID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: UUID
}

/// Identity for one time-moment group.
struct MomentID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: UUID
}

/// Identity for one duplicate/near-duplicate cluster.
struct ClusterID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: UUID
}
