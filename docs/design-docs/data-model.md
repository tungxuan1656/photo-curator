# Data Model (stored representation owner)

**Responsibility:** This file owns stored representation only: entities, IDs, lifecycle, versioning, and persistence shape (PhotoAsset, PhotoAnalysis storage shape, Moment/Cluster representation, SelectionDecision/Result/Session/Progress/Config storage, cache fingerprint and validity, `analysisVersion` vs `engineVersion`).

**Not owned here:** selection policy, formulas, sizing, and reason-code meanings ([03](../product-specs/selection-rules.md)), pipeline order and mechanics ([04](selection-engine.md)), app structure ([05](ios-architecture.md)), PhotoKit/Vision call shapes ([07](apple-frameworks.md)), performance budgets and resume mechanics ([08](../ship-gates/performance.md)), review UX and wording ([02](../product-specs/ux-flows.md)), privacy, retention, and redaction ([09](../ship-gates/privacy.md)), QA procedure ([10](../ship-gates/manual-qa.md)), metrics events ([11](../ship-gates/analytics.md)). Where those topics appear below, this file states the stored shape; the linked file states the rule.

---

## 1. Stored, cached, transient

PhotoKit stays the source of truth for photos. The app stores IDs, light metadata, derived analysis, groups, decisions, and session state. It never stores full photos in models.

| Kind | What | Lives where |
|---|---|---|
| Stored | `SelectionSession`, `SelectionResult`, `SelectionDecision`, `PhotoAnalysis`, `UserOverride`, `UserFeedback`, minimal cache-validation metadata | App local store |
| Cached, evictable | `PhotoMoment`, `PhotoCluster`, thumbnails | App cache; safe to rebuild |
| Transient only | `UIImage` / `CGImage` / `CIImage` / `CVPixelBuffer`, `PHAsset` objects, Vision requests, similarity matrix, ranking scratch arrays, face boxes, precise location, feature prints, UI state (`isExpanded`, scroll, zoom) | Memory; released after use |

Face boxes, precise location, and feature-print blobs stay in bounded temp working memory only. Retention and redaction: [09](../ship-gates/privacy.md).

Data ownership:

| Data | Owner |
|---|---|
| Original photo bytes | PhotoKit |
| Identifier and metadata snapshot | Photos Curator store |
| Thumbnail | Image cache |
| Analysis, cluster assignment, moment assignment, AI choice | Selection engine + app store |
| User override and final pick | User |
| Library change (album write) | PhotoKit layer; see [07](apple-frameworks.md) |

Loading rule: loading 1,000–5,000 assets means loading IDs, dates, sizes, favorite flags, subtypes, and location refs — never 1,000+ pixel buffers. Request pixels only for the stage that needs them, then release. See [08](../ship-gates/performance.md) for budgets.

---

## 2. Entity graph

```text
SelectionSession
├── sourceAssetIDs: [AssetID]
├── configuration: StoredConfigReference
├── progress: SessionProgress
├── clusters: [PhotoCluster]      (cached, dups first)
├── moments: [PhotoMoment]        (cached, built from cluster representatives)
└── result: SelectionResult?
     └── decisions: [SelectionDecision]
            └── assetID ─┬─ PhotoAsset
                         ├─ PhotoAnalysis
                         ├─ PhotoCluster (via lookup)
                         └─ PhotoMoment (via lookup)

UserFeedback (sessionID + assetID + action + timestamp)
UserOverride (sessionID + assetID + forceKeep/forceRemove/none)
CuratedAlbum (sessionID + assetIDs in chrono order + createdAt)
```

Rule: relations use IDs, not nested objects. A moment holds `[AssetID]`, not copies of `PhotoAsset`. A decision holds `assetID` plus `competingAssetIDs`, not photo objects. This keeps the graph flat and rebuildable.

Core pipeline in storage terms (dups before moments, per [04](selection-engine.md)):

```text
PhotoAsset → PhotoAnalysis → Cluster refs → Moment refs → SelectionDecision → SelectionResult → CuratedAlbum + UserFeedback
```

Key storage rule: photo, analysis, and decision are three separate records. Re-ranking writes new decisions from stored analyses without re-running image work. See [04](selection-engine.md) for the run order.

---

## 3. Identifier types

Use typed IDs so asset, session, moment, and cluster IDs cannot mix.

```swift
struct AssetID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: String }       // PHAsset.localIdentifier
struct SessionID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: UUID }
struct MomentID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: UUID }
struct ClusterID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: UUID }
```

Do not invent typed IDs for minor objects unless ID mix-ups are a real risk.

---

## 4. Invariants

- Store MUST be `PHAsset.localIdentifier` wrapped as `AssetID`. Models MUST never persist `PHAsset`, `UIImage`, `CGImage`, `CIImage`, or `CVPixelBuffer`.
- Store MUST never persist face boxes, precise location, or feature-print blobs beyond bounded temp working memory.
- Face, location, and feature cache rows stay session-temp with immediate release where used, never durable rows.
- Scores use `Double` in `0.0 ... 1.0` unless a field states otherwise.
- Missing analysis MUST be `nil`, never a fake `0` or `0.5`.
- One asset MUST map to at most one `PhotoAnalysis` per `analysisVersion`.
- One asset maps to at most one primary `Moment`.
- One asset maps to at most one primary `PhotoCluster` per clustering pass.
- One asset MUST map to at most one active `SelectionDecision` per session and `engineVersion`.
- One asset maps to at most one effective `UserOverride` per session; history lives in `UserFeedback` events.
- Stored `AssetID` MUST be treated as possibly unresolvable; PhotoKit is authoritative.

---

## 5. PhotoAsset storage

Light view of one PhotoKit photo. Cheap fields only, no pixels.

```swift
struct PhotoAsset: Identifiable, Codable, Hashable, Sendable {
    let id: AssetID
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let mediaSubtype: PhotoMediaSubtype
    let isFavorite: Bool
    let source: AssetSource
}
```

| Field | Notes |
|---|---|
| `creationDate` | May be nil; missing dates never lower quality, see [03](../product-specs/selection-rules.md). |
| `pixelWidth/Height` | Basis for derived `aspectRatio` and `orientation`; orientation is derived, not stored separately. |
| `mediaSubtype` | Only values that change behavior (`standard`, `livePhoto`, `screenshot`, `panorama`, `hdr`, `portrait`, `unknown`). Eligibility policy: [03](../product-specs/selection-rules.md). |
| `isFavorite` | Soft bonus flag only; see [03](../product-specs/selection-rules.md). |
| `source` | `local` / `iCloud` / `unknown`. Hint for progress and retry only; iCloud state can change. API detail: [07](apple-frameworks.md). |

Precise location is never stored here; it stays in bounded temp working memory only for grouping, then released. Retention and redaction: [09](../ship-gates/privacy.md).

Ephemeral analysis input (never persisted):

```swift
struct AnalysisInput {
    let assetID: AssetID
    let image: CGImage
}
```

Memory rule: `PhotoAsset` and `PhotoAnalysis` stay for the session; thumbnails live in cache; full images are processed then released. See [08](../ship-gates/performance.md).

---

## 6. PhotoAnalysis storage

Derived facts about one photo. Facts live here; choices live in `SelectionDecision`.

```swift
struct PhotoAnalysis: Identifiable, Codable, Sendable {
    var id: AssetID { assetID }
    let assetID: AssetID
    let technical: TechnicalAnalysis
    let people: PeopleAnalysis
    let composition: CompositionAnalysis
    let content: ContentAnalysis
    let qualityScore: Double        // stored rollup; formula owned by 03/04
    let qualityBreakdown: QualityScoreBreakdown?
    let analyzedAt: Date
    let analysisVersion: Int
}
```

### 6.1 TechnicalAnalysis

| Field | Range |
|---|---|
| `sharpnessScore`, `exposureScore`, `resolutionScore` | `0.0 ... 1.0`, higher is better |
| `blurProbability`, `underexposureProbability`, `overexposureProbability` | `0.0 ... 1.0`, higher means more likely defective |

Name fields so direction is clear (`sharpnessScore` vs `blurProbability`). Never use a bare `blurScore`. Cutoffs and tiers: [03](../product-specs/selection-rules.md).

### 6.2 PeopleAnalysis and FaceAnalysis

```swift
struct PeopleAnalysis: Codable, Sendable {
    let faceCount: Int
    let groupPhotoScore: Double?
    var containsPeople: Bool { faceCount > 0 }
}
// Session-temp only, never persisted; released after analysis:
struct FaceAnalysis: Sendable {
    let boundingBox: NormalizedRect   // 0.0 ... 1.0, resolution independent
    let qualityScore: Double          // 0.0 ... 1.0
    let eyesOpenScore: Double?
    let smileScore: Double?
    let frontalScore: Double?
}
```

Stored shape holds counts and summary scores only. Face boxes live in bounded temp working memory and are released after use. Privacy limits: anonymous faces only. No `personName`, `personID`, identity embedding, or contact link in MVP. Retention and redaction: [09](../ship-gates/privacy.md). Group and portrait scoring policy: [03](../product-specs/selection-rules.md).

### 6.3 CompositionAnalysis

```swift
struct CompositionAnalysis: Codable, Sendable {
    let aestheticScore: Double?
    let subjectPlacementScore: Double?
    let horizonScore: Double?
    let visualBalanceScore: Double?
}
```

Absent signal is `nil` (not run), distinct from `0.5` (run, middling).

### 6.4 ContentAnalysis

```swift
struct ContentAnalysis: Codable, Sendable {
    let sceneType: SceneType
    let tags: [SemanticTag]           // SemanticTag(name, confidence); keep few, high-value tags only
    let hasText: Bool?
    let screenshotProbability: Double?
}
enum SceneType: String, Codable, Sendable {
    case people, group, landscape, architecture, food, animal
    case indoor, outdoor, document, screenshot, other, unknown
}
```

Scene meanings and diversity use: [03](../product-specs/selection-rules.md). Keep tags light; no ontology in MVP.

### 6.5 Quality rollup storage

`qualityScore` (`0.0` poor … `1.0` excellent) and optional `QualityScoreBreakdown(technical, people?, composition?, content?, total)` are stored for reuse and debug. Weighting, tier cutoffs, and the split between intrinsic quality and final selection value are owned by [03](../product-specs/selection-rules.md); computation order by [04](selection-engine.md). This file defines only the stored fields.

---

## 7. Cluster and Moment representation

Definitions, grouping thresholds, time windows, per-moment keeper counts, and worked cases are owned by [03](../product-specs/selection-rules.md). Detection mechanics are owned by [04](selection-engine.md), which runs duplicate clustering before moment segmentation. This file defines only stored shape and membership.

```swift
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
enum ClusterType: String, Codable, Sendable {
    case nearDuplicate, burstLike, sameScene, samePose, groupPhotoSequence
}
```

Membership: asset → at most 1 primary cluster per pass, then moments group cluster representatives in time order (dups before moments, per [04](selection-engine.md)). References only; no embedded `PhotoAsset` copies.

Similarity storage rule: never persist an N×N matrix (5,000² = 25M pairs). Persist cluster results only. Pairwise edges are transient:

```swift
struct SimilarityEdge: Sendable {
    let first: AssetID
    let second: AssetID
    let similarity: Double
}
```

Feature prints (Vision or equivalent) stay in bounded temp working memory keyed by `AssetID` for the pairwise step, then released; they are never durable rows. Retention: [09](../ship-gates/privacy.md). API detail: [07](apple-frameworks.md).

---

## 8. SelectionDecision storage

One recorded choice per asset per session. Score math and keeper rules: [03](../product-specs/selection-rules.md).

```swift
struct SelectionDecision: Identifiable, Codable, Sendable {
    var id: AssetID { assetID }
    let assetID: AssetID
    let status: SelectionStatus       // selected / rejected / undecided
    let score: Double
    let scoreBreakdown: SelectionScoreBreakdown
    let reasons: [SelectionReason]
    let competingAssetIDs: [AssetID]  // winner(s) this asset lost to; debug gold
    let engineVersion: Int
}
struct SelectionScoreBreakdown: Codable, Sendable {
    let quality: Double
    let uniqueness: Double
    let momentImportance: Double
    let people: Double
    let diversity: Double
    let redundancyPenalty: Double
    let finalScore: Double
}
```

| Stored item | Owner of meaning |
|---|---|
| Keep/reject policy, tier cutoffs, weights, diversity and coverage model | [03](../product-specs/selection-rules.md) |
| Rank and assemble order | [04](selection-engine.md) |
| `SelectionReason` code list (e.g. `exactDuplicate`, `bestInMoment`, `userSelected`) | [03 §16](../product-specs/selection-rules.md); this file stores the codes |
| Analytics use of reasons | [11](../ship-gates/analytics.md) |

Keep `SelectionStatus` to three cases; put nuance in `reasons`. Never mutate the engine record for a user edit — write `UserOverride` + `UserFeedback` instead (§11).

---

## 9. SelectionResult, candidates, album

```swift
struct SelectionResult: Codable, Sendable {
    let sessionID: SessionID
    let selectedAssetIDs: [AssetID]   // chrono order for review by default
    let rejectedAssetIDs: [AssetID]
    let decisions: [SelectionDecision]
    let generatedAt: Date
    let engineVersion: Int
}
struct CuratedAlbum: Identifiable, Codable, Sendable {
    let id: UUID
    let sessionID: SessionID
    let assetIDs: [AssetID]           // chrono order tells the story; rank decides inclusion
    let createdAt: Date
}
```

Transient rank helper (persist only for debug):

```swift
struct RankedCandidate: Identifiable, Sendable {
    var id: AssetID { assetID }
    let assetID: AssetID
    let score: Double
    let rank: Int
}
```

Persisted shortlist and alternative shape (IDs + rank refs only, no pixels or faces):

```swift
struct StoredShortlist: Codable, Sendable {
    let sessionID: SessionID
    let assetIDs: [AssetID]
    let rankByAssetID: [AssetID: Int]
    let momentIDByAssetID: [AssetID: MomentID]
    let clusterIDByAssetID: [AssetID: ClusterID]
}
struct StoredAlternative: Codable, Sendable {
    let assetID: AssetID
    let clusterID: ClusterID
    let rank: Int
}
```

Review-surface order, shortlist sizing, and accept semantics: [02](../product-specs/ux-flows.md). Album sizing targets: [03 §14](../product-specs/selection-rules.md). Debug extras (`candidateRank`, `clusterRank`, raw score maps) stay dev-only and out of prod persistence.

---

## 10. Session, progress, config storage

```swift
struct SelectionSession: Identifiable, Codable, Sendable {
    let id: SessionID
    let createdAt: Date
    var updatedAt: Date
    var status: SessionStatus
    let sourceAssetIDs: [AssetID]
    let targetPhotoCount: Int?
    var progress: SessionProgress
    var result: SelectionResult?
    let configuration: StoredConfigReference
}
enum SessionStatus: String, Codable, Sendable {
    case created, loadingAssets, analyzing, clustering, groupingMoments
    case ranking, generatingAlbum, readyForReview, completed, interrupted, failed
}
struct SessionProgress: Codable, Sendable {
    let stage: ProcessingStage
    let processedCount: Int
    let totalCount: Int
    let message: String?
}
enum ProcessingStage: String, Codable, Sendable {
    case loading, analysis, clustering, momentDetection, ranking, finalSelection
}
// SelectionConfiguration struct owned by selection-engine.md §12; not repeated here.
struct StoredConfigReference: Codable, Sendable {
    let configVersion: Int
    let snapshotRef: String   // opaque config snapshot ref for session reproduce
}
```

Notes: `SessionStatus` mirrors pipeline phases at coarse grain; stage mechanics and retry live in [04](selection-engine.md) and [08](../ship-gates/performance.md). `ProcessingStage` is the single canonical stored stage enum; the coordinator writes it and the UI derives progress from it. Engine (10 stages), orchestration, and user phases are layer-specific labels that map onto it as below. Stored config is a version plus an opaque snapshot ref; the engine struct lives in [04 §12](selection-engine.md). Tunable defaults and sizing math: [03 §14, §17](../product-specs/selection-rules.md). Progress text is non-localized; user wording: [02](../product-specs/ux-flows.md). Progress fraction (`processedCount / totalCount`) is derived.

Stage mapping (canonical — write `ProcessingStage`, display layer labels):

| Stored `ProcessingStage` | Engine stages ([04 §2](selection-engine.md)) | Orchestration ([05 §12](ios-architecture.md)) | User phases ([02 §7](../product-specs/ux-flows.md)) |
|---|---|---|---|
| `loading` | Ingest, Eligible | preparing | Preparing photos |
| `analysis` | Analyze | analyzing | Analyzing photos |
| `clustering` | Dups | selecting | Grouping similar shots |
| `momentDetection` | Moments | selecting | Grouping similar shots |
| `ranking` | Rank, Shortlist | selecting | Choosing the best photos |
| `finalSelection` | Diversity, Verify, Order | selecting → readyForReview | Choosing the best photos → Finishing your album |

---

## 11. Feedback, override, review state

```swift
struct UserFeedback: Identifiable, Codable, Sendable {
    let id: UUID
    let sessionID: SessionID
    let assetID: AssetID
    let action: FeedbackAction       // keepRejectedPhoto / removeSelectedPhoto / restorePhoto / undo / acceptSelection
    let previousState: SelectionStatus?
    let newState: SelectionStatus?
    let timestamp: Date
}
enum UserOverride: String, Codable, Sendable { case none, forceKeep, forceRemove }
struct FinalPhotoDecision: Sendable {   // computed, not persisted
    let assetID: AssetID
    let engineDecision: SelectionDecision
    let userOverride: UserOverride
    var isSelected: Bool {
        switch userOverride {
        case .forceKeep: return true
        case .forceRemove: return false
        case .none: return engineDecision.status == .selected
        }
    }
}
struct ReviewState: Sendable {          // UI state, never persisted
    var currentAssetID: AssetID?
    var selectedAssetIDs: Set<AssetID>
    var rejectedAssetIDs: Set<AssetID>
}
```

Rules: user include/exclude is a hard session override (see [03 §14](../product-specs/selection-rules.md)); accept, restore, and undo wording and flow are owned by [02](../product-specs/ux-flows.md). Store raw feedback events in MVP; do not build preference profiles yet. No testing-only models; QA handling: [10](../ship-gates/manual-qa.md).

---

## 12. Failures

Per-asset failure (session continues):

```swift
struct AssetProcessingFailure: Codable, Sendable {
    let assetID: AssetID
    let stage: ProcessingStage
    let reason: ProcessingFailureReason
}
enum ProcessingFailureReason: String, Codable, Sendable {
    case assetUnavailable, iCloudDownloadFailed, imageRequestFailed
    case visionAnalysisFailed, unsupportedFormat, cancelled, unknown
}
```

Session failure (cannot continue):

```swift
struct SessionFailure: Codable, Sendable {
    let stage: ProcessingStage?
    let message: String
    let recoverable: Bool
}
```

Store stable categories only, never raw framework errors. Retry and backoff: [04](selection-engine.md), [08](../ship-gates/performance.md).

---

## 13. Cache fingerprint and validity

```swift
struct AnalysisCacheRecord: Codable, Sendable {
    let assetID: AssetID
    let analysis: PhotoAnalysis
    let fingerprint: AssetFingerprint
    let analysisVersion: Int
}
struct AssetFingerprint: Codable, Hashable, Sendable {
    let pixelWidth: Int
    let pixelHeight: Int
    let creationDate: Date?
    let modificationDate: Date?
}
```

| Cache is reusable only when | Check |
|---|---|
| Asset still resolves in PhotoKit | Lookup by `AssetID` succeeds |
| Fingerprint matches | Dimensions + dates compatible |
| Version matches | `record.analysisVersion == currentAnalysisVersion` |

Goal is "safe to reuse", not cryptographic proof. Eviction, checkpoint cadence, and resume-stub shape: [08](../ship-gates/performance.md). Retention and reset: [09](../ship-gates/privacy.md).

---

## 14. Versioning

Two independent counters. Bumping one never forces work owned by the other.

| Version | Bumps when | Effect |
|---|---|---|
| `analysisVersion` | Image reading changes (blur method, face request, semantic input, Vision call) | Old `PhotoAnalysis` rows invalid; re-analyze |
| `engineVersion` | Choice changes (weights, thresholds, diversity rules, moment balance) | Old `SelectionDecision` rows invalid; re-rank from stored analyses |

Changing rank weights re-ranks stored analyses into new decisions with no Vision rerun. API-side triggers: [07](apple-frameworks.md). Tuning validation: [10](../ship-gates/manual-qa.md).

---

## 15. Persistence shape

Persist: session, result, decisions, stored shortlist and alternatives, analyses + cache, overrides, feedback, minimal validation metadata. Persistence is file-based Codable with no database for MVP (see [decision-log](decision-log.md) DEC-TBD-002). Cache-only: moments, clusters, thumbnails. Temp-only with immediate release: face boxes, precise location, feature prints. Never: pixel buffers, Vision objects, matrices, UI state.

Domain models stay persistence-agnostic: `Persistence → Domain → Engine → Domain → Persistence`. Start with one model type; add DTOs only if the store forces it. Folder layout is owned by [05](ios-architecture.md); suggested code grouping is Asset / Analysis / Grouping / Selection / Session / Feedback, flattened while small.

Runtime indexes are rebuilt on load, not stored:

```swift
let assetByID: [AssetID: PhotoAsset]
let analysisByAssetID: [AssetID: PhotoAnalysis]
let decisionByAssetID: [AssetID: SelectionDecision]
let clusterByAssetID: [AssetID: ClusterID]
let momentByAssetID: [AssetID: MomentID]
```

PhotoKit changes: PhotoKit wins. If an `AssetID` no longer resolves, drop or invalidate its analysis, group refs, and decisions as needed. Store snapshots, not library truth.

Lifecycle (stored `SessionStatus`):

```text
created → loadingAssets → analyzing → clustering → groupingMoments
  → ranking → generatingAlbum → readyForReview → completed
  ↳ interrupted → resume from cached analyses → continue
  ↳ failed (any stage)
```

Resume needs only: session ID, source IDs, stage, completed analyses, config, and result if present. Example: 1,000 assets with 620 cached → reuse 620, analyze 380, continue. Full resume and background rules: [08](../ship-gates/performance.md).

Retention, deletion, logging redaction, and what never leaves device: [09](../ship-gates/privacy.md). This file adds no privacy rules.

---

## 16. Conventions and non-goals

Conventions: arrays where order matters (`[AssetID]` for albums), sets for review membership, dicts for lookup (`[AssetID: PhotoAnalysis]`). Concrete types over `Scorable`/`Clusterable`-style protocols. No per-metric models (`BlurResult`, `LandscapeResult`) when `TechnicalAnalysis` / `ContentAnalysis` cover them.

Non-goals for MVP: Photos-database replacement, cloud sync of app state, shared albums, named-person or biometric stores, lasting similarity matrices, custom photo files, event ontology, taste profiles, event sourcing, per-model repository abstractions, over-normalized schema.

Minimum start schema: `PhotoAsset`, `PhotoAnalysis`, `PhotoCluster`, `PhotoMoment`, `SelectionDecision`, `SelectionSession`, `UserFeedback`. Implement in pipeline order: IDs → asset → analysis → cluster → moment → decision → result → session → override/feedback → cache.

---

## 17. Links and Uncertain

- What to pick and why: [03](../product-specs/selection-rules.md).
- Run order and retry: [04](selection-engine.md).
- Review wording and accept flow: [02](../product-specs/ux-flows.md).
- PhotoKit/Vision calls: [07](apple-frameworks.md).
- Budgets, checkpoints, resume: [08](../ship-gates/performance.md).
- Retention, redaction, disclosures: [09](../ship-gates/privacy.md).
- QA and metrics: [10](../ship-gates/manual-qa.md), [11](../ship-gates/analytics.md).

Uncertain (storage impact only; policy tuning lives in 03/04/10):

1. Whether `PhotoMoment`/`PhotoCluster` stay cache-only or need durable rows after cost data.
2. Final `AssetFingerprint` fields, pending available PhotoKit metadata.
3. Whether `RankedCandidate` or score maps need durable debug rows.
4. Minimal resume-stub fields under background limits (see [08](../ship-gates/performance.md)).
