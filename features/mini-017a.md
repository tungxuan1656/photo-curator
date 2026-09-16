# mini-017a — Golden labels and metric ledger

## Status and parent

- Status: `done` (ledger reviewable on `tungxuan1656/mini-017a-ledger`; awaiting parent independent review + merge)
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

### Label counts

| Label | Count | Basis |
|---|---|---|
| MUST_KEEP | pending — annotation not yet performed | Manual §3.2 steps 1–4 on a physical iPhone; no annotated Golden set exists in the repo at `b1bd651` (verified: no Golden assets or label records under `docs/`, `features/`, or `apps/`) |
| ACCEPTABLE | pending (same basis) | Manual §3.2 steps 1–4; nothing annotated yet |
| REJECT | pending (same basis) | Manual §3.2 steps 1–4; nothing annotated yet |
| Total | pending (definition range 200–500 fixed assets) | `manual-qa.md` §2 Golden row at `dd7193a` |

### Note coverage

| Note | Coverage |
|---|---|
| Moment ID | pending (annotated with labels per §3.2 step 2) |
| Duplicate cluster ID + best-in-cluster flag | pending (annotated per §3.2 step 3) |
| Group / landscape / portrait / context flag | pending (optional tag per §3.1) |
| Known defect note | pending (optional tag per §3.1) |

No counts are invented: fields stay pending until a reviewer annotates per §3.2. `mini-017b` measures runs against these labels once filled.

## Frozen ledger (parent freeze; values not yet measured)

Fixture versions recorded (verified in code at `b1bd651`): `analysisVersion 1` (`AppConfiguration.default.analysis.analysisVersion`; `PhotoAnalysis.currentVersion`), `engineVersion 2` (`FinalAlbumBuilder`), `configVersion 1` (`AppConfiguration.default.configVersion`), cache `schemaVersion 1` (`CacheConfiguration`).

Nine denominators, verbatim from the `features/feat-017.md` freeze:

| # | Metric | Denominator | Value |
|---|---|---|---|
| 1 | Must-Keep Recall | total MUST_KEEP | not yet measured |
| 2 | Good Selection Rate | total selected | not yet measured |
| 3 | Bad Pick Rate | total selected | not yet measured |
| 4 | Duplicate Leakage | total selected | not yet measured |
| 5 | Best-Shot Accuracy | clusters judged | not yet measured |
| 6 | Moment Coverage | total important moments | not yet measured |
| 7 | Compression Ratio | input count (track only, no target) | not yet measured |
| 8 | Human Edit Rate | final album size (track only; removals vs add-backs split) | not yet measured |
| 9 | Subjective score 1–5 | reviewer judgment (4+ on unseen trips) | not yet measured |

Formulas and MVP targets stay owned by `manual-qa.md` §4 at `dd7193a`; this ledger freezes denominators only and redefines nothing. Devices: physical iPhone only (daily driver plus an older device when available); Simulator is UI work only, never pipeline proof. Dataset H claims stability, memory, cancel, progress, and thermal behavior only; it is never hand-scored for taste.

## Empty §8.2 rows for `mini-017b` (all values empty; `mini-017b` fills)

Template per row (`manual-qa.md` §8.2): Date / Build / Config / Dataset; Input / Final / Compression; MUST_KEEP total / selected / recall; Selected MUST_KEEP / ACCEPTABLE / REJECT; Good rate / Bad-pick rate; Clusters judged / leakage / best-shot accuracy; Key moments total / covered / coverage; User removals / add-backs; Top failures; Notes; Regression vs last build; Decision.

| Dataset | Row status |
|---|---|
| A — Basic Mixed (50–100, smoke) | empty — `mini-017b` fills; Decision unmarked |
| B — Duplicate Stress (50–150, clustering/best-shot/leakage) | empty — `mini-017b` fills; Decision unmarked |
| C — Moment Sequence (100–300, moment coverage) | empty — `mini-017b` fills; Decision unmarked |
| D — People and Groups (100–200, face/group handling) | empty — `mini-017b` fills; Decision unmarked |
| E — Landscape and Context (100–200, face-bias check) | empty — `mini-017b` fills; Decision unmarked |
| F — Bad Photo Stress (small, quality rejection) | empty — `mini-017b` fills; Decision unmarked |
| G — Real Trip (500–1,500, main qualitative check) | empty — `mini-017b` fills; Decision unmarked |
| H — Large Library Stress (1,000 / 3,000 / 5,000, stability-only; quality metrics exempt) | empty — `mini-017b` fills; Decision unmarked |
| Golden — Annotated reference (200–500, regression reference; needs the label audit above filled first) | empty — `mini-017b` fills; Decision unmarked |

Every row expects `Decision: Neutral (baseline)` when `mini-017b` fills it. No run values are reported in this file.

## Acceptance and evidence

- [x] Golden label counts are reviewable in this file (audit table + note coverage; counts honestly `pending` — no annotated Golden set exists in the repo at `b1bd651`, nothing invented).
- [x] The nine denominator rules match the parent freeze and are reviewable (verbatim copy of the `features/feat-017.md` freeze table; formulas/targets stay owned by `manual-qa.md` §4).
- [x] No production scoring, threshold, version, or QA-policy change (this file only; verified by `git diff --name-only`).
- Manual QA / benchmark command or procedure: `manual-qa.md` §3.2 annotation order (labels before runs).
- Evidence location: `features/mini-017a.md` (this ledger). Verification: `./init.sh` result, `git diff --name-only`, commit, and PR recorded in Handoff.

## Inline plan

1. Audit the Golden set against `manual-qa.md` §3.1 labels and §3.2 order; record counts by label plus moment/cluster/best-shot note coverage.
2. Record the nine frozen denominators and the fixture versions used.
3. Publish empty §8.2 rows (one per dataset) for `mini-017b` to fill.

## Handoff

State `done` (ledger reviewable on `tungxuan1656/mini-017a-ledger`; awaiting parent independent review + merge; first in merge order). Commit: branch `tungxuan1656/mini-017a-ledger` (hash in PR / worker_done). Evidence: this file §§ Golden label audit / Frozen ledger / Empty §8.2 rows; `./init.sh` PASS (format 0/57, swiftlint --strict 0 violations/57 files, BUILD SUCCEEDED, SKIP [test] per repo policy); `git diff --name-only` = `features/mini-017a.md` only, no `apps/` path.

Blockers: none for merge (gate needs no runs). Follow-up for the parent/reviewer: Golden counts stay `pending` until a reviewer annotates 200–500 fixed assets per §3.2 on a physical iPhone; `mini-017b` then measures runs against those labels.
Parent owner's next integration action: independent review (denominators vs parent freeze), merge this file only, then dispatch `mini-017b`.
