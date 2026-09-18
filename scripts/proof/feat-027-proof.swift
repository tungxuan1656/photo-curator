// swiftlint:disable function_body_length
import CoreGraphics
import Foundation

actor CallCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

actor RequestProbe {
    private(set) var calls = 0
    private(set) var candidateIDs: [[AssetID]] = []
    private(set) var allImagesPresent = true

    func record(_ request: SemanticJuryRequest) {
        calls += 1
        candidateIDs.append(request.candidates.map(\.assetID))
        allImagesPresent = allImagesPresent && request.candidates.allSatisfy { $0.image != nil }
    }
}

struct ScriptedJuryProvider: SemanticJuryProvider {
    let response: String?
    let error: Error?
    let delayNanoseconds: UInt64
    let counter: CallCounter
    let probe: RequestProbe?

    func judge(_ request: SemanticJuryRequest) async throws -> SemanticJuryResponse {
        await counter.increment()
        if let probe {
            await probe.record(request)
        }
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let error {
            throw error
        }
        return SemanticJuryResponse(json: response ?? "{}")
    }
}

struct IgnoringCancellationProvider: SemanticJuryProvider {
    let counter: CallCounter

    func judge(_ request: SemanticJuryRequest) async throws -> SemanticJuryResponse {
        await counter.increment()
        // Deliberately ignores Task cancellation. The router must release its
        // image lease at the deadline, after which this finite probe returns.
        while request.candidates.contains(where: { $0.image != nil }) {
            await Task.yield()
        }
        return SemanticJuryResponse(json: "{\"choice\":\"chooseA\"}")
    }
}

struct ProofImageLoader: PhotoImageLoader {
    let image: CGImage
    let requested: RequestProbe

    func thumbnail(for _: AssetID, targetSize _: CGSize) async throws -> CGImage {
        image
    }

    func analysisImage(for id: AssetID) async throws -> CGImage {
        await requested.record(
            SemanticJuryRequest(
                ambiguity: .similarAlternatives,
                question: "proof",
                candidates: [SemanticJuryCandidate(
                    assetID: id, image: image, score: nil, sceneType: .other, faceCount: 0
                )]
            )
        )
        return image
    }

    func preview(for _: AssetID, targetSize _: CGSize) async throws -> CGImage {
        image
    }
}

struct ProviderFailure: Error, Sendable {}

enum ProofFailure: Error {
    case assertion(String)
}

@main
struct SemanticJuryProof {
    static func main() async {
        do {
            try await run()
            print("RESULT PASS")
        } catch {
            print("RESULT FAIL \(error)")
            exit(1)
        }
    }

    static func run() async throws {
        let image = try makeImage()
        let (assets, analyses, edges) = makeSelectionFixture()
        let configuration = AppConfiguration.default.selection
        let engine = SelectionEngine()
        let deterministic = try engine.select(
            assets: assets,
            analyses: analyses,
            configuration: configuration,
            feedback: nil,
            similarityEdges: edges
        )
        let requests = SemanticJuryRequestFactory.requests(
            result: deterministic, sourceAssets: assets, analyses: analyses
        )
        try require(requests.count == 2, "request factory omitted an admitted pair")
        try require(
            requests.map { $0.candidates[0].assetID.rawValue } == ["d0", "a0"],
            "request factory ordering changed"
        )
        try require(requests.allSatisfy { $0.candidates.allSatisfy { $0.image == nil } }, "factory persisted pixels")
        print("REQUEST-FACTORY ordering=d0,a0 PASS")

        let unrelatedOverride = SemanticJuryOverride(
            first: AssetID(rawValue: "a0"), second: AssetID(rawValue: "b0"), choice: .chooseB
        )
        let untouched = try engine.applyJuryOverrides(
            to: deterministic,
            assets: assets,
            analyses: analyses,
            configuration: configuration,
            similarityEdges: edges,
            overrides: [unrelatedOverride]
        )
        try require(
            Set(untouched.selectedAssetIDs) == Set(deterministic.selectedAssetIDs),
            "unrelated IDs changed for a cross-cluster override"
        )
        print("ENGINE same-cluster-only PASS unrelated-selection-preserved")

        let ios26Calls = CallCounter()
        let ios26Probe = RequestProbe()
        let ios26Coordinator = makeCoordinator(
            provider: ScriptedJuryProvider(
                response: "{\"choice\":\"chooseB\"}", error: nil,
                delayNanoseconds: 0, counter: ios26Calls, probe: ios26Probe
            ),
            loaderProbe: ios26Probe,
            image: image,
            availability: { false }
        )
        let ios26 = try await ios26Coordinator.applySemanticJury(
            to: deterministic, assets: assets, analyses: analyses, configuration: configuration,
            similarityEdges: edges, tierCEdges: []
        )
        try require(ios26.selectedAssetIDs == deterministic.selectedAssetIDs, "iOS 26 result changed")
        try require(await ios26Calls.value == 0, "iOS 26 invoked the provider")
        try require(await ios26Probe.calls == 0, "iOS 26 loaded jury images")
        print("IOS26 coordinator gate PASS providerCalls=0 imageLoads=0")

        let acceptedCalls = CallCounter()
        let acceptedProbe = RequestProbe()
        let acceptedCoordinator = makeCoordinator(
            provider: ScriptedJuryProvider(
                response: "{\"choice\":\"chooseB\"}", error: nil,
                delayNanoseconds: 0, counter: acceptedCalls, probe: acceptedProbe
            ),
            loaderProbe: acceptedProbe,
            image: image,
            availability: { true }
        )
        let accepted = try await acceptedCoordinator.applySemanticJury(
            to: deterministic, assets: assets, analyses: analyses, configuration: configuration,
            similarityEdges: edges, tierCEdges: []
        )
        let acceptedIDs = Set(accepted.selectedAssetIDs)
        try require(acceptedIDs.contains(AssetID(rawValue: "a1")), "same-cluster chooseB did not swap a1")
        try require(acceptedIDs.contains(AssetID(rawValue: "d1")), "same-cluster chooseB did not swap d1")
        try require(acceptedIDs.contains(AssetID(rawValue: "b0")), "unrelated selected b0 was lost")
        try require(!acceptedIDs.contains(AssetID(rawValue: "a0")), "losing a0 remained selected")
        try require(!acceptedIDs.contains(AssetID(rawValue: "d0")), "losing d0 remained selected")
        try require(await acceptedCalls.value == 2, "coordinator request count changed")
        try require(await acceptedProbe.allImagesPresent, "provider did not receive in-memory images")
        print("COORDINATOR integration PASS requests=2 images=present unrelated=b0")

        let failedCalls = CallCounter()
        let failedCoordinator = makeCoordinator(
            provider: ScriptedJuryProvider(
                response: nil, error: ProviderFailure(), delayNanoseconds: 0,
                counter: failedCalls, probe: nil
            ),
            loaderProbe: RequestProbe(),
            image: image,
            availability: { true }
        )
        let failed = try await failedCoordinator.applySemanticJury(
            to: deterministic, assets: assets, analyses: analyses, configuration: configuration,
            similarityEdges: edges, tierCEdges: []
        )
        try require(
            failed.selectedAssetIDs == deterministic.selectedAssetIDs,
            "generic provider failure changed selection"
        )
        try require(await failedCalls.value == 2, "generic provider failure did not exercise calls")
        print("GENERIC provider-failure PASS deterministic-fallback")

        let request = SemanticJuryRequest(
            ambiguity: .similarAlternatives,
            question: "Choose the stronger supplied image.",
            candidates: [
                SemanticJuryCandidate(
                    assetID: AssetID(rawValue: "golden-a"), image: image, score: 0.8, sceneType: .people, faceCount: 2
                ),
                SemanticJuryCandidate(
                    assetID: AssetID(rawValue: "golden-b"), image: image, score: 0.7, sceneType: .people, faceCount: 2
                ),
            ]
        )
        let cancellationRequest = request.withImages(
            Dictionary(uniqueKeysWithValues: request.candidates.map { ($0.assetID, image) })
        )!

        let router26Calls = CallCounter()
        let router26 = await SemanticJuryRouter(
            provider: ScriptedJuryProvider(
                response: "{\"choice\":\"chooseB\"}", error: nil,
                delayNanoseconds: 0, counter: router26Calls, probe: nil
            ), availability: { false }
        ).evaluate([request])
        try require(router26.overrides.isEmpty, "iOS 26 produced a jury override")
        try require(router26.diagnostics == [.notAvailable], "iOS 26 gate diagnostic mismatch")
        try require(await router26Calls.value == 0, "iOS 26 router invoked the provider")

        let acceptedRouterCalls = CallCounter()
        let acceptedRouter = await SemanticJuryRouter(
            provider: ScriptedJuryProvider(
                response: "{\"choice\":\"chooseB\"}", error: nil,
                delayNanoseconds: 0, counter: acceptedRouterCalls, probe: nil
            ), availability: { true }
        ).evaluate([request])
        try require(acceptedRouter.overrides.count == 1, "valid chooseB was not accepted")
        try require(await acceptedRouterCalls.value == 1, "valid provider call count mismatch")
        print("IOS27 seam accepted PASS choice=chooseB")

        let malformedRows = [
            "{}",
            "{\"choice\":\"chooseC\"}",
            "{\"choice\":\"chooseA\",\"debug\":true}",
            "{\"choice\":\"chooseA\"} trailing",
        ]
        for row in malformedRows {
            let output = await SemanticJuryRouter(
                provider: ScriptedJuryProvider(
                    response: row, error: nil, delayNanoseconds: 0,
                    counter: CallCounter(), probe: nil
                ), availability: { true }
            ).evaluate([request])
            try require(output.overrides.isEmpty, "malformed response accepted: \(row)")
            try require(output.diagnostics == [.invalid], "malformed response diagnostic mismatch")
        }
        print("STRICT schema PASS invalidRows=4")

        for choice in ["keepBoth", "abstain"] {
            let output = await SemanticJuryRouter(
                provider: ScriptedJuryProvider(
                    response: "{\"choice\":\"\(choice)\"}", error: nil,
                    delayNanoseconds: 0, counter: CallCounter(), probe: nil
                ), availability: { true }
            ).evaluate([request])
            try require(output.overrides.isEmpty, "unsafe \(choice) changed selection")
            try require(output.diagnostics == [.deterministicFallback], "unsafe choice fallback mismatch")
        }
        print("SAFE choice fallback PASS keepBoth+abstain")
        #if canImport(FoundationModels)
        do {
            _ = try await FoundationModelsSemanticJuryProvider().judge(request)
            throw ProofFailure.assertion("native adapter unexpectedly ran below iOS 27")
        } catch SemanticJuryError.unavailable {
            print("NATIVE adapter iOS27-gated current-SDK fallback PASS")
        }
        #endif

        let oversized = SemanticJuryRequest(
            ambiguity: .similarAlternatives,
            question: "Too many candidates.",
            candidates: (0 ..< 7).map { index in
                SemanticJuryCandidate(
                    assetID: AssetID(rawValue: "oversized-\(index)"), image: image,
                    score: 0.8, sceneType: .people, faceCount: 2
                )
            }
        )
        let oversizedCalls = CallCounter()
        let oversizedOutput = await SemanticJuryRouter(
            provider: ScriptedJuryProvider(
                response: "{\"choice\":\"chooseA\"}", error: nil,
                delayNanoseconds: 0, counter: oversizedCalls, probe: nil
            ), availability: { true }
        ).evaluate([oversized])
        try require(oversizedOutput.overrides.isEmpty, "oversized request was admitted")
        try require(oversizedOutput.diagnostics == [.notAdmitted], "oversized diagnostic mismatch")
        try require(await oversizedCalls.value == 0, "oversized request called provider")
        print("BOUNDS PASS candidates=7 rejected")

        let unavailable = await SemanticJuryRouter(
            provider: ScriptedJuryProvider(
                response: nil, error: SemanticJuryError.unavailable,
                delayNanoseconds: 0, counter: CallCounter(), probe: nil
            ), availability: { true }
        ).evaluate([request])
        try require(unavailable.overrides.isEmpty, "unavailable provider changed selection")
        try require(unavailable.diagnostics == [.failed], "unavailable fallback diagnostic mismatch")
        print("UNAVAILABLE fallback PASS")

        let genericFailure = await SemanticJuryRouter(
            provider: ScriptedJuryProvider(
                response: nil, error: ProviderFailure(),
                delayNanoseconds: 0, counter: CallCounter(), probe: nil
            ), availability: { true }
        ).evaluate([request])
        try require(genericFailure.overrides.isEmpty, "generic failure changed selection")
        try require(genericFailure.diagnostics == [.invalid], "generic failure diagnostic mismatch")

        let timeoutRequest = request
        let timeoutStarted = DispatchTime.now().uptimeNanoseconds
        let timeout = await SemanticJuryRouter(
            provider: IgnoringCancellationProvider(counter: CallCounter()), availability: { true }
        ).evaluate([timeoutRequest])
        let timeoutElapsed = DispatchTime.now().uptimeNanoseconds - timeoutStarted
        try require(timeout.overrides.isEmpty, "timed-out provider changed selection")
        try require(timeout.diagnostics == [.timedOut], "timeout fallback diagnostic mismatch")
        try require(timeoutElapsed < 2_750_000_000, "timeout exceeded hard bound: \(timeoutElapsed)ns")
        try require(
            timeoutRequest.candidates.allSatisfy { $0.image == nil },
            "timed-out request retained candidate images"
        )
        print("TIMEOUT fallback PASS nonCooperative=true elapsedMs=\(timeoutElapsed / 1_000_000) imagesReleased=true")

        let cancelledTask = Task {
            await SemanticJuryRouter(
                provider: ScriptedJuryProvider(
                    response: "{\"choice\":\"chooseA\"}", error: nil,
                    delayNanoseconds: 3_000_000_000, counter: CallCounter(), probe: nil
                ), availability: { true }
            ).evaluate([cancellationRequest])
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        cancelledTask.cancel()
        let cancelled = await cancelledTask.value
        try require(cancelled.overrides.isEmpty, "cancelled provider changed selection")
        try require(cancelled.diagnostics == [.cancelled], "cancel diagnostic mismatch")
        print("CANCELLATION fallback PASS")

        let ids = (0 ..< 200).map { AssetID(rawValue: String(format: "golden-%03d", $0)) }
        let goldenRequests = stride(from: 0, to: 200, by: 2).map { index in
            SemanticJuryRequest(
                ambiguity: .similarAlternatives,
                question: "Golden-shaped comparison.",
                candidates: [
                    SemanticJuryCandidate(
                        assetID: ids[index], image: image, score: 0.8, sceneType: .people, faceCount: 2
                    ),
                    SemanticJuryCandidate(
                        assetID: ids[index + 1], image: image, score: 0.7, sceneType: .people, faceCount: 2
                    ),
                ]
            )
        }
        let goldenCalls = CallCounter()
        let goldenProvider = ScriptedJuryProvider(
            response: "{\"choice\":\"chooseA\"}", error: nil,
            delayNanoseconds: 0, counter: goldenCalls, probe: nil
        )
        let goldenRouter = SemanticJuryRouter(provider: goldenProvider, availability: { true })
        let first = await goldenRouter.evaluate(goldenRequests)
        let second = await goldenRouter.evaluate(goldenRequests)
        try require(first.overrides.count == 4, "request cap changed: \(first.overrides.count)")
        try require(first.overrides == second.overrides, "Golden run was not deterministic")
        try require(first.diagnostics == second.diagnostics, "Golden diagnostics changed")
        try require(await goldenCalls.value == 8, "Golden request cap call count changed")
        print("GOLDEN-SHAPED candidates=200 requests=100 attempts=4 PASS")
    }

    static func makeCoordinator(
        provider: any SemanticJuryProvider,
        loaderProbe: RequestProbe,
        image: CGImage,
        availability: @escaping @Sendable () -> Bool
    ) -> SelectionSessionCoordinator {
        let files = FileStore(rootDirectory: FileManager.default.temporaryDirectory)
        return SelectionSessionCoordinator(
            imageLoader: ProofImageLoader(image: image, requested: loaderProbe),
            analyzer: NoopImageAnalyzer(),
            analysisCache: NoopAnalysisCache(),
            checkpointStore: SessionCheckpointStore(files: files),
            engine: SelectionEngine(),
            tierCProvider: NoopVisualEmbeddingProvider(),
            semanticJuryProvider: provider,
            semanticJuryAvailability: availability
        )
    }

    static func makeSelectionFixture() -> ([PhotoAsset], [AssetID: PhotoAnalysis], [SimilarityEdge]) {
        let ids = ["d0", "d1", "b0", "a0", "a1"].map(AssetID.init(rawValue:))
        let assets = ids.enumerated().map { index, id in
            PhotoAsset(
                id: id,
                creationDate: Date(timeIntervalSince1970: Double(index)),
                pixelWidth: 1000,
                pixelHeight: 1000,
                mediaSubtype: .standard,
                isFavorite: false,
                isEdited: false,
                source: .local
            )
        }
        let analyses = Dictionary(uniqueKeysWithValues: ids.map { id in
            let isWinner = id.rawValue == "a0" || id.rawValue == "d0" || id.rawValue == "b0"
            let score = isWinner ? 0.95 : 0.7
            return (
                id,
                PhotoAnalysis.make(
                    assetID: id,
                    technical: TechnicalAnalysis(
                        sharpnessScore: score, exposureScore: score, resolutionScore: score,
                        blurProbability: 0, underexposureProbability: 0, overexposureProbability: 0
                    ),
                    faceCount: 2,
                    groupPhotoScore: score,
                    subjectPlacementScore: score,
                    sceneType: .people,
                    minFaceQuality: score,
                    meanFaceQuality: score
                )
            )
        })
        return (
            assets,
            analyses,
            [
                SimilarityEdge(first: AssetID(rawValue: "a0"), second: AssetID(rawValue: "a1"), distance: 0.1),
                SimilarityEdge(first: AssetID(rawValue: "d0"), second: AssetID(rawValue: "d1"), distance: 0.1),
            ]
        )
    }

    static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw ProofFailure.assertion(message) }
    }

    static func makeImage() throws -> CGImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                  space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let image = context.makeImage()
        else { throw ProofFailure.assertion("could not create fixture image") }
        return image
    }
}
