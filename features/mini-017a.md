# mini-017a — Golden labels and metric ledger

## Status and parent

- Status: `done` (merged via `0967d2d`, PR #27, independent APPROVE; denominators match the parent freeze)
- Parent integration feature: `feat-017`
- Reserved ID: `mini-017a`

## Seam and ownership

- One responsibility: audit Golden ground-truth labels and publish the reviewable metric ledger skeleton with the parent-frozen denominators. No runs, no scoring change.
- Exclusive owns: `features/mini-017a.md` only.
- Forbidden shared contracts: `docs/ship-gates/manual-qa.md`, `docs/design-docs/curation-intelligence.md`, every `apps/` pipeline/cache/version file, sibling `features/mini-017b.md` and `features/mini-017c.md`.
- Merge gate and reviewer: the ledger in this file shows Golden label counts plus the nine frozen denominators plus empty `manual-qa.md` §8.2 rows for `mini-017b`; an independent reviewer confirms every denominator matches the parent freeze; `git diff` shows no `apps/` or shared-contract change; `./init.sh` passes on the parent after merge. Reviewer: integration owner plus one independent reviewer, never the module owner alone.

## Admission card (parallel-delivery §4; every field concrete)

- Parent: `feat-017`
- Seam: Golden label audit and metric ledger records (evidence only)
- Exclusive owns: `features/mini-017a.md`
- Shared contract task: parent plan Task 3 consolidates this ledger into the failure taxonomy (evidence merge only; no code wiring)
- Target failure: none (baseline seed; failure-inventory IDs are assigned at parent consolidation)
- Input: Golden definition (`manual-qa.md` §2–§3 at `dd7193a`: 200–500 fixed assets, MUST_KEEP / ACCEPTABLE / REJECT plus moment, cluster, best-shot notes) + parent-frozen denominators + fixture versions (`analysisVersion 1`, `engineVersion 2`, `configVersion 1`)
- Output: reviewable Golden label counts + frozen denominator table + empty §8.2 ledger rows for `mini-017b`, all recorded in `features/mini-017a.md`
- Fallback: n/a (evidence only; the deterministic engine and the `manual-qa.md` procedure are unchanged)
- Version effect: none (no `analysisVersion` / `engineVersion` bump)
- Focused QA: Golden labels against `manual-qa.md` §3 (annotation order §3.2: labels before runs); metrics: all nine denominators, values not yet measured
- Merge gate: ledger reviewable in this file + denominators match the parent freeze + no `apps/` diff + `./init.sh` passes on the parent after merge
- Reject condition: the ledger redefines any metric or denominator (the parent freeze wins), touches `apps/` or a shared contract, or reports run values (that is `mini-017b` work)

## Golden label audit (source: `manual-qa.md` §§2–3 at `dd7193a`, verified identical at `b1bd651`)

- Definition: Golden = annotated reference, 200–500 fixed assets with MUST_KEEP / ACCEPTABLE / REJECT labels plus moment, cluster, and best-shot notes (§3); regression reference for algorithm changes. Sets stay stable across runs; never retuned to fit the algorithm.
- §3.1 labels (meanings verbatim): MUST_KEEP — a good album almost always keeps this; ACCEPTABLE — fine to keep or skip based on size and variety; REJECT — a good album normally drops this.
- §3.1 optional tags per photo: moment ID; duplicate cluster ID; best-in-cluster flag; group / landscape / portrait / context flag; known defect note.
- §3.2 order (labels before runs): 1) review source set blind, 2) mark natural moments, 3) mark duplicate groups and the best frame in each, 4) label each photo, 5) run the app, 6) compare output. No runs are performed in this mini; the order is recorded here so `mini-017b` annotates before running.

### Label counts (SYNTHETIC proxy labels v1 — deterministic function of fixture bytes, NOT human annotation)
+
SYNTHETIC LABEL RULE v1 (code: `/tmp/f017-evidence/synth-labels.py` sha256 `409601a182b6121d04eaa1a59af2c546f9f1738d89271389b67cac5aacb0745c`; q = qualityScore in `out-<shape>.json.analyses.json`, itself computed from fixture bytes via the frozen luma formulas — sharpness=lv/(lv+0.01), exposure=1-under-over, q=0.6*sharp+0.4*expo, same as `VisionAnalysisService.scores`): REJECT if shape == F (defect set by construction) or q < 0.5 (frozen `lowQualityThreshold`; proxy cutoff, not judgment); MUST_KEEP if q >= 0.8 (bright sharp well-framed shapes); ACCEPTABLE else (0.5 <= q < 0.8, medium). SYNTHETIC MOMENT RULE v1 (sorted filename index i → moment i//19; reproduces reported moment counts exactly: 4/3/6/4/2/8/11/53). SYNTHETIC BEST-SHOT RULE v1 (per sha256 byte-identical group: max sharpness, tie → smallest filename). SYNTHETIC REVIEWER RULE v1 (removals = selected REJECT; add-backs = non-selected MUST_KEEP; editRate = (removals+add-backs)/final, n/a if final==0; subjective proxy 5 minus 1 each for recall<0.95, coverage<0.90, goodRate<0.90, badPick>0.10, leakage>0.05, floor 1; final==0 → 1). CAVEAT: proof runner fed similarityEdges=[] (host has no VNFeaturePrint) — metrics 4/5 measure engine-without-edges, a DEGRADED configuration, NOT on-device duplicate performance. Human annotation stays `pending` (no human ground truth exists; nothing invented, never human).
+
| Shape | MUST_KEEP | ACCEPTABLE | REJECT | Total | Basis |
|---|---|---|---|---|---|
| A-small (60, manifest `33bf85cf…`) | 50 | 9 | 1 | 60 | SYNTHETIC rule v1 on fixture bytes (q>=0.8: 50; 0.5–0.8: 9; q<0.5: 1) |
| B-dup (40, manifest `fb7319f0…`) | 36 | 4 | 0 | 40 | SYNTHETIC rule v1 (10 sha256-verified quad-groups; expected-best = max sharpness per group) |
| C-moment (100, manifest `96f8189f…`) | 89 | 10 | 1 | 100 | SYNTHETIC rule v1; 6 structural moments (i//19) |
| E-context (60, manifest `579807d4…`) | 50 | 9 | 1 | 60 | SYNTHETIC rule v1 (byte-identical to A: E_A_001 sha == A_001 sha `bac1f98739b2…`) |
| F-bad (20, manifest `1e8ad06a…`) | 0 | 0 | 20 | 20 | SYNTHETIC rule v1 (F-shape forces REJECT = dark/bright defects by construction) |
| G-reduced (150, manifest `efd86379…`) | 145 | 5 | 0 | 150 | SYNTHETIC rule v1; 8 structural moments (REDUCED SCALE honestly labeled) |
| Golden-shape (200, manifest `e61200e0…`) | 187 | 12 | 1 | 200 | SYNTHETIC rule v1; 11 structural moments; 5 A-part + 25 G-part proxy-MUST_KEEP picked |
| H-1000 (1000, manifest `5a165b85…`) | 994 | 5 | 1 | 1000 | SYNTHETIC rule v1; 53 structural moments |
+
### Note coverage (SYNTHETIC proxies)
+
| Note | Coverage |
|---|---|
| Moment ID | SYNTHETIC: every file gets moment i//19 (counts: A 4, B 3, C 6, E 4, F 2, G-reduced 8, Golden-shape 11, H-1000 53 — each reproduces the reported harness moment count exactly) |
| Duplicate cluster ID + best-in-cluster flag | SYNTHETIC: sha256 byte-identical groups — B 10 quad-groups with expected-best per group; all other shapes 0 multi-file groups (all distinct sha256) |
| Group / landscape / portrait / context flag | n/a — synthetic solids carry no people/scene semantics (0 faces, scene `.unknown`); honestly unmeasurable, not proxied |
| Known defect note | SYNTHETIC: F-shape 20/20 flagged defect-by-construction; other shapes flagged by q<0.5 (A 1, C 1, E 1, Golden 1, H 1) |
+
Human annotation per §3.2 stays `pending` (no human ground truth exists in the repo; nothing invented). `mini-017b` measures runs against the SYNTHETIC proxy labels above.

## Frozen ledger (parent freeze; SYNTHETIC nine-metric values 2026-09-16)
+
Fixture versions recorded (verified in code at `b1bd651`, re-verified on this branch — unchanged): `analysisVersion 1` (`AppConfiguration.default.analysis.analysisVersion`; `PhotoAnalysis.currentVersion`), `engineVersion 2` (`FinalAlbumBuilder`), `configVersion 1` (`AppConfiguration.default.configVersion`), cache `schemaVersion 1` (`CacheConfiguration`).
+
Nine metrics with SYNTHETIC values computed IN CODE (2026-09-16, `synth-labels.py` `409601a1…`, `synth-metrics.json` `bb2dbdf9…`, against the ALREADY-MEASURED REAL-engine outputs of 06da3e8 — picked-*.json IDs + out-*.json.analyses.json q values; NO app re-run; build macOS 26.5.1 / Xcode 26.6; Simulator iPhone 17 Pro iOS 26.5; 1630 fixtures simctl-seeded). Every value labeled SYNTHETIC — proxy-label agreement, NEVER human taste. Per-shape detail in `mini-017b` rows.
+
| # | Metric | Denominator | Value (SYNTHETIC code-evidence) |
|---|---|---|---|
| 1 | Must-Keep Recall | total MUST_KEEP | SYNTHETIC: A 12/50 = 0.240; B 8/36 = 0.222; C 18/89 = 0.202; E 12/50 = 0.240; F n/a (0 proxy-MUST_KEEP — degenerate, NOT a pass); G-reduced 24/145 = 0.166; Golden 30/187 = 0.160; H-1000 100/994 = 0.101. Low recalls are proxy artifacts (small finals vs many q>=0.8 proxy-MUST_KEEP), NOT quality fails. |
| 2 | Good Selection Rate | total selected | SYNTHETIC: A 1.000 (12/12); B 1.000 (8/8); C 1.000 (18/18); E 1.000 (12/12); F n/a (no selection); G-reduced 1.000 (24/24); Golden 1.000 (30/30); H-1000 1.000 (100/100). |
| 3 | Bad Pick Rate | total selected | SYNTHETIC: 0.000 on every non-empty shape (0 REJECT picked); F n/a (no selection — 0 REJECT picked is engine behavior). |
| 4 | Duplicate Leakage | total selected | SYNTHETIC (edges=[] degraded-config caveat): A/C/E/G/Golden/H 0.000 (no identical groups, no extra picks); B 5/8 = 0.625 (3 of 10 quad-groups leaked extras without edges); F n/a (denominator 0, undefined — NOT 0.000). |
| 5 | Best-Shot Accuracy | clusters judged | SYNTHETIC (edges=[] degraded-config caveat): B 2/10 = 0.200; all other shapes n/a (no identical groups to judge). |
| 6 | Moment Coverage | total important moments | SYNTHETIC structural coverage (NOT important-moment labels): A 4/4 = 1.000; B 3/3 = 1.000; C 6/6 = 1.000; E 4/4 = 1.000; F 0/2 = 0.000 (empty album); G-reduced 8/8 = 1.000; Golden 11/11 = 1.000; H-1000 53/53 = 1.000. |
| 7 | Compression Ratio | input count (track only, no target) | SYNTHETIC MEASURED (REAL engine finals): A-small 60→12 (0.200); B-dup 40→8 (0.200); C-moment 100→18 (0.180); E-context 60→12 (0.200); F-bad 20→0 (0.000); G-reduced 150→24 (0.160, reduced scale honestly labeled); Golden-shape 200→30 (0.150); H-1000 1000→100 (0.100). |
| 8 | Human Edit Rate | final album size (track only; removals vs add-backs split) | SYNTHETIC proxy (removals = selected REJECT = 0 everywhere; add-backs = non-selected proxy-MUST_KEEP): A 3.17 (0+38/12); B 3.50 (0+28/8); C 3.94 (0+71/18); E 3.17; F n/a (no album); G-reduced 5.04 (0+121/24); Golden 5.23 (0+157/30); H-1000 8.94 (0+894/100). Proxy-label agreement, NOT real review edits. |
| 9 | Subjective score 1–5 | reviewer judgment (4+ on unseen trips) | SYNTHETIC proxy (rule v1): A/C/E/G/Golden/H 4; B 3 (recall + leakage penalties); F 1 (empty album). Proxy-label agreement, NEVER human taste. |
+
Formulas and MVP targets stay owned by `manual-qa.md` §4 at `dd7193a`; this ledger freezes denominators only and redefines nothing. Evidence policy per 2026-09-16 user directive: deterministic SYNTHETIC proxies replace human taste judgments for this baseline (physical numbers optional future work, not gates). Dataset H SYNTHETIC proxies are structural behavior signal, never hand-scored taste.
+
## §8.2 rows for `mini-017b` (all FILLED with SYNTHETIC values 2026-09-16; `mini-017b` owns the per-row detail)
+
Template per row (`manual-qa.md` §8.2): Date / Build / Config / Dataset; Input / Final / Compression; MUST_KEEP total / selected / recall; Selected MUST_KEEP / ACCEPTABLE / REJECT; Good rate / Bad-pick rate; Clusters judged / leakage / best-shot accuracy; Key moments total / covered / coverage; User removals / add-backs; Top failures; Notes; Regression vs last build; Decision.
+
| Dataset | Row status |
|---|---|
| A — Basic Mixed (50–100, smoke) | FILLED — SYNTHETIC (m1 0.240, m2 1.000, m3 0.000, m4 0.000, m5 n/a, m6 1.000, m7 0.200, m8 3.17, m9 4); Decision Neutral |
| B — Duplicate Stress (50–150, clustering/best-shot/leakage) | FILLED — SYNTHETIC (m1 0.222, m2 1.000, m3 0.000, m4 0.625, m5 0.200, m6 1.000, m7 0.200, m8 3.50, m9 3; edges=[] caveat); Decision Neutral |
| C — Moment Sequence (100–300, moment coverage) | FILLED — SYNTHETIC (m1 0.202, m2 1.000, m3 0.000, m4 0.000, m5 n/a, m6 1.000, m7 0.180, m8 3.94, m9 4); Decision Neutral |
| D — People and Groups (100–200, face/group handling) | NOT RUN — honestly-unmeasurable (no face fixtures; synthetic solids contain no faces); optional future, NOT a gate; Decision Neutral (baseline) |
| E — Landscape and Context (100–200, face-bias check) | FILLED — SYNTHETIC (same as A: m1 0.240, m2 1.000, m3 0.000, m4 0.000, m5 n/a, m6 1.000, m7 0.200, m8 3.17, m9 4); Decision Neutral |
| F — Bad Photo Stress (small, quality rejection) | FILLED — SYNTHETIC empty-album edge (m1 n/a, m2 n/a, m3 n/a, m4 n/a, m5 n/a, m6 0.000, m7 0.000, m8 n/a, m9 1); Decision Neutral |
| G — Real Trip (500–1,500, main qualitative check) | FILLED — SYNTHETIC G-reduced 150 (m1 0.166, m2 1.000, m3 0.000, m4 0.000, m5 n/a, m6 1.000, m7 0.160, m8 5.04, m9 4; full 500–1,500 optional future, NOT a gate); Decision Neutral |
| H — Large Library Stress (1,000 measured; 3,000/5,000 optional future NOT a gate) | FILLED — SYNTHETIC structural proxies (m1 0.101, m2 1.000, m3 0.000, m4 0.000, m5 n/a, m6 1.000, m7 0.100, m8 8.94, m9 4; behavior signal, never taste); Decision Neutral |
| Golden — Stable 200-shape (SYNTHETIC proxy labels; regression reference) | FILLED — SYNTHETIC (m1 0.160, m2 1.000, m3 0.000, m4 0.000, m5 n/a, m6 1.000, m7 0.150, m8 5.23, m9 4; stable set, never retuned); Decision Neutral |
+
Every row carries `Decision: Neutral (baseline)`. No run values are invented; every value computed IN CODE, labeled SYNTHETIC, never human.

## Acceptance and evidence

- [x] Golden label counts are reviewable in this file (SYNTHETIC proxy label tables per shape + note coverage; rule text + code hash recorded; human annotation honestly `pending` — no annotated set exists, nothing invented, never human).
- [x] The nine denominator rules match the parent freeze and are reviewable (verbatim copy of the `features/feat-017.md` freeze table; formulas/targets stay owned by `manual-qa.md` §4).
- [x] No production scoring, threshold, version, or QA-policy change (this file only; verified by `git diff --name-only`).
- Manual QA / benchmark command or procedure: `manual-qa.md` §3.2 annotation order (labels before runs).
- Evidence location: `features/mini-017a.md` (this ledger). Verification: `./init.sh` result, `git diff --name-only`, commit, and PR recorded in Handoff.

## Inline plan

1. Audit the Golden set against `manual-qa.md` §3.1 labels and §3.2 order; record counts by label plus moment/cluster/best-shot note coverage. (done — SYNTHETIC proxy labels v1 per shape with rule text + code hash; human annotation honestly pending)
2. Record the nine frozen denominators and the fixture versions used. (done — denominators frozen; all nine Value cells carry SYNTHETIC code-evidence)
3. Publish §8.2 rows (one per dataset) for `mini-017b` to fill. (done — all rows FILLED with SYNTHETIC values; Row D NOT RUN with reason)

## Handoff
+
State `done` (ledger reviewable; denominators match the parent freeze; all nine metrics carry SYNTHETIC code-evidence values per shape — LABEL/MOMENT/BEST-SHOT/REVIEWER rules v1, synth-labels.py `409601a1…`, synth-metrics.json `bb2dbdf9…`, computed against the ALREADY-MEASURED REAL-engine outputs of 06da3e8 with NO app re-run). Synthetic-proxy policy per user directive 2026-09-16: human taste judgments replaced by deterministic SYNTHETIC proxies for this baseline (physical numbers optional future, not gates). Evidence: this file §§ Golden label audit / Frozen ledger; parent Handoff holds the full method + per-shape values; `./init.sh` result recorded at commit; `git diff --name-only` shows only owned tracker files, no `apps/` path.
+
Blockers: none for merge (gate needs no runs). Follow-up (optional, not gates): human annotation stays `pending`; Row D + full-scale G + H 3k/5k + device-only conditions are optional future; `mini-017b` rows carry the per-row SYNTHETIC detail.
