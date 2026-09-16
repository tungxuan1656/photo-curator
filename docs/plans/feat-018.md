# Universal Quality Signals Integration Plan (feat-018 parent contract)

**Goal:** Freeze the universal fact schema (aesthetics, classification, FeaturePrint-use
flag, PhotoKit allowlist), the `analysisVersion` 1 → 2 migration rule, and child
ownership/merge order before any scoring or wiring change. This commit changes no
production scoring, threshold, weight, version, config, budget-constant, or QA policy,
and adds no `apps/` file.

**Base:** origin/main `a877fa0` (feat-017 `done`, squash #33). Branch
`tungxuan1656/feat-018-integration` verified at `a877fa0` with a clean tree before editing.

Per user directive 2026-09-16: manual QA is replaced by Simulator code-evidence; agents
work autonomously; squash merges always; Codex gpt-5.6-luna verify lane, OMP build
lanes; Simulator-only HARD RULE (never a physical iPhone via any channel).

## Global constraints

- One active integration parent (`feat-018`); admitted minis start as `todo`, at most
  four active at a time.
- `feat-017` `done` is the activation precondition (verified on origin/main before
  editing).
- Parent owns `PhotoAnalysis`, cache migration, `analysisVersion`, pipeline wiring.
  Children touch only their exact new files plus their own card: no shared-contract,
  sibling, or other `apps/` change.
- No test targets or test files (repo policy; `./init.sh` reports `SKIP [test]`).
  Determinism is proven by proof binaries with byte-compare, not tests.
- Metric/proxy definitions stay parent-owned; minis redefine nothing.

## Contract source of truth

The frozen schema lives in `features/feat-018.md` (new persisted fields, PhotoKit
allowlist, VN request mapping with bounded shapes and unavailable values, version bump
plus no-migration requeue rule, wiring points, deterministic fallback). This plan does
not duplicate those tables; it records children, order, rollback, and verification.

## Child files and merge order

| Order | Mini | Exclusive owns | Merge gate |
|---|---|---|---|
| 1 | `mini-018a` — universal aesthetics + classification adapter | `Services/Analysis/UniversalFactAdapter.swift`, `features/mini-018a.md` | Pure two-phase mapping per frozen schema (collect observations → map to facts), bounded outputs, explicit unavailable values; no shared-contract/sibling diff; `./init.sh` passes |
| 2 | `mini-018b` — universal-request cost benchmark | `docs/evidence/universal-request-cost.md`, `features/mini-018b.md` | Cold/warm per-request cost + QoS propagation path recorded; no `apps/` diff; `./init.sh` passes |

Each child branches from the parent contract commit and merges into this branch only
after its gate plus an independent review. Execution runs in order: 018b starts after
018a merges (it needs the stable adapter input shapes). Card files transfer to their
mini on dispatch; the parent retains the frozen schema sections.

## Admission cards (every field concrete)

### mini-018a

- Parent: `feat-018`
- Seam: universal aesthetics + classification observation collection and fact mapping
  (new adapter file only; no pipeline wiring, no `make` change)
- Exclusive owns: `Services/Analysis/UniversalFactAdapter.swift`, `features/mini-018a.md`
- Shared contract task: parent Task 3 wires the adapter phases into
  `VisionAnalysisService.performAll` + `PhotoAnalysis.make` (code wiring, parent only)
- Target failure: F-017-E / F-017-F (universal facts exist so Task 3 can measure)
- Input: frozen schema in `features/feat-018.md` + iOS 26.5 SDK request/observation
  shapes (aesthetics rev 1; classify rev 2 default; `overallScore` [-1,1] + `isUtility`;
  `identifier` + `confidence`; first-print-or-nil)
- Output: two-phase adapter — phase 1 collects the 2 new observations beside the
  existing requests (independent degrade, cancellation checks between requests);
  phase 2 pure-maps to `(aestheticScore, tags[≤3], featurePrintAvailable)` per schema
- Fallback: n/a in code beyond the frozen nil/empty/false mapping (proven at parent Verify)
- Version effect: none (no `analysisVersion` bump in the child)
- Focused QA: parent Verify proof binary compiles the adapter verbatim (double-run
  byte-compare + F-017-E/F movement)
- Merge gate: mapping matches the frozen schema exactly; bounded outputs; unavailable
  values explicit; no shared-contract/sibling diff; `./init.sh` passes on the parent
  after merge; independent review (integration owner + one reviewer, never module owner alone)
- Reject condition: touches a shared contract or sibling file; invents a fact, weight,
  or threshold; adds a tier-B request, model, or dependency

### mini-018b

- Parent: `feat-018`
- Seam: universal-request cost benchmark (evidence only)
- Exclusive owns: `docs/evidence/universal-request-cost.md`, `features/mini-018b.md`
- Shared contract task: parent Task 3 judges the recorded cost against the >~20%
  regression flag (evidence merge only; no code wiring)
- Target failure: F-017-H (request budget) — universal cost must fit the 1k budget path
- Input: merged 018a adapter phase-1 input shapes + feat-017 H-1000 host-harness baseline
  (1.186 s total, behavior reference only) + performance.md budgets
- Output: cold per-request cost (aesthetics, classify) + warm cost + print-baseline
  reference + QoS propagation-path note, all labeled by environment (host-harness vs
  Simulator-execution); nothing invented, never a device claim
- Fallback: n/a (evidence only; engine and procedure unchanged)
- Version effect: none
- Focused QA: numbers reproducible from the recorded method (fixture bytes + harness hash)
- Merge gate: cost table + QoS note reviewable in the evidence file; no `apps/` diff;
  `./init.sh` passes on the parent after merge; independent review
- Reject condition: reports device claims from Simulator/host numbers; touches `apps/`
  or a shared contract; invents a budget constant

## Tasks

### Task 1: Parent contract commit (this commit)

**Files:**

- Modify: `features/feat-018.md`
- Modify: `feature_index.json`
- Create: `docs/plans/feat-018.md`
- Create: `features/mini-018a.md`
- Create: `features/mini-018b.md`
- Modify: `progress.md`

- [x] Verified origin/main `feature_index.json` reads `feat-017` `done` / `feat-018`
  `todo` before editing (dependency rule satisfied; repo idle, no other `active`).
- [x] Verified branch at origin/main `a877fa0` with a clean tree.
- [x] Activated `feat-018`; froze schema, allowlist, VN mapping, version-2 migration rule.
- [x] Recorded exact child files, merge order, and 12-field admission cards.
- [x] Indexed the two minis as `todo` (task-ready; none active).
- [x] Ran `./init.sh` (PASS) with no `apps/` change.

### Task 2: Children collect (merge in order 018a → 018b)

- [ ] `mini-018a`: two-phase adapter reviewable (merges only after gate + review).
- [ ] `mini-018b`: cost + QoS evidence reviewable (starts after 018a merges).
- [ ] Each merge: independent review + `./init.sh` on the parent; weights untouched.

### Task 3: Integrate and gate feat-019 (parent, after all merges)

- [ ] Wire adapter phases into `performAll` + `make`; bump `analysisVersion` 1 → 2.
- [ ] Run the Verify procedure (A-shape + Golden-shape proof binary, cold/warm cost,
  QoS path, fallback byte-compare) and record F-017-E/F movement.
- [ ] Record the feat-019 admission gate in `features/feat-018.md` handoff + `progress.md`.
- [ ] Run `./init.sh` at parent close.

## Rollback

- Before any child merges: revert the contract commit; `feat-018` returns to `todo` and
  the two mini records drop from the index.
- After a child merges: revert that child merge on the parent branch; the schema freeze
  stands.

## Verify

- `./init.sh` passes on the parent branch (this commit + every child merge + parent close).
- `git diff --name-only` on the contract commit shows tracker docs only (no `apps/` paths).
- Parent close runs the full `features/feat-018.md` Verify procedure (proof binary +
  cold/warm + QoS + byte-compare), never manual QA, never a physical device.
