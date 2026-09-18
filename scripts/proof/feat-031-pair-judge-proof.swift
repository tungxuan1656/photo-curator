import CoreGraphics
import Foundation

protocol PhotoImageLoader: Sendable {
    func thumbnail(for id: AssetID, targetSize: CGSize) async throws -> CGImage
    func analysisImage(for id: AssetID) async throws -> CGImage
    func preview(for id: AssetID, targetSize: CGSize) async throws -> CGImage
}

struct QwenLoadResult: Sendable {
    let modelID: String
    let revision: String
    let elapsed: TimeInterval
}

struct QwenInferenceRequest: Sendable {
    let firstImage: URL
    let secondImage: URL
    let prompt: String
    let generation: Int
    let maxPixels: Int
    let maxTokens: Int
}

struct QwenInferenceResult: Sendable {
    let generation: Int
    let text: String
    let elapsed: TimeInterval
}

actor QwenRuntime {
    private var cancelled: Set<Int> = []
    private var response = "{\"relation\":\"retake\",\"preference\":\"chooseA\",\"reasons\":[]}"
    private var generationOffset = 0
    private var waitForRelease = false
    private var released: Set<Int> = []
    private var entered: Set<Int> = []
    private(set) var lastImageURLs: (URL, URL)?

    func load(from _: URL) async throws -> QwenLoadResult {
        QwenLoadResult(
            modelID: ModelManifest.qwen35TwoBFourBit.modelID,
            revision: ModelManifest.qwen35TwoBFourBit.revision,
            elapsed: 0
        )
    }

    func cancel(generation: Int) {
        cancelled.insert(generation)
    }

    func unload() {}

    func respond(_ request: QwenInferenceRequest) async throws -> QwenInferenceResult {
        lastImageURLs = (request.firstImage, request.secondImage)
        entered.insert(request.generation)
        while waitForRelease && !released.contains(request.generation) {
            guard !cancelled.contains(request.generation) else { throw CancellationError() }
            await Task.yield()
        }
        guard !cancelled.contains(request.generation) else { throw CancellationError() }
        return QwenInferenceResult(
            generation: request.generation + generationOffset,
            text: response,
            elapsed: 0
        )
    }

    func setResponse(_ response: String) {
        self.response = response
    }

    func setGenerationOffset(_ offset: Int) {
        generationOffset = offset
    }

    func setWaitForRelease(_ value: Bool) {
        waitForRelease = value
    }

    func waitUntilEntered(_ generation: Int) async throws {
        for _ in 0 ..< 10000 {
            if entered.contains(generation) {
                return
            }
            await Task.yield()
        }
        throw NSError(domain: "Feat031PairJudgeProof", code: 3)
    }

    func release(_ generation: Int) {
        released.insert(generation)
    }
}

struct ProofImageLoader: PhotoImageLoader {
    let image: CGImage

    func thumbnail(for _: AssetID, targetSize _: CGSize) async throws -> CGImage {
        image
    }

    func analysisImage(for _: AssetID) async throws -> CGImage {
        image
    }

    func preview(for _: AssetID, targetSize _: CGSize) async throws -> CGImage {
        image
    }
}

@main
struct Feat031PairJudgeProof {
    static func main() async throws {
        let image = try makeImage()
        let runtime = QwenRuntime()
        let judge = QwenPairJudge(imageLoader: ProofImageLoader(image: image), runtime: runtime)
        let installation = ModelInstallation(
            directory: FileManager.default.temporaryDirectory,
            modelID: ModelManifest.qwen35TwoBFourBit.modelID,
            revision: ModelManifest.qwen35TwoBFourBit.revision
        )
        _ = try await judge.load(from: installation)

        let first = AssetID(rawValue: "proof-a")
        let second = AssetID(rawValue: "proof-b")
        let valid = QualityPairRequest(
            requestID: UUID(), generation: 1, first: first, second: second, task: "compare-v1"
        )
        let result = try await judge.judge(valid)
        guard result.preference == .chooseA else { throw failure("valid result") }
        try assertLeaseGone(await runtime.lastImageURLs)

        await runtime.setWaitForRelease(true)
        let firstTask = Task {
            try await judge.judge(
                QualityPairRequest(
                    requestID: UUID(), generation: 2, first: first, second: second, task: "compare-v1"
                )
            )
        }
        try await runtime.waitUntilEntered(2)
        do {
            _ = try await judge.judge(
                QualityPairRequest(
                    requestID: UUID(), generation: 20, first: first, second: second, task: "compare-v1"
                )
            )
            throw failure("serialized comparisons")
        } catch QwenPairJudgeError.busy {}
        await runtime.release(2)
        _ = try await firstTask.value
        try assertLeaseGone(await runtime.lastImageURLs)

        let cancelledTask = Task {
            try await judge.judge(
                QualityPairRequest(
                    requestID: UUID(), generation: 3, first: first, second: second, task: "compare-v1"
                )
            )
        }
        try await runtime.waitUntilEntered(3)
        await judge.cancel(generation: 3)
        do {
            _ = try await cancelledTask.value
            throw failure("generation cancellation")
        } catch is CancellationError {}
        try assertLeaseGone(await runtime.lastImageURLs)

        await runtime.setWaitForRelease(false)
        await runtime.setGenerationOffset(1)
        do {
            _ = try await judge.judge(
                QualityPairRequest(
                    requestID: UUID(), generation: 4, first: first, second: second, task: "compare-v1"
                )
            )
            throw failure("stale generation")
        } catch QwenPairJudgeError.staleGeneration {}
        try assertLeaseGone(await runtime.lastImageURLs)

        await runtime.setGenerationOffset(0)
        await runtime.setResponse("```json\n{\"relation\":\"retake\",\"preference\":\"chooseA\",\"reasons\":[]}\n```")
        do {
            _ = try await judge.judge(
                QualityPairRequest(
                    requestID: UUID(), generation: 5, first: first, second: second, task: "compare-v1"
                )
            )
            throw failure("strict response admission")
        } catch is QwenPairResponseValidationError {}
        try assertLeaseGone(await runtime.lastImageURLs)

        print("PAIR-JUDGE PASS")
    }

    private static func assertLeaseGone(_ paths: (URL, URL)?) throws {
        guard let paths,
              !FileManager.default.fileExists(atPath: paths.0.path),
              !FileManager.default.fileExists(atPath: paths.1.path),
              !FileManager.default.fileExists(atPath: paths.0.deletingLastPathComponent().path)
        else { throw failure("terminal lease cleanup") }
    }

    private static func makeImage() throws -> CGImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: 4,
                  height: 4,
                  bitsPerComponent: 8,
                  bytesPerRow: 16,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let image = context.makeImage()
        else { throw failure("image fixture") }
        return image
    }

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "Feat031PairJudgeProof", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
