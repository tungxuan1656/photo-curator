import Foundation
import Photos

/// Concrete PhotoKit album exporter behind `AlbumExportService`.
///
/// `PHAsset` resolution stays inside this service; missing IDs become
/// missing-output data, never a crash. Every first save creates a new
/// collision-safe album (`name`, `name 2`, …); retries reuse the persisted
/// album identity. Only called after the user taps Save.
struct PhotoKitAlbumExporter: AlbumExportService, Sendable {
    func createAlbum(name: String) async throws -> CreatedAlbum {
        try Task.checkCancellation()
        guard await Self.isAuthorized() else { throw ExportError.permissionLost }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Curated Photos" : trimmed
        let title = await Self.collisionSafeTitle(for: base)
        let albumID = try await Self.createAlbumShell(title: title)
        return CreatedAlbum(localIdentifier: albumID, title: title)
    }

    /// Adds exactly these IDs to the already-created album in one change
    /// request. Never creates a second album. `performChanges` is atomic per
    /// call: success means every resolvable asset landed, so partial
    /// progress lives in the caller's persisted `addedIDs`, not here.
    func addToAlbum(albumLocalIdentifier: String, assetIDs: [AssetID]) async throws -> ExportResult {
        try Task.checkCancellation()
        guard await Self.isAuthorized() else { throw ExportError.permissionLost }
        guard !albumLocalIdentifier.isEmpty else { throw ExportError.creationFailed }
        let (phAssets, missing) = await Self.resolve(assetIDs)
        guard !phAssets.isEmpty else { throw ExportError.assetsUnavailable }
        let title = await Self.title(for: albumLocalIdentifier) ?? "Curated Photos"
        try await Self.addOneRequest(phAssets, toAlbumID: albumLocalIdentifier)
        return ExportResult(
            albumLocalIdentifier: albumLocalIdentifier,
            albumTitle: title,
            addedIDs: assetIDs.filter { !Set(missing).contains($0) },
            missingIDs: missing
        )
    }

    private static func isAuthorized() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    private static func resolve(_ ids: [AssetID]) async -> ([PHAsset], [AssetID]) {
        var found: [PHAsset] = []
        var missing: [AssetID] = []
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids.map(\.rawValue), options: nil)
        var byID: [String: PHAsset] = [:]
        fetch.enumerateObjects { asset, _, _ in
            byID[asset.localIdentifier] = asset
        }
        for id in ids {
            if let asset = byID[id.rawValue] {
                found.append(asset)
            } else {
                missing.append(id)
            }
        }
        return (found, missing)
    }

    private static func existingTitles() async -> Set<String> {
        await withCheckedContinuation { continuation in
            var titles = Set<String>()
            let collections = PHAssetCollection.fetchAssetCollections(
                with: .album, subtype: .any, options: nil
            )
            collections.enumerateObjects { collection, _, _ in
                if let title = collection.localizedTitle {
                    titles.insert(title)
                }
            }
            continuation.resume(returning: titles)
        }
    }

    private static func collisionSafeTitle(for base: String) async -> String {
        let taken = await existingTitles()
        guard taken.contains(base) else { return base }
        var suffix = 2
        while taken.contains("\(base) \(suffix)") {
            suffix += 1
        }
        return "\(base) \(suffix)"
    }

    private static func title(for albumID: String) async -> String? {
        await withCheckedContinuation { continuation in
            let collections = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [albumID], options: nil
            )
            continuation.resume(returning: collections.firstObject?.localizedTitle)
        }
    }

    private static func createAlbumShell(title: String) async throws -> String {
        var placeholderID: String?
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
                placeholderID = request.placeholderForCreatedAssetCollection.localIdentifier
            }
        } catch {
            throw ExportError.creationFailed
        }
        guard let placeholderID else { throw ExportError.creationFailed }
        return placeholderID
    }

    private static func addOneRequest(_ assets: [PHAsset], toAlbumID albumID: String) async throws {
        // A vanished album (deleted mid-save) must surface as a failure, never
        // a silent no-op the caller would report as added.
        guard PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumID],
            options: nil
        ).firstObject != nil else {
            throw ExportError.creationFailed
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                guard let album = PHAssetCollection.fetchAssetCollections(
                    withLocalIdentifiers: [albumID], options: nil
                ).firstObject,
                    let request = PHAssetCollectionChangeRequest(for: album)
                else { return }
                request.addAssets(assets as NSArray)
            }
        } catch {
            throw ExportError.creationFailed
        }
    }
}
