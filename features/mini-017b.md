# mini-017b — A-H, Golden, and Real Trip baseline runs

## Status and parent

- Status: `todo` (admitted by the feat-017 parent contract commit; task-ready, starts after `mini-017a` merges)
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

- [ ] One reproducible §8.2 row per dataset (A–H, Golden, Real Trip) is attached in this file.
- [ ] Dataset H claims stability/performance only.
- [ ] No production scoring, threshold, version, or QA-policy change.
- Manual QA / benchmark command or procedure: `manual-qa.md` §5–§6 run procedures with the §8.2 evaluation template; regression comparison per §6.2.
- Evidence location: `features/mini-017b.md`.

## Inline plan

1. Confirm the `mini-017a` ledger (denominators + Golden labels) is merged; record frozen versions, build, and devices.
2. Run A–F, Golden, one Real Trip (G), and H (stability only) on physical iPhones; fill one §8.2 row per dataset with all nine metrics or explicit H exemptions.
3. List top failures with `manual-qa.md` §7.2 tags for parent classification; mark every row `Decision: Neutral (baseline)`.

## Handoff

State `todo` (admitted, task-ready); second in merge order; starts after `mini-017a` merges. Commit: —. Evidence: —. Blockers: none (`mini-017a` ledger is the only input; its skeleton is frozen in the parent contract). Parent owner's next integration action: dispatch after `mini-017a` merges; merge after its gate; then dispatch `mini-017c`.
