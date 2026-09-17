# Contextual Quality Signals Integration Plan (feat-019 parent contract)

**Goal:** Freeze Tier-B routing (eligible subsets, expected-value skip rule),
bounded output shapes per fact, privacy plus retention rules, cache/version
behavior (`analysisVersion` 2 → 3), pipeline wiring points, and deterministic
fallback before any composition/utility adapter code or wiring change. This
commit changes no production scoring, threshold, weight, version, config,
budget-constant, or QA policy, and adds no `apps/` file.

**Base:** origin/main `72070d6` (feat-018 `done`, squash #37). Branch
`tungxuan1656/feat-019-integration` verified at `72070d6` with a clean tree
before editing.

Per user directive 2026-09-16: zero user intervention to end, manual QA replaced
by Simulator code-evidence, squash always, Codex gpt-5.6-luna verify lane, OMP
build lanes, Simulator-only HARD RULE (never a physical iPhone via any channel).

## Global constraints

- One active integration parent (`feat-019`); admitted minis start as `todo`, at most
  four active at a time.
- `feat-018` `done` is the activation precondition (verified on origin/main before
  editing).
- Parent owns `PhotoAnalysis` (`Domain/Models/PhotoAnalysis.swift`), cache behavior
  (`Infrastructure/FileAnalysisCache.swift`), `analysisVersion`
  (`Configuration/AppConfiguration.swift`, bumped 2 → 3 in Task 3), and pipeline
  wiring (`Services/Analysis/VisionAnalysisService.swift`,
  `Services/Photos/BatchPipeline.swift` — no structural change needed).
  Children touch only their exact new files plus their own card: no shared-contract,
  sibling, or other `apps/` change.
- No test targets or test files (repo policy; `./init.sh` reports `SKIP [test]`).
  Determinism is proven by proof binaries with byte-compare, not tests.
- Routing/output definitions stay parent-owned; minis redefine nothing.

## Contract source of truth

The frozen contract lives in `features/feat-019.md` (eligible subset policy with
exact triggers, expected-value skip rule, bounded output shapes per fact,
privacy plus retention rules, 2 → 3 requeue rule, wiring points, deterministic
fallback). This plan does not duplicate those tables; it records children,
order, rollback, and verification.

## Child files and merge order

| Order | Mini | Exclusive owns | Merge gate |
|---|---|---|---|
| 1 | `mini-019a` — composition evidence adapter | `Services/Analysis/CompositionEvidenceAdapter.swift`, `features/mini-019a.md` | Pure two-phase mapping per frozen schema (collect observations → map to facts), bounded outputs, explicit unavailable values; no shared-contract/sibling diff; `./init.sh` passes |
| 2 | `mini-019b` — utility evidence adapter | `Services/Analysis/UtilityEvidenceAdapter.swift`, `features/mini-019b.md` | Pure two-phase mapping per frozen schema + trigger-coverage note, bounded outputs, no raw text persisted; no shared-contract/sibling diff; `./init.sh` passes |
| 3 | `mini-019c` — experimental availability matrix (CONDITIONAL) | `docs/evidence/tier-b-experimental-matrix.md`, `features/mini-019c.md` | Activates only on a parent-named residual failure; benchmark-backed accept/reject per candidate; no `apps/` diff; `./init.sh` passes |

Each child branches from the parent contract commit and merges into this branch only
after its gate plus an independent review. Execution runs in order: 019b starts after
019a merges (stable eligibility patterns); 019c activates only when Task 3 names the
residual failure. Card files transfer to their mini on dispatch; the parent retains
the frozen routing sections.

## Admission cards (every field concrete)

### mini-019a

- Parent: `feat-019`
- Seam: composition observation collection and fact mapping (new adapter file
  only; no wiring)
- Exclusive owns: `Services/Analysis/CompositionEvidenceAdapter.swift`, `features/mini-019a.md`
- Shared contract task: parent Task 3 wires eligibility + adapter phases into
  `VisionAnalysisService.performAll` + `PhotoAnalysis.make` (code wiring, parent only)
- Target failure: F-017-E (landscape/context under-selection)
- Input: frozen schema in `features/feat-019.md` + iOS 26.5 SDK shapes (attention
  saliency rev 2 → `salientObjects`; horizon rev 1 → `angle`; person-seg rev 1
  `.balanced` → mask buffer)
- Output: two-phase adapter — phase 1 collects the 3 observations (independent
  degrade, cancellation checks); phase 2 pure-maps to `(horizonScore,
  visualBalanceScore, salientRegionCount)` per schema. No box/mask/buffer crosses out.
- Fallback: n/a in code beyond the frozen nil mapping (proven at parent Verify)
- Version effect: none (no `analysisVersion` bump in the child)
- Focused QA: parent Verify proof binary compiles the adapter verbatim (double-run
  byte-compare + bound asserts on A-shape + Golden-shape)
- Merge gate: mapping matches the frozen schema exactly; bounded outputs;
  unavailable values explicit; no shared-contract/sibling diff; `./init.sh` passes
  on the parent after merge; independent review (integration owner + one reviewer,
  never module owner alone)
- Reject condition: touches a shared contract or sibling file; invents a fact,
  weight, or threshold; adds a non-frozen request; persists or returns a box,
  mask, landmark, or pixel data

### mini-019b

- Parent: `feat-019`
- Seam: utility observation collection and fact mapping plus trigger-coverage
  note (new adapter file only; no wiring)
- Exclusive owns: `Services/Analysis/UtilityEvidenceAdapter.swift`, `features/mini-019b.md`
- Shared contract task: parent Task 3 wires eligibility + adapter phases into
  `VisionAnalysisService.performAll` + `PhotoAnalysis.make` and judges trigger
  coverage (code wiring, parent only)
- Target failure: screenshot/document pollution
- Input: frozen schema in `features/feat-019.md` + iOS 26.5 SDK shapes (text
  rev 3 `.accurate` → top-1 confidences; doc-seg rev 1 → rectangles; `mediaSubtypes`
  + transient `isUtility` as eligibility flags)
- Output: two-phase adapter — phase 1 collects the 2 observations; phase 2
  pure-maps to `(hasText, textLineCount, screenshotProbability, isDocument)` per
  schema. Raw strings dropped inside phase 2. Trigger-coverage method recorded.
- Fallback: n/a in code beyond the frozen nil mapping (proven at parent Verify)
- Version effect: none
- Focused QA: parent Verify proof binary compiles the adapter verbatim
  (double-run byte-compare + bound asserts + coverage on A-shape + Golden-shape);
  privacy proof scans persisted rows for text content
- Merge gate: mapping matches the frozen schema exactly; bounded outputs; no raw
  text persisted or returned; no shared-contract/sibling diff; `./init.sh` passes
  on the parent after merge; independent review
- Reject condition: touches a shared contract or sibling file; invents a fact,
  weight, or threshold; persists/returns a raw string, box, or confidence pair;
  widens the eligibility predicate; adds a non-frozen request

### mini-019c (CONDITIONAL)

- Parent: `feat-019`
- Seam: experimental availability matrix (evidence only)
- Exclusive owns: `docs/evidence/tier-b-experimental-matrix.md`, `features/mini-019c.md`
- Shared contract task: parent Task 3 judges the matrix (evidence merge only;
  no code wiring)
- Target failure: PARENT-NAMED residual failure only — stays `todo` until Task 3
  names the exact failure ID
- Input: the named residual failure + three frozen candidates (smudge:
  UNAVAILABLE in the iOS 26.5 SDK headers; body pose rev 1; landmarks optional)
- Output: per-candidate accept/reject with availability, cost, false-positive,
  privacy, and reconsider-trigger notes; environment-labeled numbers only
- Fallback: n/a (evidence only)
- Version effect: none (an accepted candidate lands in a later bump, never here)
- Focused QA: numbers reproducible from the recorded method
- Merge gate: matrix reviewable in the evidence file; no `apps/` diff;
  `./init.sh` passes on the parent after merge; independent review
- Reject condition: starts without a parent-named residual failure; touches
  `apps/` or a shared contract; invents a measurement or device claim

## Tasks

### Task 1: Parent contract commit (this commit)

**Files:**

- Modify: `features/feat-019.md`
- Modify: `feature_index.json`
- Create: `docs/plans/feat-019.md`
- Create: `features/mini-019a.md`
- Create: `features/mini-019b.md`
- Create: `features/mini-019c.md`
- Modify: `progress.md`

- [x] Verified origin/main `feature_index.json` reads `feat-018` `done` / `feat-019`
  `todo` before editing (dependency rule; repo idle, no other `active`).
- [x] Verified branch at origin/main `72070d6` with a clean tree.
- [x] Activated `feat-019`; froze Tier-B routing, bounds, privacy/retention,
  version-3 migration rule.
- [x] Recorded exact child files, merge order, and 12-field admission cards.
- [x] Indexed the three minis as `todo` (task-ready; 019c conditional; none active).
- [x] Ran `./init.sh` (PASS) with no `apps/` change.

### Task 2: Children collect (merge in order 019a → 019b → 019c-conditional)

- [ ] `mini-019a`: composition adapter reviewable (independent review).
- [ ] `mini-019b`: utility adapter + coverage reviewable (independent review).
- [ ] `mini-019c`: activates only on a parent-named residual failure.
- [ ] Each merge: independent review + `./init.sh` on the parent; weights untouched.

### Task 3: Integrate and gate feat-020 (parent, after all merges)

- [ ] Wire predicates + requests into `performAll` + `make`; bump `analysisVersion` 2 → 3.
- [ ] Run the Verify procedure (A-shape + Golden-shape proof binary, skip/bound
  proof, privacy no-persist proof, cost vs budget, fallback byte-compare).
- [ ] Record the feat-020 admission gate in `features/feat-019.md` handoff + `progress.md`.
- [ ] Run `./init.sh` at parent close.

## Rollback

- Before any child merges: revert the contract commit; `feat-019` returns to `todo` and
  the three mini records drop from the index.
- After a child merges: revert that child merge on the parent branch; the routing
  freeze stands.

## Verify

- `./init.sh` passes on the parent branch (this commit + every child merge + parent close).
- `git diff --name-only` on the contract commit shows tracker docs only (no `apps/` paths).
- Parent close runs the full `features/feat-019.md` Verify procedure (proof binary +
  skip/bound + privacy + cost + byte-compare), never manual QA, never a physical device.
