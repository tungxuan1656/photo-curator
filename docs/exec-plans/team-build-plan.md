# Team Build Plan (execution owner)

**Responsibility:** This file owns team execution only: stages G0–G6, lane A/B/INT ownership, file ownership, `feature_index.json` shape, git workflow, stage gates.
**Not owned here:** product scope (`product-specs/product.md`), UX (`product-specs/ux-flows.md`), selection policy (`product-specs/selection-rules.md`), pipeline mechanics (`design-docs/selection-engine.md`), budgets (`ship-gates/performance.md`), privacy rules (`ship-gates/privacy.md`), QA method (`ship-gates/manual-qa.md`), events (`ship-gates/analytics.md`). This file links to them, never copies them.

Related: `roadmap.md` owns P0–P8 order. This file owns who builds what and how lanes merge.

---

## 1. Team

| Role | Owns files | Owns work | Must not touch |
|---|---|---|---|
| Leader | `feature_index.json`, `progress.md`, `int/*` branches, all `*INT` feats | G0 contract review, all INT merges, gates, conflict resolution, release tag | Lane logic except INT |
| Dev-A (Engine) | `Domain/`, `Services/`, `Infrastructure/`, `Configuration/` | Fetch, loader, Vision, batch, dups, moments, scoring, diversity, export logic, perf/memory | `App/`, `Features/` (except INT review) |
| Dev-B (Flow) | `App/`, `Features/`, `SharedUI/`, `Resources/` | Screens S01–S20, navigation, progress UI, review, save UI, copy, accessibility | `Domain/`, `Services/` (except INT review) |

Rules:

* SwiftUI never calls PhotoKit/Vision directly. The engine never imports SwiftUI.
* No file has two owners within one stage. Shared contracts freeze in G0.
* UI runs on mocks until INT. The engine runs on logs and datasets until INT.

---

## 2. Stages (sequential) with parallel lanes inside

A later stage starts only after the previous stage is `done`. Within one stage, lanes A and B run in parallel.

### G0 — Contract (joint, one implements + one reviews)

* **feat-001:** IDs, `PhotoAsset` stub, service protocols, `SelectionEngine.select()` signature, `SelectionConfiguration`, `AppContainer` skeleton.
* Gate: protocols compile; lanes A and B can build without waiting for each other.

### G1 — Foundation

* **feat-002A (A):** `Infrastructure/FileStore.swift`, `SessionCheckpointStore.swift`, `Services/Cache/AnalysisCache.swift`, config.
* **feat-002B (B):** S02/S03/S19/S04 plus `AppModel`, `AppRoute`, `Info.plist`, privacy manifest base.
* **feat-002INT (leader):** wire `AppContainer.live()`. Gate: real permission flow for full/limited/denied.

### G2 — Input path

* **feat-003A (A):** `PhotoLibraryService.swift`, `ImageLoaderService.swift` (fetch, metadata, thumbs 200–500px, analysis image 512px, two-stage iCloud fetch, cancellation).
* **feat-003B (B):** `Features/SourceSelection/*`, `SharedUI/AsyncPhotoThumbnail.swift` (S05/S06, 50 mock assets).
* **feat-003INT:** replace mock source with real fetch. Gate: 1k local assets load.

### G3 — Analysis

* **feat-004A (A):** `VisionAnalysisService.swift`, `PhotoAnalysis.swift`, batch pipeline (batch size 32, Vision concurrency 2–4, checkpoint every ~25 assets or 10s).
* **feat-004B (B):** `Features/Processing/*` (S07/S08 on fake progress), settings skeleton.
* **feat-004INT:** fake progress becomes the real coordinator. Gate: every asset has versioned `PhotoAnalysis`.

### G4 — Engine plus review mocks (most critical stage)

* **feat-005A (A):** `DuplicateResolver.swift`, `MomentBuilder.swift`.
* **feat-005B (B):** `ReviewOverview`, `CuratedGrid`, `PhotoDetail` on a mock `SelectionResult` (S09/S10/S11).
* **feat-006A (A):** `QualityScorer`, `DiversitySelector`, `FinalAlbumBuilder` (tiers, greedy fill, sizing ~10% clamped to 30–40/120–150, reason codes, verify plus chronological order).
* **feat-006B (B):** `SimilarGroups`, `RemovedPhotos`, `FinalReview` mocks (S12/S13/S14).
* Lane B needs only the G0 contract, not the finished lane A. Gate: sensible engine output on dataset B/Golden; review flow operable on mocks.

### G5 — Integration plus save (converge, one owner)

* **feat-007INT (leader):** lane A keeps `AlbumExportService.swift`; lane B keeps real `FinalReview/Saving/Completion/Resume` (S14–S17, collision-safe album, retry of remaining assets without duplicates, resume without redo).
* Gate: a real user can pick, process, review, fix, and save without developer help.

### G6 — Ship gates

* **feat-008A (A):** interruption and resume, memory pressure drops concurrency to 1, RSS ≤350/500MB, 1k assets ≤5min, OSLog plus signposts.
* **feat-008B (B):** log redaction, retention plus Reset Analysis, calm copy, accessibility, S18 plus S20, privacy AC-01..12.
* **feat-009 (joint):** datasets A–H plus Golden, release blockers per `manual-qa.md` §7.3, 13 analytics events only when a provider is selected (DEC-TBD-003).

Allowed fast-track: 005B/006B may start as early as G2 because they need only mocks. But 007INT still waits for both 006A and 006B.

Deferred: P7 taste learning, P8 story albums, backend and accounts, paywall, test targets (`*Test*.swift` forbidden; manual QA only).

---

## 3. `feature_index.json` shape

`feature_index.json` is the index plus dependencies plus ownership; it never copies scope. Detail lives in `features/feat-<id>.md`.

```json
{
  "_harness": {"skill": "harness-slim", "version": "1.4.0"},
  "rule": "1 active / lane, 1 INT owner / stage",
  "features": [
    {"id": "feat-001", "stage": "G0", "lane": "joint", "owner": "leader",
     "title": "Contract + shell", "status": "todo",
     "depends_on": [], "owns": ["Domain/Models/", "Services/ServiceProtocols.swift"],
     "gate": "protocols compile"}
  ]
}
```

* `status`: `todo` / `active` / `blocked` / `done` only.
* `depends_on`: a feat becomes `active` only after its dependencies are `done`.
* Within one stage, two `active` feats (A+B) are allowed when `owns` does not overlap. This is a controlled exception to the one-active rule, approved by the leader.
* `INT` is a real feat: mocks removed, real flow runs on dataset A, `./init.sh` passes.

---

## 4. Git workflow

```
main (always ./init.sh pass)
  └── int/G1 ── lane-A/feat-002A
            └─ lane-B/feat-002B
```

* `main`: accepts merges from `int/*` only. No direct commits or pushes.
* `int/<stage>`: one branch per stage, owned by the leader, the only place that resolves conflicts.
* `lane-*/feat-xxx`: short branch of 1–2 days, named with the exact feat ID, deleted after merge.

Lane lifecycle: create the branch from `int/<stage>` → code within `owns` → `./init.sh` passes → open a PR into `int/<stage>` (title `[feat-xxx][lane-A]`, with scope plus acceptance plus evidence) → cross review → leader merges (squash).

INT lifecycle: the leader merges each lane into local `int` → implements `*INT` (replaces mocks with real code, deletes dead mocks, connects DI, navigation, and progress) → `./init.sh` plus a dataset-A smoke run on a real iPhone → opens PR `int → main` (merge commit) → marks feats `done` → records one `progress.md` block for the whole stage.

Commits: `feat-005A: add DuplicateResolver window 90s`. No `WIP`, no build output or `xcuserdata`. Only the leader commits `feature_index.json` plus `progress.md`, always inside the INT PR.

Tag milestones by gate (`p1-analysis`, `p4-engine`); QA follows the tag with `manual-qa.md` §7.3. A failed gate is fixed in a later stage.

---

## 5. Verify

* Lane done: `./init.sh` (format plus strict swiftlint plus build). Tests report `SKIP [test]` by policy; validation is manual.
* INT done: `./init.sh` plus a real-device smoke run plus zero remaining mocks, `DEBUG` score views, or logged asset IDs.
* Release: full `manual-qa.md` §7.3 plus privacy AC-01..12.

## 6. Links

* Order: `roadmap.md`. Policy: `selection-rules.md`. Mechanics: `selection-engine.md`. Budgets: `performance.md`. Privacy: `privacy.md`. QA: `manual-qa.md`. Events: `analytics.md`.
