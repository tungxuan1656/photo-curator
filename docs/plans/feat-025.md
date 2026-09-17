# feat-025 execution plan

Goal: evaluate difficult-only Tier-D specialist candidates only against a triggering residual feat-023 failure with cheaper remedies exhausted. A no-trigger evaluation is an explicit valid branch: all three named candidates are individually rejected and nothing is admitted.

## Scope

Owns: the Tier-D trigger search over feat-023 evidence; the three per-candidate evaluation records (DETR-style object/layout, Depth Anything V2 Small depth/context, SAM 2.1 Tiny precision segmentation); the runtime-stack §7 REJECTED rows; DEC-038; the feature/progress records; and this plan.

Explicitly NOT: any `apps/` change; model vendoring; new provider/protocol/router; new Vision request; new persisted field; new config key; `analysisVersion`/`engineVersion` move; new dependency; cluster/moment/scorer/weight/threshold changes (feat-021/feat-022/feat-023 frozen); review/jury/ranker (feat-026/027/028); cloud AI.

## Why this plan exists (file-count rule)

AGENTS.md requires `docs/plans/feat-<id>.md` when a feature changes >=4 files. This feature touches six docs/metadata paths and no code: `features/feat-025.md`, `feature_index.json`, `docs/design-docs/curation-runtime-stack.md`, `docs/design-docs/decision-log.md`, `docs/plans/feat-025.md` (this file), `progress.md`. No shared-contract code change, single workspace, no phases — this plan is the readiness record the file count requires, not a code rollout. DEC-038's verdict stands unchanged and the decision log is untouched; the "create no plan" line in DEC-038 is reconciled here by the >=4-file rule governing.

## Trigger contract (frozen)

A Tier-D candidate may be benchmarked only for one named unresolved feat-023 failure with cheaper remedies (native Tier-B facts, Tier-C embedding including the FastViT benchmark gate, feat-027 jury) exhausted first. Never admit DETR/depth/SAM as a bundle — one candidate, one named failure. Any admitted candidate needs the full gate before integration: license re-review + checksum + size/latency/memory/thermal + quality delta + bounded difficult-only routing + rollback.

## No-trigger / no-op path (explicit valid branch)

When the residual-failure search finds no triggering failure — feat-023's 12 named cases (N0–N4 novelty, S1–S3 saturation, F1–F3 fallback/determinism, G1) pass with fallback==noop exactly and double-run byte-identical, and the only ceilings are pixel-level distinctions (day/night, formal/candid same-face-count, framing magnitude, dense-timeline activity) whose recorded path is FastViT Tier-C pixel evidence or feat-027 jury first — the evaluation closes without benchmarks: each of the three named candidates is individually REJECTED (not triggered), no target/benchmark/license/resource evidence is required for an admitted model (there is none), and no runtime dependency is introduced. Rejection is a successful outcome. Privacy constraints hold throughout (on-device only per `docs/ship-gates/privacy.md`; no photo content leaves the device; no prohibited data retained).

## Candidate records

(1) DETR-style object/layout — searched failure: difficult scene-layout collapse; feat-023 N4 meaningful-variation hold PASSES, no triggering failure; cheaper FastViT Tier-C / feat-027 jury untried → REJECTED (not triggered). (2) Depth Anything V2 Small depth/context — searched failure: composition/context gap beyond native horizon/saliency; no triggering failure on fixtures; cheaper native Tier-B + Tier-C embedding untried → REJECTED. (3) SAM 2.1 Tiny precision segmentation — searched failure: native-mask insufficiency; no triggering failure; cheaper native Vision masks untried → REJECTED. All three: no license/source/version/checksum payload by construction (nothing to license/checksum/ship); no quality/latency/memory numbers invented (no benchmark without a target failure).

## Verification and rollback

Repo-state proof (no behavior change): `find apps -iname '*.mlmodel*' -o -iname '*.mlpackage*' -o -iname '*.coreml*'` → no files; `grep -rn 'DETR\|Depth Anything\|SAM 2\|mlmodel\|mlpackage' apps/` → no hits; `git status --porcelain` = five modified (`features/feat-025.md` + `feature_index.json` + `docs/design-docs/curation-runtime-stack.md` + `docs/design-docs/decision-log.md` + `progress.md`) plus `?? docs/plans/feat-025.md` (this file), no `apps/` path; `./init.sh` PASS; no test targets/`*Test*.swift`/frameworks; no manual QA (optional non-blocking per DEC-032).

Rollback / no model admission: nothing integrated, so nothing to roll back beyond reverting the six docs/metadata paths. No model vendored, no provider/request/field/key/version move, no dependency added — no migration to undo, no routing to disable.
