# feat-018 — Universal quality signals

## Status and kind

- Status: `done`
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

- [x] Aesthetics, classification, FeaturePrint policy flag, and allowed PhotoKit metadata
  are represented with availability and provenance per the frozen schema above
  (wired in Task 3: `PhotoAnalysis.featurePrintAvailable` persisted, `aestheticScore`
  populated via `make`, `tags` populated, allowlist unchanged in `map`).
- [x] Persisted per-photo fact changes bump `analysisVersion` 1 → 2 with the no-migration
  requeue rule; cache safety preserved (cache proof `REQUEUE-RULE: PASS`, below).
- [x] A-shape + Golden-shape Simulator code-evidence moves the feat-017 SYNTHETIC baseline
  for F-017-E/F with no >~20% pipeline regression (procedure in Verify; results in
  Handoff — movement is rank-order only, see the honest reading).
- [x] Fallback is deterministic per fact (nil/empty/false mapping proven by double-run
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

- State: done (parent PR #36 squash-MERGED via `a68c89a` 2026-09-16; contract + children + Task 3 + findings fix all on main; index flipped `active` → `done`)
- Activation precondition: origin/main `feature_index.json` verified 2026-09-16 —
  `feat-017` reads `done` (squash #33 at `a877fa0`), `feat-018` reads `todo`; the
  AGENTS.md dependency rule (dependency done before activation) is satisfied. Repo idle:
  no other `active` feature.
- Task 3 wiring (this commit, the only shared-contract change): `PhotoAnalysis` gains
  persisted `featurePrintAvailable: Bool` (availability only; blob never persisted);
  `make` gains `aestheticScore`/`tags`/`featurePrintAvailable` params (defaults
  nil/[]/false) wiring the frozen facts; `VisionAnalysisService.performAll` calls
  `UniversalFactAdapter.collect` (phase 1, same 512 px `.up` input, independent degrade,
  cancel maps to `.cancelled`) then `map` (phase 2, pure) with the existing
  first-print-or-nil signal; `AppConfiguration.default.analysis.analysisVersion` 1 → 2.
  No scorer-math/weight/threshold change (`QualityScorer.score` already folds
  `aestheticScore` into the composition mean over available signals only —
  verified by reading `QualityScorer.swift:49-59`); `tags` gain no scorer consumer.
  `FileAnalysisCache` version gate + `BatchPipeline.completedIDs` checkpoint-ignore
  already implement the frozen requeue rule — no new migration code.
- Task 3 Verify (Simulator code-evidence, host-harness macOS Vision backend; never
  manual QA, never a physical device; proof sources kept at
  `/tmp/f017-evidence/v2proof-main.swift` + `v2time.swift` + `v1time.swift` +
  `cacheproof.swift`, outside the repo, hosts only, never shipped):
  - Proof binary compiles the REAL shipped sources verbatim (Domain Models/Selection/
    Scoring + `AppConfiguration` + `ServiceProtocols` + `ImageSimilarityArtifact` +
    `UniversalFactAdapter` + `VisionAnalysisService`; main `bc409f47…`, binary
    `65de92e2…`) and runs the REAL `analyze` (incl. wired adapter) → `make` (v2) →
    `select` on A-shape (60, manifest `33bf85cf…`) + Golden-shape (200, manifest
    `e61200e0…`) fixture bytes twice. Facts observed live: aes 60/60 + 200/200,
    tags 180 + 600 (3/asset), prints 60/60 + 200/200. Determinism byte-compare:
    A md5 `01975608…ccc3` == `01975608…ccc3`; Golden `9f7792c7…3445` ==
    `9f7792c7…3445`. PASS.
  - F-017-E/F movement (SYNTHETIC proxy labels v1, same rule as feat-017 — q from
    fixture bytes, thresholds 0.5/0.8; HONEST READING: proxy-class totals are
    unchanged — A m1 0.240/m2 1.000/m3 0.000/m6 1.000/m7 0.200/m8 3.17 and Golden m1
    0.160/m2 1.000/m3 0.000/m6 1.000/m7 0.150/m8 5.23 identical v1→v2 — because
    every swapped pick stays inside MUST_KEEP; the v2 facts RE-RANK within the
    proxy top class: A 3/12 picks differ (`A_011/A_019/A_055` → `A_009/A_029/A_038`,
    all q 0.85–0.91 MUST_KEEP), Golden 12/30 differ with 5 A-part + 25 G-part
    composition preserved. The aesthetic signal flows end-to-end (nil→populated,
    composition mean now divides by 2 signals instead of 1) without breaking any
    proxy metric — integration signal-live, NOT a quality-gain claim; SYNTHETIC
    proxies cannot judge taste, and Golden human annotation stays pending).
  - Cold/warm cost (same host, same A-shape bytes @ 512 px; v2 binary `b009e249…`
    via REAL `analyze` vs v1-shape binary `74e6a748…` running the face/print-only
    request set + formula-identical luma probe): v2 cold 26.83 ms/asset, warm 21.75;
    v1-shape cold 18.68, warm 14.95. Pipeline delta = +8.15 ms/asset cold (+43.6%),
    +6.80 warm (+45.5%) — EXCEEDS the performance.md >~20% regression flag ON THIS
    HOST. Honest disposition: host-harness per-asset Vision inference cost is not
    the shipped pipeline budget (no batching/lanes/cache-hits, macOS backend not
    the device backend, H-1000 baseline ran zero Vision inference); the flag is
    judged at parent close against the warm-cache-hit path + lane parallelism, and
    NO budget constant is proposed or changed here. Recorded, not hidden.
  - QoS: confirmed unchanged — no `Task.detached`, no `TaskPriority`, no priority
    argument in `UniversalFactAdapter.swift` / `VisionAnalysisService.swift` lane
    bodies; new requests run inside the existing `BatchPipeline.drain` structured
    lanes and inherit lane priority (mini-018b §5 cites hold; wiring adds `perform`
    calls inside the same synchronous lane body).
  - Cache requeue proof (REAL `FileStore` + `FileAnalysisCache` +
    `SessionCheckpointStore` sources; main `58a68276…`, binary `1334bd3a…`):
    `currentVersion=2 v1rowMiss=true v2rowHit=true v1ckptIgnored=true
    v2ckptKept=true` → `REQUEUE-RULE: PASS` (v1 rows requeue, v2 rows hit).
- Evidence: `./init.sh` PASS at this commit (format, `swiftlint --strict` 0
  violations, Simulator build SUCCEEDED, SKIP [test] by policy).
- feat-019 admission gate: may start only after the parent PR to main merges AND
  its contract freezes contextual routing (tier-B subset policy), fallback bounds,
  and the F-017 failure target with a measured remedy pointer. feat-019 owns the
  same four shared-contract files after this branch lands; it must not reinterpret
  the version-2 frozen schema (aesthetic map, top-3 tags, print-availability flag,
  allowlist) — extensions bump `analysisVersion` 2 → 3 with the same requeue rule.
- Blockers: none.
- Closeout (done-flip, branch `tungxuan1656/feat-018-doneflip` from origin/main `a68c89a`):
  - Squash evidence: parent PR #36 state MERGED, mergeCommit `a68c89a` (= origin/main HEAD); squash body contains the full chain — contract `cf9cd52`, child `5b731bb` (018a, PR #34 MERGED) + `fcd4641` (018b, PR #35 MERGED), Task 3 `bc7cbd0`, findings fix `2a0834e`; pre-squash commits verified present via `git cat-file -t`.
  - Acceptance re-verified on main (all four boxes honestly still pass, read checked): (1) wiring — `featurePrintAvailable` persisted (`PhotoAnalysis.swift:77`), `make` params (`:113-115`), `performAll` wires `collect`+`map` (`VisionAnalysisService.swift:144-158`), `analysisVersion: 2` (`AppConfiguration.swift:61`), `UniversalFactAdapter.swift` + `docs/evidence/universal-request-cost.md` exist; (2) version-2 + requeue — cache version gate (`FileAnalysisCache.swift:26,35`), checkpoint-ignore (`BatchPipeline.swift:381`), v1 `decodeIfPresent`→false (`PhotoAnalysis.swift:158`); (3) Verify code-evidence — Task 3 proof results recorded in this Handoff stand (determinism byte-compare PASS, rank-order movement honest reading, cold/warm disposition recorded); (4) fallback determinism — unavailable mapping nil/[]/false in adapter `map` (`:94-102`).
  - Minis `mini-018a`/`mini-018b` already `done` in `feature_index.json`; `feat-019` stays `todo` (no start here; its contract must still freeze tier-B routing, fallback bounds, and the F-017 target with a measured remedy pointer, and bump `analysisVersion` 2 → 3 for extensions).
- Next: feat-019 selection remains user-gated; feat-019 must not start here.
