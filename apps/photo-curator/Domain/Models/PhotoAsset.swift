import Foundation

/// Values that change behavior only (eligibility policy: selection-rules).
enum PhotoMediaSubtype: String, Codable, Sendable {
    case standard, livePhoto, screenshot, panorama, hdr, portrait, unknown
}

/// Where the bytes live. Hint for progress/retry only; iCloud state can change.
enum AssetSource: String, Codable, Sendable {
    case local, iCloud, unknown
}

/// Light view of one PhotoKit photo. Cheap fields only, no pixels. Precise location is never stored here.
/// `isEdited` maps `PHAsset.hasAdjustments`: an intentional user edit earns a soft bonus and wins the
/// edited-twin tie-break, but the unedited twin is never kept alongside it.
struct PhotoAsset: Identifiable, Codable, Hashable, Sendable {
    let id: AssetID
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let mediaSubtype: PhotoMediaSubtype
    let isFavorite: Bool
    let isEdited: Bool
    let source: AssetSource
}
