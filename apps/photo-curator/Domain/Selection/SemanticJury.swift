import CoreGraphics
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The only choices the semantic jury may return. Keep this enum small: the
/// deterministic engine remains authoritative for every other selection rule.
enum SemanticJuryChoice: String, Codable, CaseIterable, Sendable {
    case chooseA
    case chooseB
    case keepBoth
    case abstain
}

/// Opaque provider output. Decoding stays in the router so every provider,
/// including proof-only providers, is held to the same strict schema.
struct SemanticJuryResponse: Sendable {
    let json: String
}

/// Owns one run-local image reference. Timeout cleanup clears the lease even
/// when a provider ignores cancellation, so the detached race task retains
/// only compact candidate facts rather than CGImage storage.
private final class SemanticJuryImageLease: @unchecked Sendable {
    private let lock = NSLock()
    private var image: CGImage?

    init(_ image: CGImage) {
        self.image = image
    }

    var current: CGImage? {
        lock.lock()
        defer { lock.unlock() }
        return image
    }

    func release() {
        lock.lock()
        image = nil
        lock.unlock()
    }
}

/// A request candidate carries only run-local pixels and compact derived facts.
/// It is never Codable and never enters a persisted session row.
struct SemanticJuryCandidate: @unchecked Sendable {
    let assetID: AssetID
    fileprivate let imageLease: SemanticJuryImageLease?
    let score: Double?
    let sceneType: SceneType
    let faceCount: Int

    var image: CGImage? {
        imageLease?.current
    }

    init(
        assetID: AssetID, image: CGImage?, score: Double?, sceneType: SceneType, faceCount: Int
    ) {
        self.assetID = assetID
        imageLease = image.map(SemanticJuryImageLease.init)
        self.score = score
        self.sceneType = sceneType
        self.faceCount = faceCount
    }
}

/// One narrow, bounded comparison. Images are local and released with the
/// request; IDs are used only to map a validated result back to this run.
struct SemanticJuryRequest: @unchecked Sendable {
    let ambiguity: UncertaintyReason
    let question: String
    let candidates: [SemanticJuryCandidate]

    func releaseImages() {
        candidates.forEach { $0.imageLease?.release() }
    }

    func withImages(_ images: [AssetID: CGImage]) -> SemanticJuryRequest? {
        let candidates = candidates.map { candidate in
            SemanticJuryCandidate(
                assetID: candidate.assetID,
                image: images[candidate.assetID],
                score: candidate.score,
                sceneType: candidate.sceneType,
                faceCount: candidate.faceCount
            )
        }
        guard candidates.allSatisfy({ $0.image != nil }) else { return nil }
        return SemanticJuryRequest(ambiguity: ambiguity, question: question, candidates: candidates)
    }
}

/// Provider seam owned by feat-027. Implementations must be on-device and
/// bounded by the router; they must not persist or emit telemetry.
protocol SemanticJuryProvider: Sendable {
    func judge(_ request: SemanticJuryRequest) async throws -> SemanticJuryResponse
}

enum SemanticJuryError: Error, Sendable {
    case unavailable
    case malformedResponse
}

enum SemanticJuryDiagnostic: Sendable, Equatable {
    case notAvailable
    case notAdmitted
    case invalid
    case timedOut
    case cancelled
    case failed
    case accepted
    case deterministicFallback
}

struct SemanticJuryOverride: Sendable, Equatable {
    let first: AssetID
    let second: AssetID
    let choice: SemanticJuryChoice
}

struct SemanticJuryEvaluation: Sendable {
    let overrides: [SemanticJuryOverride]
    let diagnostics: [SemanticJuryDiagnostic]
}

/// Product policy is deliberately not configurable. A new threshold or bound
/// requires a decision-log entry and fresh evidence.
enum SemanticJuryPolicy: Sendable {
    nonisolated static let maximumCandidates = 6
    nonisolated static let maximumRequests = 4
    nonisolated static let requestTimeoutNanoseconds: UInt64 = 2_000_000_000

    nonisolated static func isAvailableOnProductOS() -> Bool {
        if #available(iOS 27.0, *) {
            return true
        }
        return false
    }

    nonisolated static func isAdmitted(_ request: SemanticJuryRequest) -> Bool {
        guard request.ambiguity == .faceTradeoff || request.ambiguity == .similarAlternatives else {
            return false
        }
        guard request.candidates.count >= 2, request.candidates.count <= maximumCandidates else { return false }
        let ids = request.candidates.map(\.assetID)
        guard Set(ids).count == ids.count else { return false }
        guard request.candidates.allSatisfy({ $0.image != nil }) else { return false }
        return !request.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// swiftlint:disable nesting
/// Strict schema validator and bounded request runner. Diagnostics contain no
/// candidate IDs, raw model text, pixels, or errors.
struct SemanticJuryRouter: Sendable {
    let provider: any SemanticJuryProvider
    private let availability: @Sendable () -> Bool

    init(
        provider: any SemanticJuryProvider,
        availability: @escaping @Sendable () -> Bool = { SemanticJuryPolicy.isAvailableOnProductOS() }
    ) {
        self.provider = provider
        self.availability = availability
    }

    func evaluate(_ requests: [SemanticJuryRequest]) async -> SemanticJuryEvaluation {
        guard availability() else {
            return SemanticJuryEvaluation(overrides: [], diagnostics: [.notAvailable])
        }
        var overrides: [SemanticJuryOverride] = []
        var diagnostics: [SemanticJuryDiagnostic] = []
        for request in requests.prefix(SemanticJuryPolicy.maximumRequests) {
            guard !Task.isCancelled else {
                diagnostics.append(.cancelled)
                break
            }
            guard SemanticJuryPolicy.isAdmitted(request) else {
                diagnostics.append(.notAdmitted)
                continue
            }
            do {
                let response = try await Self.withTimeout(
                    operation: { try await provider.judge(request) },
                    onTimeout: { request.releaseImages() }
                )
                let output = try Self.decode(response)
                guard let override = Self.override(from: output, request: request) else {
                    diagnostics.append(.deterministicFallback)
                    continue
                }
                overrides.append(override)
                diagnostics.append(.accepted)
            } catch is JuryTimeout {
                diagnostics.append(.timedOut)
            } catch is CancellationError {
                diagnostics.append(.cancelled)
                if Task.isCancelled {
                    break
                }
            } catch SemanticJuryError.unavailable {
                diagnostics.append(.failed)
            } catch {
                diagnostics.append(.invalid)
            }
        }
        return SemanticJuryEvaluation(overrides: overrides, diagnostics: diagnostics)
    }

    private struct JuryTimeout: Error {}
    private static func withTimeout<T: Sendable>(
        operation: @escaping @Sendable () async throws -> T,
        onTimeout: @escaping @Sendable () -> Void
    ) async throws -> T {
        let race = TimeoutRace<T>()
        return try await withTaskCancellationHandler(operation: {
            let operationTask = Task.detached {
                do {
                    try race.finish(.success(await operation()))
                } catch {
                    race.finish(.failure(error))
                }
            }
            let timeoutTask = Task.detached {
                do {
                    try await Task.sleep(nanoseconds: SemanticJuryPolicy.requestTimeoutNanoseconds)
                    race.finish(.failure(JuryTimeout()), beforeResume: onTimeout)
                } catch {
                    // The losing timer is cancelled by TimeoutRace.
                }
            }
            race.install(operationTask: operationTask, timeoutTask: timeoutTask)
            if Task.isCancelled {
                race.finish(.failure(CancellationError()), beforeResume: onTimeout)
            }
            return try await withCheckedThrowingContinuation { continuation in
                race.install(continuation)
            }
        }, onCancel: {
            race.finish(.failure(CancellationError()), beforeResume: onTimeout)
        })
    }

    /// The timeout winner resumes the caller immediately. The provider task is
    /// cancelled and detached from this scope, so a non-cooperative provider
    /// cannot hold deterministic completion hostage.
    private final class TimeoutRace<Value: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var result: Result<Value, Error>?
        private var continuation: CheckedContinuation<Value, Error>?
        private var operationTask: Task<Void, Never>?
        private var timeoutTask: Task<Void, Never>?

        func install(_ continuation: CheckedContinuation<Value, Error>) {
            lock.lock()
            guard let result else {
                self.continuation = continuation
                lock.unlock()
                return
            }
            lock.unlock()
            continuation.resume(with: result)
        }

        func install(operationTask: Task<Void, Never>, timeoutTask: Task<Void, Never>) {
            lock.lock()
            guard result == nil else {
                lock.unlock()
                operationTask.cancel()
                timeoutTask.cancel()
                return
            }
            self.operationTask = operationTask
            self.timeoutTask = timeoutTask
            lock.unlock()
        }

        func finish(
            _ result: Result<Value, Error>, beforeResume: (@Sendable () -> Void)? = nil
        ) {
            lock.lock()
            guard self.result == nil else {
                lock.unlock()
                return
            }
            self.result = result
            let continuation = self.continuation
            self.continuation = nil
            let operationTask = self.operationTask
            self.operationTask = nil
            let timeoutTask = self.timeoutTask
            self.timeoutTask = nil
            lock.unlock()
            beforeResume?()
            operationTask?.cancel()
            timeoutTask?.cancel()
            continuation?.resume(with: result)
        }
    }

    private struct StrictChoice: Codable, Sendable {
        let choice: SemanticJuryChoice

        enum CodingKeys: String, CodingKey {
            case choice
        }

        private enum OpenKey: CodingKey {
            case value(String)

            var stringValue: String {
                switch self {
                case let .value(value): return value
                }
            }

            init?(stringValue: String) {
                self = .value(stringValue)
            }

            var intValue: Int? {
                nil
            }

            init?(intValue _: Int) {
                return nil
            }
        }

        init(choice: SemanticJuryChoice) {
            self.choice = choice
        }

        init(from decoder: Decoder) throws {
            let open = try decoder.container(keyedBy: OpenKey.self)
            guard Set(open.allKeys.map(\.stringValue)) == Set(["choice"]) else {
                throw SemanticJuryError.malformedResponse
            }
            let keyed = try decoder.container(keyedBy: CodingKeys.self)
            choice = try keyed.decode(SemanticJuryChoice.self, forKey: .choice)
        }
    }

    private static func decode(_ response: SemanticJuryResponse) throws -> StrictChoice {
        guard let data = response.json.data(using: .utf8) else {
            throw SemanticJuryError.malformedResponse
        }
        return try JSONDecoder().decode(StrictChoice.self, from: data)
    }

    private static func override(
        from output: StrictChoice, request: SemanticJuryRequest
    ) -> SemanticJuryOverride? {
        guard request.candidates.count == 2 else { return nil }
        let first = request.candidates[0].assetID
        let second = request.candidates[1].assetID
        switch output.choice {
        case .chooseA, .chooseB:
            return SemanticJuryOverride(first: first, second: second, choice: output.choice)
        case .keepBoth, .abstain:
            return nil
        }
    }
    // swiftlint:enable nesting
}

struct NoopSemanticJuryProvider: SemanticJuryProvider {
    func judge(_: SemanticJuryRequest) async throws -> SemanticJuryResponse {
        throw SemanticJuryError.unavailable
    }
}

#if canImport(FoundationModels)
// This condition is enabled only by the iOS 27 SDK build configuration. The
// current iOS 26 SDK exposes FoundationModels but not Attachment, so it must
// compile the typed deterministic fallback rather than hide the whole adapter
// behind a compiler-version check.
#if FOUNDATION_MODELS_IMAGE_ATTACHMENTS
@Generable
private struct NativeOutput {
    @Guide(description: "Exactly one of chooseA, chooseB, keepBoth, or abstain.")
    var choice: String
}
#endif
/// Native adapter. The product gate is iOS 27 even though the SDK's
/// Foundation Models framework is weak-linkable from the iOS 26 deployment.
struct FoundationModelsSemanticJuryProvider: SemanticJuryProvider {
    func judge(_ request: SemanticJuryRequest) async throws -> SemanticJuryResponse {
        guard #available(iOS 27.0, *) else { throw SemanticJuryError.unavailable }
        return try await judgeOnAvailableOS(request)
    }

    @available(iOS 27.0, *)
    private func judgeOnAvailableOS(_ request: SemanticJuryRequest) async throws -> SemanticJuryResponse {
        #if FOUNDATION_MODELS_IMAGE_ATTACHMENTS
        let model = SystemLanguageModel.default
        guard model.isAvailable else { throw SemanticJuryError.unavailable }
        let facts = request.candidates.enumerated().map { index, candidate in
            let label = index == 0 ? "A" : "B"
            let score = candidate.score.map { String($0) } ?? "unknown"
            return "Candidate \(label): score=\(score), scene=\(candidate.sceneType.rawValue), "
                + "faces=\(candidate.faceCount), image=attached"
        }.joined(separator: "\n")
        guard request.candidates.allSatisfy({ $0.image != nil }) else {
            throw SemanticJuryError.malformedResponse
        }
        let session = LanguageModelSession(model: model)
        let options = GenerationOptions(sampling: .greedy, maximumResponseTokens: 16)
        let response = try await session.respond(
            generating: NativeOutput.self,
            includeSchemaInPrompt: true,
            options: options
        ) {
            """
            Compare exactly the supplied local candidate images for this narrow curation question.
            Return only JSON with one key: choice. Allowed values: chooseA, chooseB, keepBoth, abstain.
            Prefer abstain when evidence is unclear. Never invent candidates.
            Question: \(request.question)
            Ambiguity: \(request.ambiguity.rawValue)
            \(facts)
            """
            for (index, candidate) in request.candidates.enumerated() {
                if let image = candidate.image {
                    Attachment(image).label(index == 0 ? "candidate-A" : "candidate-B")
                }
            }
        }
        return SemanticJuryResponse(json: response.rawContent.jsonString)
        #else
        // The current SDK has no typed image-attachment API. Never downgrade
        // to a text-only request; deterministic routing remains the fallback.
        _ = request
        throw SemanticJuryError.unavailable
        #endif
    }
}
#endif

/// Converts the persisted deterministic result into the only pair shapes that
/// feat-026 can admit without guessing at non-persisted cluster/moment state.
enum SemanticJuryRequestFactory: Sendable {
    static func requests(
        result: SelectionResult,
        sourceAssets: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis]
    ) -> [SemanticJuryRequest] {
        let sourceOrder = Dictionary(uniqueKeysWithValues: sourceAssets.enumerated().map { ($1.id, $0) })
        let byID = Dictionary(uniqueKeysWithValues: sourceAssets.map { ($0.id, $0) })
        let decisions = result.decisions
        var requests: [SemanticJuryRequest] = []
        for decision in decisions where decision.status == .selected {
            let ambiguity: UncertaintyReason?
            let question: String
            if decision.reasons.contains("bestGroupPhoto") {
                ambiguity = .faceTradeoff
                question = "Which supplied image is the stronger group representation while preserving usable faces?"
            } else if decision.reasons.contains("nearDuplicateRepresentative") {
                ambiguity = .similarAlternatives
                question = "Which supplied image better represents this similar-photo choice "
                    + "without losing meaningful variation?"
            } else {
                ambiguity = nil
                question = ""
            }
            guard let ambiguity else { continue }
            guard let rival = decisions.first(where: {
                $0.status == .rejected && $0.competingIDs.contains(decision.assetID)
            }) else { continue }
            guard let firstAsset = byID[decision.assetID], let secondAsset = byID[rival.assetID],
                  let firstAnalysis = analyses[firstAsset.id], let secondAnalysis = analyses[secondAsset.id]
            else { continue }
            var candidates: [SemanticJuryCandidate] = []
            candidates.append(SemanticJuryCandidate(
                assetID: firstAsset.id, image: nil,
                score: decision.score ?? firstAnalysis.qualityScore,
                sceneType: firstAnalysis.content.sceneType, faceCount: firstAnalysis.people.faceCount
            ))
            candidates.append(SemanticJuryCandidate(
                assetID: secondAsset.id, image: nil,
                score: rival.score ?? secondAnalysis.qualityScore,
                sceneType: secondAnalysis.content.sceneType, faceCount: secondAnalysis.people.faceCount
            ))
            requests.append(SemanticJuryRequest(ambiguity: ambiguity, question: question, candidates: candidates))
        }
        return requests.sorted {
            let left = sourceOrder[$0.candidates[0].assetID] ?? Int.max
            let right = sourceOrder[$1.candidates[0].assetID] ?? Int.max
            if left != right {
                return left < right
            }
            return $0.candidates[1].assetID.rawValue < $1.candidates[1].assetID.rawValue
        }
    }
}
