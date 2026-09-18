import Foundation

private struct ProofFailure: Error {
    let message: String
}

/// FinalAlbumBuilder shares this production error with SelectionEngine. The
/// proof intentionally compiles the selector slice without the legacy facade.
enum SelectionError: Error, Sendable {
    case `internal`
}

struct ModelInstallation: Sendable {
    let directory: URL
}

struct QwenLoadResult: Sendable {
    let modelID: String = "proof-model"
    let revision: String = "proof-revision"
    let elapsed: TimeInterval = 0
}

private actor SchedulerProbeJudge: QualityPairJudging {
    private let delayNanoseconds: UInt64
    private let blocksUntilCancelled: Bool
    private let returnsStaleRequestID: Bool
    private var active = 0
    private var maximumActive = 0
    private var calls = 0
    private var cancelledGenerations = Set<Int>()

    init(
        delayNanoseconds: UInt64 = 0,
        blocksUntilCancelled: Bool = false,
        returnsStaleRequestID: Bool = false
    ) {
        self.delayNanoseconds = delayNanoseconds
        self.blocksUntilCancelled = blocksUntilCancelled
        self.returnsStaleRequestID = returnsStaleRequestID
    }

    func judge(_ request: QualityPairRequest) async throws -> QualityPairJudgment {
        active += 1
        calls += 1
        maximumActive = max(maximumActive, active)
        defer { active -= 1 }

        if blocksUntilCancelled {
            while !cancelledGenerations.contains(request.generation) {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            throw CancellationError()
        }

        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        guard !cancelledGenerations.contains(request.generation) else {
            throw CancellationError()
        }

        return QualityPairJudgment(
            requestID: returnsStaleRequestID
                ? UUID(uuidString: "00000000-0000-0000-0000-000000009999")!
                : request.requestID,
            generation: request.generation,
            relation: .retake,
            preference: .chooseA,
            reasons: []
        )
    }

    func cancel(generation: Int) async {
        cancelledGenerations.insert(generation)
    }

    func snapshot() -> (maximumActive: Int, calls: Int, cancelled: Set<Int>) {
        (maximumActive, calls, cancelledGenerations)
    }

    func waitUntilCalled() async throws {
        for _ in 0 ..< 10000 {
            if calls > 0 {
                return
            }
            await Task.yield()
        }
        throw ProofFailure(message: "probe did not receive request")
    }
}

/// QualityComparisonScheduler keeps this production type's default conformance
/// buildable without pulling the MLX runtime into this proof executable.
struct QwenPairJudge: Sendable {
    func judge(_: QualityPairRequest) async throws -> QualityPairJudgment {
        throw CancellationError()
    }

    func cancel(generation _: Int) async {}
    func load(from _: ModelInstallation) async throws -> QwenLoadResult {
        QwenLoadResult()
    }

    func unload() async throws {}
}

@main
struct Feat031QualityProof {
    static func main() async throws {
        try await proveSchedulerSerialAndCap()
        try await proveSchedulerDeadline()
        try await proveSchedulerCancellation()
        try await proveSchedulerRejectsStaleRequest()
        try proveSelectorDoesNotApplyNativeMinimum()
        try proveSelectorKeepsUsableWinner()
        try proveQualityCheckpointIdentity()
        print("QUALITY-SCHEDULER-SELECTOR PASS")
    }

    private static func proveSchedulerSerialAndCap() async throws {
        let judge = SchedulerProbeJudge(delayNanoseconds: 2_000_000)
        let scheduler = QualityComparisonScheduler(
            judge: judge,
            policy: qualityPolicy(maxQwenRequests: 2, wallBudget: 1, deadline: 0.5)
        )
        let run = await scheduler.run((0 ..< 4).map(request))
        let probe = await judge.snapshot()
        try require(probe.maximumActive == 1, "scheduler exceeded maxActiveComparisons=1")
        try require(probe.calls == 2, "scheduler exceeded maxQwenRequests")
        try require(run.counts.planned == 2 && run.counts.attempted == 2, "scheduler cap counts")
        try require(run.counts.applied == 2 && run.counts.skipped == 2, "scheduler cap outcome")
        print("SCHEDULER-SERIAL-AND-CAP PASS")
    }

    private static func proveSchedulerDeadline() async throws {
        let judge = SchedulerProbeJudge(delayNanoseconds: 200_000_000)
        let scheduler = QualityComparisonScheduler(
            judge: judge,
            policy: qualityPolicy(maxQwenRequests: 1, wallBudget: 1, deadline: 0.02)
        )
        let run = await scheduler.run([request(10)])
        try require(run.counts.attempted == 1 && run.counts.failed == 1, "deadline counts")
        try require(run.degradationReason == .deadlineExceeded, "deadline degradation")
        print("SCHEDULER-DEADLINE PASS")
    }

    private static func proveSchedulerCancellation() async throws {
        let judge = SchedulerProbeJudge(blocksUntilCancelled: true)
        let scheduler = QualityComparisonScheduler(
            judge: judge,
            policy: qualityPolicy(maxQwenRequests: 1, wallBudget: 1, deadline: 0.5)
        )
        let task = Task { await scheduler.run([request(20)]) }
        try await judge.waitUntilCalled()
        task.cancel()
        let run = await task.value
        let probe = await judge.snapshot()
        try require(run.degradationReason == .cancellation, "cancellation degradation")
        try require(probe.cancelled.contains(21), "cancellation was not forwarded to judge")
        print("SCHEDULER-CANCELLATION PASS")
    }

    private static func proveSchedulerRejectsStaleRequest() async throws {
        let judge = SchedulerProbeJudge(returnsStaleRequestID: true)
        let scheduler = QualityComparisonScheduler(
            judge: judge,
            policy: qualityPolicy(maxQwenRequests: 1, wallBudget: 1, deadline: 0.5)
        )
        let run = await scheduler.run([request(30)])
        try require(run.comparisons.isEmpty, "stale request was applied")
        try require(run.counts.failed == 1, "stale request was not rejected")
        try require(run.degradationReason == .invalidJudgment, "stale request degradation")
        print("SCHEDULER-STALE-REQUEST PASS")
    }

    private static func proveSelectorDoesNotApplyNativeMinimum() throws {
        let usable = asset("usable")
        let request = selectionRequest(assets: [usable], analyses: [usable.id: analysis(usable.id, quality: 1)])
        let result = try QualityAlbumSelector().select(request).result
        try require(result.selectedAssetIDs.count == 1, "selector did not select the usable asset")
        try require(
            result.selectedAssetIDs.count < request.configuration.minimumFinalCount,
            "quality selector forced the native minimum"
        )
        print("SELECTOR-NO-NATIVE-MINIMUM PASS")
    }

    private static func proveSelectorKeepsUsableWinner() throws {
        let usable = asset("usable-winner")
        let low = asset("low-winner")
        let clusterID = ClusterID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!)
        let momentID = MomentID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!)
        let cluster = PhotoCluster(
            id: clusterID,
            type: .nearDuplicate,
            assetIDs: [usable.id, low.id],
            representativeAssetID: usable.id,
            similarityScore: 1
        )
        let moment = PhotoMoment(
            id: momentID,
            assetIDs: [usable.id, low.id],
            startDate: usable.creationDate,
            endDate: low.creationDate,
            representativeAssetID: usable.id,
            sceneDistribution: [.people: 1]
        )
        let pairRequest = request(40)
        let comparison = QualityPairComparison(
            first: usable.id,
            second: low.id,
            judgment: QualityPairJudgment(
                requestID: pairRequest.requestID,
                generation: pairRequest.generation,
                relation: .retake,
                preference: .chooseB,
                reasons: []
            )
        )
        let selectionRequest = selectionRequest(
            assets: [usable, low],
            analyses: [
                usable.id: analysis(usable.id, quality: 1),
                low.id: analysis(low.id, quality: 0.1),
            ],
            retakeGroups: [cluster],
            coverageGroups: [moment],
            comparisons: [comparison]
        )
        let result = try QualityAlbumSelector().select(selectionRequest).result
        try require(result.selectedAssetIDs == [usable.id], "selector replaced usable winner with low-quality winner")
        print("SELECTOR-USABLE-WINNER-PASS")
    }

    private static func proveQualityCheckpointIdentity() throws {
        let manifest = ModelManifest.qwen35TwoBFourBit
        try require(manifest.manifestDigest.count == 64, "manifest fingerprint length")
        try require(
            manifest.manifestDigest == ModelManifest.qwen35TwoBFourBit.manifestDigest,
            "manifest fingerprint stability"
        )

        guard let identity = QualityCheckpointIdentity.expected(for: .qualityQwen2B) else {
            throw ProofFailure(message: "missing Qwen checkpoint identity")
        }
        try require(identity.modelID == manifest.modelID, "checkpoint model ID")
        try require(identity.modelRevision == manifest.revision, "checkpoint model revision")
        try require(identity.manifestDigest == manifest.manifestDigest, "checkpoint manifest fingerprint")
        let data = try JSONEncoder().encode(identity)
        let decoded = try JSONDecoder().decode(QualityCheckpointIdentity.self, from: data)
        try require(decoded == identity, "checkpoint identity round trip")
        try require(QualityCheckpointIdentity.expected(for: .native) == nil, "native checkpoint compatibility")
        print("QUALITY-CHECKPOINT-IDENTITY PASS")
    }

    private static func selectionRequest(
        assets: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        retakeGroups: [PhotoCluster] = [],
        coverageGroups: [PhotoMoment]? = nil,
        comparisons: [QualityPairComparison] = []
    ) -> QualityAlbumSelectionRequest {
        let moment = coverageGroups ?? [PhotoMoment(
            id: MomentID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!),
            assetIDs: assets.map(\.id),
            startDate: assets.first?.creationDate,
            endDate: assets.last?.creationDate,
            representativeAssetID: assets.first?.id,
            sceneDistribution: [.people: 1]
        )]
        return QualityAlbumSelectionRequest(
            sessionID: SessionID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!),
            sourceAssets: assets,
            analyses: analyses,
            similarityEdges: [],
            groups: QualityGroupSet(
                candidateIDs: assets.map(\.id), retakeGroups: retakeGroups, coverageGroups: moment
            ),
            comparisons: comparisons,
            requestedMode: .qualityNative,
            executedMode: .qualityNative,
            model: nil,
            comparisonCounts: QualityComparisonCounts(),
            degradationReason: nil,
            configuration: AppConfiguration.default.selection,
            qualityPolicy: .default
        )
    }

    private static func asset(_ id: String) -> PhotoAsset {
        PhotoAsset(
            id: AssetID(rawValue: id),
            creationDate: Date(timeIntervalSince1970: 1000),
            pixelWidth: 1000,
            pixelHeight: 1000,
            mediaSubtype: .standard,
            isFavorite: false,
            isEdited: false,
            source: .local
        )
    }

    private static func analysis(_ id: AssetID, quality: Double) -> PhotoAnalysis {
        PhotoAnalysis.make(
            assetID: id,
            technical: TechnicalAnalysis(
                sharpnessScore: quality,
                exposureScore: quality,
                resolutionScore: quality,
                blurProbability: 1 - quality,
                underexposureProbability: 1 - quality,
                overexposureProbability: 1 - quality
            ),
            faceCount: 1,
            groupPhotoScore: quality,
            subjectPlacementScore: quality,
            sceneType: .people,
            aestheticScore: quality,
            featurePrintAvailable: false
        )
    }

    private static func request(_ number: Int) -> QualityPairRequest {
        QualityPairRequest(
            requestID: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!,
            generation: number + 1,
            first: AssetID(rawValue: "first-\(number)"),
            second: AssetID(rawValue: "second-\(number)"),
            task: "compare-v1"
        )
    }

    private static func qualityPolicy(
        maxQwenRequests: Int, wallBudget: TimeInterval, deadline: TimeInterval
    ) -> QualityCurationPolicy {
        QualityCurationPolicy(
            maxSourceAssets: 100,
            pairDistanceCap: 4950,
            maxActiveComparisons: 1,
            maxQwenRequests: maxQwenRequests,
            qwenWallBudget: wallBudget,
            qwenRequestDeadline: deadline,
            maxGeneratedTokens: 128,
            maxDecodedBytes: 4 * 1024,
            maxPromptTokens: 4096,
            qwenImageMaxDimension: 768,
            detailImageMaxDimension: 1536,
            jobBudget: 180,
            memorySoftCeilingBytes2B: 2500 * 1024 * 1024,
            memorySoftCeilingBytes4B: 4000 * 1024 * 1024,
            minimumAdmissionReserveBytes: 512 * 1024 * 1024,
            policyVersion: 1
        )
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw ProofFailure(message: message) }
    }
}
