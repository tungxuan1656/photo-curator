# Per-photo Analysis Transparency Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a comparable local Technical score in every Review grid and a complete, truthful per-photo analysis screen.

**Architecture:** `ReviewModel` receives the existing `AnalysisCache`, deduplicates lazy cache reads, and exposes immutable decision data plus visible analysis facts. A compact `ReviewScoreBadge` consumes one loaded analysis. `PhotoAnalysisDetail` consumes the model data and shows its own bounded thumbnail. The feature never changes the selector, cache schema, or PhotoKit/Vision contracts.

**Tech Stack:** Swift 5, SwiftUI, Observation, existing `AnalysisCache`, PhotoKit-backed `AsyncPhotoThumbnail`.

## Global Constraints

- Keep one active feature. `feat-016` follows completed `feat-015`.
- Keep selection logic and persisted shapes unchanged.
- Load analysis only when a review cell or S21 is visible.
- Use `Button` or `NavigationLink` for every action. Do not use a score badge as a tap target.
- Label a missing value as unavailable or not analyzed. Never substitute zero.
- Use numeric labels as well as meters. Color is supplementary only.
- Do not show face boxes, names, locations, embeddings, full EXIF, or raw asset IDs.
- Do not add test targets or test files. Verify manually and with `./init.sh`.
- SwiftUI never calls PhotoKit or Vision directly. `Infrastructure/` remains Foundation-only.

---

## File structure

- Modify `docs/product-specs/ux-flows.md` — make S21 and score disclosure durable product behavior.
- Modify `apps/photo-curator/App/AppModel+Save.swift` — inject `container.analysisCache` into each `ReviewModel`.
- Modify `apps/photo-curator/Features/Review/ReviewModel.swift` — cache visible analysis reads and translate stored decisions.
- Create `apps/photo-curator/Features/Review/ReviewScoreBadge.swift` — display one Technical score with a non-color meter.
- Create `apps/photo-curator/Features/Review/PhotoAnalysisDetail.swift` — render S21.
- Modify `apps/photo-curator/Features/Review/PhotoDetail.swift` — link S11 to S21.
- Modify `apps/photo-curator/Features/Review/CuratedGrid.swift`, `SimilarGroups.swift`, and `RemovedPhotos.swift` — attach lazy score badges to every Review thumbnail.

### Task 1: Add lazy analysis data to ReviewModel

**Files:**

- Modify: `apps/photo-curator/App/AppModel+Save.swift`
- Modify: `apps/photo-curator/Features/Review/ReviewModel.swift`

**Interfaces:**

- Consumes: `AnalysisCache.analysis(for:)`, `SelectionResult.decisions`, and existing `ReviewModel` session ownership.
- Produces: `func loadAnalysis(for id: AssetID) async -> PhotoAnalysis?` and `func decision(for id: AssetID) -> Decision?`.

- [x] Pass `container.analysisCache` into the new `ReviewModel` initializer.
- [x] Build a decision dictionary once in `ReviewModel.init`.
- [x] Keep ignored in-memory analysis values, missing IDs, and in-flight reads.
- [x] Share one actor read between visible callers. Store a value only for the requested asset ID.
- [x] Remember a missing cache row so scrolling does not repeatedly probe disk.
- [x] Run `swiftlint lint --strict apps/photo-curator/App/AppModel+Save.swift apps/photo-curator/Features/Review/ReviewModel.swift`.

### Task 2: Add the compact score badge to every Review grid

**Files:**

- Create: `apps/photo-curator/Features/Review/ReviewScoreBadge.swift`
- Modify: `apps/photo-curator/Features/Review/CuratedGrid.swift`
- Modify: `apps/photo-curator/Features/Review/SimilarGroups.swift`
- Modify: `apps/photo-curator/Features/Review/RemovedPhotos.swift`

**Interfaces:**

- Consumes: `PhotoAnalysis.qualityScore` and `ReviewModel.loadAnalysis(for:)`.
- Produces: `ReviewScoreBadge(assetID:model:)`, with fixed-height loading and unavailable states.

- [x] Define `ReviewScoreBadge` with a 0–100 number, a linear meter, and a VoiceOver label.
- [x] Keep a fixed footer height for loaded, loading, and unavailable cells.
- [x] Load each cell's analysis with `.task(id:)`, after the cell is visible.
- [x] Keep each `ForEach` identity as `AssetID` and preserve current thumbnail and selection controls.
- [x] Use the same badge in S10, S12, and S13.
- [x] Run SwiftLint on the four changed Review files.

### Task 3: Add S21 and the S11 entry point

**Files:**

- Create: `apps/photo-curator/Features/Review/PhotoAnalysisDetail.swift`
- Modify: `apps/photo-curator/Features/Review/PhotoDetail.swift`

**Interfaces:**

- Consumes: `ReviewModel.loadAnalysis(for:)`, `ReviewModel.decision(for:)`, `ReviewModel.isSelected(_:)`, and `AsyncPhotoThumbnail`.
- Produces: `PhotoAnalysisDetail(assetID:sessionID:)` reached from **View Analysis** in S11.

- [x] Add a `NavigationLink` in S11 that keeps the current pager and selection behavior unchanged.
- [x] In S21, trigger the same lazy model load while the screen is visible.
- [x] Render a bounded thumbnail, Technical score, technical signals, available people/composition/content facts, and original decision reasons.
- [x] Translate known reason codes to concise user-facing text. Render unknown codes as unavailable metadata, not raw internal strings.
- [x] Show current selection separately from the original automatic result.
- [x] Render an explicit unavailable state without a processing retry action.
- [x] Use Dynamic Type system styles and grouped accessibility labels for every score row.
- [x] Run SwiftLint on `PhotoDetail.swift` and `PhotoAnalysisDetail.swift`.

### Task 4: Verify behavior and close the feature

**Files:**

- Modify: `features/feat-016.md`
- Modify: `progress.md`

- [x] Run `./init.sh`.
- [x] Perform a simulator smoke: launch the app and confirm it does not crash.
- [x] Manually verify on a review result: S10 and S13 pass (score footer, S11 -> S21, current versus original state); S12 and the missing-analysis state user-verified 2026-09-16.
- [x] Record the commands and observable manual result in the feature handoff and `progress.md`.
