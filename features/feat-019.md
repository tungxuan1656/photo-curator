# feat-019 — Contextual quality signals

## Status and kind

- Status: `active`
- Kind: `integration`
- Depends on: `feat-018` (`done` on origin/main `72070d6`; verified before activation)

## Goal

Route expensive contextual (Tier-B) analysis only where feat-017 evidence plus
feat-018 universal facts show a material need. Targets F-017-E
(landscape/context under-selection) via composition evidence and
screenshot/document pollution via utility evidence. This feature produces raw
composition and utility facts only; feat-020 owns the people/group decision
policy. No weight, threshold, or scorer-math change in the contract commit.

## Contract boundary

The parent owns Tier-B eligibility, cache/version behavior, fact schema, and
pipeline wiring — the same four shared files as feat-018, plus this record:

- `Domain/Models/PhotoAnalysis.swift`
- `Services/Analysis/VisionAnalysisService.swift`
- `Services/Photos/BatchPipeline.swift`
- `Infrastructure/FileAnalysisCache.swift`
- `features/feat-019.md`

Raw facts remain separate from selection weights: this commit persists no new
fact and changes no weight, threshold, or scorer math. No child may edit the
shared files above or a sibling file. (`features/mini-019a.md` /
`features/mini-019b.md` / `features/mini-019c.md` transfer to their mini on
dispatch; the parent retains the frozen routing sections.)

## FROZEN Tier-B routing contract (locked 2026-09-17, base `72070d6`)

Base versions: `analysisVersion 2`, `engineVersion 2`, `configVersion 1`, cache
`schemaVersion 1`. Persisted per-photo changes take `analysisVersion` 2 → **3**
at parent integration (Task 3), never in a child. The feat-018 extension rule
holds: the new version's rows requeue by miss, never by crash or migration.

### Tier-A runs first

Tier-B predicates read Tier-A facts from the same `performAll` pass
(`faceCount`, `aestheticScore`, `tags`, transient `isUtility`, `mediaSubtypes`,
technical scores, pixel dims). Tier-B never runs before Tier-A in the same
asset pass.

### Eligible subset policy (exact trigger per request)

Revisions verified in the iOS 26.5 SDK headers on 2026-09-17.

| Request | Revision (frozen) | Eligible iff (all Tier-A, same pass) | Target |
|---|---|---|---|
| Attention saliency | rev 2, fallback rev 1 (improved accuracy/latency/memory per header) | `faceCount == 0` AND technically usable | F-017-E faceless composition |
| Horizon | rev 1 (only revision) | saliency-eligible AND `pixelWidth >= pixelHeight` | F-017-E landscape level |
| Person segmentation, `.balanced` | rev 1 | `faceCount >= 1` AND technically usable; output feeds `visualBalanceScore` ONLY — `faceCount`/people facts untouched (feat-020 owns) | composition balance |
| OCR text recognition | rev 3, `.accurate`, language correction on | (`mediaSubtypes` contains screenshot OR transient `isUtility == true`) AND technically usable | utility/document pollution |
| Document segmentation | rev 1 | same predicate as OCR | `isDocument` |

`Technically usable` = not on the frozen low-quality path (Tier-B cannot
rescue a bad photo; F-017-F stays Tier-A). Miss-rate note: utility triggers
cover screenshot-subtype and `isUtility` assets only; photos of documents with
neither signal are an honest miss, and mini-019b measures trigger coverage on
Golden-shape rather than widening the predicate here.

Explicitly OUT of feat-019: objectness saliency (one saliency family
suffices); foreground/person-instance masks (subject-fraction overlap with
saliency + person-seg); smudge (no such request exists in the iOS 26.5 SDK
headers — mini-019c records it UNAVAILABLE); pose/landmarks (mini-019c matrix
only, never persisted here); any Core ML/embedding (feat-024).

### Expected-value skip rule

SKIP all Tier-B work for the asset when ANY holds: (1) cache hit at version 3;
(2) technically unusable; (3) no eligibility predicate true; (4) the request is
SDK-unavailable (one throw lands in the fallback arm, no in-run retry).
Otherwise RUN each eligible request once. Skip fractions per shape are measured
in Verify (Tier-B skip/bound proof) — the rule is observable, not aspirational.

### Bounded output shapes per fact (persisted at version 3)

| # | Field | Type | Source | Unavailable value |
|---|---|---|---|---|
| 1 | `composition.horizonScore` | `Double?` 0…1 (REUSED slot, nil today) | first `VNHorizonObservation.angle`: `levelness = clamped01(1 - abs(angle)/(π/6))` | `nil` = not run or empty results |
| 2 | `composition.visualBalanceScore` | `Double?` 0…1 (REUSED slot, nil today) | person-seg foreground pixel fraction | `nil` = not run or empty mask |
| 3 | `composition.salientRegionCount` | `Int?` NEW, 0…10 capped | `salientObjects.count` (attention saliency) | `nil` = not run |
| 4 | `content.hasText` | `Bool?` (REUSED slot, nil today) | any text observation with top-1 confidence ≥ 0.5 | `nil` = not run |
| 5 | `content.textLineCount` | `Int?` NEW, 0…50 capped | text observation count | `nil` = not run |
| 6 | `content.screenshotProbability` | `Double?` (REUSED slot, nil today) | 1.0 screenshot subtype; else 0.7 `isDocument`; else 0.2 `hasText`; else 0.0 | `nil` = utility Tier-B not run |
| 7 | `content.isDocument` | `Bool?` NEW | any doc-seg rectangle | `nil` = not run |

New fields decode with `decodeIfPresent` (version-2 rows still decode; the
version gate treats them as miss, not crash).

### Privacy plus retention rules

Derived scalars/counts/flags ONLY. NEVER persisted: raw OCR strings (or string
lists, or confidence pairs), any rectangles/boxes (salient, text, document,
face), masks/pixel buffers/heatmaps, landmarks, pose joints, or face data
beyond the existing version-2 slots. `privacy.md` §3/§6 hold unchanged: the
cache holds compact derived values (never blobs); retention is until reset or
version change; logs carry no asset IDs and no text content (short hash or
index only). No per-person identity is created; counts stay in the existing
`PeopleAnalysis` (feat-020 owns any change there).

### Cache/version behavior

`analysisVersion` 2 → 3 at parent Task 3. The existing version gate IS the
migration: `FileAnalysisCache` reuses a row only when
`stored.analysisVersion == current (3)`; `BatchPipeline.completedIDs` ignores
checkpoints whose `analysisVersion != current`, so stale checkpoints re-queue
through the cache instead of marking prior work unavailable. Requeue rule: any
row or checkpoint with `analysisVersion != 3` is recomputed from pixels once,
then stored at 3. `Reset Analysis` semantics unchanged (apple-frameworks §8: do
not migrate ephemeral AI fields). No new migration code.

### Pipeline wiring points (parent Task 3, after children merge)

1. `VisionAnalysisService.performAll`: Tier-A (existing requests plus
   `UniversalFactAdapter`) → eligibility predicates → eligible Tier-B requests
   (same handler, independent `try?` per request, cancellation checks between
   requests) → pure map.
2. `PhotoAnalysis.make`: new parameters (`salientRegionCount`, `textLineCount`,
   `isDocument` plus the reused slots); `currentVersion` follows config 3.
3. `BatchPipeline` / `FileAnalysisCache`: no structural change (restore /
   rebuild / version-ignore paths already handle the bump).
4. Scoring: NO change. `horizonScore`/`visualBalanceScore` already fold into
   the composition mean over available signals only (no numerator/denominator
   when nil) — populating the facts flows through with zero scorer change and
   unchanged weights. Salient-count and utility facts gain no scorer consumer
   in feat-019 (feat-020+).
5. `AppConfiguration.default.analysis.analysisVersion`: 2 → 3.

### Deterministic fallback per fact

One attempt per asset per run; failure lands in the Unavailable column above
(never a throw, never a fabricated score). Mapping functions are pure: same
observation values give the same fact. Same-image rerun determinism is proven
by the double-run byte-compare in Verify; transient-request nondeterminism is
bounded to nil-vs-value and resolves on the next version bump or Reset
Analysis. Cancel and memory-critical paths are unchanged.

## Admitted mini-features (merge order: 019a → 019b → 019c-conditional)

| Order | Mini | Exclusive owns | Merge gate |
|---|---|---|---|
| 1 | `mini-019a` — composition evidence adapter | `Services/Analysis/CompositionEvidenceAdapter.swift`, `features/mini-019a.md` | Pure mapping per frozen schema, bounded outputs, explicit unavailable values; no shared-contract/sibling diff; `./init.sh` passes |
| 2 | `mini-019b` — utility evidence adapter | `Services/Analysis/UtilityEvidenceAdapter.swift`, `features/mini-019b.md` | Pure mapping per frozen schema + trigger-coverage note, bounded outputs, no raw text persisted; no shared-contract/sibling diff; `./init.sh` passes |
| 3 | `mini-019c` — experimental availability matrix (CONDITIONAL) | `docs/evidence/tier-b-experimental-matrix.md`, `features/mini-019c.md` | Activates only on a parent-named residual failure; benchmark-backed accept/reject per candidate; no `apps/` diff; `./init.sh` passes |

Ownership is non-overlapping; no mini touches a shared contract or a sibling
file. 019b starts after 019a merges. 019c stays `todo` until the parent names
the residual failure it targets. Full 12-field cards live in each mini file
and `docs/plans/feat-019.md`.

## Acceptance (Simulator code-evidence; manual QA replaced per user directive 2026-09-16)

- [ ] A-shape + Golden-shape proof binary (REAL shipped sources verbatim, run
  twice, byte-compare) shows Tier-B facts live with deterministic fallback.
- [ ] Tier-B skip/bound proof: measured skip fractions per shape; every
  persisted output within the frozen bounds; no unbounded shape.
- [ ] Privacy no-persist proof: persisted rows hold derived facts only — no
  strings, boxes, masks, landmarks, or joints.
- [ ] Cost vs budget: cold/warm per Tier-B request plus pipeline delta judged
  against the performance.md budgets (procedure in Verify; results in Handoff).

## Relevant docs

- `docs/design-docs/curation-intelligence.md` (failure F-017-E, §15 privacy/determinism)
- `docs/design-docs/curation-runtime-stack.md` (§2 tiers, §3 routing, §5 native policy)
- `docs/design-docs/apple-frameworks.md` (§8 Vision pipeline)
- `docs/design-docs/data-model.md` (§4 invariants, §6 shapes)
- `docs/ship-gates/performance.md` (§1/§5 budgets, regression flag)
- `docs/ship-gates/privacy.md` (canonical retention/classification owner)
- `docs/exec-plans/curation-intelligence-v2-parallel-delivery.md`

## Inline plan

1. Contract commit (this commit): activate, freeze Tier-B routing, admit 019a
   + 019b + 019c-conditional as `todo`. No `apps/` change.
2. Children: 019a composition adapter, then 019b utility adapter, then 019c
   matrix iff a residual failure is named; merge in order with independent reviews.
3. Parent Task 3: wire predicates + requests + `make` + version 3, run the
   Verify procedure, gate feat-020.

## Verify (Simulator code-evidence; manual QA replaced per user directive 2026-09-16)

- Proof binary compiling the REAL shipped Domain + adapter sources verbatim
  runs A-shape (60, manifest `33bf85cf…`) + Golden-shape (200, manifest
  `e61200e0…`) fixture bytes through analyze→score→select twice; byte-compare
  (md5) proves fallback determinism; skip fractions and bound asserts recorded
  per shape.
- Privacy proof: persisted JSON rows scanned for forbidden keys/shapes (raw
  strings, rectangles/boxes, masks, landmarks, joints) → none present.
- Cold cost (version-2 rows read as miss: full re-analyze incl. eligible
  Tier-B requests) + warm cost (version-3 cache hits) per asset; total pipeline
  delta vs the feat-018 warm baseline judged against the performance.md >~20%
  regression flag under the §1 conditions (local assets, normal thermals, Low
  Power off). Host-harness macOS Vision backend: the booted-Simulator Vision
  path throws `espresso-context` here (mini-018b finding), so no Simulator
  Vision numbers are claimed; Simulator build + launch no-crash comes from
  `./init.sh`.
- `./init.sh` PASS; `git diff --name-only` shows owned files only, no unrelated `apps/` path.
- Simulator-only HARD RULE: never touch a physical iPhone via any channel
  (no devicectl-physical / pymobiledevice3 / idb-physical / launch). Verify
  lane: Codex gpt-5.6-luna; build lanes: OMP.

## Handoff

- State: active (sole integration parent; contract commit only, no `apps/` change)
- Activation precondition: origin/main `feature_index.json` verified 2026-09-17 —
  `feat-018` reads `done` (squash #37 at `72070d6`), `feat-019` reads `todo`; the
  AGENTS.md dependency rule (dependency done before activation) is satisfied. Repo idle:
  no other `active` feature.
- Next: dispatch `mini-019a`; merge 019a → 019b → 019c-conditional with
  independent reviews; then parent Task 3 (wire + version 3 + Verify, gate feat-020).
