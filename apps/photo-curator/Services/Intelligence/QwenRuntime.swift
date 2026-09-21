import Foundation
import MLXLMCommon
import MLXVLM
import Tokenizers

struct QwenInferenceResult: Sendable {
    let generation: Int
    let text: String
    let elapsed: TimeInterval
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

enum QwenRuntimeError: Error, Sendable {
    case notLoaded
    case responseTooLarge
    case supersededGeneration
}

/// Owns the MLX model container and keeps model loading strictly local.
actor QwenRuntime {
    private let manifest: ModelManifest
    private var container: ModelContainer?
    private var cancelledGenerations: Set<Int> = []

    init(manifest: ModelManifest = .qwen35TwoBFourBit) {
        self.manifest = manifest
    }

    func load(from directory: URL) async throws -> QwenLoadResult {
        try manifest.validate(at: directory)
        let started = ContinuousClock.now
        let loaded = try await VLMModelFactory.shared.loadContainer(
            from: directory,
            using: LocalTokenizerLoader()
        )
        container = loaded
        return QwenLoadResult(
            modelID: manifest.modelID,
            revision: manifest.revision,
            elapsed: started.duration(to: .now).timeInterval
        )
    }

    func cancel(generation: Int) {
        cancelledGenerations.insert(generation)
    }

    func unload() {
        container = nil
        cancelledGenerations.removeAll()
    }

    func respond(_ request: QwenInferenceRequest) async throws -> QwenInferenceResult {
        let firstImage = request.firstImage
        let secondImage = request.secondImage
        let prompt = request.prompt
        let generation = request.generation
        guard let container else { throw QwenRuntimeError.notLoaded }
        guard !cancelledGenerations.contains(generation) else {
            throw CancellationError()
        }

        let input = UserInput(
            prompt: "Image A is the first image. Image B is the second image.\n\n\(prompt)",
            images: [.url(firstImage), .url(secondImage)],
            additionalContext: ["enable_thinking": false]
        )
        var boundedInput = input
        boundedInput.processing = .init(maxPixels: request.maxPixels)

        let started = ContinuousClock.now
        let prepared = try await container.prepare(input: boundedInput)
        let stream = try await container.generate(
            input: prepared,
            parameters: GenerateParameters(maxTokens: request.maxTokens, temperature: 0)
        )
        var response = ""
        for await event in stream {
            try Task.checkCancellation()
            guard !cancelledGenerations.contains(generation) else {
                throw CancellationError()
            }
            if case let .chunk(text) = event {
                guard response.utf8.count + text.utf8.count <= QwenPairResponseValidator.maxResponseBytes else {
                    throw QwenRuntimeError.responseTooLarge
                }
                response += text
            }
        }
        guard !cancelledGenerations.contains(generation) else {
            throw QwenRuntimeError.supersededGeneration
        }
        return QwenInferenceResult(
            generation: generation,
            text: response,
            elapsed: started.duration(to: .now).timeInterval
        )
    }
}

private extension Duration {
    nonisolated var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1e18
    }
}

private struct LocalTokenizerLoader: TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let tokenizer = try await Tokenizers.AutoTokenizer.from(modelFolder: directory)
        return LocalTokenizer(tokenizer)
    }
}

private struct LocalTokenizer: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) {
        self.upstream = upstream
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? {
        upstream.bosToken
    }

    var eosToken: String? {
        upstream.eosToken
    }

    var unknownToken: String? {
        upstream.unknownToken
    }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages,
                tools: tools,
                additionalContext: additionalContext
            )
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}
