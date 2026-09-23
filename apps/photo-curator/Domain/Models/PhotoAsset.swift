import Foundation

/// Values that change behavior only (eligibility policy: selection-rules).
enum PhotoMediaSubtype: String, Codable, Sendable {
    case standard, livePhoto, screenshot, panorama, hdr, portrait, unknown
}

/// Where the bytes live. Hint for progress/retry only; iCloud state can change.
enum AssetSource: String, Codable, Sendable {
    case local, iCloud, unknown
}

/// Stable PhotoKit-sourced revision metadata for one asset. A missing
/// modification date is still a meaningful revision: the asset ID scopes the
/// value, while a later non-nil date invalidates the cached facts.
struct AssetModificationFingerprint: Codable, Hashable, Sendable {
    let modificationDate: Date?
}

/// Light view of one PhotoKit photo. Cheap fields only, no pixels. Precise location is never stored here.
/// `isEdited` maps `PHAsset.hasAdjustments`: an intentional user edit earns a soft bonus and wins the
/// edited-twin tie-break inside one near-duplicate cluster. Twins that never become candidates
/// (outside the time window or similarity threshold) stay separate.
struct PhotoAsset: Identifiable, Codable, Hashable, Sendable {
    let id: AssetID
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let mediaSubtype: PhotoMediaSubtype
    let isFavorite: Bool
    let isEdited: Bool
    let source: AssetSource
    let modificationFingerprint: AssetModificationFingerprint
}
