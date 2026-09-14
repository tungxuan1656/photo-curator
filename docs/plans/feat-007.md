# feat-007 — Duplicates + Moments Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land deterministic duplicate clusters and moment segments on real Vision similarity so Dataset B groups correctly.

**Architecture:** Vision produces `PhotoAnalysis` plus a transient `ImageSimilarityArtifact` in one upright pass; `BatchPipeline` rebuilds prints for cache hits without persisting them and emits raw `SimilarityEdge` distances; pure `DuplicateResolver` (windowed pairs + union-find + local winner) feeds `MomentBuilder` (gap scan with visual/scene continuity); `SelectionEngine` exposes candidates/edges and returns a pass-through chrono selection until feat-008.

**Tech Stack:** Swift 5, Vision `VNGenerateImageFeaturePrintRequest`, CryptoKit SHA-256 deterministic IDs, PhotoKit-sized `CGImage`, existing `BatchPipeline`/`SessionCheckpointStore`/`FileAnalysisCache`.

## Global Constraints

- Activate only feat-007; feat-008 starts only after feat-007 is recorded done; never set two features active.
- Keep pixels, `VNFeaturePrintObservation`, hashes, face boxes, and edge lists transient; persist only existing `PhotoAnalysis`, `SelectionResult`, checkpoints, cache rows.
- Engine and grouping code stays pure synchronous Domain: no SwiftUI, PhotoKit, Vision types, file I/O, async.
- No third-party dependency, test target, `*Test*.swift`, mock-only architecture, persistent debug artifact.
- Use existing `SelectionConfiguration` knobs only (`duplicateTimeWindow`, `duplicateSimilarityThreshold`, `nearDuplicateSimilarityThreshold`, `momentSoftGap`, `momentHardGap`); introduce no new threshold or worker count.
- `SceneType` becomes `Hashable`; `ClusterID`/`MomentID` are deterministic SHA-256-derived UUIDv5, never random.
- Missing analysis or missing print is a singleton for grouping, never a rejection; visual matches are `.nearDuplicate` only.

---

## File Structure

- Create `apps/photo-curator/Services/Analysis/ImageSimilarityArtifact.swift` — hides `VNFeaturePrintObservation`; owns `distance(to:)` and `ImageAnalysisOutput`.
- Modify `apps/photo-curator/Services/ServiceProtocols.swift` — `ImageAnalysisService` returns `ImageAnalysisOutput` plus `similarityArtifact(for:)`; update `NoopImageAnalyzer`.
- Modify `apps/photo-curator/Services/Analysis/VisionAnalysisService.swift` — one `.up` handler runs existing signals plus feature print; cache-hit path runs print only.
- Modify `apps/photo-curator/Services/Photos/BatchPipeline.swift` — run-local `[AssetID: ImageSimilarityArtifact]`; bounded rebuild for cache hits; `BatchResult.similarityEdges(for:)`.
- Create `apps/photo-curator/Domain/Models/SelectionGrouping.swift` — `SimilarityCandidate`, `SimilarityEdge(distance:)`, `ClusterType`, `PhotoCluster`, `PhotoMoment`, `StableSelectionID`.
- Modify `apps/photo-curator/Domain/Models/PhotoAnalysis.swift` — add `Hashable` to `SceneType` only.
- Create `apps/photo-curator/Domain/Selection/DuplicateResolver.swift` — `candidates(for:configuration:)` + `resolve(assets:analyses:edges:configuration:)`.
- Create `apps/photo-curator/Domain/Selection/MomentBuilder.swift` — `build(representatives:analyses:edges:configuration:)`.
- Modify `apps/photo-curator/Domain/Selection/SelectionEngine.swift` — stored resolver/builder with defaults; `duplicateCandidates`; `select(..., similarityEdges: [SimilarityEdge] = [])` pass-through.
- Modify `apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift` — `selectResult` becomes `async throws`, builds candidates/edges, keeps session re-stamp.
- Modify `docs/design-docs/data-model.md` — add transient grouping shapes; rename edge field to `distance`.
- Modify `features/feat-007.md` — link this plan; record evidence on close.

---

### Task 1: Transient similarity artifact + service contract

**Files:**
- Create: `apps/photo-curator/Services/Analysis/ImageSimilarityArtifact.swift`
- Modify: `apps/photo-curator/Services/ServiceProtocols.swift:31-34`

**Interfaces:**
- Consumes: `PhotoAnalysis` (`apps/photo-curator/Domain/Models/PhotoAnalysis.swift`), `AnalysisInput` (`assetID`, `image: CGImage`).
- Produces: `final class ImageSimilarityArtifact: @unchecked Sendable { func distance(to other: ImageSimilarityArtifact) throws -> Double }`; `struct ImageAnalysisOutput: @unchecked Sendable { let analysis: PhotoAnalysis; let similarity: ImageSimilarityArtifact? }`; `protocol ImageAnalysisService { func analyze(_ input: AnalysisInput) async throws -> ImageAnalysisOutput; func similarityArtifact(for input: AnalysisInput) async throws -> ImageSimilarityArtifact? }`.

- [ ] **Step 1: Create the artifact wrapper**

```swift
import Foundation
import Vision

final class ImageSimilarityArtifact: @unchecked Sendable {
    private let observation: VNFeaturePrintObservation
    init(observation: VNFeaturePrintObservation) { self.observation = observation }
    func distance(to other: ImageSimilarityArtifact) throws -> Double {
        var distance: Float = 0
        try observation.computeDistance(&distance, to: other.observation)
        return Double(distance)
    }
}

struct ImageAnalysisOutput: @unchecked Sendable {
    let analysis: PhotoAnalysis
    let similarity: ImageSimilarityArtifact?
}
```

- [ ] **Step 2: Update the service contract and Noop**

```swift
protocol ImageAnalysisService: Sendable {
    func analyze(_ input: AnalysisInput) async throws -> ImageAnalysisOutput
    func similarityArtifact(for input: AnalysisInput) async throws -> ImageSimilarityArtifact?
}

struct NoopImageAnalyzer: ImageAnalysisService {
    func analyze(_ input: AnalysisInput) async throws -> ImageAnalysisOutput {
        throw SelectionError.internal
    }
    func similarityArtifact(for input: AnalysisInput) async throws -> ImageSimilarityArtifact? {
        nil
    }
}
```

- [ ] **Step 3: Verify contract compiles**

Run: `./init.sh`
Expected: PASS; new types compile, analyzer callers updated in Tasks 2-3.

- [ ] **Step 4: Commit**

```bash
git add apps/photo-curator/Services/Analysis/ImageSimilarityArtifact.swift apps/photo-curator/Services/ServiceProtocols.swift
git commit -m "feat(007): add transient similarity artifact contract"
```

---
### Task 2: Vision single-pass feature prints

**Files:**
- Modify: `apps/photo-curator/Services/Analysis/VisionAnalysisService.swift:11-32`
- Modify: `apps/photo-curator/Services/Analysis/VisionAnalysisService.swift:66-126`

**Interfaces:**
- Consumes: `ImageAnalysisOutput`, `ImageSimilarityArtifact` from Task 1; existing `performAll` face/luma helpers.
- Produces: `nonisolated func analyze(_ input: AnalysisInput) async throws -> ImageAnalysisOutput`; `nonisolated func similarityArtifact(for input: AnalysisInput) async throws -> ImageSimilarityArtifact?`.

- [ ] **Step 1: Run print in the existing upright pass**

```swift
nonisolated func analyze(_ input: AnalysisInput) async throws -> ImageAnalysisOutput {
    do {
        try Task.checkCancellation()
        return try await performAll(input: input)
    } catch is CancellationError {
        throw SelectionError.cancelled
    }
}

nonisolated func similarityArtifact(for input: AnalysisInput) async throws -> ImageSimilarityArtifact? {
    do {
        try Task.checkCancellation()
        let handler = VNImageRequestHandler(cgImage: input.image, orientation: .up, options: [:])
        let request = VNGenerateImageFeaturePrintRequest()
        try handler.perform([request])
        guard let observation = request.results?.first as? VNFeaturePrintObservation else { return nil }
        return ImageSimilarityArtifact(observation: observation)
    } catch is CancellationError {
        throw SelectionError.cancelled
    } catch {
        return nil
    }
}
```

Inside the existing `performAll(input:)` body, immediately after the two face-request `autoreleasepool` blocks and before the `if Task.isCancelled` check, insert exactly:

```swift
let printRequest = VNGenerateImageFeaturePrintRequest()
try Task.checkCancellation()
autoreleasepool {
    try? handler.perform([printRequest])
}
```

Then change the existing `PhotoAnalysis.make(...)` call site to capture the print from the same handler pass:

```swift
let analysis = await PhotoAnalysis.make(
    assetID: assetID,
    technical: technical,
    faceCount: faceCount,
    groupPhotoScore: faceCount >= 2 ? Double(faceCount) / 6.0 : nil,
    subjectPlacementScore: bestFaceQuality,
    sceneType: faceCount > 0 ? .people : .unknown
)
let similarity = (printRequest.results?.first as? VNFeaturePrintObservation).map(ImageSimilarityArtifact.init(observation:))
try Task.checkCancellation()
return ImageAnalysisOutput(analysis: analysis, similarity: similarity)
```

And change `performAll`'s return type from `PhotoAnalysis` to `ImageAnalysisOutput`. A nil print degrades to `similarity: nil` (singleton in grouping), never a throw. Replace the “deferred to feat-007” comment with: prints are transient, never persisted/logged, released after edge computation.
- [ ] **Step 2: Verify no durable shape changed**

Run: `./init.sh`
Expected: PASS; `PhotoAnalysis` Codable fields untouched.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Services/Analysis/VisionAnalysisService.swift
git commit -m "feat(007): emit transient feature prints in Vision pass"
```

---

### Task 3: Pipeline ephemeral artifacts and edge builder

**Files:**
- Modify: `apps/photo-curator/Services/Photos/BatchPipeline.swift:13-17`
- Modify: `apps/photo-curator/Services/Photos/BatchPipeline.swift:148-258`

**Interfaces:**
- Consumes: `ImageAnalysisOutput`, `ImageSimilarityArtifact`, `SimilarityCandidate`, `SelectionConfiguration` (`maxConcurrentImageRequests` lane count), `AnalysisCache` (stores only `PhotoAnalysis`).
- Produces: `struct BatchResult: Sendable { let analyses: [AssetID: PhotoAnalysis]; let unavailableIDs: [AssetID]; let similarities: [AssetID: ImageSimilarityArtifact]; func similarityEdges(for candidates: [SimilarityCandidate]) throws -> [SimilarityEdge] }`.

- [ ] **Step 1: Retain artifacts run-locally, rebuild for cache hits**

```swift
struct BatchResult: Sendable {
    let analyses: [AssetID: PhotoAnalysis]
    let unavailableIDs: [AssetID]
    let similarities: [AssetID: ImageSimilarityArtifact]
    func similarityEdges(for candidates: [SimilarityCandidate]) throws -> [SimilarityEdge] {
        var edges: [SimilarityEdge] = []
        edges.reserveCapacity(candidates.count)
        for candidate in candidates {
            try Task.checkCancellation()
            guard let left = similarities[candidate.first], let right = similarities[candidate.second] else { continue }
            guard let distance = try? left.distance(to: right) else { continue }
            edges.append(SimilarityEdge(first: candidate.first, second: candidate.second, distance: distance))
        }
        return edges
    }
}
```

In `RunState` add `var similarities: [AssetID: ImageSimilarityArtifact] = [:]`. In `record(.analyzed(let output))` store `output.analysis` in `analyses`, store only `output.analysis` in cache, keep `output.similarity` in `similarities`. After `restore`, for each cache-hit asset run bounded lanes (`maxConcurrentImageRequests`): `let cg = try await imageLoader.analysisImage(for: id)` then `analyzer.similarityArtifact(for: AnalysisInput(assetID: id, image: cg))`; on failure store nothing, do not touch `completed`, checkpoints, or `unavailable`. A per-pair `computeDistance` failure skips only that edge via `try?`; `similarityEdges` throws only on task cancellation, so one bad signal never fails the session.

- [ ] **Step 2: Update `processOne` to the new analyzer type**

Return `AssetOutcome.analyzed(ImageAnalysisOutput)` instead of `PhotoAnalysis`; keep unavailable mapping (loader failure, whole-decode `.internal`) and cancellation mapping unchanged.

- [ ] **Step 3: Verify pipeline gate**

Run: `./init.sh`
Expected: PASS; checkpoint/resume behavior unchanged.

- [ ] **Step 4: Commit**

```bash
git add apps/photo-curator/Services/Photos/BatchPipeline.swift
git commit -m "feat(007): carry ephemeral similarity artifacts to edges"
```

---

### Task 4: Grouping models and deterministic IDs

**Files:**
- Create: `apps/photo-curator/Domain/Models/SelectionGrouping.swift`
- Modify: `apps/photo-curator/Domain/Models/PhotoAnalysis.swift:38-41`

**Interfaces:**
- Consumes: `AssetID`, `ClusterID`, `MomentID`, `SceneType`.
- Produces: `SimilarityCandidate`, `SimilarityEdge(distance: Double)`, `ClusterType`, `PhotoCluster`, `PhotoMoment`, `StableSelectionID.uuid(kind:members:)`.

- [ ] **Step 1: Create grouping models**

```swift
import CryptoKit
import Foundation

struct SimilarityCandidate: Sendable, Hashable {
    let first: AssetID
    let second: AssetID
}

struct SimilarityEdge: Sendable, Hashable {
    let first: AssetID
    let second: AssetID
    let distance: Double
}

enum ClusterType: String, Codable, Sendable {
    case nearDuplicate, burstLike, sameScene, samePose, groupPhotoSequence
}

struct PhotoCluster: Identifiable, Codable, Sendable {
    let id: ClusterID
    let type: ClusterType
    let assetIDs: [AssetID]
    let representativeAssetID: AssetID?
    let similarityScore: Double?
}

struct PhotoMoment: Identifiable, Codable, Sendable {
    let id: MomentID
    let assetIDs: [AssetID]
    let startDate: Date?
    let endDate: Date?
    let representativeAssetID: AssetID?
    let sceneDistribution: [SceneType: Double]
}

enum StableSelectionID {
    static func uuid(kind: String, members: [AssetID]) -> UUID {
        var hasher = SHA256()
        hasher.update(data: Data(kind.utf8))
        for member in members {
            hasher.update(data: Data(member.rawValue.utf8))
            hasher.update(data: Data([0x1F]))
        }
        let digest = Array(hasher.finalize().prefix(16))
        return UUID(uuid: (digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], (digest[6] & 0x0F) | 0x50, digest[7], (digest[8] & 0x3F) | 0x80, digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]))
    }
}
```

- [ ] **Step 2: Make `SceneType` Hashable**

```swift
enum SceneType: String, Codable, Sendable, Hashable {
    case people, group, landscape, architecture, food, animal
    case indoor, outdoor, document, screenshot, other, unknown
}
```

- [ ] **Step 3: Verify models gate**

Run: `./init.sh`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add apps/photo-curator/Domain/Models/SelectionGrouping.swift apps/photo-curator/Domain/Models/PhotoAnalysis.swift
git commit -m "feat(007): add grouping models with stable IDs"
```

---

### Task 5: DuplicateResolver (windowed union-find + local winner)

**Files:**
- Create: `apps/photo-curator/Domain/Selection/DuplicateResolver.swift`

**Interfaces:**
- Consumes: `SimilarityCandidate`, `SimilarityEdge`, `PhotoCluster`, `StableSelectionID`, `PhotoAsset` (`creationDate`, `pixelWidth/Height`, `isFavorite`), `PhotoAnalysis` (`qualityScore`), `SelectionConfiguration` (`duplicateTimeWindow`, `nearDuplicateSimilarityThreshold`).
- Produces: `struct DuplicateResolution: Sendable { let clusters: [PhotoCluster]; let representativeIDs: [AssetID]; let alternativesByCluster: [ClusterID: [AssetID]] }`; `struct DuplicateResolver: Sendable { func candidates(for assets: [PhotoAsset], configuration: SelectionConfiguration) -> [SimilarityCandidate]; func resolve(assets: [PhotoAsset], analyses: [AssetID: PhotoAnalysis], edges: [SimilarityEdge], configuration: SelectionConfiguration) -> DuplicateResolution }`.

- [ ] **Step 1: Implement candidates + resolve**

```swift
struct DuplicateResolution: Sendable {
    let clusters: [PhotoCluster]
    let representativeIDs: [AssetID]
    let alternativesByCluster: [ClusterID: [AssetID]]
}

struct DuplicateResolver: Sendable {
    func candidates(for assets: [PhotoAsset], configuration: SelectionConfiguration) -> [SimilarityCandidate] {
        let indexed = Dictionary(uniqueKeysWithValues: assets.enumerated().map { ($1.id, $0) })
        let ordered = canonicalOrder(assets)
        var out: [SimilarityCandidate] = []
        for i in ordered.indices {
            for j in ordered.indices.dropFirst(i + 1) {
                guard withinWindow(ordered[i], ordered[j], indexByID: indexed, window: configuration.duplicateTimeWindow) else { break }
                out.append(SimilarityCandidate(first: ordered[i].id, second: ordered[j].id))
            }
        }
        return out
    }

    private func canonicalOrder(_ assets: [PhotoAsset]) -> [PhotoAsset] {
        assets.enumerated().sorted {
            let leftDate = $0.element.creationDate
            let rightDate = $1.element.creationDate
            if leftDate != rightDate {
                switch (leftDate, rightDate) {
                case let (left?, right?): return left < right
                case (nil, _?): return false
                case (_?, nil): return true
                default: break
                }
            }
            if $0.offset != $1.offset { return $0.offset < $1.offset }
            return $0.element.id.rawValue < $1.element.id.rawValue
        }.map(\.element)
    }

    private func withinWindow(_ left: PhotoAsset, _ right: PhotoAsset, indexByID: [AssetID: Int], window: TimeInterval) -> Bool {
        switch (left.creationDate, right.creationDate) {
        case let (leftDate?, rightDate?):
            return abs(leftDate.timeIntervalSince(rightDate)) <= window
        default:
            guard let leftIndex = indexByID[left.id], let rightIndex = indexByID[right.id] else { return false }
            return abs(leftIndex - rightIndex) == 1
        }
    }

    private func meanDistance(members: Set<AssetID>, edges: [SimilarityEdge]) -> Double {
        let distances = edges.filter { members.contains($0.first) && members.contains($0.second) }.map(\.distance)
        guard !distances.isEmpty else { return 0 }
        return distances.reduce(0, +) / Double(distances.count)
    }

    func resolve(assets: [PhotoAsset], analyses: [AssetID: PhotoAnalysis], edges: [SimilarityEdge], configuration: SelectionConfiguration) -> DuplicateResolution {
        let ordered = canonicalOrder(assets).filter { analyses[$0.id] != nil }
        var parent: [AssetID: AssetID] = Dictionary(uniqueKeysWithValues: ordered.map { ($0.id, $0.id) })
        func find(_ id: AssetID) -> AssetID {
            var root = id
            while parent[root] != root { root = parent[root]! }
            var node = id
            while parent[node] != root {
                let next = parent[node]!
                parent[node] = root
                node = next
            }
            return root
        }
        func union(_ left: AssetID, _ right: AssetID) {
            let leftRoot = find(left)
            let rightRoot = find(right)
            guard leftRoot != rightRoot else { return }
            parent[leftRoot.rawValue < rightRoot.rawValue ? leftRoot : rightRoot] = leftRoot.rawValue < rightRoot.rawValue ? rightRoot : leftRoot
        }
        for edge in edges where edge.distance < configuration.nearDuplicateSimilarityThreshold {
            union(edge.first, edge.second)
        }
        var groups: [AssetID: [PhotoAsset]] = [:]
        for asset in ordered { groups[find(asset.id), default: []].append(asset) }
        var clusters: [PhotoCluster] = []
        var representatives: [AssetID] = []
        var alternatives: [ClusterID: [AssetID]] = [:]
        for group in groups.values.sorted(by: { $0.first!.id.rawValue < $1.first!.id.rawValue }) {
            guard group.count > 1 else { representatives.append(group[0].id); continue }
            let ranked = group.sorted {
                let leftScore = analyses[$0.id]?.qualityScore ?? -1
                let rightScore = analyses[$1.id]?.qualityScore ?? -1
                if leftScore != rightScore { return leftScore > rightScore }
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
                let leftArea = $0.pixelWidth * $0.pixelHeight
                let rightArea = $1.pixelWidth * $1.pixelHeight
                if leftArea != rightArea { return leftArea > rightArea }
                return $0.id.rawValue < $1.id.rawValue
            }
            let memberIDs = group.map(\.id).sorted { $0.rawValue < $1.rawValue }
            let id = ClusterID(rawValue: StableSelectionID.uuid(kind: "cluster", members: memberIDs))
            let mean = meanDistance(members: Set(memberIDs), edges: edges)
            clusters.append(PhotoCluster(id: id, type: .nearDuplicate, assetIDs: memberIDs, representativeAssetID: ranked[0].id, similarityScore: 1 / (1 + mean)))
            representatives.append(ranked[0].id)
            alternatives[id] = Array(ranked.dropFirst().prefix(2).map(\.id))
        }
        return DuplicateResolution(clusters: clusters, representativeIDs: representatives, alternativesByCluster: alternatives)
    }
}
```

Helpers: `canonicalOrder` above preserves input order for nil/equal dates via stable indices, then `id.rawValue`; `withinWindow` returns true when both dates exist and `abs diff <= window`, true when either date is nil but index-adjacent (never block on missing dates); `meanDistance` averages direct edges inside the component for the display-only `similarityScore` and never feeds threshold decisions.

- [ ] **Step 2: Verify resolver gate**

Run: `./init.sh`
Expected: PASS; no engine behavior change yet.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Domain/Selection/DuplicateResolver.swift
git commit -m "feat(007): add windowed duplicate resolver"
```

---

### Task 6: MomentBuilder (gap scan with continuity)

**Files:**
- Create: `apps/photo-curator/Domain/Selection/MomentBuilder.swift`

**Interfaces:**
- Consumes: `PhotoAsset`, `PhotoAnalysis` (`qualityScore`, `content.sceneType`), `SimilarityEdge`, `PhotoMoment`, `StableSelectionID`, `SelectionConfiguration` (`momentSoftGap`, `momentHardGap`, `nearDuplicateSimilarityThreshold`).
- Produces: `struct MomentBuilder: Sendable { func build(representatives: [PhotoAsset], analyses: [AssetID: PhotoAnalysis], edges: [SimilarityEdge], configuration: SelectionConfiguration) -> [PhotoMoment] }`.

- [ ] **Step 1: Implement the gap walk**

```swift
struct MomentBuilder: Sendable {
    func build(representatives: [PhotoAsset], analyses: [AssetID: PhotoAnalysis], edges: [SimilarityEdge], configuration: SelectionConfiguration) -> [PhotoMoment] {
        let ordered = canonicalOrder(representatives)
        var edgeByPair: Set<String> = []
        for edge in edges where edge.distance < configuration.nearDuplicateSimilarityThreshold {
            edgeByPair.insert(edgeKey(edge.first, edge.second))
        }
        var groups: [[PhotoAsset]] = []
        for asset in ordered {
            if let last = groups.last?.last, !continuesMoment(previous: last, next: asset, analyses: analyses, closeEdges: edgeByPair, configuration: configuration) {
                groups.append([asset])
            } else if groups.isEmpty {
                groups.append([asset])
            } else {
                groups[groups.count - 1].append(asset)
            }
        }
        return groups.map { makeMoment($0, analyses: analyses) }
    }
}
```

`continuesMoment`: gap `< softGap` continues; gap `>= hardGap` starts new; middle band continues only when the adjacent pair is in `closeEdges` or both analyses share a non-`.unknown` scene; missing dates/analyses never force a boundary. `makeMoment` fills ordered IDs, start/end dates, best-quality representative, scene proportions, stable `MomentID`.

- [ ] **Step 2: Verify builder gate**

Run: `./init.sh`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Domain/Selection/MomentBuilder.swift
git commit -m "feat(007): add moment gap-scan builder"
```

---

### Task 7: Engine pass-through + coordinator cutover

**Files:**
- Modify: `apps/photo-curator/Domain/Selection/SelectionEngine.swift:11-27`
- Modify: `apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift:244-263`

**Interfaces:**
- Consumes: `DuplicateResolver`, `MomentBuilder`, `BatchResult.similarityEdges(for:)`.
- Produces: `func duplicateCandidates(for assets: [PhotoAsset], configuration: SelectionConfiguration) -> [SimilarityCandidate]`; `func select(assets:analyses:configuration:feedback:similarityEdges: [SimilarityEdge] = []) throws -> SelectionResult`; `private func selectResult(...) async throws -> SelectionResult`.

- [ ] **Step 1: Wire the pass-through engine**

```swift
struct SelectionEngine: Sendable {
    let duplicateResolver = DuplicateResolver()
    let momentBuilder = MomentBuilder()

    func duplicateCandidates(for assets: [PhotoAsset], configuration: SelectionConfiguration) -> [SimilarityCandidate] {
        duplicateResolver.candidates(for: assets, configuration: configuration)
    }

    func select(assets: [PhotoAsset], analyses: [AssetID: PhotoAnalysis], configuration: SelectionConfiguration, feedback: SelectionFeedback?, similarityEdges: [SimilarityEdge] = []) throws -> SelectionResult {
        let resolution = duplicateResolver.resolve(assets: assets, analyses: analyses, edges: similarityEdges, configuration: configuration)
        let reps = resolution.representativeIDs.compactMap { id in assets.first(where: { $0.id == id }) }
        _ = momentBuilder.build(representatives: reps, analyses: analyses, edges: similarityEdges, configuration: configuration)
        let ordered = reps.sorted { ($0.creationDate ?? .distantPast, $0.id.rawValue) < ($1.creationDate ?? .distantPast, $1.id.rawValue) }
        let winners = Set(resolution.representativeIDs)
        var decisions: [Decision] = []
        for asset in assets {
            guard analyses[asset.id] != nil else {
                decisions.append(Decision(assetID: asset.id, status: .rejected, score: nil, qualityBreakdown: nil, reasons: ["assetUnavailable"], competingIDs: []))
                continue
            }
            if winners.contains(asset.id) {
                decisions.append(Decision(assetID: asset.id, status: .selected, score: analyses[asset.id]?.qualityScore, qualityBreakdown: analyses[asset.id]?.qualityBreakdown, reasons: ["nearDuplicateRepresentative"], competingIDs: []))
            } else {
                decisions.append(Decision(assetID: asset.id, status: .rejected, score: nil, qualityBreakdown: nil, reasons: ["nearDuplicate"], competingIDs: []))
            }
        }
        return SelectionResult(sessionID: SessionID(rawValue: UUID()), selectedAssetIDs: ordered.map(\.id), rejectedAssetIDs: assets.map(\.id).filter { !winners.contains($0) }, decisions: decisions, generatedAt: Date(), engineVersion: 1)
    }
}
```

Keep `SelectionError` and determinism docs; `AppContainer.live()` keeps `SelectionEngine()` (memberwise defaults, no DI change).

- [ ] **Step 2: Make coordinator async and edge-aware**

```swift
private func selectResult(request: SelectionRequest, assets: [PhotoAsset], batchResult: BatchResult) async throws -> SelectionResult {
    let candidates = engine.duplicateCandidates(for: assets, configuration: request.config.selection)
    let edges = try batchResult.similarityEdges(for: candidates)
    let engineOut = try engine.select(assets: assets, analyses: batchResult.analyses, configuration: request.config.selection, feedback: nil, similarityEdges: edges)
    return SelectionResult(sessionID: request.sessionID, selectedAssetIDs: engineOut.selectedAssetIDs, rejectedAssetIDs: engineOut.rejectedAssetIDs, decisions: engineOut.decisions, generatedAt: engineOut.generatedAt, engineVersion: engineOut.engineVersion)
}
```

Update the `run` call site to `await selectResult`; partial-finalization keeps compiling via the default `similarityEdges: []` until feat-008 replaces it (do not claim equivalence).

- [ ] **Step 3: Verify engine gate**

Run: `./init.sh`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add apps/photo-curator/Domain/Selection/SelectionEngine.swift apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift
git commit -m "feat(007): wire duplicates and moments into engine"
```

---

### Task 8: Data-model drift fix + feature close

**Files:**
- Modify: `docs/design-docs/data-model.md` (transient grouping section only)
- Modify: `features/feat-007.md`

**Interfaces:**
- Consumes: real `SimilarityEdge.distance`, `PhotoCluster`, `PhotoMoment`, transient lifetimes from Tasks 1–7.
- Produces: corrected doc shapes; linked plan; recorded Dataset B + `./init.sh` evidence.

- [ ] **Step 1: Correct the transient representation**

Document `SimilarityCandidate`, `SimilarityEdge(distance: Double, lower is more similar)`, `PhotoCluster`/`PhotoMoment` fields from Task 4, and the rule that prints/hashes/matrices are transient while clusters/moments are cached-evictable. Change no stored schema or policy value.

- [ ] **Step 2: Link the plan and close the feature**

In `features/feat-007.md` add `Plan: docs/plans/feat-007.md`, then on manual QA record Dataset B evidence and `./init.sh` output, mark acceptance, append the `progress.md` block with feat-008 next.

- [ ] **Step 3: Verify docs gate**

Run: `./init.sh`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add docs/design-docs/data-model.md features/feat-007.md
git commit -m "feat(007): document transient grouping and close"
```

---

## Self-Review

1. **Spec coverage:** every train §3 requirement maps above — artifacts/contract (Tasks 1–3), models/IDs (Task 4), resolver/moments (Tasks 5–6), engine/coordinator (Task 7), doc/feature close (Task 8). No ranking/sizing/diversity leaks into feat-007.
2. **Placeholder scan:** no TBD/TODO/placeholder; every code block is concrete and every command is `./init.sh` plus manual Dataset B.
3. **Type consistency:** `SimilarityEdge.distance`, `BatchResult.similarities`, `ImageAnalysisOutput`, `duplicateCandidates`/`select(..., similarityEdges:)`, `StableSelectionID`, and `nearDuplicate` reasons match across tasks.
