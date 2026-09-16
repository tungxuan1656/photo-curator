# V2 Baseline Integration Plan (feat-017 parent contract)

**Goal:** Lock the measurable baseline (fixtures, nine metric denominators, devices,
evidence locations, child ownership, merge order) before any V2 behavior change.
This commit changes no production scoring, threshold, weight, version, or QA policy.

**Base:** origin/main `dd7193a` (feat-016 `done`, PR #26 merged). Branch
`tungxuan1656/feat-017-integration` was verified at `dd7193a` with a clean tree
before editing.

## Global constraints

- One active integration parent (`feat-017`); at most four active minis (none active yet).
- `feat-016` done is the activation precondition (verified on origin/main before editing).
- Parent owns the metric ledger, failure taxonomy, baselines, and shared QA policy.
- Children collect evidence only, in their own files; no `apps/` change in this plan.
- No test targets or test files (repo policy; `./init.sh` reports `SKIP [test]`).
- Metric definitions stay parent-owned; never split across minis.

## Contract source of truth

The frozen contract lives in `features/feat-017.md` (Frozen baseline contract section):
fixture versions (`analysisVersion 1`, `engineVersion 2`, `configVersion 1`, cache
`schemaVersion 1`), the nine metric denominators (`manual-qa.md` §4 at `dd7193a`),
devices (physical iPhone only; Simulator excluded from numbers), and evidence
locations (one file per mini). This plan does not duplicate those tables.

## Child files and merge order

| Order | Mini | Exclusive owns | Merge gate |
|---|---|---|---|
| 1 | `mini-017a` — Golden labels and metric ledger | `features/mini-017a.md` | Denominators match the parent freeze; no `apps/`/shared-contract diff; `./init.sh` passes |
| 2 | `mini-017b` — A–H, Golden, Real Trip baseline runs | `features/mini-017b.md` | §8.2 rows reproducible per dataset; no `apps/` diff; `./init.sh` passes |
| 3 | `mini-017c` — 1k-photo device budget inventory | `features/mini-017c.md` | Perf §7 conditions recorded; no budget-constant change; `./init.sh` passes |

Each child branches from the parent contract commit and merges into this branch only
after its gate plus an independent review. Execution runs in order: 017b starts after
017a merges (it needs the ledger); 017c merges last.

## Tasks

### Task 1: Parent contract commit (this commit)

**Files:**

- Modify: `features/feat-017.md`
- Modify: `feature_index.json`
- Create: `docs/plans/feat-017.md`
- Create: `features/mini-017a.md`
- Create: `features/mini-017b.md`
- Create: `features/mini-017c.md`
- Modify: `progress.md`

- [x] Verified origin/main `feature_index.json` shows `feat-016` `done` before editing.
- [x] Verified branch at origin/main `dd7193a` with a clean tree.
- [x] Activated `feat-017`; froze versions, denominators, devices, evidence locations.
- [x] Recorded exact child files, merge order, and 12-field admission cards.
- [x] Indexed the three minis as `todo` (task-ready; none active).
- [x] Ran `./init.sh` (PASS) with no `apps/` change.

### Task 2: Children collect evidence (merged in order 017a → 017b → 017c)

- [x] `mini-017a`: Golden label audit + ledger skeleton reviewable (merged via `0967d2d`, PR #27, independent APPROVE).
- [x] `mini-017b`: reproducible §8.2 row blocks for A–H, Golden, Real Trip (merged via `bdfa595`, PR #28, independent APPROVE; values honestly `pending` user-run physical measurement).
- [x] `mini-017c`: 1k-photo time/memory/thermal observations with §7 conditions (merged via `e7143bc`, PR #29, independent APPROVE, plus `ebb0a50` stale-line fix; values honestly `pending`).
- [x] Each merge: independent review + `./init.sh` on the parent; QA policy untouched.

### Task 3: Consolidate and gate feat-018 (parent, after all merges)

- [x] Merge ledgers into the failure taxonomy in `curation-intelligence.md` (pending-baseline IDs F-017-B/C/D/E/F/G/GLD/H with remedy pointers; no behavior change).
- [x] Record the feat-018 admission gate in `features/feat-017.md` handoff + `progress.md`.
- [x] Run `./init.sh` at parent close.

## Rollback

- Before any child merges: revert the contract commit; `feat-017` returns to `todo` and the three mini records drop from the index.
- After a child merges: revert that child merge on the parent branch; the baseline freeze stands.

## Verify

- `./init.sh` passes on the parent branch (this commit + every child merge + parent close).
- `git diff --stat` on the contract commit shows tracker docs only (no `apps/` paths).
