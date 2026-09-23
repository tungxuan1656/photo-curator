import Foundation

/// Explicit execution modes for the small-set quality route.
enum QualityMode: String, Codable, CaseIterable, Sendable {
    case native
    case qualityNative
    case qualityQwen2B
    case qualityQwen4B

    var isQualityMode: Bool {
        self != .native
    }

    var requiresModel: Bool {
        self == .qualityQwen2B || self == .qualityQwen4B
    }
}

/// Closed degradation vocabulary. Persisted metadata must never contain a free-form failure reason.
enum QualityDegradationReason: String, Codable, Sendable {
    case sourceLimitExceeded
    case modelUnavailable
    case modelRevisionMissing
    case runtimeUnsupported
    case invalidJudgment
    case deadlineExceeded
    case cancellation
    case memoryPressure
    case thermalPressure
    case supersededSession
    case partialInput
}

/// Bounds for the quality route. Native large-set settings remain in `SelectionConfiguration`.
struct QualityCurationPolicy: Codable, Sendable {
    let maxSourceAssets: Int
    let pairDistanceCap: Int
    let maxActiveComparisons: Int
    let maxQwenRequests: Int
    let qwenWallBudget: TimeInterval
    let qwenRequestDeadline: TimeInterval
    let maxGeneratedTokens: Int
    let maxDecodedBytes: Int
    let maxPromptTokens: Int
    let qwenImageMaxDimension: Int
    let detailImageMaxDimension: Int
    let jobBudget: TimeInterval
    let memorySoftCeilingBytes2B: UInt64
    let memorySoftCeilingBytes4B: UInt64
    let minimumAdmissionReserveBytes: UInt64
    let policyVersion: Int

    nonisolated static let `default` = Self(
        maxSourceAssets: 100,
        pairDistanceCap: 4950,
        maxActiveComparisons: 1,
        maxQwenRequests: 32,
        qwenWallBudget: 100,
        qwenRequestDeadline: 12,
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

    func mode(for requestedMode: QualityMode, sourceCount _: Int) -> QualityMode {
        guard requestedMode.isQualityMode else { return .native }
        // The native quality route is consistent across all source sizes.
        // Keep this policy seam so old callers and persisted mode values remain
        // source-compatible without retaining the former 100-photo switch.
        return .qualityNative
    }

    func validationErrors() -> [String] {
        var errors: [String] = []
        if maxSourceAssets < 1 {
            errors.append("maxSourceAssets")
        }
        if pairDistanceCap != maxSourceAssets * (maxSourceAssets - 1) / 2 {
            errors.append("pairDistanceCap")
        }
        if maxActiveComparisons != 1 {
            errors.append("maxActiveComparisons")
        }
        if maxQwenRequests < 1 {
            errors.append("maxQwenRequests")
        }
        if qwenWallBudget <= 0 || qwenRequestDeadline <= 0 {
            errors.append("qwenBudget")
        }
        if maxGeneratedTokens < 1 || maxDecodedBytes < 1 || maxPromptTokens < 1 {
            errors.append("outputBounds")
        }
        if qwenImageMaxDimension < 1 || detailImageMaxDimension < qwenImageMaxDimension {
            errors.append("imageBounds")
        }
        if jobBudget < qwenWallBudget {
            errors.append("jobBudget")
        }
        if minimumAdmissionReserveBytes == 0 {
            errors.append("admissionReserve")
        }
        return errors
    }
}
