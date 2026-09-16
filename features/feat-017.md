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
shared contract, a sibling file, or any `apps/` path. Children merged in order with
independent reviews: `mini-017a` via `0967d2d` (PR #27, APPROVED), `mini-017b` via
`bdfa595` (PR #28, APPROVED), `mini-017c` via `e7143bc` (PR #29, APPROVED) plus
`ebb0a50` stale-line fix. Index: `mini-017a` `done`; `mini-017b`/`mini-017c`
`blocked` with recorded pending-physical reasons (row values honestly `pending`).
The full 12-field admission card lives in each mini file.

## Acceptance

- [ ] Nine manual-QA metrics have a baseline, denominator, device, and artifact link. (pending-physical: denominators/devices/links exist but run values are pending user-run physical measurement — Golden annotation 200–500 assets per `manual-qa.md` §3.2 plus physical A-H/Golden/Real Trip plus 1k-budget rows)
- [x] A-H, Golden, and Real Trip failures are classified with candidate V2 remedies (F-017-B/C/D/E/F/G/GLD/H in `curation-intelligence.md` §14).
- [x] Dataset H is used only for stability and performance claims.
- [x] No production selection behavior changes.

## Relevant docs

- `docs/ship-gates/manual-qa.md`
- `docs/design-docs/curation-intelligence.md`
- `docs/exec-plans/curation-intelligence-v2-parallel-delivery.md`

## Plan

Plan: `docs/plans/feat-017.md`

1. Freeze fixture versions, nine metrics, devices, and evidence locations. (done, contract commit)
2. Admit evidence-only children; merge their ledgers without changing shared QA policy. (done: merged in order 017a → 017b → 017c, each with independent review)
3. Consolidate failures into the V2 design document and choose the feat-018 admission gate. (done, this commit: pending-baseline IDs F-017-B/C/D/E/F/G/GLD/H in `curation-intelligence.md` §14; gate in Handoff)

## Verify

- Run the manual baseline procedure in `manual-qa.md` section 4.
- `./init.sh`

## Handoff

- State: merged (parent PR #30 MERGED via `52588ff`; branch fully on main; children merged with reviews — `mini-017a` via `0967d2d` PR #27 APPROVED, `mini-017b` via `bdfa595` PR #28 APPROVED, `mini-017c` via `e7143bc` PR #29 APPROVED plus `ebb0a50` stale-line fix; Task 3 done via `96a4de6`)
- Evidence: `./init.sh` PASS at this commit (format, `swiftlint --strict`, Simulator build SUCCEEDED, SKIP [test] by policy); tracker-docs scope only, no `apps/` paths.
- Blockers: user-run follow-ups — Golden annotation (200–500 fixed assets per `manual-qa.md` §3.2) plus physical measurement of the §8.2 and §7 rows (Simulator-only constraint; nothing invented).
- feat-018 admission gate: baseline exists with nine denominators frozen, failures classified with candidate remedies (F-017-B/C/D/E/F/G/GLD/H), Golden annotation plus physical measurement outstanding as user-run follow-ups. feat-018 may start only after this gate.
- Next: pending user decision — user-run physical measurement, then explicit done-flip and feat-018 selection; feat-018 must not start here.
