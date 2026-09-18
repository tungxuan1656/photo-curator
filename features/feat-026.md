# feat-026 — Uncertainty review and feedback

## Status

- Status: `done` (PR #55 squash-merged to `origin/main` as `2e84812f97aa7099cdb15902f1fedc218585d0fa`; feat-023 and feat-027 state recorded below)
- Depends on: `feat-023` (`done` via PR #50 `96a75a9`; verified before activation; repo idle, no other `active`)

## Goal

Expose uncertain selection decisions as clear, reviewable work and capture bounded user
feedback without changing the on-device privacy promise.

## Contract boundary

The feature owns uncertainty thresholds, decision reasons, session state, feedback schema,
and review-flow integration. Implement the presentation component as part of this feature after its view model is fixed.

## Acceptance

- [x] Uncertain decisions enter a comprehensible Needs review queue with actionable reasons.
- [x] Feedback capture is bounded, on-device, and does not retain prohibited raw data.
- [x] Deterministic decisions retain the existing review flow.
- [x] Automated evidence shows reason, action, recovery, and persistence behavior (Simulator permitted).

## Relevant docs

- `docs/product-specs/ux-flows.md`
- `docs/ship-gates/privacy.md`

## Inline plan

1. Define uncertainty and feedback contracts from feat-023 selection outputs.
2. Implement the view component after exact ownership is assigned.
3. Integrate queue, reasons, capture, recovery, and review QA.

## Coordination plan

- `docs/plans/feat-026.md` (uncertainty contract, versioned feedback schema, review integration + ownership lifecycle, rollback — state/selection/review-flow change per AGENTS.md plan rules; DEC-042/DEC-043/DEC-044/DEC-045/DEC-046).

## Verify

- `./init.sh`
- Manual QA is not required and is never an acceptance criterion, blocker, or release gate (DEC-040). No test targets, no `*Test*.swift`, no test frameworks.

## Handoff

- State: done/merged — PR #55 (`https://github.com/tungxuan1656/photo-curator/pull/55`), branch `tungxuan1656/feat-026-integration`, squash merge commit `2e84812f97aa7099cdb15902f1fedc218585d0fa` confirmed on `origin/main`; feat-023 is `done` and feat-027 is next.
- Implementation (owned `apps/` files): new `Domain/Selection/UncertaintyReview.swift` (`UncertaintyReason` 5-case vocab + `UncertaintyAction` 4-case vocab + `UncertaintyClassifier` pure derivation + `UncertaintyReviewState` single source of truth for queue derivation/resolution/snapshot + `UncertaintyFeedbackSnapshot` schemaVersion 1 with strict seven-key read — DEC-046); new `Features/Review/NeedsReview.swift` (S22 queue surface — action buttons route without mutating selection: inspect/compare-moment open the queue-scoped S11 pager with S21 one tap deeper, similar routes S12, add-back routes S13; standalone `SelectionToggle` kept); `Features/Review/ReviewModel.swift` (holds one `UncertaintyReviewState`, delegates `isUncertaintyResolved`/`resolvedUncertaintyCount`/`uncertaintySnapshot`; `needsReviewItems` derived once in init from persisted decisions, live-config threshold, live-only filter); `Infrastructure/SessionCheckpointStore.swift` (`uncertainty-feedback/<session>.json` save/load-nil-on-any-failure/delete-absent-is-success + DEC-043 closed-session tombstone: deletes tombstone first, late writes drop, live `beginReview` reopens with a fresh generation owner; stale old-session writers pinned to a retired generation drop — DEC-046); `App/AppModel+Save.swift` (`beginReview` passes the live `lowQualityThreshold`, reopens the tombstone, assigns `reviewModel = model` before routing, installs ordered generation-pinned `PersistLatest` hook owning persist strongly with weak model capture + live snapshot derivation (DEC-045/DEC-046, no cycle, tombstone-safe, stale-writer-safe); disk failure stays `try?` retry-on-next-mutation); `docs/plans/feat-026.md` reconciled (band 0.05, schema without `analysisVersion`, single-source ownership, review-model ownership + hook lifecycle, strict read + generation guard, DEC-044/DEC-045/DEC-046); DEC-043/DEC-044/DEC-045/DEC-046 appended (DEC-042 untouched).
- Contract/data-model changes: uncertainty contract frozen (priority borderlineQuality 0 > faceTradeoff 1 > similarAlternatives 2 > secondMomentView 3 > coverageCut 4; score band 0.05 around the live `lowQualityThreshold` config value; queue cap 30 in priority/source order; `assetUnavailable`/eligibility/floor/duplicate-loser decisions never queue); feedback schema frozen per DEC-044 (`schemaVersion` 1 with exactly sessionID/engineVersion/queueSize/resolvedByReason/totalResolved/updatedAt — counts only, no identifiers/pixels/faces/EXIF/free text, no `analysisVersion`; `configVersion` 1 unchanged and not persisted in the snapshot; strict seven-key read rejects `configVersion`/extra keys with nil-on-read — DEC-046); no version move (`analysisVersion` 4, `engineVersion` 3, `configVersion` 1 — no migration); no new config keys (band/cap are policy constants beside the classifier, selection-rules §17 small-knob precedent); no engine/scorer/diversity/cluster/moment change; routes reuse S10/S11/S12/S13/S21 with a single shared selection source of truth. Canonical owner docs updated: `ux-flows.md` (S22 inventory/matrix/canonical-flow/S09 entry/S22 section + S01–S22 ownership range + S22 drill-down/diagram — DEC-045 docs sweep), `data-model.md` (§11 queue/snapshot/persistence, §14 frozen values, §15 snapshot row).
- Thresholds: scoreMargin 0.05, maxItems 30; `lowQualityThreshold` read from `AppConfiguration.default.selection` at review entry, never redefined or stored.
- Privacy boundary: snapshot carries aggregate reason counts only (fixed `UncertaintyReason` vocabulary, ephemeral per-run `sessionID`); prohibited in snapshot and logs — image bytes, face data, embeddings, GPS, full EXIF, asset identifiers, free text (JSON inspected in proof U6); retention follows `docs/ship-gates/privacy.md` §6 (dropped with discard/Reset, same idempotent rule, tombstone-guarded); no per-photo rows, no taste profiles, no cross-session learning (DEC-020/DEC-021 preserved).
- Acceptance evidence: `./init.sh` EXIT 0 — PASS format, PASS `swiftlint --strict` (0 violations/65 files), PASS Simulator build (`BUILD SUCCEEDED`), SKIP test per DEC-040. No standalone proof files, test target/framework, or `*Test*.swift`.
- Final review: Codex Luna xhigh found zero actionable findings. No tests, test target, test framework, or `*Test*.swift`; test remains SKIP by DEC-040.
- Blockers: none.
- Next: Activate feat-027 from the latest `origin/main`; this is not user-gated.
