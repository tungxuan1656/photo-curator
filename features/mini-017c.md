# mini-017c — 1k-photo device budget inventory

## Status and parent

- Status: `blocked` (merged via `e7143bc`, PR #29, independent APPROVE, plus `ebb0a50` stale-line fix; row blocks reproducible, values pending user-run physical measurement per Simulator-only constraint)
- Parent integration feature: `feat-017`
- Reserved ID: `mini-017c`

## Seam and ownership

- One responsibility: record 1,000-photo device budget observations (time, memory, thermal, cancel/resume) against the `performance.md` §1 budgets with full §7 conditions. No tuning, no scoring change.
- Exclusive owns: `features/mini-017c.md` only.
- Forbidden shared contracts: `docs/ship-gates/manual-qa.md`, `docs/design-docs/curation-intelligence.md`, `docs/ship-gates/performance.md` budgets, every `apps/` pipeline/cache/version/config file, sibling `features/mini-017a.md` and `features/mini-017b.md`.
- Merge gate and reviewer: §7 measurement rows (totalJobDuration, metadata/cheap/expensive/clustering/ranking durations, cacheHitRate, average/p95 asset time, peakMemory, failedAssetCount) plus full conditions (iPhone model, iOS version, app build, asset count, local-vs-iCloud mix, battery and Low Power state, start thermal state, `analysisVersion`) plus the §7.3 1,000-photo and cancel runs, all in this file; an independent reviewer confirms conditions are complete and no budget constant or `apps/` path changed; `./init.sh` passes on the parent after merge. Reviewer: integration owner plus one independent reviewer, never the module owner alone.

## Admission card (parallel-delivery §4; every field concrete)

- Parent: `feat-017`
- Seam: 1,000-photo device budget inventory (evidence only)
- Exclusive owns: `features/mini-017c.md`
- Shared contract task: parent plan Task 3 carries the budget findings into the feat-018 admission gate (evidence merge only; no budget change)
- Target failure: none yet (budget facts constrain future V2 cost decisions)
- Input: frozen run procedure (`manual-qa.md` §5.4 + §7.3) + `performance.md` §1 budgets (1,000 assets ≤ 5 min, look closer above 8 min; steady RSS ≤ ~350 MB, peak ≤ ~500 MB on oldest supported; cancel ack < 250 ms) + §7 capture list, all at `dd7193a`
- Output: §7 measurement rows with full conditions in `features/mini-017c.md`
- Fallback: n/a (evidence only; pressure behavior unchanged — speed degrades first, never correctness)
- Version effect: none (no `analysisVersion` / `engineVersion` bump, no budget-constant change)
- Focused QA: 1,000-photo run without critical fail + cancel run (`manual-qa.md` §7.3); oldest-supported device first, daily driver second
- Merge gate: §7 conditions complete + no budget-constant or `apps/` change + `./init.sh` passes on the parent after merge
- Reject condition: tuning constants to hit the numbers; Simulator-only numbers; bending selection quality to hit time; missing conditions fields

## Acceptance and evidence

- [x] Time, memory, and thermal observations for the 1,000-photo run are templated with full §7 conditions below (§§ Budget runs; run-dependent values `pending` — nothing invented).
- [x] Cancel behavior is templated (cancel run block with ack timing, memory release, checkpoint, restart).
- [x] No production scoring, budget-constant, version, or QA-policy change (this file only; verify with `git diff --name-only`).
- Manual QA / benchmark command or procedure: `manual-qa.md` §5.4 perf smoke + §7.3 release-validation subset (1,000-photo run, cancel run) with `performance.md` §7 capture.
- Evidence location: `features/mini-017c.md` (this file §§ Frozen budgets / Devices / Budget runs). Verification: `./init.sh` result, `git diff --name-only`, commit, and PR recorded in Handoff.

## Inline plan

1. Record devices and conditions (oldest-supported first); confirm frozen build and versions. (done — versions verified in code; devices recorded; no device touched per Simulator-only constraint)
2. Run the 1,000-photo job and the cancel run; capture the §7 rows plus thermal/memory behavior. (blocked — rows templated below with values `pending`; filling requires user-run physical measurement)
3. Note budget deltas as facts only; propose no tuning (tuning is parent Task 3 / feat-018 work). (blocked — delta rows present with values `pending`; no tuning proposed here)

## Frozen budgets (source: `performance.md` §1 at `dd7193a`)

| Budget | Value (starting default; tune only after oldest-supported profiling) |
|---|---|
| Completion 1,000 assets | ≤ 5 min (look closer above 8 min) |
| Steady-state RSS | ≤ ~350 MB on oldest supported device |
| Temporary peak RSS | ≤ ~500 MB on oldest supported device |
| Cancel UI ack | < 250 ms; no new expensive work < 1 s where practical |
| Cached rerun, 1,000 analyzed | Seconds, not minutes |
| Relative regression flag | Job time up > ~20% with no planned quality change |

Frozen §1 conditions note: assets local, normal thermals, Low Power off, normal config, oldest supported device. Separate iCloud download time from compute time. Recalibrate targets from the working prototype — never bend selection quality to hit a number. Under pressure speed degrades first, never correctness.

## Devices and run procedure

- Physical iPhone only: oldest-supported first, daily driver second, per the parent freeze. No physical device was touched for this record (user constraint 2026-09-16: Simulator only, never a physical device via any channel); the rows below are templated blocks awaiting user-run measurement — no device name, iOS version, or build number is invented here.
- Frozen fixture versions (verified in code on this branch, unchanged from the parent freeze): `analysisVersion 1` (`AppConfiguration.default.analysis.analysisVersion`; `PhotoAnalysis.currentVersion`), `engineVersion 2` (`FinalAlbumBuilder`), `configVersion 1` (`AppConfiguration.default.configVersion`), cache `schemaVersion 1` (`CacheConfiguration`).
- Run procedure: `manual-qa.md` §5.4 perf smoke (100 / 500 / 1,000 / 5,000 inputs; pass signs: run starts, progress moves, UI stays alive, heat sane, no crash, cancel works, result complete) plus §7.3 release-validation subset (1,000-photo run without critical fail; cancel run) with `performance.md` §7 capture and `OSSignposter` stage spans (job, metadata, load, Vision, clustering, ranking, persistence batches).
- Simulator: never §7 device proof (parent freeze: Simulator is UI work only). No Simulator numbers are recorded in this file; the `./init.sh` Simulator build in Handoff is build verification only, not a §7 measurement.
- Merge order: this mini merges last, after `mini-017b` (PR #28 merged via bdfa595).

## Budget runs (§7 rows; all run-dependent values `pending`)

### Run 1 — 1,000-photo budget run (`manual-qa.md` §7.3)

```text
Date: pending (user-run) / Build: pending / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1
iPhone model: pending / iOS version: pending / app build: pending
Asset count: 1,000 (dataset H scale) / local vs iCloud mix: pending (completion budgets assume local; download time recorded separately)
Battery: pending / Low Power: off (budgets assume off) / Start thermal state: pending (budgets assume normal) / analysisVersion: 1
totalJobDuration: pending (budget ≤ 5 min; look closer above 8 min)
metadataDuration: pending / cheapAnalysisDuration: pending / expensiveAnalysisDuration: pending / clusteringDuration: pending / rankingDuration: pending
cacheHitRate: pending (note cold first run vs cached rerun; cached rerun of 1,000 analyzed budgets seconds-not-minutes)
averageAssetAnalysisTime: pending / p95AssetAnalysisTime: pending
peakMemory: pending — steady RSS vs ≤ ~350 MB: pending; temporary peak vs ≤ ~500 MB: pending (oldest-supported device)
failedAssetCount: pending (report analyzed vs unavailable; one bad asset never ends the job)
Thermal/memory behavior: pending — start/end/max thermal state; heat sane or throttling observed; memory band flat across batches (a steady climb points to held refs); memory warnings / OS kills: none expected; Instruments only if a real problem shows
Budget deltas (facts only, no tuning proposed): pending — each §7 value vs its §1 budget recorded as observed-vs-budget fact; pressure/speed findings go to parent Task 3 / feat-018
Regression vs last build: n/a — this is the baseline
```

### Run 2 — Cancel run (`manual-qa.md` §7.3 + §5.3; cancel at ~25% / ~50% / ~90%)

```text
Date: pending (user-run) / Build: pending / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1
iPhone model: pending / iOS version: pending / app build: pending
Asset count: 1,000 / local vs iCloud mix: pending
Battery: pending / Low Power: pending / Start thermal state: pending / analysisVersion: 1
Cancel point(s): pending (~25% / ~50% / ~90% per §5.3; record each attempted)
Cancel UI ack latency: pending (budget < 250 ms); no new expensive work after cancel known (< 1 s where practical): pending
Post-cancel: app responsive: pending; work stopped: pending; memory cleared: pending; no fake completed album: pending; new run can start: pending; sources untouched: pending
Checkpoint/resume: completed analysis kept: pending; resume skips valid cache entries (no restart-from-zero): pending; job state (stage, completed count, status) intact: pending
Thermal/memory behavior: pending — thermal state at cancel; memory released after cancel; no leak across cancel → restart
Budget deltas (facts only, no tuning proposed): pending — ack latency vs the < 250 ms budget as observed fact
Regression vs last build: n/a — this is the baseline
```

## Constraint record

- No scoring, threshold, weight, config, version, or budget-constant change (frozen versions re-verified in code on this branch; this diff touches `features/mini-017c.md` only).
- No tuning proposed: delta rows record observed-vs-budget facts only; tuning is parent Task 3 / feat-018 work.
- No Simulator numbers recorded or presented as §7 device proof; none were collected (the Simulator-only constraint covers build verification via `./init.sh`, never pipeline proof).
- No selection quality bent for time; no missing conditions fields — every row carries the full §7 conditions list (model, iOS, build, count, local/iCloud mix, battery + Low Power, start thermal, analysisVersion) with run-dependent values honestly `pending`.
- No test targets or `*Test*.swift` files (repo policy).

## Handoff

State `blocked` (two §7 row blocks templated in §§ Budget runs with run-dependent values honestly `pending`; merges last). Commit: branch `tungxuan1656/mini-017c-budget` (hash in PR / worker_done). Evidence: this file §§ Frozen budgets / Devices / Budget runs / Constraint record; `./init.sh` result recorded below; `git diff --name-only` = `features/mini-017c.md` only, no `apps/` path. Blockers: user-run physical measurement required — no physical-device operations permitted (user constraint 2026-09-16); `mini-017b` merged via bdfa595, this mini merged last. Parent owner's next integration action: review this file (conditions complete, facts-only deltas, no tuning); then run parent Task 3.
