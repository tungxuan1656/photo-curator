# feat-017 — V2 baseline and failure inventory

## Status and kind

- Status: `active`
- Kind: `integration`
- Depends on: `feat-016` (done on origin/main `dd7193a`; verified before activation)

## Goal

Make the current curator measurable before V2 behavior changes. This feature does not
ship a new scoring signal or model.

## Contract boundary

The parent owns the metric ledger, failure taxonomy, and acceptance baselines. Children
may collect independent evidence only; they do not change production scoring or QA gates.

## Frozen baseline contract (locked 2026-09-16, base `dd7193a`)

This commit freezes without changing: no production scoring, threshold, weight,
version, config, budget-constant, or QA-policy change.

### Fixture versions

- `analysisVersion 1` (`AppConfiguration.default.analysis.analysisVersion`)
- `engineVersion 2` (`FinalAlbumBuilder`: first real pipeline)
- `configVersion 1` (`AppConfiguration.default.configVersion`)
- Cache `schemaVersion 1` (`CacheConfiguration`)

### Metric definitions and denominators

The nine `manual-qa.md` §4 metrics at `dd7193a`, frozen as denominators (values not
yet measured):

| # | Metric | Denominator |
|---|---|---|
| 1 | Must-Keep Recall | total MUST_KEEP |
| 2 | Good Selection Rate | total selected |
| 3 | Bad Pick Rate | total selected |
| 4 | Duplicate Leakage | total selected |
| 5 | Best-Shot Accuracy | clusters judged |
| 6 | Moment Coverage | total important moments |
| 7 | Compression Ratio | input count (track only, no target) |
| 8 | Human Edit Rate | final album size (track only; removals vs add-backs split) |
| 9 | Subjective score 1–5 | reviewer judgment (4+ on unseen trips) |

Metric definitions stay parent-owned; no mini may redefine a metric or denominator.

### Devices

Physical iPhone only: the daily driver plus an older device when available
(oldest-supported first for budget work). The Simulator is UI work only, never
pipeline proof. Dataset H (1,000 / 3,000 / 5,000) claims stability, memory, cancel,
progress, and thermal behavior only; it is never hand-scored for taste.

### Evidence locations

- `features/mini-017a.md` — Golden labels and ledger skeleton
- `features/mini-017b.md` — one reproducible §8.2 row per dataset
- `features/mini-017c.md` — §7 budget rows with full conditions

## Admitted mini-features (merge order: 017a → 017b → 017c)

| Order | Mini | Exclusive owns | Merge gate |
|---|---|---|---|
| 1 | `mini-017a` — Golden labels and metric ledger | `features/mini-017a.md` | Denominators match this freeze; no `apps/`/shared-contract diff; `./init.sh` passes |
| 2 | `mini-017b` — A–H, Golden, Real Trip baseline runs | `features/mini-017b.md` | §8.2 rows reproducible per dataset; no `apps/` diff; `./init.sh` passes |
| 3 | `mini-017c` — 1k-photo device budget inventory | `features/mini-017c.md` | Perf §7 conditions recorded; no budget-constant change; `./init.sh` passes |

Ownership is non-overlapping: each mini owns exactly its own file; no mini touches a
shared contract, a sibling file, or any `apps/` path. All three are indexed in
`feature_index.json` as task-ready `todo` records (none active yet). Children branch
from the parent contract commit and merge here only after their gate plus an
independent review. `mini-017b` starts after `mini-017a` merges (it needs the ledger);
`mini-017c` merges last. The full 12-field admission card lives in each mini file.

## Acceptance

- [ ] Nine manual-QA metrics have a baseline, denominator, device, and artifact link.
- [ ] A-H, Golden, and Real Trip failures are classified with candidate V2 remedies.
- [ ] Dataset H is used only for stability and performance claims.
- [ ] No production selection behavior changes.

## Relevant docs

- `docs/ship-gates/manual-qa.md`
- `docs/design-docs/curation-intelligence.md`
- `docs/exec-plans/curation-intelligence-v2-parallel-delivery.md`

## Plan

Plan: `docs/plans/feat-017.md`

1. Freeze fixture versions, nine metrics, devices, and evidence locations. (done, this commit)
2. Admit evidence-only children; merge their ledgers without changing shared QA policy. (admitted; merges pending in order 017a → 017b → 017c)
3. Consolidate failures into the V2 design document and choose the feat-018 admission gate. (after all merges)

## Verify

- Run the manual baseline procedure in `manual-qa.md` section 4.
- `./init.sh`

## Handoff

- State: active (sole integration parent; no active minis yet)
- Evidence: parent contract commit on `tungxuan1656/feat-017-integration` (tracker docs only, no `apps/` paths); `./init.sh` PASS at contract commit.
- Blockers: none (feat-016 `done` verified on origin/main `dd7193a` before activation).
- Next: dispatch `mini-017a`; merge children in order 017a → 017b → 017c; then run parent plan Task 3.
