import Foundation

// swiftformat:disable redundantMemberwiseInit — plan mandates explicit memberwise inits in this file.
/// Stable identity for one photo in the Photos library.
/// Wraps `PHAsset.localIdentifier`. PhotoKit is authoritative: a stored id may no longer resolve.
struct AssetID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    // Plan mandates explicit memberwise inits in this file.
    // swiftlint:disable:next unneeded_synthesized_initializer
    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Identity for one curation session.
struct SessionID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: UUID

    // Plan mandates explicit memberwise inits in this file.
    // swiftlint:disable:next unneeded_synthesized_initializer
    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

/// Identity for one time-moment group.
struct MomentID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: UUID

    // Plan mandates explicit memberwise inits in this file.
    // swiftlint:disable:next unneeded_synthesized_initializer
    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

/// Identity for one duplicate/near-duplicate cluster.
struct ClusterID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: UUID

    // Plan mandates explicit memberwise inits in this file.
    // swiftlint:disable:next unneeded_synthesized_initializer
    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

// swiftformat:enable redundantMemberwiseInit
