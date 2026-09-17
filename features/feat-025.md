# feat-025 — Conditional specialist models

## Status

- Status: `done` (DEC-032 automated gate: no residual feat-023 failure triggers Tier-D evaluation; three candidates explicitly rejected; no `apps/` change; sole integration; feat-023 stays `done`)
- Depends on: `feat-023` (`done` via PR #50 `96a75a9`; verified before activation; repo idle, no other `active`)

## Goal

Evaluate difficult-only specialist candidates only when a remaining baseline failure has
no cheaper accepted remedy. Rejection is a successful outcome.

## Contract boundary

The feature owns candidate selection, target failure, accept/reject decision, routing,
resource budget, license/provenance, and rollback. Do not pre-admit DETR, depth, or SAM
as a bundle. Create a feature only for one candidate with one named failure.

- [x] No-trigger branch is an explicit valid outcome: feat-023 has no unresolved named failure and cheaper remedies remain unexhausted, so the evaluation closes with all three named candidates individually rejected and no model admitted (see Handoff).
- [x] Each candidate has on-device quality, latency, memory, license, checksum, and availability evidence — not required for an admitted model on the no-trigger branch by construction: nothing vendored, no runtime dependency introduced (see Handoff).
- [x] Each candidate is explicitly accepted or rejected; rejection leaves no speculative runtime dependency (all three REJECTED individually, never bundled; grep/find proof in Handoff).
- [x] Accepted routing is difficult-only, bounded, and reversible (vacuous pass on the no-trigger branch — no accepted routing, no routing change, nothing to roll back).

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/design-docs/curation-runtime-stack.md` (Tier-D §7)
- `docs/design-docs/decision-log.md` (DEC-038)
- `docs/ship-gates/privacy.md`

## Inline plan

1. Select a single unresolved feat-023 failure and verify no cheaper signal fixes it.
2. Create one evaluation record for each candidate; benchmark and decide.
3. Integrate only an accepted candidate, otherwise record the rejection and close.

## Coordination plan

- `docs/plans/feat-025.md` (Tier-D trigger/no-trigger readiness record: frozen trigger contract, no-trigger branch, per-candidate records, repo-state verification, rollback/no-model-admission).

## Verify

- Reproducible automated evidence for every behavior change (Simulator permitted): target fixture plus Golden-shaped and 1k-scale for any accepted candidate; record commands, fixtures, and outputs in the handoff.
- `./init.sh`
- Manual QA per `docs/ship-gates/manual-qa.md` is optional non-blocking exploratory guidance only, never an acceptance blocker (DEC-032). No test targets, no `*Test*.swift`, no test frameworks.

## Handoff

- State: done (sole integration; no `apps/` change; `docs/plans/feat-025.md` created per AGENTS.md >=4-file rule — five changed paths `features/feat-025.md` + `feature_index.json` + `docs/design-docs/curation-runtime-stack.md` + `docs/design-docs/decision-log.md` + `progress.md` plus this plan as sixth; no shared-contract code change, single workspace, no phases; feat-023 stays `done`, feat-026 stays `todo`)
- Activation precondition: `feature_index.json` verified feat-023 `done` / feat-025 `todo`; branch `tungxuan1656/feat-025-integration` at `2e153a7` with a clean tree; no other `active` feature.
- Implementation (owned `apps/` files): none — deliberate no-op. No model vendored, no provider/protocol/router, no Vision request, no persisted field, no config key, no `analysisVersion`/`engineVersion` move, no dependency added.
- Residual-failure search (feat-023 evidence, read before deciding): feat-023 proof passes all 12 named cases (N0–N4 novelty, S1–S3 saturation, F1–F3 fallback/determinism, G1 bounds) on Smoke 60→6 + Golden 200→15 + Trip G 150→24 + H 1000→56 with fallback==noop exactly and double-run byte-identical; the only documented ceilings are pixel-level distinctions (day/night, formal/candid same-face-count, framing magnitude, dense-timeline activity) which per `features/feat-023.md` Handoff + DEC-036 reconsider need FastViT Tier-C pixel evidence or feat-027 jury first — a cheaper remedy that must be exhausted before any Tier-D specialist per `curation-runtime-stack.md` §4 failure→tool map. No named feat-023 failure maps to a Tier-D-only gap with cheaper remedies exhausted.
- Candidate verdicts (evaluated individually, never bundled): (1) DETR-style object/layout — searched failure difficult scene-layout collapse; feat-023 N4 meaningful-variation hold PASSES, no triggering failure; cheaper FastViT Tier-C / feat-027 jury untried → REJECTED (not triggered). (2) Depth Anything V2 Small depth/context — searched failure composition/context gap beyond native horizon/saliency; no triggering failure on fixtures; cheaper native Tier-B + Tier-C embedding untried → REJECTED. (3) SAM 2.1 Tiny precision segmentation — searched failure native-mask insufficiency; no triggering failure; cheaper native Vision masks untried → REJECTED. All three: no license/source/version/checksum payload by construction (nothing to license/checksum/ship); no quality/latency/memory claim invented (no benchmark without a target failure); rollback N/A (nothing integrated).
- Acceptance evidence (no behavior change, so repo-state proof on the no-trigger branch — no target/benchmark/license/resource evidence required for an admitted model, no runtime dependency introduced): `find apps -iname '*.mlmodel*' -o -iname '*.mlpackage*' -o -iname '*.coreml*'` → no files; `grep -rn 'DETR\|Depth Anything\|SAM 2\|mlmodel\|mlpackage' apps/` → no hits; on-device/privacy hold per `docs/ship-gates/privacy.md` (nothing leaves the device, no prohibited data retained); `git status --porcelain` = five modified (`features/feat-025.md` + `feature_index.json` + `docs/design-docs/curation-runtime-stack.md` + `docs/design-docs/decision-log.md` + `progress.md`) plus `?? docs/plans/feat-025.md`, no `apps/` path; `./init.sh` PASS (result recorded below); DEC-038 recorded append-only with per-candidate alternatives/evidence/reconsider.
- Evidence: `./init.sh` PASS (format, `swiftlint --strict`, Simulator build SUCCEEDED, SKIP [test] per no-test-targets policy); no test targets/`*Test*.swift`/frameworks; no manual QA (optional non-blocking per DEC-032).
- Blockers: none.
- Next: feat-026 is the next approved feature (depends on feat-023, done); it can activate after this closeout is merged; feat-025 must not be reactivated here.
