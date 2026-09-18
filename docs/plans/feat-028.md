# feat-028 execution plan

**Decision:** close V2 with the current deterministic ranker; do not admit a learned ranker.

**Scope:** freeze the deterministic baseline, labels, provenance/privacy boundary, evaluation splits,
metrics, acceptance thresholds, and replay procedure; run the same automated smoke,
Golden-shaped, trip-shaped, and 1k-scale evidence; record the no-ranker product decision.
No application behavior, persisted shape, model artifact, dependency, network path, telemetry,
or version changes are in scope.

## Owner boundary

- Selection policy remains `docs/product-specs/selection-rules.md`.
- Rank-stage mechanics remain `docs/design-docs/selection-engine.md`.
- Concrete model/routing status is owned by `docs/design-docs/curation-runtime-stack.md`.
- Stored versions and migration rules remain `docs/design-docs/data-model.md`.
- Privacy/training boundary remains `docs/ship-gates/privacy.md` and `curation-runtime-stack.md` §11.
- Latency and regression budgets remain `docs/ship-gates/performance.md`.
- Product sequence remains `docs/exec-plans/roadmap.md`.
- The decision record is append-only in `docs/design-docs/decision-log.md`.

## Frozen baseline contract

The production baseline is the shipped deterministic pipeline at this branch:

- `analysisVersion = 4`, `engineVersion = 3`, `configVersion = 1`.
- `SelectionConfiguration.default` remains the sole rank configuration: target ratio `0.10`,
  minimum/final clamps `30`/`150`, shortlist multiplier `2.0`, quality floors `0.50`/`0.25`,
  and the existing configured weights and tie-breaks.
- `QualityScorer` ranks local candidates from persisted analysis facts only. The rank order is
  score descending, edited-twin preference, favorite preference, usable pixel area descending,
  then stable asset ID. Diversity, coverage, duplicate suppression, moments, explicit user
  overrides, and the quality floor remain authoritative after local rank.
- Results remain deterministic: identical assets, analyses, configuration, and feedback produce
  identical decisions. No random seed, learned state, cross-session taste profile, or hidden
  fallback is admitted.
- `engineVersion` stays 3. No ranker field, model checksum, cache row, migration, or rollback
  adapter is added. Existing re-ranking continues to use stored analyses without Vision reruns.

## Labels, provenance, and prohibited-data boundary

The proof uses `fixture-oracle-v3`, a repository-local static annotation manifest implemented by
`FixtureOracle.manifests` in `scripts/proof/feat-028-proof.swift`. The manifest is the independent
label source: it assigns authored structural `MUST_KEEP`/`ACCEPTABLE`/`REJECT` rows without reading
`PhotoAnalysis`, scalar scores, rank order, or engine output. The H-1000 manifest includes an
explicit group where the oracle `MUST_KEEP` is not the highest deterministic rank; the proof asserts
that mismatch and the selected rank winner. Every split uses the same manifest version and labels.
This is deterministic structural fixture evidence only; it is not human taste, an external
benchmark, or a production-quality claim, and no benchmark result is invented.

The oracle rows and run-local synthetic IDs are never persisted. No production user photo, user
correction, feedback row, face/identity data, demographic data, precise location, raw EXIF, image
bytes, or cross-user label is allowed in this evaluation or in future ranker training. No
network/cloud inference, telemetry, or persistent label store is allowed. A future candidate
cannot be admitted from this fixture alone; it requires a new evidence-backed decision with an
approved owned/licensed label source and privacy review.

## Splits and candidate admission

There is no fit or calibration split because no candidate was admitted: `fit = none` and
`calibration = none`. The evaluation split consists of four disjoint, deterministic namespaces,
asset-ID sets, and oracle-manifest rows:

| Split | Shape | Purpose |
|---|---:|---|
| Smoke | 60 assets / 15 groups × 4 / 15 moments | basic rank, duplicate, moment, and recall smoke |
| Golden-shaped | 200 assets / 20 groups × 10 / 20 moments | fixed regression-shaped rank and selection gate |
| Trip-shaped | 150 assets / 30 groups × 5 / 30 moments | multi-moment coverage and repetition shape |
| H-1000 | 1,000 assets / 50 groups × 20 / 50 moments | large-library determinism and bounded selection shape |

The wider duplicate groups keep the independent oracle rows representable while preserving the four
input counts and compression shapes. The proof asserts asset-ID disjointness across every split,
complete label coverage, the same `fixture-oracle-v3` provenance for all four rows, and an explicit
MUST_KEEP-vs-rank selection mismatch.

If a future residual failure crosses the admission gate, freeze train/dev/test provenance before
any model work. Do not use the evaluation namespaces for fitting or threshold tuning.


## Metrics and acceptance thresholds

The historical metric names and owner definitions remain those in `manual-qa.md` §4 and feat-017;
the manual handbook is archival and non-gating under DEC-040. The proof reports:

- Must-Keep Recall = selected `MUST_KEEP` / total oracle `MUST_KEEP`; the proof asserts the
  owner reference target `≥95%` on every evaluation split.
- Good Selection Rate = selected (`MUST_KEEP` + `ACCEPTABLE`) / selected.
- Bad Pick Rate = selected `REJECT` / selected.
- Duplicate Leakage = needless repeat selections / total selected. The automated fixture computes
  needless repeats as `max(0, selected members in a duplicate group - 1)` and asserts the
  denominator is exactly the selected output count, matching the owner definition.
- Best-Shot Accuracy = selected groups whose selected member is the oracle expected best /
  selected groups.
- Moment Coverage = moments represented by a selected member / total moments.
- Compression = selected / input, tracked only; it is not a quality score.
- Determinism = canonical selected/rejected/decision summary identical on two runs.

The owner reference targets are preserved, never lowered: Must-Keep Recall `≥95%`, Good Selection
Rate `≥90%`, Bad Pick Rate `≤10%`, Duplicate Leakage `≤5%`, Best-Shot Accuracy `≥80–85%`, and
Moment Coverage `≥90%`. The independent oracle's broader duplicate groups leave each split's
structural `MUST_KEEP` rows representable; the observed Recall is therefore an asserted quality
gate, not compression context. Ranker-admission gates remain Good Selection Rate `≥90%`, Bad Pick
Rate `≤10%`, Duplicate Leakage `≤5%`, Best-Shot Accuracy `≥80%`, Moment Coverage `≥90%`, exact
determinism, unchanged `engineVersion`, and no performance regression beyond the existing
performance owner flag (`>~20%` without a planned quality change).

A material baseline gap means a repeatable named failure or any ranker-admission metric missing
its threshold on a disjoint evaluation shape. One better metric cannot offset a material recall,
coverage, privacy, determinism, or performance regression. Without such a gap, do not evaluate a
learning-to-rank candidate merely because the architecture permits one.

## Evaluation procedure

Run from the repository root:

```text
./scripts/proof/feat-028.sh
```

The script stages every shipped source used by the proof, checks byte identity, compiles for the
iOS Simulator SDK, boots `iPhone 17 Pro`, and runs the proof through `simctl spawn`. Each split
runs the real `SelectionEngine` twice with the same deterministic inputs and FeaturePrint-shaped
edges. Before evaluation, the proof asserts the complete `AppConfiguration.default.selection`
field set, frozen weights/bonuses, behavior of the edited/favorite/pixel-area/asset-ID tie-break
chain on equal-score fixtures (including reversed input order), oracle provenance, exact label
coverage, asset-ID disjointness, the explicit MUST_KEEP-vs-rank mismatch/selection case, and
oracle/rank independence. It then checks versions, Recall and the remaining metrics, the canonical
Duplicate Leakage denominator, and canonical output equality. No test target or test framework is
used.

Recorded focused proof (2026-09-18):

```text
STAGED-MATCH 17
ORACLE-MISMATCH split=H-1000 group=0 rankWinner=H-1000-g000-m0 mustKeep=H-1000-g000-m1 selectedRankWinner=true selectedMustKeep=false PASS
CONTRACT baseline=deterministic engineVersion=3 analysisVersion=4 configVersion=1 PASS
CONFIG complete=true frozenWeights=technical,human,representativeness,uniqueness,diversity,coverage,redundancy all=1.000 bonuses=0.000/0.000 tieBreak=score-desc,edited-desc,favorite-desc,pixel-area-desc,asset-id-asc behavior=asserted PASS
TIE-BREAK behavior=edited>favorite>pixel-area>asset-id cases=4 input-order-replay=true PASS
LABELS provenance=fixture-oracle-v3 source=repo-local-static-annotation-manifest independent-of=PhotoAnalysis-rank-order explicit-MUST_KEEP-rank-mismatch=true boundary=no-user-photos-no-persisted-labels PASS
SPLITS fit=none calibration=none evaluation=smoke,Golden-shaped,trip-shaped,H-1000 assetIDsDisjoint=true labelsEquivalent=true PASS
SMOKE input=60 output=15 mustKeepRecall=1.000 good=1.000 bad=0.000 leakage=0.000 leakageNumerator=0 leakageDenominator=15 bestShot=1.000 coverage=1.000 compression=0.250 deterministic=true engineVersion=3 PASS
GOLDEN-SHAPED input=200 output=20 mustKeepRecall=1.000 good=1.000 bad=0.000 leakage=0.000 leakageNumerator=0 leakageDenominator=20 bestShot=1.000 coverage=1.000 compression=0.100 deterministic=true engineVersion=3 PASS
TRIP-SHAPED input=150 output=30 mustKeepRecall=1.000 good=1.000 bad=0.000 leakage=0.000 leakageNumerator=0 leakageDenominator=30 bestShot=1.000 coverage=1.000 compression=0.200 deterministic=true engineVersion=3 PASS
H-1000 input=1000 output=50 mustKeepRecall=0.980 good=0.980 bad=0.020 leakage=0.000 leakageNumerator=0 leakageDenominator=50 bestShot=0.980 coverage=1.000 compression=0.050 deterministic=true engineVersion=3 PASS
NO-RANKER GATE PASS baseline-measurable-gap=false candidate-evaluation=not-admitted
RESULT PASS
```

These are repository-local structural oracle labels, not human taste, an external benchmark, or a
production-user quality claim. They show no measurable ranker-admission gap in the frozen baseline;
the learned candidate is therefore not evaluated and no benchmark result is invented.

The repository's preceding automated records independently preserve the same deterministic
contract: feat-023 ran Smoke 60, Golden-shaped 200, Trip-shaped 150, and H-1000 1,000 with
fallback-identical picks and double-run byte equality; feat-026 preserved deterministic engine
output while adding review-only state; and feat-027 kept iOS 26 provider/image calls at zero
with Golden-shaped bounded jury fallback. Those records contain no unresolved named baseline
failure requiring a learned ranker. The feat-028 proof is the focused rank-stage replay, not a
claim that this structural oracle replaces a future approved product-quality annotation set.


## Product decision and rollback

**No-ranker:** retain the deterministic `QualityScorer` and close the V2 ranker phase. Update the
runtime status and decision log, but do not change app code, selection behavior, persisted data,
versions, or fallback behavior. The iOS 26 native path and the iOS 27 optional semantic jury
remain the only shipped intelligence layers; both continue to fall back deterministically.

Rollback is documentation/proof-only: revert the feat-028 tracker/plan/decision/runtime-status
changes and remove `scripts/proof/feat-028.sh` plus `scripts/proof/feat-028-proof.swift`.
There is no model artifact, migration, cache invalidation, or runtime adapter to roll back.

Reconsider only when a named residual failure remains after the deterministic baseline and
semantic-jury paths, appears on a newly frozen admissible label set, and a candidate can pass the
full quality, privacy, license, performance, versioning, and fallback gates without using
production user photos or corrections as global training data.

## Verification status

- [x] Focused smoke, Golden-shaped, trip-shaped, and H-1000 proof passed.
- [x] `./init.sh` final post-implementation pass: SwiftFormat PASS (`0/87` files formatted),
  SwiftLint strict PASS (`0` violations in `66` files), Simulator build PASS (`BUILD SUCCEEDED`),
  tests SKIP by DEC-040 (`no automated tests`).
- [x] Feature and progress handoff synchronized.
