# feat-012 — Reliability + performance

## Goal

Land reliability + performance so resume works without redo within budgets. Memory pressure degrades speed (never quality) through one infrastructure observer the batch loop reads at batch boundaries; terminal transitions stay single-owner so cancel/supersede/save can never persist a false completion.

## Scope

- `Infrastructure/MemoryPressureObserver.swift` (new: warning/critical state; notification code lives here only)
- `Services/Photos/BatchPipeline.swift` (read pressure at batch boundaries: shrink work, stop preheat, checkpoint, pause at critical)
- `Features/Processing/ProcessingModel.swift` (paused-pressure state mapping; save-claim vs supersede/discard interleave)
- `Services/Session/SelectionSessionCoordinator.swift` (only if terminal-ownership needs a guard the model cannot hold)
- `App/AppContainer.swift`, `App/AppModel.swift` (only if observer lifetime needs injection; owning files stay minimal)
- `Services/Photos/ImageLoaderService.swift` (only to expose a preheat-stop hook the pipeline already implies)

## Non-goals

- Anything outside owns; privacy + polish stays in feat-013.

## Task 1: Batch reacts safely to memory pressure

- [ ] Observer posts `.warning`/`.critical`/recovered via `NotificationCenter` memory notification; SwiftUI/analysis code never observes directly.
- [ ] On warning: stop speculative preheat, release local decoded refs (scope exit, no retained images), shrink next batch toward 16 and lanes toward 1; never drop completed analysis or lower selection quality.
- [ ] On critical: finish/abandon only the current safe unit, persist the checkpoint, surface resumable paused state (`Curation Paused` + saved-progress copy, no memory vocabulary) instead of running until an OS kill.
- [ ] Defaults stay enforced: batch 32, heavy Vision 2, max large PhotoKit requests 2, progress ≤4 Hz, no unbounded task-per-asset execution.

## Task 2: Reconcile resume and terminal interleavings

- [ ] One unavailable asset never fails the job (analyzed vs unavailable counts stay separate); valid per-asset analysis survives cancellation and resume skips it via cache/version check, processing only missing/invalid IDs.
- [ ] Terminal ownership is single: completion/cancel/supersede/background-checkpoint/save-claim cannot each publish a contradictory state; cancel-vs-persist micro-race and completion-vs-supersede ordering stay checkpoint-first-then-throw.
- [ ] Save-claim vs supersede/discard: starting or discarding a session cancels an in-flight save for that session (no orphan export writing into a deleted session); `finishSave` clears only its own session claim.
- [ ] Device gates on the oldest supported device: cancel near 25% → resume without reanalyzing completed items; 1,000-photo run with usable UI/progress and no crash; 5,000-photo memory/checkpoint run before done.
- [ ] `./init.sh` passes + measurements required by `performance.md` §7 attached to the close commit.

## Acceptance

- [ ] Resume without redo; budgets per performance §1
- [ ] `./init.sh` passes

## Depends

- feat-011

## Handoff

- State: active
- Evidence: —
- Blockers: none
- Next: Task 1 (pressure observer + batch reaction).

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
