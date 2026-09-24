import Foundation

/// A run-local hash value used only to find cross-date candidates.
///
/// This type intentionally does not conform to `Codable`: input hashes are
/// retrieval aids and are never part of a catalog projection.
struct ComparisonInputHash: Hashable, Sendable {
    let rawValue: UInt64
}

/// The two independent bounded paths that can propose a visual comparison.
enum ComparisonCandidatePath: String, Codable, Hashable, Sendable {
    case chronologicalNeighbors
    case inputHashBucket
}

/// Cheap, transient input to candidate retrieval. It contains metadata only;
/// the hash is supplied by the current analysis run and is not persisted.
struct ComparisonCandidateInput: Hashable, Sendable {
    let id: AssetID
    let creationDate: Date?
    let inputHash: ComparisonInputHash?

    init(id: AssetID, creationDate: Date?, inputHash: ComparisonInputHash? = nil) {
        self.id = id
        self.creationDate = creationDate
        self.inputHash = inputHash
    }
}

/// One bounded proposal. A proposal is not evidence of visual similarity;
/// callers must validate it with image-derived evidence before grouping.
struct ComparisonCandidate: Hashable, Sendable {
    let first: AssetID
    let second: AssetID
    let relation: ComparisonGroupRelation
    let path: ComparisonCandidatePath

    init(
        first: AssetID,
        second: AssetID,
        relation: ComparisonGroupRelation,
        path: ComparisonCandidatePath
    ) {
        if first.rawValue < second.rawValue {
            self.first = first
            self.second = second
        } else {
            self.first = second
            self.second = first
        }
        self.relation = relation
        self.path = path
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(first)
        hasher.combine(second)
        hasher.combine(relation.rawValue)
        hasher.combine(path)
    }
}

struct ComparisonRetrieverConfiguration: Hashable, Sendable {
    let maxChronologicalNeighborsPerAsset: Int
    let sameCaptureTimeWindow: TimeInterval
    let maxHashBucketSize: Int
    let maxHashCandidatesPerAsset: Int

    init(
        maxChronologicalNeighborsPerAsset: Int = 3,
        sameCaptureTimeWindow: TimeInterval = 90,
        maxHashBucketSize: Int = 32,
        maxHashCandidatesPerAsset: Int = 8
    ) {
        self.maxChronologicalNeighborsPerAsset = max(0, maxChronologicalNeighborsPerAsset)
        self.sameCaptureTimeWindow = sameCaptureTimeWindow.isFinite ? max(0, sameCaptureTimeWindow) : 0
        self.maxHashBucketSize = max(0, maxHashBucketSize)
        self.maxHashCandidatesPerAsset = max(0, maxHashCandidatesPerAsset)
    }
}

/// Explicitly reports retrieval truncation. A complete result means only that
/// this bounded retriever did not overflow; it is not a whole-library recall
/// claim.
struct ComparisonCandidateCoverage: Hashable, Sendable {
    /// Number of eligible candidate pairs omitted by any retrieval bound.
    let omittedCandidateCount: Int

    var isComplete: Bool {
        omittedCandidateCount == 0
    }
}

struct ComparisonCandidateRetrieval: Sendable {
    let candidates: [ComparisonCandidate]
    let coverage: ComparisonCandidateCoverage
}

private struct HashCandidateResult: Sendable {
    let candidates: Set<ComparisonCandidate>
    let omittedCandidateCount: Int
}

private struct HashCandidateAccumulator: Sendable {
    var candidates: Set<ComparisonCandidate> = []
}

/// Produces bounded, deterministic candidate proposals without loading image
/// data. Hash buckets are intentionally built inside this call and discarded
/// with the returned value.
struct ComparisonCandidateRetriever: Sendable {
    let configuration: ComparisonRetrieverConfiguration

    init(configuration: ComparisonRetrieverConfiguration = .init()) {
        self.configuration = configuration
    }

    func retrieve(from inputs: [ComparisonCandidateInput]) -> ComparisonCandidateRetrieval {
        let uniqueInputs = uniqueInputsByAssetID(inputs)
        let chronological = chronologicalCandidates(
            from: uniqueInputs,
            limit: configuration.maxChronologicalNeighborsPerAsset
        )
        let crossDate = hashCandidates(
            from: uniqueInputs,
            bucketLimit: configuration.maxHashBucketSize,
            perAssetLimit: configuration.maxHashCandidatesPerAsset
        )

        let candidates = Set(chronological.candidates).union(crossDate.candidates).sorted(by: candidateOrder)
        let coverage = ComparisonCandidateCoverage(
            omittedCandidateCount: chronological.omittedCandidateCount + crossDate.omittedCandidateCount
        )
        return ComparisonCandidateRetrieval(candidates: candidates, coverage: coverage)
    }

    private func uniqueInputsByAssetID(_ inputs: [ComparisonCandidateInput]) -> [ComparisonCandidateInput] {
        var byID: [AssetID: ComparisonCandidateInput] = [:]
        for input in inputs {
            guard let existing = byID[input.id] else {
                byID[input.id] = input
                continue
            }
            if inputOrder(input, isBefore: existing) {
                byID[input.id] = input
            }
        }
        return byID.values.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    // swiftlint:disable:next function_body_length
    private func chronologicalCandidates(
        from inputs: [ComparisonCandidateInput],
        limit: Int
    ) -> (candidates: Set<ComparisonCandidate>, omittedCandidateCount: Int) {
        let dated = inputs.compactMap { input -> (ComparisonCandidateInput, Date)? in
            guard let date = input.creationDate else { return nil }
            return (input, date)
        }
        .sorted {
            if $0.1 != $1.1 {
                return $0.1 < $1.1
            }
            return $0.0.id.rawValue < $1.0.id.rawValue
        }

        var potential: [ComparisonCandidate: TimeInterval] = [:]
        var lowerBound = dated.startIndex
        var upperBound = dated.startIndex
        var eligiblePairCount = 0
        for index in dated.indices {
            while lowerBound < index {
                guard !isSameCapture(
                    dated[lowerBound].1,
                    dated[index].1,
                    window: configuration.sameCaptureTimeWindow
                ) else { break }
                lowerBound += 1
            }
            while upperBound < dated.endIndex {
                guard isSameCapture(
                    dated[upperBound].1,
                    dated[index].1,
                    window: configuration.sameCaptureTimeWindow
                ) else { break }
                upperBound += 1
            }
            eligiblePairCount += max(0, upperBound - index - 1)

            var left = index > dated.startIndex ? index - 1 : index
            var leftAvailable = index > lowerBound
            var right = index + 1
            var selected = 0
            while selected < limit, leftAvailable || right < upperBound {
                let useLeft: Bool
                if right >= upperBound {
                    useLeft = true
                } else if !leftAvailable {
                    useLeft = false
                } else {
                    useLeft = neighborIsBefore(dated[left], dated[right], centerDate: dated[index].1)
                }
                let neighbor = useLeft ? dated[left] : dated[right]
                if useLeft {
                    if left == lowerBound {
                        leftAvailable = false
                    } else {
                        left -= 1
                    }
                } else {
                    right += 1
                }
                let candidate = ComparisonCandidate(
                    first: dated[index].0.id,
                    second: neighbor.0.id,
                    relation: .retake,
                    path: .chronologicalNeighbors
                )
                let distance = abs(neighbor.1.timeIntervalSince(dated[index].1))
                potential[candidate] = min(potential[candidate] ?? .greatestFiniteMagnitude, distance)
                selected += 1
            }
        }

        var degree: [AssetID: Int] = [:]
        let orderedCandidates = potential.sorted { left, right in
            if left.value != right.value {
                return left.value < right.value
            }
            return candidateOrder(left.key, right.key)
        }
        var candidates: [ComparisonCandidate] = []
        for (candidate, _) in orderedCandidates {
            guard degree[candidate.first, default: 0] < limit,
                  degree[candidate.second, default: 0] < limit else { continue }
            degree[candidate.first, default: 0] += 1
            degree[candidate.second, default: 0] += 1
            candidates.append(candidate)
        }
        return (Set(candidates), max(0, eligiblePairCount - candidates.count))
    }

    private func hashCandidates(
        from inputs: [ComparisonCandidateInput],
        bucketLimit: Int,
        perAssetLimit: Int
    ) -> HashCandidateResult {
        var buckets: [ComparisonInputHash: [ComparisonCandidateInput]] = [:]
        for input in inputs {
            guard let hash = input.inputHash else { continue }
            buckets[hash, default: []].append(input)
        }

        return hashBucketCandidates(
            buckets: buckets,
            bucketLimit: bucketLimit,
            perAssetLimit: perAssetLimit
        )
    }

    private func hashBucketCandidates(
        buckets: [ComparisonInputHash: [ComparisonCandidateInput]],
        bucketLimit: Int,
        perAssetLimit: Int
    ) -> HashCandidateResult {
        var accumulator = HashCandidateAccumulator()
        var eligiblePairCount = 0
        for bucket in buckets.values {
            let orderedBucket = bucket.sorted { $0.id.rawValue < $1.id.rawValue }
            eligiblePairCount = saturatingAdd(
                eligiblePairCount, nearCopyPairCount(in: orderedBucket)
            )
            appendHashBucketCandidates(
                bucket,
                bucketLimit: bucketLimit,
                perAssetLimit: perAssetLimit,
                accumulator: &accumulator
            )
        }

        return HashCandidateResult(
            candidates: accumulator.candidates,
            omittedCandidateCount: max(0, eligiblePairCount - accumulator.candidates.count)
        )
    }

    private func appendHashBucketCandidates(
        _ bucket: [ComparisonCandidateInput],
        bucketLimit: Int,
        perAssetLimit: Int,
        accumulator: inout HashCandidateAccumulator
    ) {
        let orderedBucket = bucket.sorted { $0.id.rawValue < $1.id.rawValue }
        let retained = Array(orderedBucket.prefix(bucketLimit))
        var potential: [ComparisonCandidate: TimeInterval] = [:]
        for input in retained {
            let options = nearestNearCopyOptions(
                for: input, in: retained, limit: perAssetLimit
            )
            for other in options.prefix(perAssetLimit) {
                let candidate = ComparisonCandidate(
                    first: input.id,
                    second: other.0.id,
                    relation: .nearCopy,
                    path: .inputHashBucket
                )
                let distance = other.1
                potential[candidate] = min(potential[candidate] ?? .greatestFiniteMagnitude, distance)
            }
        }
        var degree: [AssetID: Int] = [:]
        for (candidate, _) in potential.sorted(by: { left, right in
            if left.value != right.value {
                return left.value < right.value
            }
            return candidateOrder(left.key, right.key)
        }) {
            guard degree[candidate.first, default: 0] < perAssetLimit,
                  degree[candidate.second, default: 0] < perAssetLimit else { continue }
            degree[candidate.first, default: 0] += 1
            degree[candidate.second, default: 0] += 1
            accumulator.candidates.insert(candidate)
        }
    }

    private func nearestNearCopyOptions(
        for input: ComparisonCandidateInput,
        in retained: [ComparisonCandidateInput],
        limit: Int
    ) -> [(ComparisonCandidateInput, TimeInterval)] {
        guard limit > 0 else { return [] }
        var best: [(ComparisonCandidateInput, TimeInterval)] = []
        for other in retained where other.id != input.id {
            guard isNearCopyDate(input.creationDate, other.creationDate) else { continue }
            best.append((other, dateDistance(input.creationDate, other.creationDate)))
            best.sort { left, right in
                if left.1 != right.1 {
                    return left.1 < right.1
                }
                return left.0.id.rawValue < right.0.id.rawValue
            }
            if best.count > limit {
                best.removeLast()
            }
        }
        return best
    }

    private func inputOrder(_ left: ComparisonCandidateInput, isBefore right: ComparisonCandidateInput) -> Bool {
        let leftDate = left.creationDate?.timeIntervalSinceReferenceDate ?? -.greatestFiniteMagnitude
        let rightDate = right.creationDate?.timeIntervalSinceReferenceDate ?? -.greatestFiniteMagnitude
        if leftDate != rightDate {
            return leftDate < rightDate
        }
        return (left.inputHash?.rawValue ?? 0) < (right.inputHash?.rawValue ?? 0)
    }

    private func dateDistance(_ left: Date?, _ right: Date?) -> TimeInterval {
        guard let left, let right else { return .greatestFiniteMagnitude }
        return abs(left.timeIntervalSince(right))
    }

    private func nearCopyPairCount(in inputs: [ComparisonCandidateInput]) -> Int {
        max(0, pairCount(inputs.count) - sameCapturePairCount(in: inputs))
    }

    private func sameCapturePairCount(in inputs: [ComparisonCandidateInput]) -> Int {
        let dated = inputs.compactMap { input -> Date? in input.creationDate }.sorted()
        var upperBound = 0
        var count = 0
        for index in dated.indices {
            upperBound = max(upperBound, index + 1)
            while upperBound < dated.endIndex {
                guard isSameCapture(
                    dated[index], dated[upperBound], window: configuration.sameCaptureTimeWindow
                ) else { break }
                upperBound += 1
            }
            count = saturatingAdd(count, max(0, upperBound - index - 1))
        }
        return count
    }

    private func pairCount(_ count: Int) -> Int {
        guard count > 1 else { return 0 }
        let product = count.multipliedReportingOverflow(by: count - 1)
        return product.overflow ? Int.max : product.partialValue / 2
    }

    private func saturatingAdd(_ left: Int, _ right: Int) -> Int {
        let result = left.addingReportingOverflow(right)
        return result.overflow ? Int.max : result.partialValue
    }

    private func neighborIsBefore(
        _ left: (ComparisonCandidateInput, Date),
        _ right: (ComparisonCandidateInput, Date),
        centerDate: Date
    ) -> Bool {
        let leftDistance = abs(left.1.timeIntervalSince(centerDate))
        let rightDistance = abs(right.1.timeIntervalSince(centerDate))
        if leftDistance != rightDistance {
            return leftDistance < rightDistance
        }
        if left.1 != right.1 {
            return left.1 < right.1
        }
        return left.0.id.rawValue < right.0.id.rawValue
    }

    private func isSameCapture(_ left: Date?, _ right: Date?, window: TimeInterval) -> Bool {
        guard let left, let right else { return false }
        return abs(left.timeIntervalSince(right)) <= window
    }

    private func isNearCopyDate(_ left: Date?, _ right: Date?) -> Bool {
        guard let left, let right else { return true }
        return abs(left.timeIntervalSince(right)) > configuration.sameCaptureTimeWindow
    }

    private func candidateOrder(_ left: ComparisonCandidate, _ right: ComparisonCandidate) -> Bool {
        if left.first.rawValue != right.first.rawValue {
            return left.first.rawValue < right.first.rawValue
        }
        if left.second.rawValue != right.second.rawValue {
            return left.second.rawValue < right.second.rawValue
        }
        return left.path.rawValue < right.path.rawValue
    }
}
