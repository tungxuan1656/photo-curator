# People and Group Selection Integration Plan (feat-020 parent contract)

**Goal:** Freeze the people/group decision contract (aggregation inputs,
weakest-face protection, candid guard, reason-code policy, privacy limits,
cache/version behavior, wiring points, deterministic fallback) before any
calculator code or wiring change. This commit changes no production scoring,
threshold, weight, version, config, budget-constant, or QA policy, and adds
no `apps/` file.

**Base:** origin/main `00c62e2` (feat-019 `done`, squash #41). Branch
`tungxuan1656/feat-020-integration` verified at `00c62e2` with a clean tree
before editing.

Per user directive 2026-09-16: zero user intervention to end, manual QA replaced
by Simulator code-evidence, squash always, Codex gpt-5.6-luna verify lane, OMP
build lanes, Simulator-only HARD RULE (never a physical iPhone via any channel).

## Global constraints

- One active integration parent (`feat-020`); the admitted mini starts as
  `todo`, at most four active at a time.
- `feat-019` `done` is the activation precondition (verified on origin/main before
  editing).
- Parent owns `QualityScorer` (`Domain/Scoring/QualityScorer.swift`), engine
  orchestration (`Domain/Selection/SelectionEngine.swift`), `analysisVersion`
  (`Configuration/AppConfiguration.swift`, bumped 3 → 4 in Task 3), and pipeline
  pass-through (`Services/Analysis/VisionAnalysisService.swift` — existing
  Tier-A face lane only, no new request in the contract) plus
  `FinalAlbumBuilder` reason-code wiring (inside the `SelectionEngine.swift`
  owns entry via the shared selection path). Children touch only their exact
  new files plus their own card: no shared-contract, sibling, or other `apps/`
  change.
- No test targets or test files (repo policy; `./init.sh` reports `SKIP [test]`).
  Determinism is proven by proof binaries with byte-compare, not tests.
- Decision definitions stay parent-owned; the mini redefines nothing.

## Contract source of truth

The frozen contract lives in `features/feat-020.md` (exact aggregation inputs
from feat-019 Tier-A outputs, weakest-face rule, candid-guard rule,
reason-code policy plus review-surface copy, privacy limits, 3 → 4 requeue
rule, wiring points, deterministic fallback). This plan does not duplicate
those tables; it records children, order, rollback, and verification.

## Child files and merge order

| Order | Mini | Exclusive owns | Merge gate |
|---|---|---|---|
| 1 | `mini-020a` — group evidence calculator | `Services/Analysis/GroupEvidenceCalculator.swift`, `features/mini-020a.md` | Pure transient mapping per frozen contract (per-face values → count/min/mean scalars), no persisted/raw-face return, no shared-contract/sibling diff; `./init.sh` passes |

The child branches from the parent contract commit and merges into this branch
only after its gate plus an independent review. The card file transfers to its
mini on dispatch; the parent retains the frozen decision sections.

## Admission cards (every field concrete)

### mini-020a

- Parent: `feat-020`
- Seam: per-face distribution computation (new calculator file only; no wiring,
  no `make` change, no weights, no reason codes)
- Exclusive owns: `Services/Analysis/GroupEvidenceCalculator.swift`, `features/mini-020a.md`
- Shared contract task: parent Task 3 wires the calculator into
  `VisionAnalysisService.performAll` (pass-through) + `QualityScorer.score`
  (weakest-face fold) + `FinalAlbumBuilder.decision` (reason codes) and bumps
  `analysisVersion` 3 → 4 (code wiring, parent only)
- Target failure: F-017-D (group-photo / people handling) — the distribution
  exists so Task 3 can measure
- Input: frozen contract in `features/feat-020.md` + iOS 26.5 SDK shapes
  (`VNDetectFaceRectanglesRequest` → face observations count;
  `VNDetectFaceCaptureQualityRequest` → per-face `faceCaptureQuality` values;
  same 512 px `.up` input; transient, never persisted)
- Output: pure calculator in the new file — per-face values map to
  `(faceCount, minFaceQuality, meanFaceQuality)` bounded scalars
  (`faceCount = max(0, count)`; qualities `clamped01`; nil arms when no faces
  or quality unavailable). No box, landmark, crop, or pixel buffer crosses to
  the caller — scalars only, transient only.
- Fallback: n/a in code beyond the frozen nil arm (proven at parent Verify)
- Version effect: none (no `analysisVersion` bump in the child)
- Focused QA: parent Verify proof binary compiles the calculator verbatim
  (double-run byte-compare + distribution asserts + weakest-face asserts on
  B-shape + Golden-shape with face-bearing fixtures where available)
- Merge gate: mapping matches the frozen contract exactly; bounded outputs;
  unavailable values explicit; no persisted or returned face box/landmark/
  pixel data; no shared-contract/sibling diff; `./init.sh` passes on the
  parent after merge; independent review (integration owner + one reviewer,
  never module owner alone)
- Reject condition: touches a shared contract or sibling file; invents a fact,
  weight, threshold, reason code, or Vision request; persists or returns a box,
  landmark, crop, embedding, or pixel data; reinterprets the version-3 frozen
  Tier-A/B schema

## Tasks

### Task 1: Parent contract commit (this commit)

**Files:**

- Modify: `features/feat-020.md`
- Modify: `feature_index.json`
- Create: `docs/plans/feat-020.md`
- Create: `features/mini-020a.md`
- Modify: `progress.md`

- [x] Verified origin/main `feature_index.json` reads `feat-019` `done` / `feat-020`
  `todo` before editing (dependency rule; repo idle, no other `active`).
- [x] Verified branch at origin/main `00c62e2` with a clean tree.
- [x] Activated `feat-020`; froze people/group decision contract, privacy
  limits, version-4 migration rule.
- [x] Recorded exact child files, merge order, and the 12-field admission card.
- [x] Indexed the mini as `todo` (task-ready; not active).
- [x] Ran `./init.sh` (PASS) with no `apps/` change.

### Task 2: Child collects (merge mini-020a)

- [x] `mini-020a`: group evidence calculator reviewable (merged via `84af07d`, PR #42,
  Codex APPROVE; `./init.sh` on the parent; weights untouched).

### Task 3: Integrate and gate feat-021 (parent, after the merge)

- [x] Wire calculator pass-through + scorer weakest-face fold + reason codes;
  bump `analysisVersion` 3 → 4.
- [x] Run the Verify procedure (B-shape + Golden-shape proof binary,
  candid-guard proof, privacy no-persist proof, cost vs budget, fallback
  byte-compare) and record F-017-D movement.
- [x] Record the feat-021 admission gate in `features/feat-020.md` handoff + `progress.md`.
- [x] Run `./init.sh` at parent close.

## Rollback

- Before the child merges: revert the contract commit; `feat-020` returns to `todo` and
  the mini record drops from the index.
- After the child merges: revert that child merge on the parent branch; the decision
  freeze stands.

## Verify

- `./init.sh` passes on the parent branch (this commit + the child merge + parent close).
- `git diff --name-only` on the contract commit shows tracker docs only (no `apps/` paths).
- Parent close runs the full `features/feat-020.md` Verify procedure (proof binary +
  candid-guard + privacy + cost + byte-compare), never manual QA, never a physical device.
