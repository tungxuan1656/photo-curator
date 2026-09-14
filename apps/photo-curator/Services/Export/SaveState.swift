import Foundation

/// Durable save state for one session: the created album identity plus what
/// actually landed. Persisted before retryable adds so a resumed or retried
/// save adds only missing assets to the same album — never a second album.
struct SaveState: Codable, Sendable {
    let sessionID: SessionID
    let albumLocalIdentifier: String
    let albumTitle: String
    let requestedIDs: [AssetID]
    var addedIDs: [AssetID]
    var missingIDs: [AssetID]

    var remainingIDs: [AssetID] {
        requestedIDs.filter { !Set(addedIDs).contains($0) && !Set(missingIDs).contains($0) }
    }
}
