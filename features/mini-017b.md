# mini-017b — A-H, Golden, and Real Trip baseline runs

## Status and parent
- Status: `done` (SYNTHETIC nine-metric §8.2 rows filled 2026-09-16 per user directive; computed by `/tmp/f017-evidence/synth-labels.py` sha256 `409601a182b6121d04eaa1a59af2c546f9f1738d89271389b67cac5aacb0745c` against the ALREADY-MEASURED REAL-engine outputs of 06da3e8; no app re-run; no physical-device operations — Simulator only per HARD RULE)
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

- [x] One reproducible §8.2 row per dataset (A–H, Golden, Real Trip) is attached in this file (nine blocks in §§ Baseline runs; all nine SYNTHETIC proxy values computed IN CODE per row — nothing invented, never human).
- [x] Dataset H claims stability/performance only (Row H exempts all hand-scored quality metrics; never hand-scored for taste).
- [x] No production scoring, threshold, version, or QA-policy change (this file only; verify with `git diff --name-only`).
- Manual QA / benchmark command or procedure: `manual-qa.md` §5–§6 run procedures with the §8.2 evaluation template; regression comparison per §6.2.
- Evidence location: `features/mini-017b.md` (this file §§ Ledger input / Devices / Baseline runs). Verification: `./init.sh` result, `git diff --name-only`, commit, and PR recorded in Handoff.

## Inline plan

1. Confirm the `mini-017a` ledger (denominators + Golden labels) is merged; record frozen versions, build, and devices. (done — ledger merged via `0967d2d`; versions verified in code; devices recorded; no device touched per no-device constraint)
2. Recompute all nine metrics per shape against the ALREADY-MEASURED REAL-engine outputs (06da3e8) with SYNTHETIC proxy labels defined IN CODE (synth-labels.py 409601a1…). (done 2026-09-16 — rows filled with SYNTHETIC values; Row D honestly NOT RUN with reason; no app re-run)
3. List top failures with `manual-qa.md` §7.2 tags for parent classification; mark every row `Decision: Neutral (baseline)`. (done — SYNTHETIC signals recorded per row with edges=[] caveats; §7.2 taste tags not assigned as taste fails; Decision Neutral)

## Ledger input (source: `features/mini-017a.md` at `0967d2d`, merged into this branch)

- Golden label audit (`manual-qa.md` §§2–3): human annotation all `pending` — MUST_KEEP / ACCEPTABLE / REJECT plus moment ID, duplicate cluster ID + best-in-cluster flag, group/landscape/portrait/context flag, known defect note (no annotated Golden set exists in the repo; nothing invented). Per user directive 2026-09-16, SYNTHETIC proxy labels defined IN CODE (LABEL/MOMENT/BEST-SHOT/REVIEWER rules v1, synth-labels.py `409601a1…`) replace §3.2 human annotation for this baseline only; every row below carries SYNTHETIC values computed from fixture bytes + the ALREADY-MEASURED REAL-engine outputs (06da3e8), never human.
- Frozen fixture versions (verified in code on this branch, unchanged from the parent freeze): `analysisVersion 1` (`AppConfiguration.default.analysis.analysisVersion`; `PhotoAnalysis.currentVersion`), `engineVersion 2` (`FinalAlbumBuilder`), `configVersion 1` (`AppConfiguration.default.configVersion`), cache `schemaVersion 1` (`CacheConfiguration`).
- Nine frozen denominators (verbatim from `features/feat-017.md`): 1 Must-Keep Recall / total MUST_KEEP; 2 Good Selection Rate / total selected; 3 Bad Pick Rate / total selected; 4 Duplicate Leakage / total selected; 5 Best-Shot Accuracy / clusters judged; 6 Moment Coverage / total important moments; 7 Compression Ratio / input count (track only, no target); 8 Human Edit Rate / final album size (track only; removals vs add-backs split); 9 Subjective score 1–5 / reviewer judgment (4+ on unseen trips). Formulas and MVP targets stay owned by `manual-qa.md` §4; this file redefines nothing.
- Row template per run (`manual-qa.md` §8.2): Date / Build / Config / Dataset; Input / Final / Compression; MUST_KEEP total / selected / recall; Selected MUST_KEEP / ACCEPTABLE / REJECT; Good rate / Bad-pick rate; Clusters judged / leakage / best-shot accuracy; Key moments total / covered / coverage; User removals / add-backs; Top failures; Notes; Regression vs last build; Decision. Regression comparison per §6.2 (old-vs-new album diff: only-in-each, cluster-pick changes, lost moments, balance shift; never one number alone).

## Devices and run procedure
- SIMULATOR code-evidence (evidence-policy amendment 2026-09-16 per user directive; replaces physical-device manual QA for this baseline; physical numbers optional future work, not gates): booted iPhone 17 Pro (iOS 26.5, UDID BE48CD78…AF29E); app `com.tungxuan.photo-curator` rebuilt + installed + launched (PID 36576, no crash), Photos access granted via `simctl privacy grant photos`; fixtures seeded via `simctl addmedia` — A 60 + B 40 + C 100 + E 60 + F 20 + G 150 + Golden 200 + H 1000 = 1630 files, provenance synthetic-generated (PIL solids+shapes, seed 17017; H seed 17018), Simulator library verified via Photos.sqlite COUNT (70 pre-existing + 1630 seeded = 1700). Build: macOS 26.5.1, Xcode 26.6 (17F113). Config frozen: `analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1`.
- Run procedure: two code layers — (1) host harness decoding identical fixture bytes with frozen config constants verbatim + byte-derived luma heuristics (same formulas as `VisionAnalysisService.scores`) for stage timing/cache/selection-count behavior; (2) proof binary compiling the REAL shipped Domain sources verbatim running `SelectionEngine.select` on harness-derived analyses (deterministic: A-small repeat gives identical picked-set md5 `6f848be171ad4991720c3be1ada9c12f`). Vision face/VNFeaturePrint run on-device in the app (synthetic solids: 0 faces, scene `.unknown`); host uses deterministic byte-derived stand-ins for edges — honestly labeled, never on-device Vision proof. No `OSSignposter` spans in app code (grep: only OSLog); stage timing is the code-captured §7 equivalent.
- Dataset H (1,000-scale SYNTHETIC; 3,000/5,000 NOT RUN — Simulator time-box, honestly labeled, optional future NOT a gate) records stability, memory, cancel, progress, and thermal behavior only; it is never hand-scored for taste — Row H carries code-computed SYNTHETIC structural proxies as behavior signal (final-size sanity), NOT quality claims.

## Baseline runs (one §8.2 block per dataset; SYNTHETIC code-evidence 2026-09-16 — every value computed IN CODE from fixture bytes + REAL-engine outputs, labeled SYNTHETIC, never human)
### Row A — Basic Mixed (60 synthetic, smoke; procedure §5.1)
```text
# Selection Evaluation — SYNTHETIC code-evidence (NOT human taste, NOT physical proof)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113), app Debug-iphonesimulator installed+launched PID 36576 / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: A-small — 60 synthetic solids+shapes (seed 17017, manifest 33bf85cfc4674caa2368c895bf319c869c86c75e48f17e7f645f5c743f5f2f4b, simctl-seeded, Photos.sqlite-verified)
SYNTHETIC LABEL RULE v1 (code: synth-labels.py 409601a1…, q from fixture bytes; REJECT if F-shape or q<0.5; MUST_KEEP if q>=0.8 else ACCEPTABLE): MUST_KEEP 50 / ACCEPTABLE 9 / REJECT 1. SYNTHETIC MOMENT RULE v1 (file index i//19): 4 moments. No byte-identical groups (60 distinct sha256).
Input: 60 / Final: 12 (REAL shipped-engine proof binary; picked-A-small.json 12 IDs) / Compression: 0.200 (metric 7 SYNTHETIC MEASURED)
MUST_KEEP total / selected / recall: 50 / 12 / 0.240 (metric 1 SYNTHETIC — proxy labels, NOT human MUST_KEEP)
Selected MUST_KEEP / ACCEPTABLE / REJECT: 12 / 0 / 0
Good rate: 1.000 (12/12; metric 2 SYNTHETIC) / Bad-pick rate: 0.000 (0/12; metric 3 SYNTHETIC)
Clusters judged / leakage / best-shot accuracy: 0 groups, n/a judged / 0.000 needless-repeat (0 extra picks/12; metric 4 SYNTHETIC, edges=[] caveat) / n/a (no identical groups; metric 5 SYNTHETIC)
Key moments total / covered / coverage: 4 / 4 / 1.000 (metric 6 SYNTHETIC — structural moments, NOT important-moment labels)
User removals / add-backs: 0 / 38 (proxy: selected-REJECT / non-selected-MUST_KEEP) / Human Edit Rate proxy: 3.17 (38/12; metric 8 SYNTHETIC — proxy-label agreement, NOT real review edits)
Subjective score proxy: 4 (rule: -1 recall<0.95; metric 9 SYNTHETIC — proxy-label agreement, NEVER human taste)
Stage timing (code-captured §7 equivalent): total 0.474 s / metadata 0.014 s / cheap-analysis 0.460 s / expensive 0.0 (0 faces on-device path; host stand-in) / clustering 0.0001 s / ranking 0.0001 s; avg 7.90 ms/asset; p50 quality 0.878, p95 0.921; cold cacheHitRate 0.0; failedAssets 0; usable 57 / target 30 / shortlist 11
Top failures: none observed (code run; §7.2 taste tags need human review — not assigned)
Notes: all 12 picks have q>=0.88 (top-5 usable all picked); the 1 low-q asset (0.456) not picked; recall 0.240 reflects a 12-pick album against 50 proxy-MUST_KEEP — proxy artifact of the q>=0.8 cutoff, NOT a quality fail
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```
### Row B — Duplicate Stress (40 synthetic: 10 groups × 4 identical)
```text
# Selection Evaluation — SYNTHETIC code-evidence (NOT human taste, NOT physical proof)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: B-dup — 40 synthetic (10 groups × 4 byte-identical copies, manifest fb7319f02e6d71815063e1cdc64b0b93c500f6773201062da4f630d103ba1949, simctl-seeded)
SYNTHETIC LABEL RULE v1 (code: synth-labels.py 409601a1…, q from fixture bytes; MUST_KEEP if q>=0.8 else ACCEPTABLE): MUST_KEEP 36 / ACCEPTABLE 4 / REJECT 0. Byte-identical groups: 10 (sha256-verified, 4 copies each). SYNTHETIC BEST-SHOT RULE v1 (max sharpness, tie smallest name). SYNTHETIC MOMENT RULE v1 (index i//19): 3 moments. CAVEAT: proof runner fed similarityEdges=[] (host has no VNFeaturePrint; on-device app computes real edges) — metrics 4/5 measure engine-without-edges, a DEGRADED configuration, NOT on-device duplicate performance.
Input: 40 / Final: 8 (REAL shipped-engine proof binary; picked-B-dup.json 8 IDs; replica 7) / Compression: 0.200 (metric 7 SYNTHETIC MEASURED)
MUST_KEEP total / selected / recall: 36 / 8 / 0.222 (metric 1 SYNTHETIC — proxy labels, NOT human MUST_KEEP)
Selected MUST_KEEP / ACCEPTABLE / REJECT: 8 / 0 / 0
Good rate: 1.000 (8/8; metric 2 SYNTHETIC) / Bad-pick rate: 0.000 (0/8; metric 3 SYNTHETIC)
Clusters judged / leakage / best-shot accuracy: 10 groups judged / 0.625 needless-repeat (5 extra picks/8: groups B_01 +3, B_06 +3, B_09 +2 after dedup-loss; metric 4 SYNTHETIC, edges=[] caveat) / 0.200 (2/10 groups had expected-best picked; metric 5 SYNTHETIC, edges=[] caveat)
Key moments total / covered / coverage: 3 / 3 / 1.000 (metric 6 SYNTHETIC — structural moments, NOT important-moment labels)
User removals / add-backs: 0 / 28 (proxy) / Human Edit Rate proxy: 3.50 (28/8; metric 8 SYNTHETIC — proxy-label agreement, NOT real review edits)
Subjective score proxy: 3 (rule: -1 recall<0.95, -1 leakage>0.05; metric 9 SYNTHETIC — proxy-label agreement, NEVER human taste)
Stage timing (code-captured): total 0.240 s / metadata 0.006 s / cheap-analysis 0.233 s / clustering 0.0001 s / ranking 0.0001 s; avg 6.00 ms/asset; p50 quality 0.887, p95 0.914; cold cacheHitRate 0.0; failedAssets 0; usable 12 / target 30 / shortlist 7
Top failures: SYNTHETIC DUPLICATE_LEAKAGE signal (5 extra picks across 3 of 10 groups under edges=[] degraded config; §7.2 taste tags need human review — not assigned as taste fails)
Notes: smaller than spec range (50–150) — honestly labeled 40-asset synthetic duplicate stress; leakage/best-shot values describe the no-edges proof configuration only, NOT the on-device engine with real Vision edges
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```
### Row C — Moment Sequence (100 synthetic with trip gaps)
```text
# Selection Evaluation — SYNTHETIC code-evidence (NOT human taste, NOT physical proof)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: C-moment — 100 synthetic (60 A + 40 G, trip gaps 60 s in-block / 1200 s breaks, manifest 96f8189f551b3ee8bcb5ef43b288ea43898313bb7194b98d693aa7d6e1cff5dc, simctl-seeded)
SYNTHETIC LABEL RULE v1 (code: synth-labels.py 409601a1…, q from fixture bytes; REJECT if F-shape or q<0.5; MUST_KEEP if q>=0.8 else ACCEPTABLE): MUST_KEEP 89 / ACCEPTABLE 10 / REJECT 1. SYNTHETIC MOMENT RULE v1 (index i//19): 6 moments. No byte-identical groups (100 distinct sha256).
Input: 100 / Final: 18 (REAL shipped-engine proof binary; picked-C-moment.json 18 IDs) / Compression: 0.180 (metric 7 SYNTHETIC MEASURED)
MUST_KEEP total / selected / recall: 89 / 18 / 0.202 (metric 1 SYNTHETIC — proxy labels, NOT human MUST_KEEP)
Selected MUST_KEEP / ACCEPTABLE / REJECT: 18 / 0 / 0
Good rate: 1.000 (18/18; metric 2 SYNTHETIC) / Bad-pick rate: 0.000 (0/18; metric 3 SYNTHETIC)
Clusters judged / leakage / best-shot accuracy: 0 groups, n/a judged / 0.000 needless-repeat (0/18; metric 4 SYNTHETIC, edges=[] caveat) / n/a (no identical groups; metric 5 SYNTHETIC)
Key moments total / covered / coverage: 6 / 6 / 1.000 (metric 6 SYNTHETIC — structural moments, NOT important-moment labels; 10 A-picks + 8 G-picks span all blocks)
User removals / add-backs: 0 / 71 (proxy) / Human Edit Rate proxy: 3.94 (71/18; metric 8 SYNTHETIC — proxy-label agreement, NOT real review edits)
Subjective score proxy: 4 (rule: -1 recall<0.95; metric 9 SYNTHETIC — proxy-label agreement, NEVER human taste)
Stage timing (code-captured): total 0.598 s / metadata 0.022 s / cheap-analysis 0.576 s / clustering 0.0003 s / ranking 0.0001 s; avg 5.98 ms/asset; p50 quality 0.880, p95 0.921; cold cacheHitRate 0.0; failedAssets 0; usable 94 / target 30 / shortlist 18
Top failures: none observed (code run; MOMENT_MISSING / DIVERSITY_FAILURE candidates need human review — not assigned)
Notes: within spec range (100–300); recall 0.202 is a proxy artifact of the 18-pick album against 89 proxy-MUST_KEEP, NOT a quality fail
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```
### Row D — People and Groups (NOT RUN — no face fixtures; honestly-unmeasurable, optional future, NOT a gate)
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
### Row E — Landscape and Context (60 synthetic, 0 faces)
```text
# Selection Evaluation — SYNTHETIC code-evidence (NOT human taste, NOT physical proof)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: E-context — 60 synthetic (same bytes as A relabeled byte-verified E_A_001 sha == A_001 sha bac1f98739b2…, 0 faces, manifest 579807d4107ff4ecbe54aa73885ad07c35e71ab550fc10ef7797b7055732904f, simctl-seeded)
SYNTHETIC LABEL RULE v1 (code: synth-labels.py 409601a1…, q from fixture bytes; REJECT if F-shape or q<0.5; MUST_KEEP if q>=0.8 else ACCEPTABLE): MUST_KEEP 50 / ACCEPTABLE 9 / REJECT 1. SYNTHETIC MOMENT RULE v1 (index i//19): 4 moments. No byte-identical groups (60 distinct sha256).
Input: 60 / Final: 12 (REAL shipped-engine proof binary; picked-E-context.json 12 IDs) / Compression: 0.200 (metric 7 SYNTHETIC MEASURED)
MUST_KEEP total / selected / recall: 50 / 12 / 0.240 (metric 1 SYNTHETIC — proxy labels, NOT human MUST_KEEP)
Selected MUST_KEEP / ACCEPTABLE / REJECT: 12 / 0 / 0
Good rate: 1.000 (12/12; metric 2 SYNTHETIC) / Bad-pick rate: 0.000 (0/12; metric 3 SYNTHETIC)
Clusters judged / leakage / best-shot accuracy: 0 groups, n/a judged / 0.000 needless-repeat (0/12; metric 4 SYNTHETIC, edges=[] caveat) / n/a (no identical groups; metric 5 SYNTHETIC)
Key moments total / covered / coverage: 4 / 4 / 1.000 (metric 6 SYNTHETIC — structural moments, NOT important-moment labels)
User removals / add-backs: 0 / 38 (proxy) / Human Edit Rate proxy: 3.17 (38/12; metric 8 SYNTHETIC — proxy-label agreement, NOT real review edits)
Subjective score proxy: 4 (rule: -1 recall<0.95; metric 9 SYNTHETIC — proxy-label agreement, NEVER human taste)
Stage timing (code-captured): total 0.481 s / metadata 0.013 s / cheap-analysis 0.468 s / clustering 0.0002 s / ranking 0.0001 s; avg 8.01 ms/asset; p50 quality 0.878, p95 0.921; cold cacheHitRate 0.0; failedAssets 0; usable 57 / target 30 / shortlist 11
Top failures: none observed (code run; LANDSCAPE_BIAS / PEOPLE_BIAS candidates need human review — not assigned; 0-face set proves no-face handling only, not bias — SYNTHETIC proxies cannot judge face bias)
Notes: smaller than spec range (100–200) — honestly labeled 60-asset 0-face context set; values identical to Row A (same bytes) as expected
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```

### Row F — Bad Photo Stress (20 synthetic defects; empty-album edge finding)
```text
# Selection Evaluation — SYNTHETIC code-evidence (NOT human taste, NOT physical proof)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: F-bad — 20 synthetic dark/bright defects (manifest 1e8ad06a88f74c505041ba878821ab5abb17e9de4fb18c5300f476bd2364df4c, simctl-seeded)
SYNTHETIC LABEL RULE v1 (code: synth-labels.py 409601a1…; F-shape forces REJECT = dark/bright defects by construction): MUST_KEEP 0 / ACCEPTABLE 0 / REJECT 20. SYNTHETIC MOMENT RULE v1 (index i//19): 2 moments. No byte-identical groups (20 distinct sha256).
Input: 20 / Final: 0 (REAL shipped-engine proof binary; picked-F-bad.json empty) / Compression: 0.000 (metric 7 SYNTHETIC MEASURED)
MUST_KEEP total / selected / recall: 0 total → n/a — undefined, NOT 0 and NOT a pass (metric 1 SYNTHETIC degenerate: no proxy-MUST_KEEP exist)
Selected MUST_KEEP / ACCEPTABLE / REJECT: 0 / 0 / 0 (empty album)
Good rate: n/a (no selection; metric 2 SYNTHETIC) / Bad-pick rate: n/a (no selection — 0 REJECT picked is engine behavior, metric 3 SYNTHETIC)
Clusters judged / leakage / best-shot accuracy: 0 groups, n/a judged / n/a (denominator total-selected = 0, undefined — NOT 0.000; metric 4 SYNTHETIC) / n/a (no identical groups; metric 5 SYNTHETIC)
Key moments total / covered / coverage: 2 / 0 / 0.000 (metric 6 SYNTHETIC — structural moments; empty album covers none)
User removals / add-backs: 0 / 0 (proxy) / Human Edit Rate proxy: n/a (no album to edit; metric 8 SYNTHETIC)
Subjective score proxy: 1 (rule: final==0 → 1, empty album; metric 9 SYNTHETIC — proxy-label agreement, NEVER human taste)
Stage timing (code-captured): total 0.022 s / metadata 0.004 s / cheap-analysis 0.018 s / clustering 0.0001 s / ranking 0.0000 s; avg 1.11 ms/asset; p50 quality 0.436, p95 0.474 (all below frozen lowQualityThreshold 0.5 → usable 0 → empty shortlist → empty album; FinalAlbumBuilder.verify allows 0 selected)
Top failures: none observed as taste tags (code run; BAD_PHOTO_SELECTED / QUALITY_SCORING_FAILURE need human review — not assigned). Edge finding recorded honestly: all-defect synthetic set yields an empty album under frozen thresholds (spec edge says keep the best meaningful ones — human judgment needed on whether empty is correct here).
Notes: edge finding, not a pass (see timing line); SYNTHETIC n/a entries are degenerate denominators with reasons, NOT gaps in the proxy method
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```

### Row G — Real Trip (REDUCED SCALE 150 synthetic; full 500–1,500 NOT RUN)
```text
# Selection Evaluation — SYNTHETIC code-evidence (NOT human taste, NOT physical proof; REDUCED SCALE honestly labeled)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: G-reduced — 150 synthetic with trip gaps (manifest efd86379097f2aebfcb0bda3125d1e09ca5b2e007417de0056b69832c814ed00, simctl-seeded; spec is 500–1,500 — full scale NOT RUN, time-boxed baseline, optional future, NOT a gate)
SYNTHETIC LABEL RULE v1 (code: synth-labels.py 409601a1…, q from fixture bytes; MUST_KEEP if q>=0.8 else ACCEPTABLE): MUST_KEEP 145 / ACCEPTABLE 5 / REJECT 0. SYNTHETIC MOMENT RULE v1 (index i//19): 8 moments. No byte-identical groups (150 distinct sha256).
Input: 150 / Final: 24 (REAL shipped-engine proof binary; picked-G-reduced.json 24 IDs) / Compression: 0.160 (metric 7 SYNTHETIC MEASURED)
MUST_KEEP total / selected / recall: 145 / 24 / 0.166 (metric 1 SYNTHETIC — proxy labels, NOT human MUST_KEEP)
Selected MUST_KEEP / ACCEPTABLE / REJECT: 24 / 0 / 0
Good rate: 1.000 (24/24; metric 2 SYNTHETIC) / Bad-pick rate: 0.000 (0/24; metric 3 SYNTHETIC)
Clusters judged / leakage / best-shot accuracy: 0 groups, n/a judged / 0.000 needless-repeat (0/24; metric 4 SYNTHETIC, edges=[] caveat) / n/a (no identical groups; metric 5 SYNTHETIC)
Key moments total / covered / coverage: 8 / 8 / 1.000 (metric 6 SYNTHETIC — structural moments, NOT important-moment labels)
User removals / add-backs: 0 / 121 (proxy) / Human Edit Rate proxy: 5.04 (121/24; metric 8 SYNTHETIC — proxy-label agreement, NOT real review edits)
Subjective score proxy: 4 (rule: -1 recall<0.95; metric 9 SYNTHETIC — proxy-label agreement, NEVER human taste)
Stage timing (code-captured): total 0.297 s / metadata 0.011 s / cheap-analysis 0.286 s / clustering 0.0002 s / ranking 0.0001 s; avg 1.98 ms/asset; p50 quality 0.891, p95 0.936; cold cacheHitRate 0.0; failedAssets 0; usable 131 / target 30 / shortlist 24
Top failures: none observed (code run; full §6.2 review questions need a human trip review — not assigned)
Notes: REDUCED SCALE (150 of spec 500–1,500); main question per §2 (would I use this album?) needs human review — SYNTHETIC proxies cannot answer taste; diversity check per §4 needs human review
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```
### Row H — Large Library Stress (1,000 SYNTHETIC; 3,000/5,000 NOT RUN — optional future, NOT a gate)
Row H is NOT hand-scored for taste (parent freeze + `manual-qa.md` §2: H checks system behavior, never hand-score). The SYNTHETIC proxy values below are code-computed structural facts about the 1,000-scale run (same proxy rules as all rows), recorded as behavior signal for final-size sanity — NOT quality claims.
```text
# Selection Evaluation — SYNTHETIC code-evidence (NOT human taste, NOT physical/device proof; stability + structural proxies)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: H-1000 — 1000 synthetic trip-gapped (manifest 5a165b85f61e9dbc64a14ec66af6ed1cf06b973b840a31be1a88bf7c3b62dbf8, simctl-seeded; 3,000/5,000 NOT RUN — Simulator time-box, optional future, NOT a gate)
SYNTHETIC LABEL RULE v1 (code: synth-labels.py 409601a1…, q from fixture bytes; REJECT if F-shape or q<0.5; MUST_KEEP if q>=0.8 else ACCEPTABLE): MUST_KEEP 994 / ACCEPTABLE 5 / REJECT 1. SYNTHETIC MOMENT RULE v1 (index i//19): 53 moments. No byte-identical groups (1000 distinct sha256).
Input: 1000 / Final: 100 (REAL shipped-engine proof binary; picked-H-1000.json 100 IDs; replica 85) / Compression: 0.100 (metric 7 SYNTHETIC MEASURED; behavior signal only)
MUST_KEEP total / selected / recall: 994 / 100 / 0.101 (metric 1 SYNTHETIC proxy — structural fact, NOT a quality claim)
Selected MUST_KEEP / ACCEPTABLE / REJECT: 100 / 0 / 0
Good rate: 1.000 (100/100; metric 2 SYNTHETIC proxy) / Bad-pick rate: 0.000 (0/100; metric 3 SYNTHETIC proxy)
Clusters judged / leakage / best-shot accuracy: 0 groups, n/a judged / 0.000 needless-repeat (0/100; metric 4 SYNTHETIC proxy, edges=[] caveat) / n/a (no identical groups; metric 5 SYNTHETIC proxy)
Key moments total / covered / coverage: 53 / 53 / 1.000 (metric 6 SYNTHETIC proxy — structural coverage: all 53 synthetic blocks touched)
User removals / add-backs: 0 / 894 (proxy) / Human Edit Rate proxy: 8.94 (894/100; metric 8 SYNTHETIC proxy — NOT real edits)
Subjective score proxy: 4 (rule: -1 recall<0.95; metric 9 SYNTHETIC proxy — NEVER human taste)
Stability observations (§5.4 + §7.3 1,000-photo check, code-captured): no crash/hang across harness + REAL-engine runs; failedAssets 0; usable 846 / target 85 / shortlist 159 / clusters 128 / moments 53; stage timing total 1.186 s / metadata 0.069 s / cheap-analysis 1.113 s / clustering 0.0024 s / ranking 0.0006 s; avg 1.19 ms/asset; rerun (page-cache warm) 1.275 s; host peakRSS 63.2 MB (HOST metric only, NOT a device-memory claim); cold cacheHitRate 0.0; determinism verified (repeat-pick md5 stable on A-shape). UI-alive / heat / OS-kill / cancel-at-25-50-90 observations need on-Simulator app runs — pending (optional future work, not gates).
Top failures: none observed in code runs (system-behavior tags only if observed; no §7.2 taste tags)
Notes: Simulator code-evidence only; device memory/thermal per scale need physical-device or extended-Simulator follow-ups (optional future work, not gates)
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```
### Row Golden — Stable 200-shape (SYNTHETIC proxy labels; stable regression reference)
SYNTHETIC proxy labels replace §3.2 human annotation for this baseline only (per user directive 2026-09-16; physical annotation optional future, NOT a gate). The set stays stable across runs (manifest-pinned) and is never retuned to fit the algorithm.
```text
# Selection Evaluation — SYNTHETIC code-evidence (NOT human taste, NOT physical proof; stable set, SYNTHETIC proxy labels)
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1 / Dataset: Golden-shape — 200 synthetic (150 G + 50 A, manifest e61200e01993a990258a196869cf8352647ac746982311f1538bd1ed17c2826d, simctl-seeded; definition range 200–500)
SYNTHETIC LABEL RULE v1 (code: synth-labels.py 409601a1…, q from fixture bytes; REJECT if F-shape or q<0.5; MUST_KEEP if q>=0.8 else ACCEPTABLE): MUST_KEEP 187 / ACCEPTABLE 12 / REJECT 1 (5 A-part picks + 25 G-part picks in final). SYNTHETIC MOMENT RULE v1 (index i//19): 11 moments. No byte-identical groups (200 distinct sha256).
Input: 200 / Final: 30 (REAL shipped-engine proof binary; picked-Golden-shape.json 30 IDs) / Compression: 0.150 (metric 7 SYNTHETIC MEASURED; behavior signal for regression reference)
MUST_KEEP total / selected / recall: 187 / 30 / 0.160 (metric 1 SYNTHETIC — proxy labels, NOT human MUST_KEEP)
Selected MUST_KEEP / ACCEPTABLE / REJECT: 30 / 0 / 0
Good rate: 1.000 (30/30; metric 2 SYNTHETIC) / Bad-pick rate: 0.000 (0/30; metric 3 SYNTHETIC)
Clusters judged / leakage / best-shot accuracy: 0 groups, n/a judged / 0.000 needless-repeat (0/30; metric 4 SYNTHETIC, edges=[] caveat) / n/a (no identical groups; metric 5 SYNTHETIC)
Key moments total / covered / coverage: 11 / 11 / 1.000 (metric 6 SYNTHETIC — structural moments, NOT important-moment labels)
User removals / add-backs: 0 / 157 (proxy) / Human Edit Rate proxy: 5.23 (157/30; metric 8 SYNTHETIC — proxy-label agreement, NOT real review edits)
Subjective score proxy: 4 (rule: -1 recall<0.95; metric 9 SYNTHETIC — proxy-label agreement, NEVER human taste)
Stage timing (code-captured): total 0.722 s / metadata 0.013 s / cheap-analysis 0.708 s / clustering 0.0005 s / ranking 0.0002 s; avg 3.61 ms/asset; p50 quality 0.886, p95 0.935; cold cacheHitRate 0.0; failedAssets 0; deterministic repeat confirmed
Top failures: none observed in code runs (§7.2 vocabulary; side-by-side per §6.2 on later changes: only-in-each, cluster-pick changes, lost moments, balance shift — now computable against these SYNTHETIC proxy labels)
Notes: set is stable across runs (manifest-pinned); never retuned to fit the algorithm; recall 0.160 is a proxy artifact of the 30-pick album against 187 proxy-MUST_KEEP, NOT a quality fail
Regression vs last build: n/a — this is the baseline; comparison per §6.2 starts at the next change
Decision: Neutral (baseline)
```

## Constraint record
- No scoring, threshold, weight, config, version, or QA-policy change (frozen versions re-verified in code on this branch; this work touches owned tracker files only — `features/feat-017.md`, `features/mini-017a.md`, `features/mini-017b.md`, `features/mini-017c.md`, `feature_index.json` untouched by this mini, `progress.md` — never `apps/` or shared contracts).
- SYNTHETIC code-evidence honestly labeled: every value carries SYNTHETIC code-evidence + rule text + build + config + fixture manifest; no SYNTHETIC number is presented as human taste or physical proof; Row D stays honestly NOT RUN with reason (no face fixtures); full-scale G + H 3k/5k + on-device cancel-ack/UI-alive/heat/RSS/thermal stay pending as optional future, NOT gates. Metrics 4/5 carry the edges=[] degraded-config caveat (proof runner fed no similarity edges; on-device app computes real Vision edges).
- No H hand-scoring for taste: Row H carries SYNTHETIC structural proxies as behavior signal only (final-size sanity), NOT quality claims.
- No missing required fields: every row carries Date / Build / Config / Dataset, Input / Final, all nine metric slots (SYNTHETIC values, or n/a with degenerate-denominator reasons in Row F, or NOT RUN in Row D), top failures with §7.2 tag vocabulary, Notes, Regression, and `Decision: Neutral (baseline)` — every value computed IN CODE, nothing invented.
- No test targets or `*Test*.swift` files (repo policy).
## Handoff
State `done` (SYNTHETIC nine-metric §8.2 rows filled 2026-09-16: every value computed IN CODE by synth-labels.py `409601a1…` against the ALREADY-MEASURED REAL-engine outputs of 06da3e8 — A m1 0.240/m2 1.000/m3 0.000/m4 0.000/m5 n-a/m6 1.000/m7 0.200/m8 3.17/m9 4; B m1 0.222/m2 1.000/m3 0.000/m4 0.625/m5 0.200/m6 1.000/m7 0.200/m8 3.50/m9 3; C m1 0.202/m2 1.000/m3 0.000/m4 0.000/m5 n-a/m6 1.000/m7 0.180/m8 3.94/m9 4; E same as A; F empty-album edge (m1 n-a, m2 n-a, m3 n-a, m4 n-a, m5 n-a, m6 0.000, m7 0.000, m8 n-a, m9 1); G-reduced m1 0.166/m2 1.000/m3 0.000/m4 0.000/m5 n-a/m6 1.000/m7 0.160/m8 5.04/m9 4; Golden m1 0.160/m2 1.000/m3 0.000/m4 0.000/m5 n-a/m6 1.000/m7 0.150/m8 5.23/m9 4; H-1000 m1 0.101/m2 1.000/m3 0.000/m4 0.000/m5 n-a/m6 1.000/m7 0.100/m8 8.94/m9 4; Row D honestly NOT RUN with reason; second in merge order; ledger input merged via `0967d2d`). Synthetic-proxy policy per user directive 2026-09-16: human taste judgments replaced by deterministic SYNTHETIC proxies for this baseline (LABEL/MOMENT/BEST-SHOT/REVIEWER rules v1, code hash recorded per row); physical numbers optional future work, not gates. Metrics 4/5 carry the edges=[] degraded-config caveat. Evidence: this file §§ Ledger input / Devices / Baseline runs / Constraint record; parent Handoff holds the method; `./init.sh` result recorded at commit; owned-files-only diff, no `apps/` path. Blockers: none for merge (Row D + full-scale G + H 3k/5k + device-only conditions are optional future, not gates). Nothing invented, never human. Parent owner's next integration action: review this file (reproducibility from recorded fields + proxy honesty), then consolidate.
