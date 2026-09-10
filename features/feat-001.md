# feat-001 — Contract + shell

## Goal

Freeze G0 contracts so lanes A and B build without waiting: protocols compile, `AppContainer.live()` returns Noop stubs, app still builds/runs on template UI.

## Scope

- `Domain/Models/`: `AssetID` (String = PHAsset.localIdentifier), `SessionID`/`MomentID`/`ClusterID` (UUID), `PhotoAsset` (id, creationDate?, pixelW/H, mediaSubtype, isFavorite, source), `PhotoAnalysis` minimal (assetID, technical/people/composition/content, qualityScore, analyzedAt, analysisVersion=1), `SelectionResult` + `Decision` minimal (sessionID, selected/rejectedIDs, decisions, generatedAt, engineVersion=1).
- `Services/ServiceProtocols.swift`: 6 protocols at Apple-framework boundary only — `PhotoLibraryService`, `PhotoImageLoader`, `ImageAnalysisService`, `AnalysisCache` (actor), `AlbumExportService`, `AnalyticsService`. No protocols for `SelectionEngine`/`CheckpointStore` (concrete per DEC-015).
- `Domain/Selection/SelectionEngine.swift`: `struct SelectionEngine: Sendable` with `func select(assets:[PhotoAsset], analyses:[AssetID:PhotoAnalysis], configuration:SelectionConfiguration, feedback:SelectionFeedback?) throws -> SelectionResult`. G0 stub returns empty result (no fatalError). Sync + deterministic noted in docstring.
- `Configuration/AppConfiguration.swift`: `struct AppConfiguration: Sendable` with nested `analysis/selection/performance/cache` + `static default` (selection defaults: analysis512, dupWindow 90s, moment gaps 3m/15m, ratio 10% / min 30 / max 150, shortlist 2x). `configVersion=1`.
- `App/AppContainer.swift`: `struct AppContainer: Sendable` with 7 fields (all of ios-architecture §5 except `checkpointStore`, which joins in feat-002A) + `static live()` returning Noop stubs.
- `SelectionError` minimal: `invalidInput`, `cancelled`, `internal`.
- `SelectionFeedback` minimal (per DEC-021, engine signature needs it): struct with `removedIDs: Set<AssetID>`, `restoredIDs: Set<AssetID>`, `favoriteIDs: Set<AssetID>`, `swapWinner: [ClusterID: AssetID]` — empty default; learn later.
- Rename sweep: `PhotosCurator` → `PhotoCurator` in `README.md`, `docs/` + Swift code comments. Xcode target/scheme/`.xcodeproj` names unchanged.
- Note in decision-log: keep `PhotoCuratorApp`; canonical `PhotoAsset` (drop `PhotoAssetRecord` at G0); engine file is `SelectionEngine.swift` (feature_index owns updated accordingly by leader).

## Non-goals

- No PhotoKit fetch, Vision run, scoring, duplicates, moments, diversity logic (G1–G4).
- No `RootView`/`AppModel`/`AppRoute` (feat-002B), no `ContentView` replacement.
- No detailed error mapping (permission/iCloud/export — later stages).
- No DB, packages, DI frameworks, test targets (DEC-015/016, DEC-TBD-002).

## Acceptance

- [ ] `./init.sh` passes (format + strict swiftlint + build; SKIP [test]).
- [ ] Lane A check (a temp file under `Domain/` or `Services/`) and lane B check (a temp file under `App/` or `Features/`) both import the contract; both temp files deleted before PR.
- [ ] `AppContainer.live()` constructs without fatalError; app launches on simulator.
- [ ] Zero `PhotosCurator` occurrences in `README.md`, `docs/**/*.md`, `apps/**/*.swift` — excluding `features/feat-001.md` (this record) and `*.xcodeproj`/target/scheme names.
- [ ] Every final pick path noted as carrying reason codes (docstring), chronological order default noted.

## Relevant docs

- `docs/design-docs/ios-architecture.md`
- `docs/design-docs/selection-engine.md`
- `docs/design-docs/data-model.md`

## Plan

> **Execution:** Follow the repository's implementation and verification rules. No automated tests per DEC-016 — each task's test cycle is `./init.sh` (SwiftFormat + `swiftlint lint --strict` + simulator build). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the G0 contract + shell in 10 tasks so lanes A and B compile against frozen types.

**Architecture:** Value-type domain models (`Sendable` + `Codable`) under `Domain/Models/`; capability-shaped service protocols with Noop doubles in one file; concrete `SelectionEngine` facade with an empty-result stub; one `AppConfiguration.default`; `AppContainer.live()` wiring Noops. Ordered so `./init.sh` stays green after every task.

**Tech Stack:** Swift 5.0, SwiftUI (untouched template), Foundation + CoreGraphics only, single app target `photo-curator` (synced folders — new files need no `.pbxproj` edit).

**Plan artifact decision:** Plan stays inline here. AGENTS.md requires >=2 substantial signals for `docs/plans/feat-<id>.md`; this work has 1 (8 new files, 1 workspace, no migration, no phases/rollback).

## Global Constraints

- No test targets, no `*Test*.swift` files, no test frameworks (AGENTS.md; DEC-016).
- Validation is manual only; `./init.sh` reports `SKIP [test]` (AGENTS.md).
- Swift 5.0, iOS 26 minimum, single app target `photo-curator`.
- Zero third-party runtime dependencies (ios-architecture invariant).
- The engine never imports SwiftUI; SwiftUI never calls PhotoKit/Vision directly (team-build-plan).
- Lines fit 120 cols (warn) / 150 (error); SwiftFormat (`--maxwidth 120`, indent 4) runs before lint in `./init.sh`.
- App prefix is `PhotoCurator` (no `s`); canonical model is `PhotoAsset`; `SelectionEngine` stays concrete, no protocol (DEC-015).
- No file has two owners within one stage; contracts freeze in G0 — post-G0 extensions go through leader review (team-build-plan).
- Branch `joint/feat-001` (from `int/G0`); commit subjects `feat-001: <imperative>`; no `WIP` (team-build-plan §4).
- `feature_index.json` + `progress.md` are touched by the leader only inside the INT PR — this lane branch does NOT edit them.

---

### Task 1: Asset IDs

**Files:**
- Create: `apps/photo-curator/Domain/Models/AssetIDs.swift`

**Interfaces:**
- Consumes: nothing (first file).
- Produces: `AssetID`, `SessionID`, `MomentID`, `ClusterID` — `RawRepresentable` structs (`String` for assets = `PHAsset.localIdentifier`; `UUID` otherwise), all `Codable, Hashable, Sendable`. Later tasks use `AssetID(rawValue:)`, `SessionID(rawValue: UUID())`.

- [ ] **Step 1: Create the file with this exact content**

```swift
import Foundation

/// Stable identity for one photo in the Photos library.
/// Wraps `PHAsset.localIdentifier`. PhotoKit is authoritative: a stored id may no longer resolve.
struct AssetID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Identity for one curation session.
struct SessionID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

/// Identity for one time-moment group.
struct MomentID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}

/// Identity for one duplicate/near-duplicate cluster.
struct ClusterID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID) {
        self.rawValue = rawValue
    }
}
```

- [ ] **Step 2: Run verification**

Run: `./init.sh`
Expected: `PASS [format]`, `PASS [lint]`, `PASS [build]`, `SKIP [test]`, `=== Verification passed ===`. If SwiftLint flags anything, fix the flagged lines and re-run until green.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Domain/Models/AssetIDs.swift
git commit -m "feat-001: add AssetID family"
```

### Task 2: PhotoAsset

**Files:**
- Create: `apps/photo-curator/Domain/Models/PhotoAsset.swift`

**Interfaces:**
- Consumes: `AssetID` from Task 1.
- Produces: `PhotoMediaSubtype`, `AssetSource`, `PhotoAsset` (light PhotoKit view, cheap fields only, no pixels — data-model §5).

- [ ] **Step 1: Create the file with this exact content**

```swift
import Foundation

/// Values that change behavior only (eligibility policy: selection-rules).
enum PhotoMediaSubtype: String, Codable, Sendable {
    case standard, livePhoto, screenshot, panorama, hdr, portrait, unknown
}

/// Where the bytes live. Hint for progress/retry only; iCloud state can change.
enum AssetSource: String, Codable, Sendable {
    case local, iCloud, unknown
}

/// Light view of one PhotoKit photo. Cheap fields only, no pixels. Precise location is never stored here.
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

- [ ] **Step 2: Run verification**

Run: `./init.sh`
Expected: PASS across format/lint/build, `SKIP [test]`, `=== Verification passed ===`. Fix any flagged lines, re-run until green.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Domain/Models/PhotoAsset.swift
git commit -m "feat-001: add PhotoAsset light model"
```

### Task 3: PhotoAnalysis

**Files:**
- Create: `apps/photo-curator/Domain/Models/PhotoAnalysis.swift`

**Interfaces:**
- Consumes: `AssetID` from Task 1.
- Produces: `TechnicalAnalysis`, `PeopleAnalysis`, `CompositionAnalysis`, `SemanticTag`, `SceneType`, `ContentAnalysis`, `QualityScoreBreakdown`, `PhotoAnalysis`, `AnalysisInput` (ephemeral, never persisted — data-model §5/§6).

- [ ] **Step 1: Create the file with this exact content**

```swift
import CoreGraphics
import Foundation

/// Pixel-derived sharpness/exposure facts. Higher score is better; higher probability is more defective.
struct TechnicalAnalysis: Codable, Sendable {
    let sharpnessScore: Double
    let exposureScore: Double
    let resolutionScore: Double
    let blurProbability: Double
    let underexposureProbability: Double
    let overexposureProbability: Double
}

/// Stored people facts: counts and summary scores only. Face boxes are session-temp and never persisted.
struct PeopleAnalysis: Codable, Sendable {
    let faceCount: Int
    let groupPhotoScore: Double?

    var containsPeople: Bool {
        faceCount > 0
    }
}

/// Composition signals. Absent (`nil`) means not run, distinct from middling (`0.5`).
struct CompositionAnalysis: Codable, Sendable {
    let aestheticScore: Double?
    let subjectPlacementScore: Double?
    let horizonScore: Double?
    let visualBalanceScore: Double?
}

/// One semantic tag with confidence. Keep few, high-value tags only.
struct SemanticTag: Codable, Sendable {
    let name: String
    let confidence: Double
}

enum SceneType: String, Codable, Sendable {
    case people, group, landscape, architecture, food, animal
    case indoor, outdoor, document, screenshot, other, unknown
}

struct ContentAnalysis: Codable, Sendable {
    let sceneType: SceneType
    let tags: [SemanticTag]
    let hasText: Bool?
    let screenshotProbability: Double?
}

/// Stored quality rollup. Weighting and tier cutoffs are owned by selection-rules; this file stores fields only.
struct QualityScoreBreakdown: Codable, Sendable {
    let technical: Double
    let people: Double?
    let composition: Double?
    let content: Double?
    let total: Double
}

/// Derived facts about one photo. Facts live here; choices live in `Decision`.
struct PhotoAnalysis: Identifiable, Codable, Sendable {
    var id: AssetID {
        assetID
    }

    let assetID: AssetID
    let technical: TechnicalAnalysis
    let people: PeopleAnalysis
    let composition: CompositionAnalysis
    let content: ContentAnalysis
    let qualityScore: Double
    let qualityBreakdown: QualityScoreBreakdown?
    let analyzedAt: Date
    let analysisVersion: Int
}

/// Ephemeral analysis input. Never persisted; the image is released after analysis.
struct AnalysisInput: @unchecked Sendable {
    let assetID: AssetID
    let image: CGImage
}
```

- [ ] **Step 2: Run verification**

Run: `./init.sh`
Expected: PASS across format/lint/build, `SKIP [test]`, `=== Verification passed ===`. Fix any flagged lines, re-run until green.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Domain/Models/PhotoAnalysis.swift
git commit -m "feat-001: add PhotoAnalysis stored shape"
```

### Task 4: SelectionResult + SelectionFeedback

**Files:**
- Create: `apps/photo-curator/Domain/Models/SelectionResult.swift`

**Interfaces:**
- Consumes: `AssetID`, `SessionID`, `ClusterID` from Task 1; `QualityScoreBreakdown` from Task 3.
- Produces: `DecisionStatus`, `Decision` (reasons are raw `selection-rules §16` codes until feat-006A types them), `SelectionResult`, `SelectionFeedback` (DEC-021 shape, empty default).

- [ ] **Step 1: Create the file with this exact content**

```swift
import Foundation

enum DecisionStatus: String, Codable, Sendable {
    case selected, rejected
}

/// One keep/reject choice. Rejected means "not in this album", never "safe to delete" (DEC-026).
struct Decision: Codable, Sendable {
    let assetID: AssetID
    let status: DecisionStatus
    let score: Double?
    let qualityBreakdown: QualityScoreBreakdown?
    let reasons: [String]
    let competingIDs: [AssetID]
}

struct SelectionResult: Codable, Sendable {
    let sessionID: SessionID
    let selectedAssetIDs: [AssetID]
    let rejectedAssetIDs: [AssetID]
    let decisions: [Decision]
    let generatedAt: Date
    let engineVersion: Int
}

/// Review overrides collected by UI. Stored per session; learning from it is post-MVP (DEC-020).
struct SelectionFeedback: Codable, Sendable {
    var removedIDs: Set<AssetID> = []
    var restoredIDs: Set<AssetID> = []
    var favoriteIDs: Set<AssetID> = []
    var swapWinner: [ClusterID: AssetID] = [:]
}
```

- [ ] **Step 2: Run verification**

Run: `./init.sh`
Expected: PASS across format/lint/build, `SKIP [test]`, `=== Verification passed ===`. Fix any flagged lines, re-run until green.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Domain/Models/SelectionResult.swift
git commit -m "feat-001: add SelectionResult and SelectionFeedback"
```

### Task 5: SelectionEngine + SelectionError

**Files:**
- Create: `apps/photo-curator/Domain/Selection/SelectionEngine.swift`

**Interfaces:**
- Consumes: `PhotoAsset` (Task 2), `PhotoAnalysis` (Task 3), `SelectionResult`/`SelectionFeedback`/`SessionID` (Task 4), `SelectionConfiguration` (Task 7 — signature only; the type must exist before the final build, so this task's `./init.sh` is expected to FAIL on build until Task 7 lands; run lint-only check instead: `swiftlint lint --strict apps/photo-curator/Domain/Selection/SelectionEngine.swift`).
- Produces: `SelectionError`, `SelectionEngine.select(assets:analyses:configuration:feedback:)`.

- [ ] **Step 1: Create the file with this exact content**

```swift
import Foundation

/// Minimal engine errors. Typed per-layer errors arrive with their owning stages.
enum SelectionError: Error, Sendable {
    case invalidInput, cancelled, `internal`
}

/// Pure deterministic selection facade. Same assets + analyses + configuration + feedback give the same
/// result (tie-breaks: selection-rules §15). Real stages land in G4; this G0 stub returns an empty result
/// so lanes link without waiting. Final picks are chronologically ordered and each carries reason codes.
struct SelectionEngine: Sendable {
    func select(
        assets: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        configuration: SelectionConfiguration,
        feedback: SelectionFeedback?
    ) throws -> SelectionResult {
        SelectionResult(
            sessionID: SessionID(rawValue: UUID()),
            selectedAssetIDs: [],
            rejectedAssetIDs: assets.map(\.id),
            decisions: [],
            generatedAt: Date(),
            engineVersion: 1
        )
    }
}
```

- [ ] **Step 2: Run lint check (build lands in Task 7)**

Run: `swiftlint lint --strict apps/photo-curator/Domain/Selection/SelectionEngine.swift`
Expected: `Done linting! Found 0 violations`. Fix any flagged lines, re-run until clean.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Domain/Selection/SelectionEngine.swift
git commit -m "feat-001: add SelectionEngine facade stub"
```

### Task 6: Service protocols + Noop doubles

**Files:**
- Create: `apps/photo-curator/Services/ServiceProtocols.swift`

**Interfaces:**
- Consumes: `PhotoAsset` (Task 2), `AnalysisInput`/`PhotoAnalysis` (Task 3), `SelectionError` (Task 5).
- Produces: `PhotoLibraryAuthorization`, `AnalyticsEvent`, 6 service protocols (Apple-framework boundary only), 6 `Noop` doubles used by `AppContainer.live()` (Task 8).

- [ ] **Step 1: Create the file with this exact content**

```swift
import CoreGraphics
import Foundation

/// Photo-library access level. Full/limited/denied flow is wired in feat-002INT.
enum PhotoLibraryAuthorization: Sendable {
    case notDetermined, limited, authorized, denied, restricted
}

/// Aggregate-only analytics event. Never carries image pixels or face data (DEC-018).
/// Typed per-event cases arrive with feat-009; G0 tracks by name.
struct AnalyticsEvent: Sendable {
    let name: String
}

/// Auth state, asset fetch, metadata map. No pixels, no scoring.
protocol PhotoLibraryService: Sendable {
    func authorizationStatus() async -> PhotoLibraryAuthorization
    func requestAuthorization() async -> PhotoLibraryAuthorization
    func fetchAssets() async throws -> [PhotoAsset]
}

/// Sized image delivery. Picks request parameters; owns cancellation via task cooperation.
protocol PhotoImageLoader: Sendable {
    func thumbnail(for id: AssetID, targetSize: CGSize) async throws -> CGImage
    func analysisImage(for id: AssetID) async throws -> CGImage
}

/// Image facts in, `PhotoAnalysis` out. No albums, no SwiftUI, no final picks.
protocol ImageAnalysisService: Sendable {
    func analyze(_ input: AnalysisInput) async throws -> PhotoAnalysis
}

/// Actor-isolated store of recomputable derived analysis. Original photo bytes never enter.
protocol AnalysisCache: Actor {
    func analysis(for id: AssetID) async -> PhotoAnalysis?
    func store(_ analysis: PhotoAnalysis) async
}

/// Creates a new collision-safe album from existing assets. Never modifies or deletes originals.
protocol AlbumExportService: Sendable {
    func exportAlbum(name: String, assetIDs: [AssetID]) async throws
}

/// Product-behavior logging within the approved privacy model. Stays separate from OSLog logging.
protocol AnalyticsService: Sendable {
    func track(_ event: AnalyticsEvent)
}

// MARK: - Noop doubles for AppContainer.live()

struct NoopPhotoLibrary: PhotoLibraryService {
    func authorizationStatus() async -> PhotoLibraryAuthorization {
        .denied
    }

    func requestAuthorization() async -> PhotoLibraryAuthorization {
        .denied
    }

    func fetchAssets() async throws -> [PhotoAsset] {
        []
    }
}

/// G0 Noop only: typed service errors arrive with their owning stages.
struct NoopImageLoader: PhotoImageLoader {
    func thumbnail(for id: AssetID, targetSize: CGSize) async throws -> CGImage {
        throw SelectionError.internal
    }

    func analysisImage(for id: AssetID) async throws -> CGImage {
        throw SelectionError.internal
    }
}

struct NoopImageAnalyzer: ImageAnalysisService {
    func analyze(_ input: AnalysisInput) async throws -> PhotoAnalysis {
        throw SelectionError.internal
    }
}

actor NoopAnalysisCache: AnalysisCache {
    func analysis(for id: AssetID) async -> PhotoAnalysis? {
        nil
    }

    func store(_ analysis: PhotoAnalysis) async {}
}

struct NoopAlbumExporter: AlbumExportService {
    func exportAlbum(name: String, assetIDs: [AssetID]) async throws {}
}

struct NoopAnalytics: AnalyticsService {
    func track(_ event: AnalyticsEvent) {}
}
```

- [ ] **Step 2: Run verification**

Run: `./init.sh`
Expected: build still FAILS (missing `SelectionConfiguration` — lands in Task 7). Instead run: `swiftlint lint --strict apps/photo-curator/Services/ServiceProtocols.swift`, expect `Done linting! Found 0 violations`. Fix flagged lines, re-run until clean.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Services/ServiceProtocols.swift
git commit -m "feat-001: add service protocols and Noop doubles"
```

### Task 7: AppConfiguration

**Files:**
- Create: `apps/photo-curator/Configuration/AppConfiguration.swift`

**Interfaces:**
- Consumes: nothing (standalone; unblocks Task 5/6 builds).
- Produces: `AnalysisConfiguration`, `PerformanceConfiguration`, `CacheConfiguration`, `SelectionConfiguration` (all 22 canonical keys from selection-engine §12), `AppConfiguration` + ``AppConfiguration.default``. Defaults are documented starts: selection-engine §12 (512, 90 s, 3 m/15 m, 2×), selection-rules §14/§17 (~10%, clamps 30/150 outer edges), performance §1 (batch 32, image requests 2, Vision 2, checkpoint 25 assets/10 s, progress 4 Hz), cache enabled with version key (performance §1). Untuned weights are neutral (1.0), bonuses off (0.0), cutoffs mid (0.5/0.25, reject floor below penalty floor); feat-005A/006A tune via manual QA.

- [ ] **Step 1: Create the file with this exact content**

```swift
import Foundation

/// Analysis knobs. Version bumps on incompatible Vision/reading changes (performance §5).
struct AnalysisConfiguration: Codable, Sendable {
    var analysisVersion: Int
}

/// Run budgets. Values: performance §1. Tune after profiling on the oldest supported device.
struct PerformanceConfiguration: Codable, Sendable {
    var analysisBatchSize: Int
    var maxConcurrentImageRequests: Int
    var heavyVisionConcurrency: Int
    var checkpointEveryAssets: Int
    var checkpointEverySeconds: TimeInterval
    var progressMaxHertz: Double
}

/// Derived-analysis cache policy. Holds compact values only, never image blobs (performance §5).
struct CacheConfiguration: Codable, Sendable {
    var enabled: Bool
    var schemaVersion: Int
}

/// All selection knobs in one place. Key names are canonical per selection-engine §12.
/// Policy meaning: selection-rules; mechanics: selection-engine; budgets: performance.
struct SelectionConfiguration: Codable, Sendable {
    var analysisImageMaxDimension: Int
    var duplicateTimeWindow: TimeInterval
    var duplicateSimilarityThreshold: Double
    var nearDuplicateSimilarityThreshold: Double
    var momentSoftGap: TimeInterval
    var momentHardGap: TimeInterval
    var maxPhotosPerMoment: Int
    var targetSelectionRatio: Double
    var minimumFinalCount: Int
    var maximumFinalCount: Int
    var shortlistMultiplier: Double
    var technicalQualityWeight: Double
    var humanImportanceWeight: Double
    var representativenessWeight: Double
    var uniquenessWeight: Double
    var diversityWeight: Double
    var coverageWeight: Double
    var redundancyPenaltyWeight: Double
    var favoriteBonus: Double
    var editedBonus: Double
    var lowQualityThreshold: Double
    var hardRejectThreshold: Double
}

/// Centralized knobs; scatter no constants through views or services.
struct AppConfiguration: Codable, Sendable {
    var analysis: AnalysisConfiguration
    var selection: SelectionConfiguration
    var performance: PerformanceConfiguration
    var cache: CacheConfiguration
    var configVersion: Int

    static var `default`: Self {
        Self(
            analysis: AnalysisConfiguration(analysisVersion: 1),
            selection: SelectionConfiguration(
                analysisImageMaxDimension: 512,
                duplicateTimeWindow: 90,
                duplicateSimilarityThreshold: 0.5,
                nearDuplicateSimilarityThreshold: 0.5,
                momentSoftGap: 180,
                momentHardGap: 900,
                maxPhotosPerMoment: 3,
                targetSelectionRatio: 0.10,
                minimumFinalCount: 30,
                maximumFinalCount: 150,
                shortlistMultiplier: 2.0,
                technicalQualityWeight: 1.0,
                humanImportanceWeight: 1.0,
                representativenessWeight: 1.0,
                uniquenessWeight: 1.0,
                diversityWeight: 1.0,
                coverageWeight: 1.0,
                redundancyPenaltyWeight: 1.0,
                favoriteBonus: 0.0,
                editedBonus: 0.0,
                lowQualityThreshold: 0.5,
                hardRejectThreshold: 0.25
            ),
            performance: PerformanceConfiguration(
                analysisBatchSize: 32,
                maxConcurrentImageRequests: 2,
                heavyVisionConcurrency: 2,
                checkpointEveryAssets: 25,
                checkpointEverySeconds: 10,
                progressMaxHertz: 4
            ),
            cache: CacheConfiguration(enabled: true, schemaVersion: 1),
            configVersion: 1
        )
    }
}
```

- [ ] **Step 2: Run verification**

Run: `./init.sh`
Expected: full PASS now (all types resolve) — `PASS [format]`, `PASS [lint]`, `PASS [build]`, `SKIP [test]`, `=== Verification passed ===`. If SwiftLint flags alignment in the long initializers, align the flagged lines and re-run until green.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Configuration/AppConfiguration.swift
git commit -m "feat-001: add AppConfiguration with defaults"
```

### Task 8: AppContainer

**Files:**
- Create: `apps/photo-curator/App/AppContainer.swift`

**Interfaces:**
- Consumes: all service protocols + Noops (Task 6), `SelectionEngine` (Task 5).
- Produces: `AppContainer` + `AppContainer.live()`. Note: `SessionCheckpointStore` joins in feat-002A and real DI in feat-002INT — G0 holds the other 7 arch §5 fields.

- [ ] **Step 1: Create the file with this exact content**

```swift
/// Plain dependency holder, not a framework. Holds no feature state.
/// `SessionCheckpointStore` joins in feat-002A; real DI replaces Noops in feat-002INT.
struct AppContainer: Sendable {
    let photoLibrary: any PhotoLibraryService
    let imageLoader: any PhotoImageLoader
    let analyzer: any ImageAnalysisService
    let analysisCache: any AnalysisCache
    let selectionEngine: SelectionEngine
    let exporter: any AlbumExportService
    let analytics: any AnalyticsService

    /// G0 wiring: Noop doubles so lanes A and B link without waiting for each other.
    static func live() -> Self {
        Self(
            photoLibrary: NoopPhotoLibrary(),
            imageLoader: NoopImageLoader(),
            analyzer: NoopImageAnalyzer(),
            analysisCache: NoopAnalysisCache(),
            selectionEngine: SelectionEngine(),
            exporter: NoopAlbumExporter(),
            analytics: NoopAnalytics()
        )
    }
}
```

- [ ] **Step 2: Run verification**

Run: `./init.sh`
Expected: full PASS. Additionally confirm zero `fatalError` in new code: `grep -rn "fatalError" apps/photo-curator/Domain apps/photo-curator/Services apps/photo-curator/Configuration apps/photo-curator/App` must print nothing.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/App/AppContainer.swift
git commit -m "feat-001: add AppContainer live wiring"
```

### Task 9: Rename sweep + decision-log note

**Files:**
- Modify: `README.md:52`, `docs/design-docs/ios-architecture.md:68,105,106,126` (`PhotosCurator` → `PhotoCurator`; target/scheme/`.xcodeproj` untouched).
- Modify: `docs/design-docs/decision-log.md` (status table + new entry, append-only).

**Interfaces:**
- Consumes: nothing.
- Produces: zero stray `PhotosCurator` outside this record; DEC-028 rationale entry.

- [ ] **Step 1: Apply these exact replacements**

`README.md:52`: `├── App/                 PhotosCuratorApp, AppContainer, AppModel, AppRoute` → `├── App/                 PhotoCuratorApp, AppContainer, AppModel, AppRoute`
`ios-architecture.md:68`: `` `PhotosCuratorApp` builds `` → `` `PhotoCuratorApp` builds ``
`ios-architecture.md:105`: `PhotosCurator/` → `PhotoCurator/`
`ios-architecture.md:106`: `├── App/            PhotosCuratorApp,` → `├── App/            PhotoCuratorApp,`
`ios-architecture.md:126`: `struct PhotosCuratorApp: App {` → `struct PhotoCuratorApp: App {`

- [ ] **Step 2: Append DEC-028 (status table row after the DEC-027 row, entry after the DEC-027 block)**

Table row: `| DEC-028 | G0 contract naming | 05 |`

Entry text:

```text
**DEC-028 — G0 contract naming (Accepted).**
Keep `PhotoCuratorApp` (matches Xcode target); canonical model `PhotoAsset` (drop `PhotoAssetRecord`
at G0); engine file `SelectionEngine.swift` holds concrete `SelectionEngine` (no protocol per DEC-015).
Owner: 05. Affected: feature_index owns, 05. Risk: later stages extend contracts via leader review only.
Reconsider when: a stage needs a name the contract cannot express.
```

- [ ] **Step 3: Run verification**

Run: `./init.sh` (docs-only change: expect PASS), then:
`grep -rn "PhotosCurator" README.md docs apps --include="*.md" --include="*.swift" | grep -v "features/feat-001.md" | grep -v ".xcodeproj"`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/design-docs/ios-architecture.md docs/design-docs/decision-log.md
git commit -m "feat-001: rename PhotosCurator to PhotoCurator, add DEC-028"
```

### Task 10: A/B import check + evidence

**Files:**
- Create then delete: `apps/photo-curator/Domain/__ContractCheckA.swift`, `apps/photo-curator/App/__ContractCheckB.swift`
- Modify: `features/feat-001.md` (Handoff Evidence)

**Interfaces:**
- Consumes: `AppContainer.live()` (Task 8), `SelectionEngine` (Task 5).
- Produces: proof both lanes link against the frozen contract with no contract edits.

- [ ] **Step 1: Create the two temp check files**

`apps/photo-curator/Domain/__ContractCheckA.swift`:

```swift
import Foundation

func __contractCheckA() {
    let container = AppContainer.live()
    let configuration = AppConfiguration.default
    _ = (container, configuration)
}
```

`apps/photo-curator/App/__ContractCheckB.swift`:

```swift
import Foundation

func __contractCheckB() {
    let engine = AppContainer.live().selectionEngine
    _ = engine
}
```

- [ ] **Step 2: Run verification, then delete the temp files and re-verify**

Run: `./init.sh` (expect full PASS with temp files present). Then:

```bash
rm apps/photo-curator/Domain/__ContractCheckA.swift apps/photo-curator/App/__ContractCheckB.swift
```

Run: `./init.sh` (expect full PASS again).

- [ ] **Step 3: Record evidence and commit**

Set Handoff in this file to: State `active` (unchanged), Evidence `./init.sh PASS (BUILD SUCCEEDED, SKIP [test]) + A/B temp import check green, temp files removed`, Next `open PR joint/feat-001 → int/G0`.

```bash
git add features/feat-001.md
git commit -m "feat-001: record G0 verification evidence"
```

## Verify

- `./init.sh`

## Handoff

- State: active
- Evidence: —
- Blockers: none
- Next: Execute Plan Tasks 1–10, then open PR `joint/feat-001` → `int/G0`.

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
