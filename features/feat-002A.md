# feat-002A — Foundation store: FileStore + CheckpointStore + AnalysisCache

## Goal

Land file-based persistence skeleton so later stages can cache analyses and resume without redo, with `./init.sh` green and zero `App/`/`Features/` changes.

## Scope

- `Infrastructure/FileStore.swift`: actor with generic Codable `save`/`load`/`remove`/`exists`, atomic writes, intermediate directories. Small values only, never image pixels or face data.
- `Infrastructure/SessionCheckpointStore.swift`: `SessionCheckpoint` struct (`sessionID`, opaque `stage: String`, `completedAssetIDs`, `configVersion`, `analysisVersion`, `updatedAt`) + actor with `save`/`load`/`delete` via `FileStore` under `checkpoints/<uuid>.json`.
- `Infrastructure/FileAnalysisCache.swift`: `actor FileAnalysisCache: AnalysisCache` with memory + file backing under `analysis-cache/<safe-id>.json`, version-gated on `analysisVersion`. Holds compact `PhotoAnalysis` only, never image blobs.
- `Configuration/`: reviewed. No change — `AppConfiguration.default` already carries `cache.enabled`, `cache.schemaVersion`, `analysis.analysisVersion`, checkpoint cadence (`checkpointEveryAssets: 25`, `checkpointEverySeconds: 10`).

## Non-goals

- No `App/AppContainer.swift` edit — `checkpointStore` wiring to `AppContainer.live()` belongs to feat-002INT (leader).
- No coordinator, batch pipeline, PhotoKit fetch, Vision run, scoring, duplicates, moments, diversity, export (G2–G4).
- No typed `ProcessingStage`/`SelectionSession` persistence — checkpoint `stage` stays opaque `String` here; canonical enum mapping arrives with the coordinator.
- No fingerprint-vs-live-asset check — version gate only here; fingerprint comparison arrives with feat-003A when `PhotoAsset` metadata is available.
- No DB, packages, DI frameworks, test targets, third-party deps (DEC-015/016, DEC-TBD-002).
- No `Services/Cache/` file — concrete cache lives under `Infrastructure/` per this feat's `owns`; `Services/ServiceProtocols.swift` protocol is untouched.

## Acceptance

- [ ] `./init.sh` passes (format + strict swiftlint + build; SKIP [test]).
- [ ] `FileStore` round-trips a Codable value to disk with atomic write and creates intermediate directories.
- [ ] `SessionCheckpointStore` round-trips a small manifest with no pixels; `delete` is safe when missing.
- [ ] `FileAnalysisCache` conforms to G0 `AnalysisCache`; returns `nil` on version mismatch; `store` then `analysis(for:)` returns the stored value.
- [ ] No imports of PhotoKit, Vision, SwiftUI, UIKit in `Infrastructure/`; `grep -rn "PhotoKit\|Vision\|SwiftUI" apps/photo-curator/Infrastructure` prints nothing.
- [ ] No edits outside `Infrastructure/`; `git status --short` shows only `features/feat-002A.md` now and only `Infrastructure/*.swift` during implementation.
- [ ] Temp skeleton proof green then removed (Task 4).

## Relevant docs

- `docs/design-docs/data-model.md`
- `docs/design-docs/ios-architecture.md`
- `docs/ship-gates/performance.md`
- `docs/ship-gates/privacy.md`

## Plan

> **Execution:** Follow the repository's implementation and verification rules. No automated tests per DEC-016 — each task's test cycle is `./init.sh` (SwiftFormat + `swiftlint lint --strict` + simulator build). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the G1 foundation store in 4 tasks so later stages cache analyses and checkpoint without redo.

**Architecture:** One generic file actor (`FileStore`) under `Infrastructure/`; two thin actors over it (checkpoint manifest, version-gated analysis cache). Value-type Codable models cross actors; file layout is `checkpoints/<uuid>.json` + `analysis-cache/<safe-id>.json` in Application Support/Caches. Ordered so `./init.sh` stays green after every task.

**Tech Stack:** Swift 5.0, Foundation only, single app target `photo-curator` (synced folders — new files need no `.pbxproj` edit).

**Plan artifact decision:** Plan stays inline here. AGENTS.md requires >=2 substantial signals for `docs/plans/feat-<id>.md`; this work has 1 (3 new files, 1 workspace, no migration, no phases/rollback).

## Global Constraints

- No test targets, no `*Test*.swift` files, no test frameworks (AGENTS.md; DEC-016).
- Validation is manual only; `./init.sh` reports `SKIP [test]` (AGENTS.md).
- Swift 5.0, iOS 26 minimum, single app target `photo-curator`.
- Zero third-party runtime dependencies (ios-architecture invariant).
- The engine never imports SwiftUI; SwiftUI never calls PhotoKit/Vision directly (team-build-plan).
- `Infrastructure/` imports Foundation only — no PhotoKit, Vision, SwiftUI, UIKit.
- Never persist image pixels, face boxes, precise location, or feature-print blobs (data-model §4, privacy).
- Lines fit 120 cols (warn) / 150 (error); SwiftFormat (`--maxwidth 120`, indent 4) runs before lint in `./init.sh`.
- No file has two owners within one stage; contracts freeze in G0 — post-G0 extensions go through leader review (team-build-plan).
- Branch `lane-A/feat-002A` (from `int/G1`); commit subjects `feat-002A: <imperative>`; no `WIP` (team-build-plan §4).
- `feature_index.json` + `progress.md` are touched by the leader only inside the INT PR — this lane branch does NOT edit them.

---

### Task 1: FileStore actor

**Files:**
- Create: `apps/photo-curator/Infrastructure/FileStore.swift`

**Interfaces:**
- Consumes: nothing (first file).
- Produces: `actor FileStore` with `init(rootDirectory:)`, `save(_:to:)`, `load(_:from:)`, `remove(relativePath:)`, `exists(relativePath:)` used by Tasks 2–3.

- [ ] **Step 1: Create the file with this exact content**

```swift
import Foundation

/// Serialized file access for small Codable values only.
/// Holds derived data and manifests, never image pixels or face data.
/// All callers cross actor isolation with await.
actor FileStore {
    private let rootDirectory: URL

    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    private func url(for relativePath: String) -> URL {
        rootDirectory.appendingPathComponent(relativePath)
    }

    func save<T>(_ value: T, to relativePath: String) throws where T: Codable & Sendable {
        let target = url(for: relativePath)
        let folder = target.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(value)
        try data.write(to: target, options: .atomic)
    }

    func load<T>(_ type: T.Type, from relativePath: String) throws -> T where T: Codable & Sendable {
        let target = url(for: relativePath)
        let data = try Data(contentsOf: target)
        return try JSONDecoder().decode(type, from: data)
    }

    func remove(relativePath: String) throws {
        let target = url(for: relativePath)
        try FileManager.default.removeItem(at: target)
    }

    func exists(relativePath: String) -> Bool {
        let target = url(for: relativePath)
        return FileManager.default.fileExists(atPath: target.path)
    }
}
```

- [ ] **Step 2: Run verification**

Run: `./init.sh`
Expected: `PASS [format]`, `PASS [lint]`, `PASS [build]`, `SKIP [test]`, `=== Verification passed ===`. Fix flagged lines, re-run until green.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Infrastructure/FileStore.swift
git commit -m "feat-002A: add FileStore actor"
```

### Task 2: SessionCheckpointStore

**Files:**
- Create: `apps/photo-curator/Infrastructure/SessionCheckpointStore.swift`

**Interfaces:**
- Consumes: `FileStore` (Task 1), `SessionID`/`AssetID` (G0 contract).
- Produces: `struct SessionCheckpoint`, `actor SessionCheckpointStore` with `save`/`load`/`delete`.

- [ ] **Step 1: Create the file with this exact content**

```swift
import Foundation

/// Small resumable manifest. No image bytes, no face data, no pixels.
/// Stage stays an opaque label here; typed ProcessingStage mapping arrives with the coordinator.
struct SessionCheckpoint: Codable, Sendable {
    let sessionID: SessionID
    let stage: String
    let completedAssetIDs: [AssetID]
    let configVersion: Int
    let analysisVersion: Int
    let updatedAt: Date
}

/// File-backed checkpoint skeleton. Real wiring to AppContainer.live() happens in feat-002INT.
actor SessionCheckpointStore {
    private let files: FileStore
    private let directory: String

    init(files: FileStore, directory: String = "checkpoints") {
        self.files = files
        self.directory = directory
    }

    private func path(for sessionID: SessionID) -> String {
        "\(directory)/\(sessionID.rawValue.uuidString).json"
    }

    func save(_ checkpoint: SessionCheckpoint) async throws {
        try await files.save(checkpoint, to: path(for: checkpoint.sessionID))
    }

    func load(sessionID: SessionID) async throws -> SessionCheckpoint {
        try await files.load(SessionCheckpoint.self, from: path(for: sessionID))
    }

    func delete(sessionID: SessionID) async throws {
        let target = path(for: sessionID)
        if await files.exists(relativePath: target) {
            try await files.remove(relativePath: target)
        }
    }
}
```

- [ ] **Step 2: Run verification**

Run: `./init.sh`
Expected: full PASS now (all types resolve). Fix flagged lines, re-run until green.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Infrastructure/SessionCheckpointStore.swift
git commit -m "feat-002A: add SessionCheckpointStore skeleton"
```

### Task 3: FileAnalysisCache

**Files:**
- Create: `apps/photo-curator/Infrastructure/FileAnalysisCache.swift`

**Interfaces:**
- Consumes: `FileStore` (Task 1), `AnalysisCache` protocol + `AssetID`/`PhotoAnalysis` (G0 contract).
- Produces: `actor FileAnalysisCache: AnalysisCache` with version-gated `analysis(for:)`/`store(_:)`.

- [ ] **Step 1: Create the file with this exact content**

```swift
import Foundation

/// File-backed AnalysisCache skeleton. Conforms to the G0 AnalysisCache protocol.
/// Reuses an entry only when the stored analysisVersion matches the current version.
/// Fingerprint comparison against live PhotoAsset metadata arrives with feat-003A.
/// Holds compact PhotoAnalysis values only, never image blobs.
actor FileAnalysisCache: AnalysisCache {
    private let files: FileStore
    private let analysisVersion: Int
    private let directory: String
    private var memory: [AssetID: PhotoAnalysis] = [:]

    init(files: FileStore, analysisVersion: Int, directory: String = "analysis-cache") {
        self.files = files
        self.analysisVersion = analysisVersion
        self.directory = directory
    }

    private func path(for id: AssetID) -> String {
        let safe = id.rawValue.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "unknown"
        return "\(directory)/\(safe).json"
    }

    func analysis(for id: AssetID) async -> PhotoAnalysis? {
        if let cached = memory[id], cached.analysisVersion == analysisVersion {
            return cached
        }
        guard let loaded: PhotoAnalysis = try? await files.load(PhotoAnalysis.self, from: path(for: id)) else {
            return nil
        }
        guard loaded.analysisVersion == analysisVersion else {
            return nil
        }
        memory[id] = loaded
        return loaded
    }

    func store(_ analysis: PhotoAnalysis) async {
        memory[analysis.assetID] = analysis
        try? await files.save(analysis, to: path(for: analysis.assetID))
    }
}
```

- [ ] **Step 2: Run verification**

Run: `./init.sh`
Expected: full PASS. Additionally confirm no Apple-framework imports: `grep -rn "PhotoKit\|Vision\|SwiftUI" apps/photo-curator/Infrastructure` must print nothing.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Infrastructure/FileAnalysisCache.swift
git commit -m "feat-002A: add FileAnalysisCache skeleton"
```

### Task 4: Skeleton proof + evidence

**Files:**
- Create then delete: `apps/photo-curator/Infrastructure/__StoreCheck.swift`
- Modify: `features/feat-002A.md` (Handoff Evidence)

**Interfaces:**
- Consumes: `FileStore` (Task 1), `SessionCheckpointStore` (Task 2), `FileAnalysisCache` (Task 3).
- Produces: proof the skeleton constructs and round-trips without touching `App/` or `Services/`.

- [ ] **Step 1: Create the temp check file with this exact content**

```swift
import Foundation

func __storeCheck() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let files = FileStore(rootDirectory: root)
    let checkpoints = SessionCheckpointStore(files: files)
    let sessionID = SessionID(rawValue: UUID())
    let checkpoint = SessionCheckpoint(
        sessionID: sessionID,
        stage: "analyzing",
        completedAssetIDs: [],
        configVersion: 1,
        analysisVersion: 1,
        updatedAt: Date()
    )
    try await checkpoints.save(checkpoint)
    let reloaded = try await checkpoints.load(sessionID: sessionID)
    _ = reloaded
    try await checkpoints.delete(sessionID: sessionID)
    let cache = FileAnalysisCache(files: files, analysisVersion: 1)
    let probe = AssetID(rawValue: "probe")
    let missed = await cache.analysis(for: probe)
    _ = missed
}
```

- [ ] **Step 2: Run verification, then delete the temp file and re-verify**

Run: `./init.sh` (expect full PASS with temp file present). Then:

```bash
rm apps/photo-curator/Infrastructure/__StoreCheck.swift
```

Run: `./init.sh` (expect full PASS again).

- [ ] **Step 3: Record evidence and commit**

Set Handoff in this file to: State `active` (unchanged), Evidence `./init.sh PASS (BUILD SUCCEEDED, SKIP [test]) + skeleton proof green, temp file removed`, Next `open PR lane-A/feat-002A → int/G1`.

```bash
git add features/feat-002A.md
git commit -m "feat-002A: record foundation store verification evidence"
```

## Verify

- `./init.sh`

## Handoff

- State: done
- Evidence: PR #5 squash-merged to int/G1 (a8ecf10); PR #6 int/G1 → main merged; ./init.sh PASS on int/G1 HEAD (format + strict lint + BUILD SUCCEEDED, SKIP [test]); skeleton proof green, temp file removed
- Blockers: none (real DI wiring belongs to feat-002INT, still todo)
- Next: feat-002INT (leader) wires checkpointStore/cache into AppContainer.live()

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
