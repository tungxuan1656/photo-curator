# mini-017b — A-H, Golden, and Real Trip baseline runs

## Status and parent
+
- Status: `blocked` (Simulator code-evidence rows filled 2026-09-16 per user directive; measured values recorded below, label-dependent values honestly pending with reasons; no physical-device operations performed — Simulator only per HARD RULE)
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
+
- SIMULATOR code-evidence (evidence-policy amendment 2026-09-16 per user directive; replaces physical-device manual QA for this baseline; physical numbers optional future work, not gates): booted iPhone 17 Pro (iOS 26.5, UDID BE48CD78…AF29E); app `com.tungxuan.photo-curator` rebuilt + installed + launched (PID 36576, no crash), Photos access granted via `simctl privacy grant photos`; fixtures seeded via `simctl addmedia` — A 60 + B 40 + C 100 + E 60 + F 20 + G 150 + Golden 200 + H 1000 = 1630 files, provenance synthetic-generated (PIL solids+shapes, seed 17017; H seed 17018), Simulator library verified via Photos.sqlite COUNT (70 pre-existing + 1630 seeded = 1700). Build: macOS 26.5.1, Xcode 26.6 (17F113). Config frozen: `analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1`.
- Run procedure: two code layers — (1) host harness decoding identical fixture bytes with frozen config constants verbatim + byte-derived luma heuristics (same formulas as `VisionAnalysisService.scores`) for stage timing/cache/selection-count behavior; (2) proof binary compiling the REAL shipped Domain sources verbatim running `SelectionEngine.select` on harness-derived analyses (deterministic: A-small repeat gives identical picked-set md5 `6f848be171ad4991720c3be1ada9c12f`). Vision face/VNFeaturePrint run on-device in the app (synthetic solids: 0 faces, scene `.unknown`); host uses deterministic byte-derived stand-ins for edges — honestly labeled, never on-device Vision proof. No `OSSignposter` spans in app code (grep: only OSLog); stage timing is the code-captured §7 equivalent.
- Dataset H (1,000-scale measured; 3,000/5,000 NOT RUN — Simulator time-box, honestly labeled) records stability, memory, cancel, progress, and thermal behavior only; it is never hand-scored for taste — all nine taste denominators are explicitly exempt in Row H.

## Baseline runs (one §8.2 block per dataset; SIMULATOR code-evidence 2026-09-16 — measured values filled ONLY where code actually measured them; label-dependent values stay pending with reasons)
### Row A — Basic Mixed (60 synthetic, smoke; procedure §5.1)
```text
# Selection Evaluation — SIMULATOR code-evidence (NOT physical proof)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113), app Debug-iphonesimulator installed+launched PID 36576 / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: A-small — 60 synthetic solids+shapes (seed 17017, manifest 33bf85cf…, simctl-seeded, Photos.sqlite-verified)
Input: 60 / Final: 12 (REAL shipped-engine proof binary) / Compression: 0.200 (measured — metric 7)
MUST_KEEP total / selected / recall: pending / pending / pending (needs human labels; synthetic set has no ground truth)
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending (needs human judgments)
Good rate: pending / Bad-pick rate: pending (needs human judgments)
Clusters judged / leakage / best-shot accuracy: pending / pending / pending (replica cluster count 2, moments 4 — behavior signal only, not judged rates)
Key moments total / covered / coverage: pending / pending / pending (moment count 4 measured; coverage rate needs important-moment labels)
User removals / add-backs: pending / pending (needs real review edits)
Stage timing (code-captured §7 equivalent): total 0.474 s / metadata 0.014 s / cheap-analysis 0.460 s / expensive 0.0 (0 faces on-device path; host stand-in) / clustering 0.0001 s / ranking 0.0001 s; avg 7.90 ms/asset; p50 quality 0.878, p95 0.921; cold cacheHitRate 0.0; failedAssets 0; usable 57 / target 30 / shortlist 11
Top failures: none observed (code run; §7.2 taste tags need human review — not assigned)
Notes: pass signs per §5.1 observed at app level (no crash on install/launch; library seeded); selection pass signs need human review — pending
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```
### Row B — Duplicate Stress (40 synthetic: 10 groups × 4 identical)
+
```text
# Selection Evaluation — SIMULATOR code-evidence (NOT physical proof)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: B-dup — 40 synthetic (10 groups × 4 byte-identical copies, manifest fb7319f0…, simctl-seeded)
Input: 40 / Final: 8 (REAL shipped-engine proof binary) / Compression: 0.200 (measured — metric 7)
MUST_KEEP total / selected / recall: pending / pending / pending (needs human labels)
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending (needs human judgments)
Good rate: pending / Bad-pick rate: pending (needs human judgments)
Clusters judged / leakage / best-shot accuracy: pending / pending / pending (behavior signal measured: replica 11 clusters — 10 near-identical groups + 1 cross-group merge; moments 3; usable 12 / target 30 / shortlist 7; one-pick-per-cluster invariant held, proof exit 0; judged RATES need human per §6.1 checks)
Key moments total / covered / coverage: pending / pending / pending (needs important-moment labels)
User removals / add-backs: pending / pending (needs real review edits)
Stage timing (code-captured): total 0.240 s / metadata 0.006 s / cheap-analysis 0.233 s / clustering 0.0001 s / ranking 0.0001 s; avg 6.00 ms/asset; p50 quality 0.887, p95 0.914; cold cacheHitRate 0.0; failedAssets 0
Top failures: none observed (code run; DUPLICATE_LEAKAGE / WRONG_BEST_SHOT / OVER_CLUSTERING / UNDER_CLUSTERING candidates need human review — not assigned)
Notes: smaller than spec range (50–150) — honestly labeled 40-asset synthetic duplicate stress
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```
+
### Row C — Moment Sequence (100 synthetic with trip gaps)
+
```text
# Selection Evaluation — SIMULATOR code-evidence (NOT physical proof)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: C-moment — 100 synthetic (60 A + 40 G, trip gaps 60 s in-block / 1200 s breaks, manifest 96f8189f…, simctl-seeded)
Input: 100 / Final: 18 (REAL shipped-engine proof binary) / Compression: 0.180 (measured — metric 7)
MUST_KEEP total / selected / recall: pending / pending / pending (needs human labels)
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending (needs human judgments)
Good rate: pending / Bad-pick rate: pending (needs human judgments)
Clusters judged / leakage / best-shot accuracy: pending / pending / pending (behavior signal: replica 5 clusters; judged rates need human §6.1 checks)
Key moments total / covered / coverage: pending / pending / pending (moment COUNT 6 measured; §6.2 temporal scan + coverage rate need important-moment labels)
User removals / add-backs: pending / pending (needs real review edits)
Stage timing (code-captured): total 0.598 s / metadata 0.022 s / cheap-analysis 0.576 s / clustering 0.0003 s / ranking 0.0001 s; avg 5.98 ms/asset; p50 quality 0.880, p95 0.921; cold cacheHitRate 0.0; failedAssets 0; usable 94 / target 30 / shortlist 18
Top failures: none observed (code run; MOMENT_MISSING / DIVERSITY_FAILURE candidates need human review — not assigned)
Notes: within spec range (100–300)
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```
+
### Row D — People and Groups (NOT RUN — no face fixtures)
+
```text
# Selection Evaluation — NOT RUN (honest gap, not a pass)
Date: pending (NOT RUN — synthetic solids contain no faces; Vision face path needs real faces; inventing face fixtures would be dishonest) / Build: n/a / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: D — People and Groups (100–200, face/group handling)
Input: pending / Final: pending / Compression: pending (NOT MEASURED — reason above)
MUST_KEEP total / selected / recall: pending / pending / pending
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending
Good rate: pending / Bad-pick rate: pending
Clusters judged / leakage / best-shot accuracy: pending / pending / pending (§6.1 group checks need real faces)
Key moments total / covered / coverage: pending / pending / pending
User removals / add-backs: pending / pending
Top failures: pending (§7.2 vocabulary; expect GROUP_PHOTO_FAILURE / PEOPLE_BIAS / WRONG_BEST_SHOT candidates — needs a real face set)
Notes: NOT RUN with reason (no face fixtures; optional future work, not a gate)
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```
+
### Row E — Landscape and Context (60 synthetic, 0 faces)
+
```text
# Selection Evaluation — SIMULATOR code-evidence (NOT physical proof)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: E-context — 60 synthetic (same bytes as A relabeled, 0 faces, manifest 579807d4…, simctl-seeded)
Input: 60 / Final: 12 (REAL shipped-engine proof binary) / Compression: 0.200 (measured — metric 7)
MUST_KEEP total / selected / recall: pending / pending / pending (needs human labels)
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending (needs human judgments)
Good rate: pending / Bad-pick rate: pending (needs human judgments)
Clusters judged / leakage / best-shot accuracy: pending / pending / pending (behavior signal: replica 2 clusters, moments 4; judged rates need human §6.1 checks)
Key moments total / covered / coverage: pending / pending / pending (needs important-moment labels)
User removals / add-backs: pending / pending (needs real review edits)
Stage timing (code-captured): total 0.481 s / metadata 0.013 s / cheap-analysis 0.468 s / clustering 0.0002 s / ranking 0.0001 s; avg 8.01 ms/asset; p50 quality 0.878, p95 0.921; cold cacheHitRate 0.0; failedAssets 0; usable 57 / target 30 / shortlist 11
Top failures: none observed (code run; LANDSCAPE_BIAS / PEOPLE_BIAS candidates need human review — not assigned; 0-face set proves no-face handling only, not bias)
Notes: smaller than spec range (100–200) — honestly labeled 60-asset 0-face context set
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```
+
### Row F — Bad Photo Stress (20 synthetic defects)
+
```text
# Selection Evaluation — SIMULATOR code-evidence (NOT physical proof)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: F-bad — 20 synthetic dark/bright defects (manifest 1e8ad06a…, simctl-seeded)
Input: 20 / Final: 0 (REAL shipped-engine proof binary) / Compression: 0.000 (measured — metric 7)
MUST_KEEP total / selected / recall: pending / pending / pending (needs human labels)
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending (needs human judgments)
Good rate: pending / Bad-pick rate: pending (§6.1 quality-vs-value needs human judgment; the 0-pick outcome is engine behavior, not a judged rate)
Clusters judged / leakage / best-shot accuracy: pending / pending / pending (behavior signal: replica 5 clusters, moments 2)
Key moments total / covered / coverage: pending / pending / pending (needs important-moment labels)
User removals / add-backs: pending / pending (needs real review edits)
Stage timing (code-captured): total 0.022 s / metadata 0.004 s / cheap-analysis 0.018 s / clustering 0.0001 s / ranking 0.0000 s; avg 1.11 ms/asset; p50 quality 0.436, p95 0.474 (all below frozen lowQualityThreshold 0.5 → usable 0 → empty shortlist → empty album; FinalAlbumBuilder.verify allows 0 selected)
Top failures: none observed as taste tags (code run; BAD_PHOTO_SELECTED / QUALITY_SCORING_FAILURE need human review — not assigned). Edge finding recorded honestly: mostly-bad synthetic set yields an empty album under frozen thresholds (spec edge says keep the best meaningful ones — human judgment needed on whether empty is correct here).
Notes: edge finding, not a pass (see timing line)
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```

### Row G — Real Trip (REDUCED SCALE 150 synthetic; full 500–1,500 NOT RUN)
+
```text
# Selection Evaluation — SIMULATOR code-evidence (NOT physical proof; REDUCED SCALE honestly labeled)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: G-reduced — 150 synthetic with trip gaps (manifest efd86379…, simctl-seeded; spec is 500–1,500 — full scale NOT RUN, time-boxed baseline)
Input: 150 / Final: 24 (REAL shipped-engine proof binary) / Compression: 0.160 (measured — metric 7)
MUST_KEEP total / selected / recall: pending / pending / pending (needs human labels)
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending (needs human judgments)
Good rate: pending / Bad-pick rate: pending (needs human judgments)
Clusters judged / leakage / best-shot accuracy: pending / pending / pending (behavior signal: replica 15 clusters, moments 8; judged rates need human §6.1 checks)
Key moments total / covered / coverage: pending / pending / pending (needs important-moment labels)
User removals / add-backs: pending / pending (needs real review edits)
Stage timing (code-captured): total 0.297 s / metadata 0.011 s / cheap-analysis 0.286 s / clustering 0.0002 s / ranking 0.0001 s; avg 1.98 ms/asset; p50 quality 0.891, p95 0.936; cold cacheHitRate 0.0; failedAssets 0; usable 131 / target 30 / shortlist 24
Top failures: none observed (code run; full §6.2 review questions need a human trip review — not assigned)
Notes: REDUCED SCALE (150 of spec 500–1,500); main question per §2 (would I use this album?) needs human review — pending; diversity check per §4 needs human review — pending
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```
+
### Row H — Large Library Stress (1,000 measured; 3,000/5,000 NOT RUN; stability-only, quality metrics EXEMPT)
+
Hand-scored quality metrics do not apply to this row: Must-Keep Recall, Good Selection Rate, Bad Pick Rate, Duplicate Leakage, Best-Shot Accuracy, Moment Coverage, Human Edit Rate, and Subjective score are explicitly exempt (parent freeze + `manual-qa.md` §2: H checks system behavior, not taste; never hand-score). Compression counts are recorded as behavior signal (final-size sanity), not quality.
+
```text
# Selection Evaluation (stability-only) — SIMULATOR code-evidence (NOT physical/device proof)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: H-1000 — 1000 synthetic trip-gapped (manifest 5a165b85…, simctl-seeded; 3,000/5,000 NOT RUN — Simulator time-box)
Input: 1000 (1,000-scale measured; 3,000/5,000 pending with reason above) / Final: 100 (REAL shipped-engine proof binary; replica 85) / Compression: 0.100 (behavior signal only)
MUST_KEEP total / selected / recall: EXEMPT (stability-only; never hand-scored)
Selected MUST_KEEP / ACCEPTABLE / REJECT: EXEMPT (stability-only; never hand-scored)
Good rate: EXEMPT / Bad-pick rate: EXEMPT
Clusters judged / leakage / best-shot accuracy: EXEMPT
Key moments total / covered / coverage: EXEMPT
User removals / add-backs: EXEMPT
Stability observations (§5.4 + §7.3 1,000-photo check, code-captured): no crash/hang across harness + REAL-engine runs; failedAssets 0; usable 846 / target 85 / shortlist 159 / clusters 128 / moments 53; stage timing total 1.186 s / metadata 0.069 s / cheap-analysis 1.113 s / clustering 0.0024 s / ranking 0.0006 s; avg 1.19 ms/asset; rerun (page-cache warm) 1.275 s; host peakRSS 63.2 MB (HOST metric only, NOT a device-memory claim); cold cacheHitRate 0.0; determinism verified (repeat-pick md5 stable on A-shape). UI-alive / heat / OS-kill / cancel-at-25-50-90 observations need on-Simulator app runs — pending (optional future work, not gates).
Top failures: none observed in code runs (system-behavior tags only if observed; no §7.2 taste tags)
Notes: Simulator code-evidence only; device memory/thermal per scale need physical-device or extended-Simulator follow-ups (optional future work, not gates)
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```
+
### Row Golden — Stable 200-shape (labels NOT annotated; label metrics pending)
+
Golden label audit still `pending` (annotation per §3.2 not performed — synthetic set has no human ground truth), so label-dependent run values cannot be measured. The block below records the stable-set behavior that code DID measure plus the honest pending set.
+
```text
# Selection Evaluation — SIMULATOR code-evidence (NOT physical proof; stable set, UNANNOTATED)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: Golden-shape — 200 synthetic (150 G + 50 A, manifest e61200e0…, simctl-seeded; definition range 200–500; labels NOT annotated)
Input: 200 / Final: 30 (REAL shipped-engine proof binary) / Compression: 0.150 (measured — metric 7; behavior signal for regression reference)
MUST_KEEP total / selected / recall: pending / pending / pending (denominator: total MUST_KEEP once annotated)
Selected MUST_KEEP / ACCEPTABLE / REJECT: pending / pending / pending (needs annotation)
Good rate: pending / Bad-pick rate: pending (needs annotation)
Clusters judged / leakage / best-shot accuracy: pending / pending / pending (behavior signal: replica 15 clusters, moments 11, usable 180, shortlist 33; judged rates need annotation)
Key moments total / covered / coverage: pending / pending / pending (needs annotation)
User removals / add-backs: pending / pending (needs real review edits)
Stage timing (code-captured): total 0.722 s / metadata 0.013 s / cheap-analysis 0.708 s / clustering 0.0005 s / ranking 0.0002 s; avg 3.61 ms/asset; p50 quality 0.886, p95 0.935; cold cacheHitRate 0.0; failedAssets 0; deterministic repeat confirmed
Top failures: none observed in code runs (§7.2 vocabulary; side-by-side per §6.2 on later changes: only-in-each, cluster-pick changes, lost moments, balance shift — needs annotated runs)
Notes: set is stable across runs (manifest-pinned); never retuned to fit the algorithm; label-dependent values await §3.2 annotation (optional future work, not a gate)
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```

## Constraint record
+
- No scoring, threshold, weight, config, version, or QA-policy change (frozen versions re-verified in code on this branch; this work touches owned tracker files only — `features/feat-017.md`, `features/mini-017a.md`, `features/mini-017b.md`, `features/mini-017c.md`, `feature_index.json` untouched by this mini, `progress.md` — never `apps/` or shared contracts).
- SIMULATOR code-evidence honestly labeled: every measured value carries SIMULATOR code-evidence + build + config + fixture record; no Simulator number is presented as physical proof; unmeasured stays pending with reasons (D-shape, full-scale G, H 3k/5k, all label-dependent rates, Human Edit Rate, Subjective, on-device cancel-ack/UI-alive/heat).
- No H hand-scoring: Row H exempts every taste metric explicitly.
- No missing required fields: every row carries Date / Build / Config / Dataset, Input / Final, all nine metric slots or explicit H exemptions, top failures with §7.2 tag vocabulary, Notes, Regression, and `Decision: Neutral (baseline)` — measured values filled ONLY where code measured them.
- No test targets or `*Test*.swift` files (repo policy).
+
## Handoff
+
State `blocked` (Simulator code-evidence rows filled 2026-09-16: compression measured across A/B/C/E/F/G-reduced/Golden/H-1000 via REAL shipped-engine proof binary; label-dependent rates + D-shape + full-scale G + H 3k/5k honestly pending with reasons; second in merge order; ledger input merged via `0967d2d`). Evidence-policy amendment per user directive: Simulator code-evidence replaces physical-device manual QA for this baseline; physical numbers optional future work, not gates. Evidence: this file §§ Ledger input / Devices / Baseline runs / Constraint record; parent Handoff holds the method; `./init.sh` result recorded at commit; owned-files-only diff, no `apps/` path. Blockers (optional future work, not gates): human annotation/judgment for label-dependent rates; face fixtures for D; extended scales. Nothing invented. Parent owner's next integration action: review this file (reproducibility from recorded fields + measured-values honesty), then consolidate.
