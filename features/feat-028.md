# feat-028 — Ranker decision gate

## Status

- Status: `done`
- Depends on: `feat-027` (done/merged)

## Goal

Make a measured, versioned decision to use a learning-to-rank layer or to close V2 with
the deterministic ranker. Either outcome is valid when supported by evidence.

## Contract boundary

The feature owns labels, offline evaluation, acceptance threshold, ranker version,
rollback, and the final product decision. It does not depend on feat-025: specialist
models may be rejected and are not a ranker prerequisite. The external readiness,
rollback, and evaluation plan is [`docs/plans/feat-028.md`](../docs/plans/feat-028.md).

## Acceptance

- [x] Labels and evaluation splits have recorded provenance and no prohibited user data.
- [x] Candidate ranker demonstrably beats the deterministic baseline on the agreed gates,
  or the no-ranker decision is recorded with the same evidence.
- [x] Any accepted ranker has explicit version, migration, rollback, and fallback behavior.
  The valid no-ranker branch records that no ranker, migration, or runtime fallback was accepted.
- [x] Final Golden-shaped, trip-shaped, and 1k-scale automated gates pass (Simulator permitted).

## Relevant docs

- `docs/plans/feat-028.md`
- `docs/design-docs/curation-intelligence.md`
- `docs/design-docs/curation-runtime-stack.md`
- `docs/product-specs/selection-rules.md`
- `docs/design-docs/selection-engine.md`
- `docs/design-docs/data-model.md`
- `docs/ship-gates/privacy.md`
- `docs/ship-gates/performance.md`
- `docs/exec-plans/roadmap.md`
- `docs/design-docs/decision-log.md` (DEC-040, DEC-050, DEC-051, DEC-052)

## Plan

1. Freeze labels, metrics, and the deterministic baseline before evaluating candidates.
2. Evaluate a candidate only if the baseline exposes a material remaining gap.
3. Integrate a versioned ranker or record the no-ranker decision and close V2.

Plan: [`docs/plans/feat-028.md`](../docs/plans/feat-028.md).

## Verify

- `./scripts/proof/feat-028.sh` — reproducible automated proof stages the real deterministic
  ranking sources and runs smoke, Golden-shaped, trip-shaped, and H-1000 fixtures twice each.
- `./init.sh` — required final workspace verification.
- Manual QA is not required and is never an acceptance criterion, blocker, or release gate
  (DEC-040). No test targets, no `*Test*.swift`, no test frameworks.

## Handoff

- State: done/merged (post-merge closeout complete; PR #59 (`https://github.com/tungxuan1656/photo-curator/pull/59`) merged at `986f5dd82970afd5cd46fe2651fad689bf9eb87f`, confirmed on `origin/main`; `feature_index.json` remains `done`; no application-code change)
- Decision: retain deterministic `QualityScorer`/`SelectionEngine` at `analysisVersion 4`,
  `engineVersion 3`, `configVersion 1`; learned ranker not admitted because the baseline exposes
  no material measurable gap on the frozen independent oracle fixture.
- Labels: `fixture-oracle-v3`, repository-local authored annotation rows from
  `FixtureOracle.manifests`; labels never read `PhotoAnalysis`, scalar scores, rank order, engine
  output, user photos, corrections, identities, faces, precise location, EXIF, free text,
  embeddings, network, cloud, telemetry, or persisted label rows. H-1000 includes an explicit
  MUST_KEEP label below the deterministic rank winner; proof asserts the mismatch and selected
  rank winner. No external benchmark is claimed.
- Splits: fit none, calibration none; disjoint Smoke 60 (15 groups × 4 / 15 moments),
  Golden-shaped 200 (20 × 10 / 20 moments), Trip-shaped 150 (30 × 5 / 30 moments), H-1000
  1,000 (50 × 20 / 50 moments); same oracle semantics across evaluation only, no candidate
  tuning; asset-ID disjointness is asserted.
- Metrics: Duplicate Leakage is needless repeat selections / total selected, with the proof
  computing repeat excess per duplicate group and asserting the denominator equals selected output.
  Owner gates remain unchanged.
- Tie-break evidence: equal-primary-score fixtures behaviorally assert edited > favorite >
  pixel-area > asset-ID and deterministic replay under reversed input order.
- Acceptance/evidence: all four feat-028 acceptance criteria remain checked; `./scripts/proof/feat-028.sh`
  EXIT 0, `STAGED-MATCH 17`; explicit H-1000 `MUST_KEEP`/rank mismatch selects the deterministic
  rank winner; equal-score edited/favorite/pixel-area/asset-ID tie-break fixtures pass under
  reversed input order. Smoke `60→15`, Golden-shaped `200→20`, Trip-shaped `150→30`, H-1000
  `1,000→50`; Recall/Good Selection/Best-Shot/Moment Coverage are `1.000`, `1.000`, `1.000`,
  `1.000` on the first three and `0.980`, `0.980`, `0.980`, `1.000` on H-1000; Bad Pick is
  `0.000`, `0.000`, `0.000`, `0.020`; Duplicate Leakage is `0.000` with denominator equal to
  selected output (`15/20/30/50`).
- Proof source: `scripts/proof/feat-028.sh` + `scripts/proof/feat-028-proof.swift`; no shipped
  model, dependency, persisted field, migration, or fallback adapter.
- Final verification: `./init.sh` EXIT 0 — SwiftFormat PASS (`0/87` files formatted), SwiftLint
  strict PASS (`0 violations in 66 files`), Simulator build `BUILD SUCCEEDED`, and tests SKIP by
  DEC-040. Manual QA is removed and non-gating per DEC-040; no automated tests, test targets,
  `*Test*.swift` files, or test frameworks.
- Contract: no contract or data-model change.
- Blockers: none.
- Next: none — the full approved feature sequence is complete. Reconsider a ranker only on a
  named residual failure with a newly approved admissible label source and a new decision record
  satisfying the full quality/privacy/license/performance/version/fallback gate.
