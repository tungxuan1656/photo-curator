# mini-017b — A-H, Golden, and Real Trip baseline runs

## Status and parent

- Status: `blocked` (rows templated per no-device constraint; values pending user-run physical measurement; ledger merged via `0967d2d`)
- Parent integration feature: `feat-017`
- Reserved ID: `mini-017b`

## Seam and ownership

- One responsibility: run the frozen baseline on datasets A–H plus Golden plus one Real Trip and attach one reproducible `manual-qa.md` §8.2 row per dataset to the ledger. No scoring change.
- Exclusive owns: `features/mini-017b.md` only.
- Forbidden shared contracts: `docs/ship-gates/manual-qa.md`, `docs/design-docs/curation-intelligence.md`, every `apps/` pipeline/cache/version/config file, sibling `features/mini-017a.md` and `features/mini-017c.md`.
- Merge gate and reviewer: one §8.2 row per dataset (A, B, C, D, E, F, G Real Trip, H stability-only, Golden) in this file, each with date, build, config, dataset, input/final counts, all nine metric values or explicit H exemptions, top failures, and `Decision: Neutral (baseline)`; an independent reviewer confirms every row is reproducible from the recorded fields and that the diff touches no `apps/` path; `./init.sh` passes on the parent after merge. Reviewer: integration owner plus one independent reviewer, never the module owner alone.

## Admission card (parallel-delivery §4; every field concrete)

- Parent: `feat-017`
- Seam: baseline runs on A–H, Golden, and Real Trip (evidence only)
- Exclusive owns: `features/mini-017b.md`
- Shared contract task: parent plan Task 3 classifies these rows into the failure taxonomy (evidence merge only; no code wiring)
- Target failure: none yet (these rows are the baseline that later failures are measured against)
- Input: `mini-017a` ledger (denominators + Golden labels) + frozen fixture versions (`analysisVersion 1`, `engineVersion 2`, `configVersion 1`) + physical iPhones (daily driver + older when available; Simulator excluded from numbers)
- Output: one reproducible §8.2 row per dataset in `features/mini-017b.md`
- Fallback: n/a (evidence only; current deterministic engine behavior is the baseline)
- Version effect: none (no `analysisVersion` / `engineVersion` bump)
- Focused QA: datasets A (50–100 smoke), B (50–150 duplicates), C (100–300 moments), D (100–200 people), E (100–200 context), F (bad-photo stress), G Real Trip (500–1,500, the main qualitative check), H (1,000 / 3,000 / 5,000: stability, memory, cancel, progress, thermal only — never hand-scored), Golden (200–500 regression reference); all nine metrics with H quality exemptions
- Merge gate: every row reproducible + no `apps/` diff + `./init.sh` passes on the parent after merge
- Reject condition: any scoring, threshold, weight, config, or version change during the runs; Simulator numbers presented as pipeline proof; H hand-scored for taste; missing date/build/config/dataset/count fields

## Acceptance and evidence

- [x] One reproducible §8.2 row per dataset (A–H, Golden, Real Trip) is attached in this file (nine pending blocks in §§ Baseline runs; run-dependent values `pending` — nothing invented).
- [x] Dataset H claims stability/performance only (Row H exempts all hand-scored quality metrics; never hand-scored for taste).
- [x] No production scoring, threshold, version, or QA-policy change (this file only; verify with `git diff --name-only`).
- Manual QA / benchmark command or procedure: `manual-qa.md` §5–§6 run procedures with the §8.2 evaluation template; regression comparison per §6.2.
- Evidence location: `features/mini-017b.md` (this file §§ Ledger input / Devices / Baseline runs). Verification: `./init.sh` result, `git diff --name-only`, commit, and PR recorded in Handoff.

## Inline plan

1. Confirm the `mini-017a` ledger (denominators + Golden labels) is merged; record frozen versions, build, and devices. (done — ledger merged via `0967d2d`; versions verified in code; devices recorded; no device touched per no-device constraint)
2. Run A–F, Golden, one Real Trip (G), and H (stability only) on physical iPhones; fill one §8.2 row per dataset with all nine metrics or explicit H exemptions. (blocked — nine rows templated below with values `pending`; filling requires user-run physical measurement)
3. List top failures with `manual-qa.md` §7.2 tags for parent classification; mark every row `Decision: Neutral (baseline)`. (blocked — tag vocabulary recorded per row; assignment awaits runs; Decision pre-registered Neutral)

## Ledger input (source: `features/mini-017a.md` at `0967d2d`, merged into this branch)

- Golden label audit (`manual-qa.md` §§2–3): all counts `pending` — MUST_KEEP / ACCEPTABLE / REJECT plus moment ID, duplicate cluster ID + best-in-cluster flag, group/landscape/portrait/context flag, known defect note. No annotated Golden set exists in the repo; nothing invented here. Per §3.2 order (labels before runs), annotation must complete before Golden/any run values are measured — so every row below stays `pending` until then.
- Frozen fixture versions (verified in code on this branch, unchanged from the parent freeze): `analysisVersion 1` (`AppConfiguration.default.analysis.analysisVersion`; `PhotoAnalysis.currentVersion`), `engineVersion 2` (`FinalAlbumBuilder`), `configVersion 1` (`AppConfiguration.default.configVersion`), cache `schemaVersion 1` (`CacheConfiguration`).
- Nine frozen denominators (verbatim from `features/feat-017.md`): 1 Must-Keep Recall / total MUST_KEEP; 2 Good Selection Rate / total selected; 3 Bad Pick Rate / total selected; 4 Duplicate Leakage / total selected; 5 Best-Shot Accuracy / clusters judged; 6 Moment Coverage / total important moments; 7 Compression Ratio / input count (track only, no target); 8 Human Edit Rate / final album size (track only; removals vs add-backs split); 9 Subjective score 1–5 / reviewer judgment (4+ on unseen trips). Formulas and MVP targets stay owned by `manual-qa.md` §4; this file redefines nothing.
- Row template per run (`manual-qa.md` §8.2): Date / Build / Config / Dataset; Input / Final / Compression; MUST_KEEP total / selected / recall; Selected MUST_KEEP / ACCEPTABLE / REJECT; Good rate / Bad-pick rate; Clusters judged / leakage / best-shot accuracy; Key moments total / covered / coverage; User removals / add-backs; Top failures; Notes; Regression vs last build; Decision. Regression comparison per §6.2 (old-vs-new album diff: only-in-each, cluster-pick changes, lost moments, balance shift; never one number alone).

## Devices and run procedure

- Physical iPhone only: daily driver plus an older device when available (oldest-supported first for budget work), per the parent freeze. No physical device was touched for this record (user constraint 2026-09-16: no physical-device operations via any channel); the rows below are templated blocks awaiting user-run measurement — no device name, iOS version, or build number is invented here.
- Run procedure: `manual-qa.md` §5 app QA (smoke §5.1 on A; states/cancel/interrupt/review/save §5.3; perf/memory §5.4) plus §6 selection QA (per-cluster §6.1; album-level §6.2 review questions, temporal scan, blind check, side-by-side). Golden: annotate first (§3.2), then run, then compare.
- Simulator: never pipeline proof (parent freeze: Simulator is UI work only). No Simulator numbers are recorded in this file.
- Dataset H (1,000 / 3,000 / 5,000) records stability, memory, cancel, progress, and thermal behavior only, per `manual-qa.md` §2 (quality scoring optional) and the parent freeze; it is never hand-scored for taste — all nine taste denominators are explicitly exempt in Row H.

## Baseline runs (one §8.2 block per dataset; all run-dependent values `pending`)

### Row A — Basic Mixed (50–100, smoke; procedure §5.1)

```text
# Selection Evaluation
Date: pending (user-run) / Build: pending / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: A — Basic Mixed (50–100, smoke)
Input: pending / Final: pending / Compression: pending (track only, no target)
MUST_KEEP total / selected / recall: pending / pending / pending
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending
Good rate: pending / Bad-pick rate: pending
Clusters judged / leakage / best-shot accuracy: pending / pending / pending
Key moments total / covered / coverage: pending / pending / pending
User removals / add-backs: pending / pending
Top failures: pending (tag with manual-qa.md §7.2 vocabulary when observed: IMPORTANT_PHOTO_MISSED, BAD_PHOTO_SELECTED, DUPLICATE_LEAKAGE, WRONG_BEST_SHOT, OVER_CLUSTERING, UNDER_CLUSTERING, MOMENT_MISSING, PEOPLE_BIAS, LANDSCAPE_BIAS, DIVERSITY_FAILURE, GROUP_PHOTO_FAILURE, QUALITY_SCORING_FAILURE, ALBUM_TOO_LARGE, ALBUM_TOO_SMALL, UNKNOWN_SELECTION_FAILURE; severity per §7.1)
Notes: pending (pass signs per §5.1: no crash/freeze; progress moves; counts look right; edits stick; save works; originals unchanged)
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```

### Row B — Duplicate Stress (50–150, clustering / best-shot / leakage)

```text
# Selection Evaluation
Date: pending (user-run) / Build: pending / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: B — Duplicate Stress (50–150)
Input: pending / Final: pending / Compression: pending (track only, no target)
MUST_KEEP total / selected / recall: pending / pending / pending
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending
Good rate: pending / Bad-pick rate: pending
Clusters judged / leakage / best-shot accuracy: pending / pending / pending (§6.1 per-cluster checks: frames belong together; picked frame sharper/better exposed/framed, open eyes, clear faces; no needless copies; no meaningful variant killed)
Key moments total / covered / coverage: pending / pending / pending
User removals / add-backs: pending / pending
Top failures: pending (§7.2 vocabulary; expect DUPLICATE_LEAKAGE / WRONG_BEST_SHOT / OVER_CLUSTERING / UNDER_CLUSTERING candidates)
Notes: pending
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```

### Row C — Moment Sequence (100–300, moment coverage)

```text
# Selection Evaluation
Date: pending (user-run) / Build: pending / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: C — Moment Sequence (100–300)
Input: pending / Final: pending / Compression: pending (track only, no target)
MUST_KEEP total / selected / recall: pending / pending / pending
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending
Good rate: pending / Bad-pick rate: pending
Clusters judged / leakage / best-shot accuracy: pending / pending / pending
Key moments total / covered / coverage: pending / pending / pending (§6.2 temporal scan: no day/moment starved without cause)
User removals / add-backs: pending / pending
Top failures: pending (§7.2 vocabulary; expect MOMENT_MISSING / DIVERSITY_FAILURE candidates)
Notes: pending
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```

### Row D — People and Groups (100–200, face / group handling)

```text
# Selection Evaluation
Date: pending (user-run) / Build: pending / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: D — People and Groups (100–200)
Input: pending / Final: pending / Compression: pending (track only, no target)
MUST_KEEP total / selected / recall: pending / pending / pending
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending
Good rate: pending / Bad-pick rate: pending
Clusters judged / leakage / best-shot accuracy: pending / pending / pending (§6.1 group checks: face count, closed eyes, sharpness, expression, blocked faces, key people visible/looking, framing, two-variants-both-deserve-a-slot)
Key moments total / covered / coverage: pending / pending / pending
User removals / add-backs: pending / pending
Top failures: pending (§7.2 vocabulary; expect GROUP_PHOTO_FAILURE / PEOPLE_BIAS / WRONG_BEST_SHOT candidates)
Notes: pending
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```

### Row E — Landscape and Context (100–200, face-bias check)

```text
# Selection Evaluation
Date: pending (user-run) / Build: pending / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: E — Landscape and Context (100–200, no faces)
Input: pending / Final: pending / Compression: pending (track only, no target)
MUST_KEEP total / selected / recall: pending / pending / pending
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending
Good rate: pending / Bad-pick rate: pending
Clusters judged / leakage / best-shot accuracy: pending / pending / pending
Key moments total / covered / coverage: pending / pending / pending (§6.1 landscape check: strong views, landmarks, sunsets, night streets, context survive; an all-portrait album fails)
User removals / add-backs: pending / pending
Top failures: pending (§7.2 vocabulary; expect LANDSCAPE_BIAS / PEOPLE_BIAS candidates)
Notes: pending
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```

### Row F — Bad Photo Stress (small, quality rejection)

```text
# Selection Evaluation
Date: pending (user-run) / Build: pending / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: F — Bad Photo Stress (small)
Input: pending / Final: pending / Compression: pending (track only, no target)
MUST_KEEP total / selected / recall: pending / pending / pending
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending
Good rate: pending / Bad-pick rate: pending (§6.1: quality and value separately — a weak frame of a unique moment can stay)
Clusters judged / leakage / best-shot accuracy: pending / pending / pending
Key moments total / covered / coverage: pending / pending / pending
User removals / add-backs: pending / pending
Top failures: pending (§7.2 vocabulary; expect BAD_PHOTO_SELECTED / QUALITY_SCORING_FAILURE candidates)
Notes: pending (edge: mostly-bad set keeps the best meaningful ones)
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```

### Row G — Real Trip (500–1,500, main qualitative check)

```text
# Selection Evaluation
Date: pending (user-run) / Build: pending / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: G — Real Trip (500–1,500, main qualitative check)
Input: pending / Final: pending / Compression: pending (track only, no target)
MUST_KEEP total / selected / recall: pending / pending / pending
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending
Good rate: pending / Bad-pick rate: pending
Clusters judged / leakage / best-shot accuracy: pending / pending / pending
Key moments total / covered / coverage: pending / pending / pending
User removals / add-backs: pending / pending
Top failures: pending (§7.2 vocabulary; full §6.2 review questions: kept the most important memories? anything obviously bad? duplicates? best frame? groups? landscapes/context? all trip parts present? one person/scene taking over? faster to review? acceptable with small edits?)
Notes: pending (main question per §2: would I use this album? diversity check per §4: people, groups, landscapes, buildings, food, details, transport, day and night)
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```

### Row H — Large Library Stress (1,000 / 3,000 / 5,000; stability-only, quality metrics EXEMPT)

Hand-scored quality metrics do not apply to this row: Must-Keep Recall, Good Selection Rate, Bad Pick Rate, Duplicate Leakage, Best-Shot Accuracy, Moment Coverage, Human Edit Rate, and Subjective score are explicitly exempt (parent freeze + `manual-qa.md` §2: H checks system behavior, not taste; never hand-score). Compression counts are recorded as behavior signal (final-size sanity), not quality.

```text
# Selection Evaluation (stability-only)
Date: pending (user-run) / Build: pending / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: H — Large Library Stress (1,000 / 3,000 / 5,000)
Input: pending (record each scale attempted: 1,000 / 3,000 / 5,000) / Final: pending / Compression: pending (behavior signal only)
MUST_KEEP total / selected / recall: EXEMPT (stability-only; never hand-scored)
Selected MUST_KEEP / ACCEPTABLE / REJECT: EXEMPT (stability-only; never hand-scored)
Good rate: EXEMPT / Bad-pick rate: EXEMPT
Clusters judged / leakage / best-shot accuracy: EXEMPT
Key moments total / covered / coverage: EXEMPT
User removals / add-backs: EXEMPT
Stability observations (§5.4 + §7.3 1,000-photo check): pending per scale — run starts; progress moves; UI stays alive; heat stays sane; no crash/OS kill/hang; cancel at ~25% / ~50% / ~90% responsive with memory cleared and restartable; counts logged (session start, input, analyzed/skipped, cluster/moment, shortlist/final, stage timing, cancel, load errors per §5.4)
Top failures: pending (system-behavior tags only if observed; no §7.2 taste tags)
Notes: pending (device per scale incl. older device when available for memory/heat; SIMULATOR-ONLY numbers never recorded here)
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```

### Row Golden — Annotated reference (200–500, regression reference)

Blocked on the `mini-017a` label audit: labels are still `pending`, so no run values can be measured against them yet (annotation per §3.2 must come first). The block below records the full §8.2 shape with values `pending`.

```text
# Selection Evaluation
Date: pending (user-run, after Golden annotation) / Build: pending / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: Golden — Annotated reference (200–500)
Input: pending / Final: pending / Compression: pending (track only, no target)
MUST_KEEP total / selected / recall: pending / pending / pending (denominator: total MUST_KEEP once annotated)
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending
Good rate: pending / Bad-pick rate: pending
Clusters judged / leakage / best-shot accuracy: pending / pending / pending
Key moments total / covered / coverage: pending / pending / pending
User removals / add-backs: pending / pending
Top failures: pending (§7.2 vocabulary; side-by-side per §6.2 on later changes: only-in-each, cluster-pick changes, lost moments, balance shift)
Notes: pending (sets stay stable across runs; never retuned to fit the algorithm)
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```

## Constraint record

- No scoring, threshold, weight, config, version, or QA-policy change (frozen versions re-verified in code on this branch; this diff touches `features/mini-017b.md` only).
- No Simulator numbers recorded or presented as pipeline proof; none were collected (no-device constraint).
- No H hand-scoring: Row H exempts every taste metric explicitly.
- No missing required fields: every row carries Date / Build / Config / Dataset, Input / Final, all nine metric slots or explicit H exemptions, top failures with §7.2 tag vocabulary, Notes, Regression, and `Decision: Neutral (baseline)` — with run-dependent values honestly `pending`.
- No test targets or `*Test*.swift` files (repo policy).

## Handoff

State `blocked` (nine §8.2 row blocks templated in §§ Baseline runs with run-dependent values honestly `pending`; second in merge order; ledger input merged via `0967d2d`). Commit: branch `tungxuan1656/mini-017b-runs` (hash in PR / worker_done). Evidence: this file §§ Ledger input / Devices / Baseline runs / Constraint record; `./init.sh` PASS (format PASS, swiftlint --strict PASS, BUILD SUCCEEDED, SKIP [test] per repo policy); `git diff --name-only` = `features/mini-017b.md` only, no `apps/` path. Blockers: user-run physical measurement required — no physical-device operations permitted (user constraint 2026-09-16); Golden annotation still `pending` per `mini-017a` audit; nothing invented. Parent owner's next integration action: review this file (reproducibility of row shapes, no `apps/` diff, H exemptions, Neutral decisions), merge after gate, then dispatch `mini-017c`.
