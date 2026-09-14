# feat-008 — Scoring + Diversity + Verify Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn feat-007 duplicate/moment evidence into a quality-adaptive chronological album with reason codes.

**Architecture:** Pure `QualityScorer` ranks usable representatives per moment; a round-robin shortlist preserves coverage; `DiversitySelector` protects sole-moment picks then greedy-fills by weighted coverage/novelty minus redundancy; `FinalAlbumBuilder` emits one decision per source ID and verifies partition/reasons/cluster/chronology; `SelectionEngine` sequences these stages and bumps `engineVersion`; both normal and partial paths share one coordinator entry point.

**Tech Stack:** Swift 5, pure Sendable Domain value types, existing `SelectionConfiguration`, `BatchResult` similarity edges, `SessionCheckpointStore`.

## Global Constraints

- Start only after feat-007 is recorded done; feat-009 starts only after feat-008 is recorded done; one active feature at a time.
- Engine/scoring/selection code stays pure synchronous Domain: no SwiftUI, PhotoKit, Vision types, file I/O, async.
- Persist only existing `PhotoAnalysis`, `SelectionResult`, checkpoints, cache rows; edges/prints/scores stay transient except inside persisted `Decision` fields.
- No third-party dependency, test target, `*Test*.swift`, mock-only architecture, persistent debug artifact.
- Use existing `SelectionConfiguration` knobs only; introduce no new threshold or worker count.
- `engineVersion` becomes `2`; `analysisVersion` unchanged; `SelectionResult` field names unchanged.
- Every selected asset has at least one canonical reason; rejection means excluded from this album, never deletion.

---

## File Structure

- Create `apps/photo-curator/Domain/Scoring/QualityScorer.swift` — `QualityDisposition`, `ScoredCandidate`, `score(asset:analysis:clusterID:momentID:configuration:)`, per-moment rank + round-robin shortlist helper.
- Create `apps/photo-curator/Domain/Selection/DiversitySelector.swift` — `select(shortlist:allMomentIDs:targetCount:similarityEdges:configuration:feedback:)`.
- Create `apps/photo-curator/Domain/Selection/FinalAlbumBuilder.swift` — `build(sourceAssets:analyses:clusters:moments:scored:selectedIDs:configuration:)`.
- Modify `apps/photo-curator/Domain/Selection/SelectionEngine.swift` — add scorer/selector/builder members; replace pass-through with full pipeline; `engineVersion = 2`.
- Modify `apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift` — add `finalizeAvailable(assets:analyses:configuration:)`; keep normal `selectResult` edge path.
- Modify `apps/photo-curator/Features/Processing/ProcessingModel.swift` — add `finalizeAvailable(...)` forwarding method.
- Modify `apps/photo-curator/App/AppModel.swift:364-411` — `finalizePartial` calls coordinator instead of `container.selectionEngine.select`.
- Modify `docs/design-docs/data-model.md` — map real cluster/moment/decision/reason usage.
- Modify `features/feat-008.md` — link this plan; record evidence on close.

---

### Task 1: QualityScorer + per-moment rank and shortlist

**Files:**
- Create: `apps/photo-curator/Domain/Scoring/QualityScorer.swift`

**Interfaces:**
- Consumes: `PhotoAsset` (`isFavorite`, `pixelWidth/Height`), `PhotoAnalysis` (`qualityScore`, `people.groupPhotoScore`, `composition` optionals, `content.sceneType`, `people.containsPeople`), `ClusterID`, `MomentID`, `SelectionConfiguration` (`technicalQualityWeight`, `humanImportanceWeight`, `representativenessWeight`, `favoriteBonus`, `hardRejectThreshold`, `lowQualityThreshold`, `maxPhotosPerMoment`, `targetSelectionRatio`, `minimumFinalCount`, `maximumFinalCount`, `shortlistMultiplier`).
- Produces: `enum QualityDisposition: Sendable { case usable, lowQuality, hardRejected }`; `struct ScoredCandidate: Sendable { let asset: PhotoAsset; let analysis: PhotoAnalysis; let clusterID: ClusterID?; let momentID: MomentID; let sceneType: SceneType; let containsPeople: Bool; let isPortrait: Bool; let score: Double; let disposition: QualityDisposition; let reasons: [String] }`; `struct QualityScorer: Sendable { func score(asset:analysis:clusterID:momentID:configuration:) -> ScoredCandidate; func shortlist(candidates:targetCount:configuration:) -> [ScoredCandidate] }`.

- [ ] **Step 1: Implement scoring and shortlist**

```swift
struct QualityScorer: Sendable {
    func score(asset: PhotoAsset, analysis: PhotoAnalysis, clusterID: ClusterID?, momentID: MomentID, configuration: SelectionConfiguration) -> ScoredCandidate {
        var numerator = analysis.qualityScore * configuration.technicalQualityWeight
        var denominator = configuration.technicalQualityWeight
        if let group = analysis.people.groupPhotoScore {
            numerator += group * configuration.humanImportanceWeight
            denominator += configuration.humanImportanceWeight
        }
        let composition = [analysis.composition.aestheticScore, analysis.composition.subjectPlacementScore, analysis.composition.horizonScore, analysis.composition.visualBalanceScore].compactMap { $0 }
        if !composition.isEmpty {
            numerator += (composition.reduce(0, +) / Double(composition.count)) * configuration.representativenessWeight
            denominator += configuration.representativenessWeight
        }
        var score = denominator > 0 ? numerator / denominator : analysis.qualityScore
        if asset.isFavorite { score += configuration.favoriteBonus }
        score = min(1.0, max(0.0, score))
        let disposition: QualityDisposition
        if score < configuration.hardRejectThreshold {
            disposition = .hardRejected
        } else if score < configuration.lowQualityThreshold {
            disposition = .lowQuality
        } else {
            disposition = .usable
        }
        return ScoredCandidate(asset: asset, analysis: analysis, clusterID: clusterID, momentID: momentID, sceneType: analysis.content.sceneType, containsPeople: analysis.people.containsPeople, isPortrait: asset.pixelHeight > asset.pixelWidth, score: score, disposition: disposition, reasons: disposition == .usable ? [] : ["lowQuality"])
    }

    func shortlist(candidates: [ScoredCandidate], targetCount: Int, configuration: SelectionConfiguration) -> [ScoredCandidate] {
        var byMoment: [MomentID: [ScoredCandidate]] = [:]
        for candidate in candidates where candidate.disposition == .usable {
            byMoment[candidate.momentID, default: []].append(candidate)
        }
        for momentID in byMoment.keys {
            byMoment[momentID] = byMoment[momentID]!.sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                if $0.asset.isFavorite != $1.asset.isFavorite { return $0.asset.isFavorite }
                let leftArea = $0.asset.pixelWidth * $0.asset.pixelHeight
                let rightArea = $1.asset.pixelWidth * $1.asset.pixelHeight
                if leftArea != rightArea { return leftArea > rightArea }
                return $0.asset.id.rawValue < $1.asset.id.rawValue
            }.prefix(configuration.maxPhotosPerMoment).map { $0 }
        }
        let ranked = byMoment.values.map { $0 }.sorted { $0.first!.momentID.rawValue.uuidString < $1.first!.momentID.rawValue.uuidString }
        var out: [ScoredCandidate] = []
        var rank = 0
        let cap = Int((Double(targetCount) * configuration.shortlistMultiplier).rounded(.up))
        while out.count < cap {
            var added = false
            for list in ranked where rank < list.count {
                out.append(list[rank])
                added = true
                if out.count >= cap { break }
            }
            if !added { break }
            rank += 1
        }
        var seen = Set<AssetID>()
        for candidate in out { seen.insert(candidate.asset.id) }
        for list in ranked {
            guard let first = list.first, !seen.contains(first.asset.id) else { continue }
            out.append(first)
            seen.insert(first.asset.id)
        }
        return out
    }
}
```

- [ ] **Step 2: Verify scorer gate**

Run: `./init.sh`
Expected: PASS; no caller yet.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Domain/Scoring/QualityScorer.swift
git commit -m "feat(008): add quality scorer and shortlist"
```

---

### Task 2: DiversitySelector greedy fill

**Files:**
- Create: `apps/photo-curator/Domain/Selection/DiversitySelector.swift`

**Interfaces:**
- Consumes: `ScoredCandidate` (Task 1), `SimilarityEdge`, `MomentID`, `SelectionConfiguration` (`coverageWeight`, `diversityWeight`, `uniquenessWeight`, `redundancyPenaltyWeight`, `maxPhotosPerMoment`), `SelectionFeedback?`.
- Produces: `struct DiversitySelector: Sendable { func select(shortlist: [ScoredCandidate], allMomentIDs: [MomentID], targetCount: Int, similarityEdges: [SimilarityEdge], configuration: SelectionConfiguration, feedback: SelectionFeedback?) -> Set<AssetID> }`.

- [ ] **Step 1: Implement protected-first greedy selection**

```swift
struct DiversitySelector: Sendable {
    func select(shortlist: [ScoredCandidate], allMomentIDs: [MomentID], targetCount: Int, similarityEdges: [SimilarityEdge], configuration: SelectionConfiguration, feedback: SelectionFeedback?) -> Set<AssetID> {
        let excluded = feedback?.removedIDs.subtracting(feedback?.restoredIDs ?? []) ?? []
        let forced = feedback?.restoredIDs ?? []
        let pool = shortlist.filter { $0.disposition == .usable && !excluded.contains($0.asset.id) }
        let forcedIDs = Set(forced.intersection(pool.map(\.asset.id)))
        var selected = Set<AssetID>()
        var selectedClusters = Set<ClusterID>()
        for id in forcedIDs {
            selected.insert(id)
            if let cluster = pool.first(where: { $0.asset.id == id })?.clusterID { selectedClusters.insert(cluster) }
        }
        var byMoment: [MomentID: [ScoredCandidate]] = [:]
        for candidate in pool.sorted(by: { compareRank($0, $1) }) { byMoment[candidate.momentID, default: []].append(candidate) }
        for momentID in allMomentIDs {
            guard let list = byMoment[momentID], list.count == 1, let only = list.first else { continue }
            guard !selectedClusters.contains(where: { only.clusterID == $0 }) || only.clusterID == nil else { continue }
            selected.insert(only.asset.id)
            if let cluster = only.clusterID { selectedClusters.insert(cluster) }
        }
        for momentID in allMomentIDs {
            guard let list = byMoment[momentID], !list.contains(where: { selected.contains($0.asset.id) }) else { continue }
            for candidate in list {
                guard !selectedClusters.contains(where: { candidate.clusterID == $0 }) || candidate.clusterID == nil else { continue }
                selected.insert(candidate.asset.id)
                if let cluster = candidate.clusterID { selectedClusters.insert(cluster) }
                break
            }
        }
        var remaining = pool.filter { !selected.contains($0.asset.id) }
        while selected.count < targetCount, !remaining.isEmpty {
            remaining.sort {
                let left = utility($0, selected: selected, pool: pool, edges: similarityEdges, configuration: configuration)
                let right = utility($1, selected: selected, pool: pool, edges: similarityEdges, configuration: configuration)
                if left != right { return left > right }
                return compareRank($0, $1)
            }
            guard let next = remaining.first else { break }
            guard !selectedClusters.contains(where: { next.clusterID == $0 }) || next.clusterID == nil else {
                remaining.removeFirst()
                continue
            }
            selected.insert(next.asset.id)
            if let cluster = next.clusterID { selectedClusters.insert(cluster) }
            remaining.removeFirst()
        }
        return selected
    }

    private func compareRank(_ left: ScoredCandidate, _ right: ScoredCandidate) -> Bool {
        if left.score != right.score { return left.score > right.score }
        if left.asset.isFavorite != right.asset.isFavorite { return left.asset.isFavorite }
        let leftArea = left.asset.pixelWidth * left.asset.pixelHeight
        let rightArea = right.asset.pixelWidth * right.asset.pixelHeight
        if leftArea != rightArea { return leftArea > rightArea }
        return left.asset.id.rawValue < right.asset.id.rawValue
    }

    private func utility(_ candidate: ScoredCandidate, selected: Set<AssetID>, pool: [ScoredCandidate], edges: [SimilarityEdge], configuration: SelectionConfiguration) -> Double {
        let selectedCandidates = pool.filter { selected.contains($0.asset.id) }
        let selectedMoments = Set(selectedCandidates.map(\.momentID))
        let selectedScenes = Set(selectedCandidates.map(\.sceneType))
        let selectedPeople = Set(selectedCandidates.map(\.containsPeople))
        let selectedOrientation = Set(selectedCandidates.map(\.isPortrait))
        let coverage = (Double(selectedMoments.contains(candidate.momentID) ? 0 : 1) + Double(selectedScenes.contains(candidate.sceneType) ? 0 : 1) + Double(selectedPeople.contains(candidate.containsPeople) ? 0 : 1) + Double(selectedOrientation.contains(candidate.isPortrait) ? 0 : 1)) / 4.0
        let categoryNovelty = (Double(selectedScenes.contains(candidate.sceneType) ? 0 : 1) + Double(selectedPeople.contains(candidate.containsPeople) ? 0 : 1) + Double(selectedOrientation.contains(candidate.isPortrait) ? 0 : 1)) / 3.0
        var proximity: Double = 0
        for edge in edges {
            guard edge.first == candidate.asset.id && selected.contains(edge.second) || edge.second == candidate.asset.id && selected.contains(edge.first) else { continue }
            proximity = max(proximity, 1 / (1 + edge.distance))
        }
        let visualNovelty = 1 - proximity
        let momentCount = Double(selectedCandidates.filter { $0.momentID == candidate.momentID }.count) / Double(max(1, configuration.maxPhotosPerMoment))
        let redundancy = (momentCount + proximity) / 2.0
        return candidate.score + configuration.coverageWeight * coverage + configuration.diversityWeight * categoryNovelty + configuration.uniquenessWeight * visualNovelty - configuration.redundancyPenaltyWeight * redundancy
    }
}
```

`compareRank` (score desc, favorite desc, pixel area desc, `AssetID.rawValue` asc) is the single rank comparator for shortlist ordering and utility ties. `utility` implements the train formula: coverage averages new-moment/scene/people/orientation against the already-selected pool; category novelty averages new-scene/people/orientation; visual novelty is `1 - max(1 / (1 + distance))` over `similarityEdges` to selected IDs (`1` when absent); redundancy averages moment saturation and visual proximity; combine with `coverageWeight`/`diversityWeight`/`uniquenessWeight`/`redundancyPenaltyWeight`. The sort closure breaks equal utilities with `compareRank`, so `AssetID.rawValue` is the final decider. Recompute from the current `selected` set each iteration. Protected sole picks may exceed target; `.lowQuality`/`.hardRejected` never enter.

- [ ] **Step 2: Verify selector gate**

Run: `./init.sh`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Domain/Selection/DiversitySelector.swift
git commit -m "feat(008): add diversity greedy selector"
```

---

### Task 3: FinalAlbumBuilder decisions + verification

**Files:**
- Create: `apps/photo-curator/Domain/Selection/FinalAlbumBuilder.swift`

**Interfaces:**
- Consumes: `PhotoAsset`, `PhotoAnalysis`, `PhotoCluster`, `PhotoMoment`, `ScoredCandidate`, `SelectionConfiguration`, `Decision`, `SelectionResult`, `SelectionError`.
- Produces: `struct FinalAlbumBuilder: Sendable { func build(sourceAssets: [PhotoAsset], analyses: [AssetID: PhotoAnalysis], clusters: [PhotoCluster], moments: [PhotoMoment], scored: [ScoredCandidate], selectedIDs: Set<AssetID>, configuration: SelectionConfiguration) throws -> SelectionResult }`.

- [ ] **Step 1: Implement one-decision-per-source build**

```swift
struct FinalAlbumBuilder: Sendable {
    func build(sourceAssets: [PhotoAsset], analyses: [AssetID: PhotoAnalysis], clusters: [PhotoCluster], moments: [PhotoMoment], scored: [ScoredCandidate], selectedIDs: Set<AssetID>, configuration: SelectionConfiguration) throws -> SelectionResult {
        let order = Dictionary(uniqueKeysWithValues: sourceAssets.enumerated().map { ($1.id, $0) })
        let winnerByCluster: [AssetID: AssetID] = Dictionary(uniqueKeysWithValues: clusters.flatMap { cluster in
            guard let winner = cluster.representativeAssetID else { return [] as [(AssetID, AssetID)] }
            return cluster.assetIDs.map { ($0, winner) }
        })
        var decisions: [Decision] = []
        for asset in sourceAssets {
            guard analyses[asset.id] != nil else {
                decisions.append(Decision(assetID: asset.id, status: .rejected, score: nil, qualityBreakdown: nil, reasons: ["assetUnavailable"], competingIDs: []))
                continue
            }
            if selectedIDs.contains(asset.id) {
                var reasons = moments.first(where: { $0.representativeAssetID == asset.id }) != nil ? ["bestInMoment"] : ["secondaryMomentRepresentative"]
                if winnerByCluster[asset.id] != nil { reasons.append("nearDuplicateRepresentative") }
                decisions.append(Decision(assetID: asset.id, status: .selected, score: scored.first(where: { $0.asset.id == asset.id })?.score, qualityBreakdown: analyses[asset.id]?.qualityBreakdown, reasons: reasons, competingIDs: []))
            } else if let winner = winnerByCluster[asset.id], winner != asset.id {
                decisions.append(Decision(assetID: asset.id, status: .rejected, score: nil, qualityBreakdown: nil, reasons: ["nearDuplicate"], competingIDs: [winner]))
            } else if scored.first(where: { $0.asset.id == asset.id })?.disposition != .usable {
                // Quality-floor cut: truthful lowQuality for hardRejected/lowQuality dispositions.
                decisions.append(Decision(assetID: asset.id, status: .rejected, score: nil, qualityBreakdown: nil, reasons: ["lowQuality"], competingIDs: []))
            } else {
                // Usable but cut by shortlist/diversity: no false quality claim. Attribute the surviving
                // coverage dimension honestly: temporal when its moment kept another pick, scene/people
                // when that category is already represented, else compositional redundancy.
                decisions.append(Decision(assetID: asset.id, status: .rejected, score: scored.first(where: { $0.asset.id == asset.id })?.score, qualityBreakdown: analyses[asset.id]?.qualityBreakdown, reasons: [diversityCutReason(for: asset.id, scored: scored, selectedIDs: selectedIDs)], competingIDs: []))
            }
        let byID = Dictionary(uniqueKeysWithValues: sourceAssets.map { ($0.id, $0) })
        let selected = decisions.filter { $0.status == .selected }.map(\.assetID).sorted {
            let left = byID[$0]!
            let right = byID[$1]!
            if (left.creationDate ?? .distantPast) != (right.creationDate ?? .distantPast) { return (left.creationDate ?? .distantPast) < (right.creationDate ?? .distantPast) }
            if order[$0] != order[$1] { return order[$0]! < order[$1]! }
            return $0.rawValue < $1.rawValue
        }
        guard decisions.count == sourceAssets.count, Set(decisions.map(\.assetID)).count == sourceAssets.count else { throw SelectionError.internal }
        guard decisions.filter({ $0.status == .selected }).allSatisfy({ !$0.reasons.isEmpty }) else { throw SelectionError.internal }
        let selectedClusters = decisions.filter { $0.status == .selected }.compactMap { winnerByCluster[$0.assetID] }
        guard Set(selectedClusters).count == selectedClusters.count else { throw SelectionError.internal }
        guard zip(selected, selected.dropFirst()).allSatisfy({ chronological($0, $1, byID: byID, order: order) }) else { throw SelectionError.internal }
        return SelectionResult(sessionID: SessionID(rawValue: UUID()), selectedAssetIDs: selected, rejectedAssetIDs: sourceAssets.map(\.id).filter { !selected.contains($0) }, decisions: decisions, generatedAt: Date(), engineVersion: 2)
    }

    private func chronological(_ left: AssetID, _ right: AssetID, byID: [AssetID: PhotoAsset], order: [AssetID: Int]) -> Bool {
        let leftAsset = byID[left]!
        let rightAsset = byID[right]!
        if (leftAsset.creationDate ?? .distantPast) != (rightAsset.creationDate ?? .distantPast) {
            return (leftAsset.creationDate ?? .distantPast) < (rightAsset.creationDate ?? .distantPast)
        }
        if order[left] != order[right] { return order[left]! < order[right]! }
        return left.rawValue < right.rawValue
    }

    private func diversityCutReason(for id: AssetID, scored: [ScoredCandidate], selectedIDs: Set<AssetID>) -> String {
        guard let candidate = scored.first(where: { $0.asset.id == id }) else { return "compositionDiversity" }
        let selected = scored.filter { selectedIDs.contains($0.asset.id) }
        if selected.contains(where: { $0.momentID == candidate.momentID }) { return "temporalCoverage" }
        if selected.contains(where: { $0.sceneType == candidate.sceneType }) { return "sceneDiversity" }
        if selected.contains(where: { $0.containsPeople == candidate.containsPeople }) { return "peopleDiversity" }
        return "compositionDiversity"
    }
}
```

Both rejected non-winner paths share one `lowQuality` branch as implemented above.

- [ ] **Step 2: Verify builder gate**

Run: `./init.sh`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Domain/Selection/FinalAlbumBuilder.swift
git commit -m "feat(008): add final album builder and checks"
```

---

### Task 4: Full engine pipeline + shared partial path

**Files:**
- Modify: `apps/photo-curator/Domain/Selection/SelectionEngine.swift`
- Modify: `apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift:244-263`
- Modify: `apps/photo-curator/Features/Processing/ProcessingModel.swift`
- Modify: `apps/photo-curator/App/AppModel.swift:364-411`

**Interfaces:**
- Consumes: feat-007 `DuplicateResolver`, `MomentBuilder`, `duplicateCandidates`, `similarityEdges`; Tasks 1–3 modules; `BatchPipeline` for `finalizeAvailable`.
- Produces: full `select` pipeline; `func finalizeAvailable(assets: [PhotoAsset], analyses: [AssetID: PhotoAnalysis], configuration: SelectionConfiguration) async throws -> SelectionResult`; `ProcessingModel.finalizeAvailable(...)`; updated `finalizePartial`.

- [ ] **Step 1: Replace pass-through with full pipeline**

```swift
struct SelectionEngine: Sendable {
    let duplicateResolver = DuplicateResolver()
    let momentBuilder = MomentBuilder()
    let qualityScorer = QualityScorer()
    let diversitySelector = DiversitySelector()
    let finalAlbumBuilder = FinalAlbumBuilder()

    func select(assets: [PhotoAsset], analyses: [AssetID: PhotoAnalysis], configuration: SelectionConfiguration, feedback: SelectionFeedback?, similarityEdges: [SimilarityEdge] = []) throws -> SelectionResult {
        let ordered = assets.sorted { ($0.creationDate ?? .distantPast, $0.id.rawValue) < ($1.creationDate ?? .distantPast, $1.id.rawValue) }
        let available = ordered.filter { analyses[$0.id] != nil }
        let resolution = duplicateResolver.resolve(assets: available, analyses: analyses, edges: similarityEdges, configuration: configuration)
        let repAssets = resolution.representativeIDs.compactMap { id in available.first(where: { $0.id == id }) }
        let moments = momentBuilder.build(representatives: repAssets, analyses: analyses, edges: similarityEdges, configuration: configuration)
        let clusterByRep = Dictionary(uniqueKeysWithValues: resolution.clusters.flatMap { cluster in cluster.assetIDs.map { ($0, cluster.id) } })
        let momentByRep = Dictionary(uniqueKeysWithValues: moments.flatMap { moment in moment.assetIDs.map { ($0, moment.id) } })
        let scored = repAssets.compactMap { asset -> ScoredCandidate? in
            guard let analysis = analyses[asset.id], let momentID = momentByRep[asset.id] else { return nil }
            return qualityScorer.score(asset: asset, analysis: analysis, clusterID: clusterByRep[asset.id], momentID: momentID, configuration: configuration)
        }
        let target = min(max(Int((Double(scored.filter { $0.disposition == .usable }.count) * configuration.targetSelectionRatio).rounded(.up)), configuration.minimumFinalCount), configuration.maximumFinalCount)
        let shortlist = qualityScorer.shortlist(candidates: scored, targetCount: target, configuration: configuration)
        let picked = diversitySelector.select(shortlist: shortlist, allMomentIDs: moments.map(\.id), targetCount: target, similarityEdges: similarityEdges, configuration: configuration, feedback: feedback)
        return try finalAlbumBuilder.build(sourceAssets: assets, analyses: analyses, clusters: resolution.clusters, moments: moments, scored: scored, selectedIDs: picked, configuration: configuration)
    }
}
```

`engineVersion` is `2` via the builder; keep `analysisVersion`.

- [ ] **Step 2: Add the shared partial entry point**

```swift
func finalizeAvailable(assets: [PhotoAsset], analyses: [AssetID: PhotoAnalysis], configuration: SelectionConfiguration) async throws -> SelectionResult {
    let candidates = engine.duplicateCandidates(for: assets, configuration: configuration)
    let edges = try await rebuildSimilarityEdges(for: assets, candidates: candidates)
    return try engine.select(assets: assets, analyses: analyses, configuration: configuration, feedback: nil, similarityEdges: edges)
}
```

Implement `rebuildSimilarityEdges` with the pipeline's existing image loader + analyzer + bounded lanes: load analysis images only for the available IDs, call `similarityArtifact(for:)`, skip failures, compute edges in stable order with cancellation checks. Change `ProcessingModel` to forward `finalizeAvailable` to the coordinator; change `AppModel.finalizePartial` to call `processing.finalizeAvailable` instead of `container.selectionEngine.select`, keeping its cancellation/race gate, result save, checkpoint, and route.

- [ ] **Step 3: Verify engine gate**

Run: `./init.sh`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add apps/photo-curator/Domain/Selection/SelectionEngine.swift apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift apps/photo-curator/Features/Processing/ProcessingModel.swift apps/photo-curator/App/AppModel.swift
git commit -m "feat(008): complete engine pipeline and partial path"
```

---

### Task 5: Data-model mapping + feature close

**Files:**
- Modify: `docs/design-docs/data-model.md` (decision/reason usage only)
- Modify: `features/feat-008.md`

**Interfaces:**
- Consumes: real `Decision` reasons, `engineVersion = 2`, cluster/moment usage from Tasks 1–4.
- Produces: corrected doc mapping; linked plan; recorded Dataset B + Golden + `./init.sh` evidence.

- [ ] **Step 1: Map decisions without schema change**

Document that `Decision.reasons` carries canonical `selection-rules §16` strings, `competingIDs` holds the duplicate winner, `engineVersion = 2` marks the first real pipeline, and clusters/moments remain cached-evictable inputs to decisions. Change no stored field or policy value.

- [ ] **Step 2: Link the plan and close the feature**

In `features/feat-008.md` add `Plan: docs/plans/feat-008.md`, then on manual QA record Dataset B + Golden evidence, sizing/reason/chronology findings, and `./init.sh` output; append the `progress.md` block with feat-009 next.

- [ ] **Step 3: Verify docs gate**

Run: `./init.sh`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add docs/design-docs/data-model.md features/feat-008.md
git commit -m "feat(008): map decisions and close"
```

---

## Self-Review

1. **Spec coverage:** every train §4 requirement maps above — scorer/shortlist (Task 1), diversity (Task 2), builder (Task 3), engine + shared partial path (Task 4), doc/feature close (Task 5).
2. **Placeholder scan:** no TBD/TODO/placeholder; Task 2–3 sketches name the exact invariant or branch to finish rather than deferring design.
3. **Type consistency:** `ScoredCandidate` fields, `QualityDisposition`, `similarityEdges`, `finalizeAvailable`, `engineVersion = 2`, and canonical reasons match across tasks.
