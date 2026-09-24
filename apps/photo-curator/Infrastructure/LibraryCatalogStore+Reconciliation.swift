import Foundation

private struct StagedCatalogGeneration: Sendable {
    let assets: [PhotoAsset]
    let assetIDs: Set<String>
    let assetCount: Int
}

extension LibraryCatalogStore {
    /// Reconciles one complete Photos enumeration. Actor isolation provides
    /// single-flight behavior for callers and preserves the prior pointer on
    /// every failure path.
    func reconcile(using photoLibrary: any PhotoLibraryService) async throws -> CatalogReconciliationResult {
        guard !Task.isCancelled else { throw CancellationError() }
        try acquireReconciliationFlight()
        defer { releaseReconciliationFlight() }

        let authorization = await photoLibrary.authorizationStatus()
        let initialAuthorization = Self.snapshot(for: authorization)
        let generationID = UUID()
        try beginGenerationOrThrow(id: generationID, authorization: initialAuthorization)

        do {
            let staged = try await stageGeneration(
                generationID: generationID,
                authorization: authorization,
                photoLibrary: photoLibrary
            )
            let finalAuthorization = try await validateFinalAuthorization(
                initial: initialAuthorization,
                photoLibrary: photoLibrary
            )
            let changedAssetIDs = try publishGeneration(
                generationID: generationID,
                staged: staged,
                authorization: finalAuthorization
            )
            pruneCatalogHistoryIfNeeded()
            return CatalogReconciliationResult(
                generationID: generationID,
                assetCount: staged.assetCount,
                changedAssetIDs: changedAssetIDs.sorted { $0.rawValue < $1.rawValue }
            )
        } catch is CancellationError {
            try? abandon(generationID: generationID, category: .cancelled)
            throw CancellationError()
        } catch let error as LibraryCatalogStoreError {
            try? abandon(generationID: generationID, category: Self.failureCategory(for: error))
            throw error
        } catch {
            try? abandon(generationID: generationID, category: .persistenceFailed)
            throw LibraryCatalogStoreError.persistenceFailed
        }
    }

    private func beginGenerationOrThrow(
        id: UUID,
        authorization: CatalogAuthorizationSnapshot
    ) throws {
        do {
            try beginGeneration(id: id, authorization: authorization)
        } catch {
            throw LibraryCatalogStoreError.persistenceFailed
        }
    }

    private func stageGeneration(
        generationID: UUID,
        authorization: PhotoLibraryAuthorization,
        photoLibrary: any PhotoLibraryService
    ) async throws -> StagedCatalogGeneration {
        guard Self.isAccessible(authorization) else {
            throw LibraryCatalogStoreError.accessRequired
        }
        guard !Task.isCancelled else { throw CancellationError() }

        let assets = try await fetchAssets(from: photoLibrary)
        let assetIDs = try uniqueAssetIDs(in: assets)
        for batch in assets.chunked(into: Self.observationBatchSize) {
            guard !Task.isCancelled else { throw CancellationError() }
            do {
                try stage(batch, generationID: generationID)
            } catch let error as LibraryCatalogStoreError {
                throw error
            } catch {
                throw LibraryCatalogStoreError.persistenceFailed
            }
        }

        let assetCount = try persistedGenerationCount(id: generationID)
        guard assetCount == assetIDs.count else {
            throw LibraryCatalogStoreError.incompleteGeneration
        }
        return StagedCatalogGeneration(assets: assets, assetIDs: assetIDs, assetCount: assetCount)
    }

    private func fetchAssets(from photoLibrary: any PhotoLibraryService) async throws -> [PhotoAsset] {
        do {
            let assets = try await photoLibrary.fetchAssets()
            guard !Task.isCancelled else { throw CancellationError() }
            return assets
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw LibraryCatalogStoreError.fetchFailed
        }
    }

    private func uniqueAssetIDs(in assets: [PhotoAsset]) throws -> Set<String> {
        var assetIDs = Set<String>()
        for asset in assets {
            guard assetIDs.insert(asset.id.rawValue).inserted else {
                throw LibraryCatalogStoreError.duplicateAssetID
            }
        }
        return assetIDs
    }

    private func persistedGenerationCount(id: UUID) throws -> Int {
        do {
            guard let generation = try fetchGeneration(id: id) else {
                throw LibraryCatalogStoreError.incompleteGeneration
            }
            return generation.assetCount
        } catch let error as LibraryCatalogStoreError {
            throw error
        } catch {
            throw LibraryCatalogStoreError.persistenceFailed
        }
    }

    private func validateFinalAuthorization(
        initial: CatalogAuthorizationSnapshot,
        photoLibrary: any PhotoLibraryService
    ) async throws -> CatalogAuthorizationSnapshot {
        let finalAuthorization = await photoLibrary.authorizationStatus()
        guard !Task.isCancelled else { throw CancellationError() }
        let finalSnapshot = Self.snapshot(for: finalAuthorization)
        guard finalSnapshot == initial else {
            if !Self.isAccessible(finalAuthorization) {
                throw LibraryCatalogStoreError.accessRequired
            }
            throw LibraryCatalogStoreError.authorizationChanged
        }
        guard Self.isAccessible(finalAuthorization) else {
            throw LibraryCatalogStoreError.accessRequired
        }
        return finalSnapshot
    }

    private func publishGeneration(
        generationID: UUID,
        staged: StagedCatalogGeneration,
        authorization: CatalogAuthorizationSnapshot
    ) throws -> [AssetID] {
        do {
            return try commit(
                generationID: generationID,
                assets: staged.assets,
                assetIDs: staged.assetIDs,
                authorization: authorization
            )
        } catch let error as LibraryCatalogStoreError {
            throw error
        } catch {
            throw LibraryCatalogStoreError.persistenceFailed
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        var result: [[Element]] = []
        result.reserveCapacity((count + size - 1) / size)
        var start = startIndex
        while start < endIndex {
            let end = index(start, offsetBy: Swift.min(size, distance(from: start, to: endIndex)))
            result.append(Array(self[start ..< end]))
            start = end
        }
        return result
    }
}
