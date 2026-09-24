# Incremental Library Analysis Lifecycle Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules.

**Goal:** Enrich library assets without an album-selection run or blocking browsing.

**Architecture:** Adapt the bounded image-analysis pipeline behind an actor-isolated catalog job coordinator. Publish one revisioned `nativeImageFacts` capability and resume only invalid/missing work.

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
- [ ] Define the minimal capability contract as `nativeImageFacts` with asset-fingerprint, analysis, and provider/runtime revisions.
- [ ] Retain session compatibility entry points while catalog jobs use asset/capability revisions and the same shared two-permit `ImageWorkArbiter`.
- [ ] Establish bounded queues with visible-photo requests taking priority over session and enrichment work.

### 2. Persist safe progress

Existing: `apps/photo-curator/Infrastructure/FileAnalysisCache.swift`, `SessionCheckpointStore.swift`.
Proposed new: `apps/photo-curator/Infrastructure/LibraryAnalysisCheckpointStore.swift`.

- [ ] Add the additive V4 per-asset/capability work-state record without moving evidence facts into SwiftData.
- [ ] Treat the evidence file as authoritative; use SwiftData for current status and a checkpoint only as a resume hint.
- [ ] Check asset, analysis, and provider/runtime revisions before reuse and before result commit.
- [ ] Commit in order: durable evidence → guarded catalog commit → publish → durable reconciliation checkpoint.
- [ ] Requeue stale or missing cache work even when old counters report completion.
- [ ] Preserve typed unavailable/retry reasons and distinguish completed empty output from failed capability output.
- [ ] Publish progress only after the corresponding result/checkpoint boundary is safe.

### 3. Integrate lifecycle

Existing: `apps/photo-curator/App/AppContainer.swift`, `AppModel.swift`, `PhotoCuratorApp.swift`, `Infrastructure/MemoryPressureObserver.swift`.

- [ ] Coalesce library changes and invalidate obsolete generations through a durable reconciliation handoff.
- [ ] Keep generation, fingerprint, revision, and commit guards actor-isolated; reject late publications.
- [ ] Use a run token: new runs invalidate older work, cancellation drains tasks before terminal publication, and reset invalidates the token and clears resumable work safely.
- [ ] Pause/cancel at safe boundaries and share the two-permit `ImageWorkArbiter` across session, enrichment, and visible image work.
- [ ] Resume on app execution opportunity with explicit status; expose typed iCloud waiting, access, model, and transient retry reasons separately.
- [ ] Provide capability coverage to feat-043 without a full-result barrier.

## Verification

Run baseline/final `./init.sh` and `git diff --check`.
Inspect cancellation before/after load, revision changes during inference, cache loss, interrupted durable handoff, access revocation, run-token reset, arbiter contention, and typed unavailable/retry paths.
Record actual evidence and limits without adding a proof program.

## Rollback and handoff

Pause the new scheduler while retaining completed evidence, current work state, durable reconciliation handoff, and user state.
The previous session reader remains usable for saved work.
Document coordinator inputs, ordered evidence/status/checkpoint publication, run-token invariants, arbiter ownership, and revision rejection for feat-042/044.
