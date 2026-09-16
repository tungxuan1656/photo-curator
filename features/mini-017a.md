# mini-017a — Golden labels and metric ledger

## Status and parent

- Status: `todo` (admitted by the feat-017 parent contract commit; task-ready, awaiting dispatch)
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

## Acceptance and evidence

- [ ] Golden label counts are reviewable in this file.
- [ ] The nine denominator rules match the parent freeze and are reviewable.
- [ ] No production scoring, threshold, version, or QA-policy change.
- Manual QA / benchmark command or procedure: `manual-qa.md` §3.2 annotation order (labels before runs).
- Evidence location: `features/mini-017a.md`.

## Inline plan

1. Audit the Golden set against `manual-qa.md` §3.1 labels and §3.2 order; record counts by label plus moment/cluster/best-shot note coverage.
2. Record the nine frozen denominators and the fixture versions used.
3. Publish empty §8.2 rows (one per dataset) for `mini-017b` to fill.

## Handoff

State `todo` (admitted, task-ready); first in merge order. Commit: —. Evidence: —.
Blockers: none. Parent owner's next integration action: dispatch this mini first; merge after its gate; then dispatch `mini-017b`.
