# feat-018 — Universal quality signals

## Status and kind

- Status: `active`
- Kind: `integration`
- Depends on: `feat-017` (`done` on origin/main `a877fa0`; verified before activation)

## Goal

Add cheap, universal facts that improve quality decisions without tier-B or model cost.
Targets feat-017 failures F-017-E (landscape/context under-selection) and F-017-F
(bad-photo selection); secondary input to Golden regression. No tier-B/C/D/E work and
no weight, threshold, or scorer-math change in the contract commit.

## Contract boundary

The parent owns `PhotoAnalysis`, cache migration, `analysisVersion`, and pipeline wiring:

- `Domain/Models/PhotoAnalysis.swift`
- `Services/Analysis/VisionAnalysisService.swift`
- `Services/Photos/BatchPipeline.swift`
- `Infrastructure/FileAnalysisCache.swift`
- `features/feat-018.md`

Raw facts remain separate from selection weights: this commit persists no new fact and
changes no weight, threshold, or scorer math. No child may edit the shared files above
or a sibling file. (`features/mini-018a.md` / `features/mini-018b.md` transfer to their
mini on dispatch; the parent retains the frozen schema sections.)

## FROZEN universal fact schema (locked 2026-09-16, base `a877fa0`)

Base versions: `analysisVersion 1`, `engineVersion 2`, `configVersion 1`, cache
`schemaVersion 1`. Persisted per-photo changes take `analysisVersion` 1 → **2** at
parent integration (Task 3), never in a child.

### New persisted fields (all inside `PhotoAnalysis`, version 2)

| # | Field | Type | Source | Unavailable value |
|---|---|---|---|---|
| 1 | `composition.aestheticScore` | `Double?` 0…1 | aesthetics `overallScore`, mapped (see VN table) | `nil` = not run or request failed; distinct from middling 0.5 |
| 2 | `content.tags` | `[SemanticTag]`, max 3, confidence-ordered | top-3 `VNClassifyImageRequest` identifier + confidence pairs | `[]` = request failed or no results; never fabricated |
| 3 | `featurePrintAvailable` | `Bool`, default `false` | `VNGenerateImageFeaturePrintRequest` produced a print consumed transiently | `false` = no print; asset groups as singleton (current behavior) |
| 4 | PhotoKit metadata allowlist | no new field; frozen fetch/map contract | `PhotoLibraryPermissionService.map` | unmapped fields are never read |

Field 1 reuses the existing Optional slot (always `nil` today); field 2 reuses the
existing tags slot (always `[]` today); field 3 is the one new stored scalar. Face
boxes, precise location, and feature-print blobs are NEVER persisted (data-model §4,
apple-frameworks §8) — field 3 records availability only.

Availability-plus-provenance: availability is the Optional / empty / `false` above
(missing is `nil`, never a fake 0 or 0.5 per data-model §4). Provenance is
`analysisVersion 2` plus the frozen request-revision table below — no per-row strings.

### Allowed PhotoKit metadata (frozen; fetch reads nothing else)

`localIdentifier`, `creationDate`, `pixelWidth`, `pixelHeight`, `mediaSubtypes`,
`isFavorite`, `hasAdjustments`. Explicitly forbidden: `location`, burst identifiers,
face data, image blobs. Matches the current `map` exactly — no fetch change in feat-018.

### VN request mapping

All requests run on the 512 px analysis `CGImage`, orientation `.up`, inside the
existing `performAll` lane structure (one handler, independent `try?` per request,
cancellation checks between requests). Revisions: SDK default at build (classify rev 2
on iOS 17+; aesthetics rev 1, the only revision — verified in the iOS 26.5 SDK headers).

| Request | Observation (bounded shape) | Fact mapping | Unavailable |
|---|---|---|---|
| `VNCalculateImageAestheticsScoresRequest` (iOS 18+) | first `VNImageAestheticsScoresObservation`: `overallScore` Float in [-1, 1], `isUtility` Bool | `aestheticScore = clamped01((Double(overallScore) + 1) / 2)` in `PhotoAnalysis.make`; `isUtility` is transient utility-policy input only, never persisted | throw / empty results → `aestheticScore nil` |
| `VNClassifyImageRequest` (1,303-identifier taxonomy) | `VNClassificationObservation` list: `identifier` String + `confidence` (`VNConfidence` 0…1) | `tags` = top-3 by confidence as `SemanticTag(name:identifier, confidence:)`; `sceneType` rule UNCHANGED (faces-based) in feat-018 | throw / empty → `tags []` |
| `VNGenerateImageFeaturePrintRequest` (existing) | first `VNFeaturePrintObservation` | transient edges only (unchanged); sets `featurePrintAvailable` | nil print → `false` |

No saliency, mask, horizon, OCR, smudge, or pose requests in feat-018 (tier-B,
feat-019). No Core ML, no embedding (feat-024).

### Cache migration + requeue rule

No migration code: the existing version gate IS the migration. `FileAnalysisCache`
reuses a row only when `stored.analysisVersion == current (2)`; version-1 rows read as
miss. `BatchPipeline.completedIDs` ignores checkpoints whose `analysisVersion !=
current`, so stale checkpoints re-queue through the cache instead of marking prior work
unavailable. Requeue rule: any row or checkpoint with `analysisVersion != 2` is
recomputed from pixels once, then stored at 2. `Reset Analysis` semantics unchanged
(apple-frameworks §8: do not migrate ephemeral AI fields).

### Pipeline wiring points (parent Task 3, after children merge)

1. `VisionAnalysisService.performAll`: add aesthetics + classify requests beside the
   face/print requests (same independent-degrade pattern).
2. `PhotoAnalysis.make`: new parameters (aesthetic, tags, featurePrintAvailable);
   `currentVersion` follows config 2.
3. `BatchPipeline`: no structural change (restore / rebuild / version-ignore paths
   already handle the bump).
4. Scoring: `QualityScorer.score` ALREADY folds `aestheticScore` into the composition
   mean over available signals only (no numerator/denominator when nil) — populating
   the fact flows through with zero scorer change and unchanged weights.
   `tags` gain no scorer consumer in feat-018 (feat-019+).
5. `AppConfiguration.default.analysis.analysisVersion`: 1 → 2.

### Deterministic fallback per fact

One attempt per asset per run; failure lands in the Unavailable column above (never a
throw, never a fabricated score). Mapping functions are pure: same observation values
give the same fact. Same-image rerun determinism is proven by the double-run
byte-compare in Verify; transient-request nondeterminism is bounded to nil-vs-value and
resolves on the next version bump or Reset Analysis. Cancel and memory-critical paths
are unchanged.

## Admitted mini-features (merge order: 018a → 018b)

| Order | Mini | Exclusive owns | Merge gate |
|---|---|---|---|
| 1 | `mini-018a` — universal aesthetics + classification adapter | `Services/Analysis/UniversalFactAdapter.swift`, `features/mini-018a.md` | Pure mapping per frozen schema, bounded outputs, explicit unavailable values; no shared-contract/sibling diff; `./init.sh` passes |
| 2 | `mini-018b` — universal-request cost benchmark | `docs/evidence/universal-request-cost.md`, `features/mini-018b.md` | Cold/warm per-request cost + QoS path note recorded; no `apps/` diff; `./init.sh` passes |

Ownership is non-overlapping; neither mini touches a shared contract or a sibling file.
018b starts after 018a merges (it needs stable adapter input shapes). Full 12-field
cards live in each mini file and `docs/plans/feat-018.md`.

## Acceptance

- [ ] Aesthetics, classification, FeaturePrint policy flag, and allowed PhotoKit metadata
  are represented with availability and provenance per the frozen schema above.
- [ ] Persisted per-photo fact changes bump `analysisVersion` 1 → 2 with the no-migration
  requeue rule; cache safety preserved.
- [ ] A-shape + Golden-shape Simulator code-evidence moves the feat-017 SYNTHETIC baseline
  for F-017-E/F with no >~20% pipeline regression (procedure in Verify).
- [ ] Fallback is deterministic per fact (nil/empty/false mapping proven by double-run
  byte-compare; no fabricated values).

## Relevant docs

- `docs/design-docs/curation-intelligence.md` (failures F-017-E/F)
- `docs/design-docs/curation-runtime-stack.md` (§2 tiers, §5 native policy)
- `docs/design-docs/apple-frameworks.md` (§8 Vision pipeline)
- `docs/design-docs/data-model.md` (§4 invariants, §6 shapes)
- `docs/ship-gates/performance.md` (§5 budgets, regression flag)
- `docs/exec-plans/curation-intelligence-v2-parallel-delivery.md`

## Inline plan

1. Contract commit (this commit): activate, freeze schema, admit 018a + 018b as `todo`.
   No `apps/` change.
2. Children: 018a adapter, then 018b benchmark; merge in order with independent reviews.
3. Parent Task 3: wire requests + `make` + version 2, run the Verify procedure, gate feat-019.

## Verify (Simulator code-evidence; manual QA replaced per user directive 2026-09-16)

- Proof binary compiling the REAL shipped Domain + adapter sources verbatim runs A-shape
  (60, manifest `33bf85cf…`) + Golden-shape (200, manifest `e61200e0…`) fixture bytes
  through analyze→score→select twice; byte-compare (md5) proves fallback determinism;
  SYNTHETIC proxy metrics (mini-017a rules v1) compare version-2 facts against the
  feat-017 baseline for F-017-E/F movement.
- Cold cost (version-1 rows read as miss: full re-analyze incl. 2 new requests) + warm
  cost (version-2 cache hits + print rebuild) per asset from the mini-018b evidence;
  total pipeline delta vs the feat-017 H-1000 host-harness baseline stays within the
  performance.md >~20% regression flag. Simulator-only; never a device claim.
- QoS: no new task API — new requests run inside the existing structured lanes and
  inherit lane priority (no `Task.detached`, no priority parameter); mini-018b records
  the propagation path.
- `./init.sh` PASS; `git diff --name-only` shows owned files only, no unrelated `apps/` path.
- Simulator-only HARD RULE: never touch a physical iPhone via any channel
  (no devicectl-physical / pymobiledevice3 / idb-physical / launch).

## Handoff

- State: active (sole integration; contract commit only, no `apps/` change)
- Activation precondition: origin/main `feature_index.json` verified 2026-09-16 —
  `feat-017` reads `done` (squash #33 at `a877fa0`), `feat-018` reads `todo`; the
  AGENTS.md dependency rule (dependency done before activation) is satisfied. Repo idle:
  no other `active` feature. (Task premise expected feat-017 `active`; the #33 SYNTHETIC
  close flipped it to `done`, which satisfies the rule more strongly.)
- Evidence: `./init.sh` PASS at this commit (format, `swiftlint --strict`, Simulator build SUCCEEDED, SKIP [test] by policy); `git diff --name-only` owned-files-only.
- Blockers: none.
- Next: dispatch `mini-018a`; merge 018a → 018b; then parent Task 3 (wire + version bump + Verify).
