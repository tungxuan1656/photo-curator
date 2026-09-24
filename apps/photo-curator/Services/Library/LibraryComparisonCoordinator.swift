import CoreGraphics
import Foundation

/// Rebuilds the durable comparison projection from one committed catalog
/// generation. All image evidence in this lane is transient; the catalog store
/// receives only the validated projection and its explicit coverage.
actor LibraryComparisonCoordinator {
    static let comparisonImageEdge = 256
    static let imageBatchSize = 2
    static let groupingRevision = "comparison-groups-v1"
    static let providerRevision = "vision-feature-print-v1"

    private let catalogStore: LibraryCatalogStore
    private let imageLoader: any PhotoImageLoader
    private let analyzer: any ImageAnalysisService
    private let imageWorkArbiter: ImageWorkArbiter
    private let retriever: ComparisonCandidateRetriever
    private let builder: ComparisonGroupBuilder

    private var rootTask: Task<Void, Never>?
    private var runToken: UInt64 = 0
    private var rebuildRequested = false
    private var attemptedGenerationID: UUID?

    init(
        catalogStore: LibraryCatalogStore,
        imageLoader: any PhotoImageLoader,
        analyzer: any ImageAnalysisService,
        imageWorkArbiter: ImageWorkArbiter,
        retriever: ComparisonCandidateRetriever = ComparisonCandidateRetriever(),
        builder: ComparisonGroupBuilder = ComparisonGroupBuilder()
    ) {
        self.catalogStore = catalogStore
        self.imageLoader = imageLoader
        self.analyzer = analyzer
        self.imageWorkArbiter = imageWorkArbiter
        self.retriever = retriever
        self.builder = builder
    }

    /// Coalesces notifications. The worker itself is deliberately detached from
    /// the caller so browsing and catalog lifecycle code never wait for images.
    func reconcile() {
        rebuildRequested = true
        guard rootTask == nil else { return }
        rebuildRequested = false
        startRootTask()
    }

    /// Cancels and drains all image work before returning from the background
    /// lifecycle. No projection is changed by cancellation.
    func pause() async {
        runToken &+= 1
        rebuildRequested = false
        guard let rootTask else { return }
        rootTask.cancel()
        await rootTask.value
        self.rootTask = nil
    }
}

private extension LibraryComparisonCoordinator {
    struct GenerationSource: Sendable {
        let generationID: UUID
        let assets: [PhotoAsset]
    }

    struct BuildOutput: Sendable {
        let generationID: UUID
        let coverage: ComparisonCoverage
        let groups: [ComparisonGroupInput]
    }

    struct EdgeValidationResult: Sendable {
        let edges: [ComparisonValidatedVisualEdge]
        let attemptedCount: Int
        let successfulCount: Int
    }

    enum InputOutcome: Sendable {
        case loaded(ComparisonCandidateInput)
        case unavailable(AssetID)
        case cancelled
    }

    enum EndpointOutcome: Sendable {
        case loaded(AssetID, ImageSimilarityArtifact)
        case unavailable(AssetID)
        case cancelled
    }

    func startRootTask() {
        let token = runToken
        rootTask = Task { [weak self] in
            guard let self else { return }
            await self.run(token: token)
        }
    }

    func run(token: UInt64) async {
        defer {
            if isCurrentRun(token) {
                rootTask = nil
                if rebuildRequested {
                    rebuildRequested = false
                    startRootTask()
                }
            }
        }

        do {
            guard let source = try await currentGenerationSource() else { return }
            guard attemptedGenerationID != source.generationID else { return }
            let output = try await build(source: source, token: token)
            guard isCurrentRun(token) else { return }

            // The store repeats this guard inside its transaction. This early
            // read avoids doing a publish attempt for an obviously superseded
            // generation, while the atomic store call remains authoritative.
            guard let current = try await catalogStore.currentGeneration(),
                  current.id == output.generationID
            else {
                rebuildRequested = true
                return
            }
            _ = try await catalogStore.publishComparisonSnapshot(
                ComparisonSnapshotInput(
                    catalogGenerationID: output.generationID,
                    groupingRevision: Self.groupingRevision,
                    providerRevision: Self.providerRevision,
                    coverage: output.coverage,
                    groups: output.groups
                )
            )
            guard isCurrentRun(token) else { return }
            // A completed incomplete projection is intentionally remembered.
            // Foreground reconciliation must not retry persistent unavailable
            // image work for the same committed generation.
            attemptedGenerationID = output.generationID
        } catch is CancellationError {
            // Cancellation is lifecycle control, not an unavailable result.
        } catch let error as LibraryCatalogStoreError {
            if case .analysisTransitionRejected = error {
                rebuildRequested = true
            }
        } catch {
            // Image failures are represented in coverage. Other failures leave
            // the last coherent projection untouched and are retried only by a
            // later explicit lifecycle/catalog request.
        }
    }

    func currentGenerationSource() async throws -> GenerationSource? {
        guard let generation = try await catalogStore.currentGeneration(),
              generation.status == .committed else { return nil }
        let observations = try await catalogStore.currentObservations()
        guard observations.allSatisfy({ $0.generationID == generation.id }),
              observations.count == generation.assetCount else { return nil }
        // This second read closes the ordinary read-side race. The guarded
        // publish is still required because reconciliation can commit after it.
        guard let confirmed = try await catalogStore.currentGeneration(),
              confirmed.id == generation.id,
              confirmed.status == .committed
        else {
            return nil
        }
        return GenerationSource(
            generationID: generation.id,
            assets: observations.map(\.asset).sorted { $0.id.rawValue < $1.id.rawValue }
        )
    }

    func build(source: GenerationSource, token: UInt64) async throws -> BuildOutput {
        let inputResult = try await loadInputs(for: source.assets)
        try Task.checkCancellation()
        guard isCurrentRun(token) else { throw CancellationError() }

        let retrieval = retriever.retrieve(from: inputResult.inputs)
        let overflowCount = retrieval.coverage.omittedCandidateCount
        var unavailableAssetIDs = inputResult.unavailableAssetIDs
        let endpointIDs = Set(retrieval.candidates.flatMap { [$0.first, $0.second] })
        let artifacts = try await rebuildArtifacts(
            for: endpointIDs.sorted { $0.rawValue < $1.rawValue },
            assets: source.assets
        )
        unavailableAssetIDs.formUnion(artifacts.unavailableAssetIDs)

        let validation = try validatedEdges(
            from: retrieval.candidates, artifacts: artifacts.artifacts
        )
        let buildResult = builder.build(assetIDs: source.assets.map(\.id), validatedEdges: validation.edges)
        let groups = coherentGroups(buildResult.groups).map { makeGroupInput($0, source: source) }
        let candidateCount = retrieval.candidates.count
        let coverage = ComparisonCoverage(
            status: unavailableAssetIDs.isEmpty && overflowCount == 0
                && validation.attemptedCount == candidateCount
                && validation.successfulCount == validation.attemptedCount
                ? .complete
                : .incomplete,
            assetCount: source.assets.count,
            eligibleAssetCount: max(0, source.assets.count - unavailableAssetIDs.count),
            candidateCount: candidateCount,
            validatedCandidateCount: validation.successfulCount,
            groupedAssetCount: groups.reduce(0) { $0 + $1.members.count },
            unavailableAssetCount: unavailableAssetIDs.count,
            overflowedCandidateCount: overflowCount,
            attemptedComparisonCount: validation.attemptedCount,
            successfulComparisonCount: validation.successfulCount,
            acceptedEdgeCount: validation.edges.count
        )
        return BuildOutput(generationID: source.generationID, coverage: coverage, groups: groups)
    }

    func loadInputs(for assets: [PhotoAsset]) async throws -> (
        inputs: [ComparisonCandidateInput], unavailableAssetIDs: Set<AssetID>
    ) {
        var inputs: [ComparisonCandidateInput] = []
        var unavailable = Set<AssetID>()
        let edge = CGFloat(Self.comparisonImageEdge)
        for start in stride(from: 0, to: assets.count, by: Self.imageBatchSize) {
            try Task.checkCancellation()
            let batch = assets[start ..< min(start + Self.imageBatchSize, assets.count)]
            let loader = imageLoader
            let arbiter = imageWorkArbiter
            let outcomes = await withTaskGroup(of: InputOutcome.self, returning: [InputOutcome].self) { group in
                for asset in batch {
                    group.addTask { [loader, arbiter, asset] in
                        do {
                            let hash = try await arbiter.withPermit(priority: .enrichment) {
                                let image = try await loader.thumbnail(
                                    for: asset.id, targetSize: CGSize(width: edge, height: edge)
                                )
                                try Task.checkCancellation()
                                return ComparisonInputHasher.hash(image)
                            }
                            return .loaded(ComparisonCandidateInput(
                                id: asset.id, creationDate: asset.creationDate, inputHash: hash
                            ))
                        } catch {
                            return PhotoImageLoadError.classify(error) == .cancelled
                                ? .cancelled
                                : .unavailable(asset.id)
                        }
                    }
                }
                var values: [InputOutcome] = []
                for await outcome in group {
                    values.append(outcome)
                }
                return values
            }
            for outcome in outcomes {
                switch outcome {
                case let .loaded(input): inputs.append(input)
                case let .unavailable(id): unavailable.insert(id)
                case .cancelled: throw CancellationError()
                }
            }
        }
        return (inputs.sorted { $0.id.rawValue < $1.id.rawValue }, unavailable)
    }

    func rebuildArtifacts(
        for ids: [AssetID], assets: [PhotoAsset]
    ) async throws -> (artifacts: [AssetID: ImageSimilarityArtifact], unavailableAssetIDs: Set<AssetID>) {
        let assetsByID = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
        var artifacts: [AssetID: ImageSimilarityArtifact] = [:]
        var unavailable = Set<AssetID>()
        let edge = CGFloat(Self.comparisonImageEdge)
        for start in stride(from: 0, to: ids.count, by: Self.imageBatchSize) {
            try Task.checkCancellation()
            let batch = ids[start ..< min(start + Self.imageBatchSize, ids.count)]
            let loader = imageLoader
            let analyzer = analyzer
            let arbiter = imageWorkArbiter
            let outcomes = await withTaskGroup(of: EndpointOutcome.self, returning: [EndpointOutcome].self) { group in
                for id in batch {
                    guard let asset = assetsByID[id] else { continue }
                    group.addTask { [loader, analyzer, arbiter, asset] in
                        do {
                            let artifact = try await arbiter.withPermit(priority: .enrichment) {
                                let image = try await loader.thumbnail(
                                    for: asset.id, targetSize: CGSize(width: edge, height: edge)
                                )
                                try Task.checkCancellation()
                                return try await analyzer.similarityArtifact(for: AnalysisInput(
                                    assetID: asset.id,
                                    image: image,
                                    isScreenshotSubtype: asset.mediaSubtype == .screenshot
                                ))
                            }
                            guard let artifact else { return .unavailable(asset.id) }
                            return .loaded(asset.id, artifact)
                        } catch {
                            return PhotoImageLoadError.classify(error) == .cancelled
                                ? .cancelled
                                : .unavailable(asset.id)
                        }
                    }
                }
                var values: [EndpointOutcome] = []
                for await outcome in group {
                    values.append(outcome)
                }
                return values
            }
            for outcome in outcomes {
                switch outcome {
                case let .loaded(id, artifact): artifacts[id] = artifact
                case let .unavailable(id): unavailable.insert(id)
                case .cancelled: throw CancellationError()
                }
            }
        }
        return (artifacts, unavailable)
    }

    func validatedEdges(
        from candidates: [ComparisonCandidate],
        artifacts: [AssetID: ImageSimilarityArtifact]
    ) throws -> EdgeValidationResult {
        var edgesByPair: [String: ComparisonValidatedVisualEdge] = [:]
        var attemptedCount = 0
        var successfulCount = 0
        for candidate in candidates {
            try Task.checkCancellation()
            guard let first = artifacts[candidate.first], let second = artifacts[candidate.second] else {
                continue
            }
            attemptedCount += 1
            guard let distance = try? first.distance(to: second),
                  distance.isFinite,
                  distance >= 0
            else {
                continue
            }
            successfulCount += 1
            let threshold = candidate.relation == .retake
                ? AppConfiguration.default.selection.duplicateSimilarityThreshold
                : AppConfiguration.default.selection.nearDuplicateSimilarityThreshold
            guard distance <= threshold else { continue }
            let reference = evidenceReference(for: candidate)
            let edge = ComparisonValidatedVisualEdge(
                first: candidate.first,
                second: candidate.second,
                relation: candidate.relation,
                path: candidate.path,
                visualDistance: distance,
                evidenceReference: reference
            )
            let key = pairKey(candidate.first, candidate.second)
            if let existing = edgesByPair[key] {
                let prefersRetake = existing.relation == .nearCopy && edge.relation == .retake
                let improvesDistance = edge.relation == existing.relation && distance < existing.visualDistance
                if prefersRetake || improvesDistance {
                    edgesByPair[key] = edge
                }
            } else {
                edgesByPair[key] = edge
            }
        }
        let edges = edgesByPair.values.sorted {
            if $0.first.rawValue != $1.first.rawValue {
                return $0.first.rawValue < $1.first.rawValue
            }
            return $0.second.rawValue < $1.second.rawValue
        }
        return EdgeValidationResult(
            edges: edges, attemptedCount: attemptedCount, successfulCount: successfulCount
        )
    }

    func coherentGroups(_ groups: [ComparisonGroup]) -> [ComparisonGroup] {
        let ordered = groups.sorted {
            let leftPriority = $0.relation == .retake ? 0 : 1
            let rightPriority = $1.relation == .retake ? 0 : 1
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }
            return $0.id.rawValue < $1.id.rawValue
        }
        var used = Set<AssetID>()
        return ordered.filter { group in
            guard used.isDisjoint(with: group.assetIDs) else { return false }
            used.formUnion(group.assetIDs)
            return true
        }.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    func makeGroupInput(_ group: ComparisonGroup, source: GenerationSource) -> ComparisonGroupInput {
        let assetsByID = Dictionary(uniqueKeysWithValues: source.assets.map { ($0.id, $0) })
        let references = group.reason.evidenceReferences.compactMap {
            makeEvidenceReference($0, source: source, assetsByID: assetsByID)
        }
        var referenceByAsset: [AssetID: String] = [:]
        for reference in references {
            referenceByAsset[reference.firstAssetID] = reference.identifier
            referenceByAsset[reference.secondAssetID] = reference.identifier
        }
        let members = group.assetIDs.map { id in
            ComparisonMemberInput(assetID: id, evidenceReferenceID: referenceByAsset[id])
        }
        return ComparisonGroupInput(
            id: stableUUID(for: group.id.rawValue),
            relation: group.relation,
            reason: group.relation == .retake ? .sameCaptureImageSimilarity : .crossDateImageSimilarity,
            representativeAssetID: group.representativeAssetID,
            groupingRevision: Self.groupingRevision,
            providerRevision: Self.providerRevision,
            evidenceReferenceIDs: references.map(\.identifier),
            evidenceReferences: references,
            members: members
        )
    }

    func makeEvidenceReference(
        _ value: String,
        source: GenerationSource,
        assetsByID: [AssetID: PhotoAsset]
    ) -> ComparisonEvidenceReferenceInput? {
        let parts = value.split(separator: "|", maxSplits: 3).map(String.init)
        guard parts.count == 4,
              let first = assetsByID[AssetID(rawValue: parts[2])],
              let second = assetsByID[AssetID(rawValue: parts[3])] else { return nil }
        return ComparisonEvidenceReferenceInput(
            identifier: value,
            sourceGenerationID: source.generationID,
            firstAssetID: first.id,
            firstAssetFingerprint: first.modificationFingerprint,
            secondAssetID: second.id,
            secondAssetFingerprint: second.modificationFingerprint,
            analysisRevision: AppConfiguration.default.analysis.analysisVersion,
            providerRevision: Self.providerRevision
        )
    }

    func evidenceReference(for candidate: ComparisonCandidate) -> String {
        "edge|\(candidate.path.rawValue)|\(candidate.first.rawValue)|\(candidate.second.rawValue)"
    }

    func pairKey(_ first: AssetID, _ second: AssetID) -> String {
        let values = [first.rawValue, second.rawValue].sorted()
        return "\(values[0])::\(values[1])"
    }

    func stableUUID(for value: String) -> UUID {
        let first = ComparisonInputHasher.fnv(value, seed: 14_695_981_039_346_656_037)
        let second = ComparisonInputHasher.fnv(value, seed: 109_511_628_211)
        let bytes: uuid_t = (
            UInt8((first >> 56) & 0xFF), UInt8((first >> 48) & 0xFF), UInt8((first >> 40) & 0xFF),
            UInt8((first >> 32) & 0xFF), UInt8((first >> 24) & 0xFF), UInt8((first >> 16) & 0xFF),
            UInt8((first >> 8) & 0xFF), UInt8(first & 0xFF), UInt8((second >> 56) & 0xFF),
            UInt8((second >> 48) & 0xFF), UInt8((second >> 40) & 0xFF), UInt8((second >> 32) & 0xFF),
            UInt8((second >> 24) & 0xFF), UInt8((second >> 16) & 0xFF), UInt8((second >> 8) & 0xFF),
            UInt8(second & 0xFF)
        )
        return UUID(uuid: bytes)
    }

    func isCurrentRun(_ token: UInt64) -> Bool {
        token == runToken && !Task.isCancelled
    }
}

private enum ComparisonInputHasher {
    static func hash(_ image: CGImage) -> ComparisonInputHash {
        let size = 8
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return ComparisonInputHash(rawValue: 0) }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let data = context.data else { return ComparisonInputHash(rawValue: 0) }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        let values = (0 ..< size * size).map { Double(pixels[$0]) }
        let average = values.reduce(0, +) / Double(values.count)
        let bits = values.reduce(UInt64(0)) { result, value in
            (result << 1) | (value >= average ? 1 : 0)
        }
        return ComparisonInputHash(rawValue: bits)
    }

    static func fnv(_ value: String, seed: UInt64) -> UInt64 {
        value.utf8.reduce(seed) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}
