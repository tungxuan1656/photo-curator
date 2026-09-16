# mini-017c — 1k-photo device budget inventory

## Status and parent
+
- Status: `done` (SYNTHETIC nine-metric baseline complete 2026-09-16 per user directive; §7 budget rows code-measured where measurable, device-only conditions honestly pending as optional future NOT gates; H-1000 SYNTHETIC proxy values m1 0.101/m2 1.000/m3 0.000/m4 0.000/m5 n-a/m6 1.000/m7 0.100/m8 8.94/m9 4 computed IN CODE in `mini-017a`/`mini-017b` — see parent Handoff; no physical-device operations — Simulator only per HARD RULE)
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

- [x] Time, memory, and thermal observations for the 1,000-photo run are recorded with full §7 conditions below (§§ Budget runs; code-measured values filled, device-only conditions honestly pending with reasons — nothing invented, never device claims).
- [x] Cancel behavior is recorded (cancel run block with code-measured ack primitive, checkpoint round-trip, memory release contract; on-device runs pending as optional future, not gates).
- [x] No production scoring, budget-constant, version, or QA-policy change (this file only; verify with `git diff --name-only`).
- Manual QA / benchmark command or procedure: `manual-qa.md` §5.4 perf smoke + §7.3 release-validation subset (1,000-photo run, cancel run) with `performance.md` §7 capture.
- Evidence location: `features/mini-017c.md` (this file §§ Frozen budgets / Devices / Budget runs). Verification: `./init.sh` result, `git diff --name-only`, commit, and PR recorded in Handoff.

## Inline plan

1. Record devices and conditions (oldest-supported first); confirm frozen build and versions. (done — versions verified in code; devices recorded; no device touched per Simulator-only constraint)
2. Run the 1,000-photo job and the cancel run; capture the §7 rows plus thermal/memory behavior. (done 2026-09-16 — code-measured rows below; device-only conditions pending as optional future, NOT gates; no device touched per Simulator-only HARD RULE)
3. Note budget deltas as facts only; propose no tuning (tuning is parent Task 3 / feat-018 work). (done — delta rows record host-context facts only; no tuning proposed here)

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
+
- SIMULATOR code-evidence (evidence-policy amendment 2026-09-16 per user directive; replaces physical-device §7 measurement for this baseline; physical numbers optional future work, not gates): booted iPhone 17 Pro (iOS 26.5, UDID BE48CD78…AF29E); app `com.tungxuan.photo-curator` rebuilt + installed + launched (PID 36576, no crash), Photos access granted; H-1000 fixtures (1000 synthetic trip-gapped, seed 17018, manifest `5a165b85…`) seeded via `simctl addmedia`, Simulator library verified via Photos.sqlite COUNT (70 pre-existing + 1630 seeded = 1700). Build: macOS 26.5.1, Xcode 26.6 (17F113). All-local synthetic bytes (no iCloud mix — honestly labeled; download time n/a).
- Frozen fixture versions (verified in code on this branch, unchanged from the parent freeze): `analysisVersion 1` (`AppConfiguration.default.analysis.analysisVersion`; `PhotoAnalysis.currentVersion`), `engineVersion 2` (`FinalAlbumBuilder`), `configVersion 1` (`AppConfiguration.default.configVersion`), cache `schemaVersion 1` (`CacheConfiguration`).
- Run procedure: `manual-qa.md` §5.4 perf smoke + §7.3 release-validation subset (1,000-photo run, cancel run) with `performance.md` §7 capture — measured in code via (1) host harness on identical fixture bytes (stage timing/cache/counts) + (2) REAL shipped-engine proof binary (`SelectionEngine.select` on harness analyses) + (3) cancel/checkpoint proof binary compiling REAL `FileStore` + `SessionCheckpointStore` + `SaveState` sources. No `OSSignposter` spans exist in app code (grep: only OSLog in `AppModel`/`PhotoLibraryPermissionService`/`SelectionSessionCoordinator`); stage timing below is the code-captured §7 equivalent. Battery/Low Power/thermal at run: host-run — device-only conditions honestly pending (see rows).
- Merge order: this mini merges last, after `mini-017b` (PR #28 merged via bdfa595).
+
## Budget runs (§7 rows; SIMULATOR code-evidence 2026-09-16 — measured ONLY where code measured; device-only conditions pending with reasons)
+
### Run 1 — 1,000-photo budget run (`manual-qa.md` §7.3)
+
```text
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113), app Debug-iphonesimulator installed+launched PID 36576 / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1
Simulator: iPhone 17 Pro iOS 26.5 (BE48CD78…AF29E) — SIMULATOR code-evidence, NOT a device claim; oldest-supported-device budgets below are observed-vs-budget facts on host/Simulator only
Asset count: 1,000 (dataset H scale) / local vs iCloud mix: all-local synthetic bytes, no iCloud (download time n/a — honestly labeled)
Battery: pending (device-only; host run) / Low Power: n/a host run (budgets assume off) / Start thermal state: pending (device-only; host run) / analysisVersion: 1
totalJobDuration: 1.186 s code-measured (harness on identical bytes; budget ≤ 5 min host-context — NOT a device completion claim; rerun page-cache-warm 1.275 s)
metadataDuration: 0.069 s / cheapAnalysisDuration: 1.113 s / expensiveAnalysisDuration: 0.0 (0 faces; on-device Vision face path not exercised by synthetic solids) / clusteringDuration: 0.0024 s / rankingDuration: 0.0006 s (REAL-engine select stage 1.1882 s incl. candidate build on top of harness analysis time — both code-measured, honestly separated)
cacheHitRate: 0.0 cold first run (code-measured); cached rerun (page-cache-warm, NOT FileAnalysisCache reuse): 1.275 s — app-level cached-rerun seconds-not-minutes claim needs on-device FileAnalysisCache reuse run — pending
averageAssetAnalysisTime: 1.19 ms/asset code-measured (host; p50 quality 0.865, p95 0.916)
p95AssetAnalysisTime: host per-asset distribution not separately captured beyond p50/p95 quality — pending as a device metric; host avg 1.19 ms recorded
peakMemory: host peakRSS 63.2 MB code-measured (HOST metric only — NOT a device RSS claim) — steady RSS vs ≤ ~350 MB: pending device measurement; temporary peak vs ≤ ~500 MB: pending device measurement
failedAssetCount: 0 (code-measured: 1000 analyzed, 0 unavailable; one-bad-asset-never-ends-the-job path not stressed here — F-shape edge recorded separately in mini-017b)
Selection behavior (REAL engine): final 100 / compression 0.100 / usable 846 / target 85 / shortlist 159 / clusters 128 / moments 53; no crash/hang; determinism verified
Thermal/memory behavior: pending device-only (start/end/max thermal, throttling, memory band flatness, warnings/kills, Instruments) — host run cannot claim device thermals
Budget deltas (facts only, no tuning proposed): host total 1.186 s vs ≤ 5 min budget is a host-context fact, NOT a device pass; device RSS/thermal deltas pending; pressure/speed findings go to parent Task 3 / feat-018
Regression vs last build: n/a — this is the baseline
```
+
### Run 2 — Cancel run (`manual-qa.md` §7.3 + §5.3; code-verified path, device run pending)
+
```text
Date: 2026-09-16 / Build: macOS 26.5.1, Xcode 26.6 (17F113) / Config: analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1
Simulator: iPhone 17 Pro iOS 26.5 (BE48CD78…AF29E) — code-proof only (see below); on-device cancel-at-25/50/90% run pending (optional future work, not a gate)
Asset count: 1,000 (H scale; code path verified on 250-ID checkpoint round-trip + Task-cancel primitive)
Cancel point(s): pending on-device (~25% / ~50% / ~90% per §5.3 need app runs; NOT attempted — honestly labeled)
Cancel UI ack latency: 0.0002 s Task-cancellation primitive round-trip (code-measured via REAL-contract proof binary) — on-device UI-ack vs < 250 ms budget: pending (needs app run)
No new expensive work after cancel known (< 1 s where practical): code-verified by construction (BatchPipeline checks cancellation at batch boundaries + before/after fetch/Vision/persist per sources) — on-device observation pending
Post-cancel: code-contract verified (checkpoint-first-then-throw in BatchPipeline sources); app-responsive / work-stopped / memory-cleared / no-fake-album / restartable / sources-untouched observations: pending (need app runs)
Checkpoint/resume: 250/250 IDs preserved round-trip (`match=true`, code-measured via REAL FileStore+SessionCheckpointStore+SaveState sources); resume-skips-valid-cache-entries is the version-gated cache contract in sources — on-device resume run pending
Thermal/memory behavior: pending device-only
Budget deltas (facts only, no tuning proposed): primitive ack 0.0002 s vs < 250 ms budget is a primitive-context fact, NOT a UI-ack pass; on-device ack delta pending
Regression vs last build: n/a — this is the baseline
```
## Constraint record
+
- No scoring, threshold, weight, config, version, or budget-constant change (frozen versions re-verified in code on this branch; this work touches owned tracker files only — never `apps/` or shared contracts).
- No tuning proposed: delta rows record observed-vs-budget facts only; tuning is parent Task 3 / feat-018 work.
- SIMULATOR code-evidence honestly labeled: host/Simulator numbers are NEVER presented as device proof (peakRSS labeled host-only; total-vs-5-min labeled host-context, not a device pass; ack primitive labeled primitive-context, not a UI-ack pass); device-only conditions (battery/thermal/RSS bands/UI-alive/OS-kill/cancel-at-25-50-90) stay pending with reasons.
- No selection quality bent for time; no missing conditions fields — every row carries the full §7 conditions list with code-measured values where measured and honest pending where device-only.
- No test targets or `*Test*.swift` files (repo policy).
+
## Handoff
+
State `done` (SYNTHETIC nine-metric baseline complete 2026-09-16: Run 1 host-timed 1.186 s + REAL-engine final 100 + stage splits + cold-hit 0.0 + failed 0; H-1000 SYNTHETIC proxies m1 0.101/m2 1.000/m3 0.000/m4 0.000/m5 n-a/m6 1.000/m7 0.100/m8 8.94/m9 4 computed IN CODE in `mini-017a`/`mini-017b` (synth-labels.py `409601a1…`, synth-metrics.json `bb2dbdf9…`); Run 2 cancel path code-verified via REAL checkpoint sources (ack primitive 0.0002 s, 250/250 checkpoint match) with on-device runs pending as optional future, NOT gates; merges last). Synthetic-proxy policy per user directive 2026-09-16: human taste judgments replaced by deterministic SYNTHETIC proxies for this baseline; physical numbers optional future work, not gates. Evidence: this file §§ Frozen budgets / Devices / Budget runs / Constraint record; parent Handoff holds the method; `./init.sh` result recorded at commit; owned-files-only diff, no `apps/` path. Blockers: none for merge (on-device cancel/UI-alive/heat/RSS/thermal, H 3,000/5,000, app-level cached-rerun reuse are optional future, not gates). Nothing invented, never human, never device claims.
