# Incremental Library Analysis Lifecycle Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Activation requires user approval after feat-040.

**Goal:** Enrich library assets without an album-selection run or blocking browsing.

**Architecture:** Adapt the bounded image-analysis pipeline behind a catalog job coordinator. Publish revisioned capability results and resume only invalid/missing work.

**Tech Stack:** Swift concurrency, Vision, PhotoKit, SwiftData catalog projections, file checkpoints.

## Global constraints

- iPhone 14+ / iOS 26+, on-device, English/Vietnamese UI.
- Follow [performance bounds](../ship-gates/performance.md); do not promise continuous suspended execution.
- Run `./init.sh`; no tests/proof harnesses. Manual QA is not a gate.

## Inputs and outputs

Consumes feat-040 catalog snapshots, `PhotoImageLoader`, `ImageAnalysisService`, and revision-aware `AnalysisCache`.
Produces per-capability evidence/status updates and job checkpoints for grouping and labeling.
It does not produce mandatory album picks or mutate saved choices.

## Files and tasks

### 1. Separate jobs from selections

Existing: `apps/photo-curator/Services/Photos/BatchPipeline.swift`, `Services/Session/SelectionSessionCoordinator.swift`, `Services/ServiceProtocols.swift`.
Proposed new: `apps/photo-curator/Services/Library/LibraryAnalysisCoordinator.swift`.

- [ ] Extract the reusable analysis lifecycle without invoking album sizing, diversity selection, or final album building.
- [ ] Retain session compatibility entry points while catalog jobs use asset/capability revisions.
- [ ] Establish bounded queues with visible-photo requests taking priority over enrichment.

### 2. Persist safe progress

Existing: `apps/photo-curator/Infrastructure/FileAnalysisCache.swift`, `SessionCheckpointStore.swift`.
Proposed new: `apps/photo-curator/Infrastructure/LibraryAnalysisCheckpointStore.swift`.

- [ ] Check asset and provider revisions before reuse and before result commit.
- [ ] Requeue stale or missing cache work even when old counters report completion.
- [ ] Preserve explicit unavailable reasons and distinguish completed empty output from failed capability output.
- [ ] Publish progress only after the corresponding result/checkpoint boundary is safe.

### 3. Integrate lifecycle

Existing: `apps/photo-curator/App/AppContainer.swift`, `AppModel.swift`, `PhotoCuratorApp.swift`, `Infrastructure/MemoryPressureObserver.swift`.

- [ ] Coalesce library changes and invalidate obsolete generations.
- [ ] Pause/cancel at safe boundaries, drain structured tasks, and reject late publications.
- [ ] Resume on app execution opportunity with explicit status; expose iCloud waiting and retry separately.
- [ ] Provide capability coverage to feat-043 without a full-result barrier.

## Verification

Run baseline/final `./init.sh` and `git diff --check`.
Inspect cancellation before/after load, revision changes during inference, cache loss, interrupted checkpoint, access revocation, and unavailable retry paths.
Record actual evidence and limits without adding a proof program.

## Rollback and handoff

Pause the new scheduler while retaining completed evidence and user state.
The previous session reader remains usable for saved work.
Document coordinator inputs, status publication, and revision rejection for feat-042/044.
