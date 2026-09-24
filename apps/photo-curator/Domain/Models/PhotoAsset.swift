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
nonisolated struct AssetModificationFingerprint: Codable, Hashable, Sendable {
    let modificationDate: Date?
    /// False only for a PhotoAsset decoded from a legacy payload that did not
    /// contain a fingerprint. A present fingerprint with a nil date remains a
    /// valid, distinct revision value.
    let isPresent: Bool

    init(modificationDate: Date?) {
        self.modificationDate = modificationDate
        isPresent = true
    }

    private init(modificationDate: Date?, isPresent: Bool) {
        self.modificationDate = modificationDate
        self.isPresent = isPresent
    }

    static let missing = Self(modificationDate: nil, isPresent: false)

    private enum CodingKeys: String, CodingKey {
        case modificationDate, isPresent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modificationDate = try container.decodeIfPresent(Date.self, forKey: .modificationDate)
        // Fingerprints written before the presence marker were real
        // fingerprints, including the meaningful nil-date form.
        isPresent = try container.decodeIfPresent(Bool.self, forKey: .isPresent) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(modificationDate, forKey: .modificationDate)
        try container.encode(isPresent, forKey: .isPresent)
    }
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

    /// Explicit memberwise compatibility initializer. Older source callers do
    /// not have revision metadata; those values are deliberately marked
    /// missing so revision-aware cache reads miss rather than reuse by ID.
    init(
        id: AssetID,
        creationDate: Date?,
        pixelWidth: Int,
        pixelHeight: Int,
        mediaSubtype: PhotoMediaSubtype,
        isFavorite: Bool,
        isEdited: Bool,
        source: AssetSource = .unknown,
        modificationFingerprint: AssetModificationFingerprint? = nil
    ) {
        self.id = id
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.mediaSubtype = mediaSubtype
        self.isFavorite = isFavorite
        self.isEdited = isEdited
        self.source = source
        self.modificationFingerprint = modificationFingerprint ?? .missing
    }

    private enum CodingKeys: String, CodingKey {
        case id, creationDate, pixelWidth, pixelHeight, mediaSubtype
        case isFavorite, isEdited, source, modificationFingerprint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(AssetID.self, forKey: .id),
            creationDate: container.decodeIfPresent(Date.self, forKey: .creationDate),
            pixelWidth: container.decode(Int.self, forKey: .pixelWidth),
            pixelHeight: container.decode(Int.self, forKey: .pixelHeight),
            mediaSubtype: container.decodeIfPresent(PhotoMediaSubtype.self, forKey: .mediaSubtype) ?? .unknown,
            isFavorite: container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false,
            isEdited: container.decodeIfPresent(Bool.self, forKey: .isEdited) ?? false,
            source: container.decodeIfPresent(AssetSource.self, forKey: .source) ?? .unknown,
            modificationFingerprint: container.decodeIfPresent(
                AssetModificationFingerprint.self, forKey: .modificationFingerprint
            )
        )
    }
}
