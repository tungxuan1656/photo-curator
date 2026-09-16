# mini-017c — 1k-photo device budget inventory

## Status and parent

- Status: `todo` (admitted by the feat-017 parent contract commit; task-ready, merges last)
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

- [ ] Time, memory, and thermal observations for the 1,000-photo run are recorded with full §7 conditions.
- [ ] Cancel behavior is recorded.
- [ ] No production scoring, budget-constant, version, or QA-policy change.
- Manual QA / benchmark command or procedure: `manual-qa.md` §5.4 perf smoke + §7.3 release-validation subset (1,000-photo run, cancel run) with `performance.md` §7 capture.
- Evidence location: `features/mini-017c.md`.

## Inline plan

1. Record devices and conditions (oldest-supported first); confirm frozen build and versions.
2. Run the 1,000-photo job and the cancel run; capture the §7 rows plus thermal/memory behavior.
3. Note budget deltas as facts only; propose no tuning (tuning is parent Task 3 / feat-018 work).

## Handoff

State `todo` (admitted, task-ready); third in merge order. Commit: —. Evidence: —. Blockers: none (run procedure frozen in the parent contract). Parent owner's next integration action: dispatch after `mini-017b` merges; merge after its gate; then run parent Task 3.
