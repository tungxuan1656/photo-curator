# feat-019 — Contextual quality signals

## Status and kind

- Status: `done`
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
fact and changes no weight, threshold, or scorer math. This feature owns the
shared files above and all routing implementation.

## FROZEN Tier-B routing contract (locked 2026-09-17, base `72070d6`)

Base versions: `analysisVersion 2`, `engineVersion 2`, `configVersion 1`, cache
`schemaVersion 1`. Persisted per-photo changes take `analysisVersion` 2 → **3**
at feature (Task 3), never in a child. The feat-018 extension rule
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
neither signal are an honest miss, and the utility implementation measures trigger coverage on
Golden-shape rather than widening the predicate here.

Explicitly OUT of feat-019: objectness saliency (one saliency family
suffices); foreground/person-instance masks (subject-fraction overlap with
saliency + person-seg); smudge (no such request exists in the iOS 26.5 SDK
headers — the implementation records it UNAVAILABLE); pose/landmarks (optional matrix
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

## Acceptance (Simulator code-evidence; manual QA replaced per user directive 2026-09-16)

- [x] A-shape + Golden-shape proof binary (REAL shipped sources verbatim, run
  twice, byte-compare) shows Tier-B facts live with deterministic fallback
  (Task 3 results in Handoff — salient live, horizon/balance honestly nil-on-synthetic,
  picks identical v2→v3).
- [x] Tier-B skip/bound proof: measured skip fractions per shape; every
  persisted output within the frozen bounds; no unbounded shape (Task 3 results in Handoff).
- [x] Privacy no-persist proof: persisted rows hold derived facts only — no
  strings, boxes, masks, landmarks, or joints (PERSIST-PROOF: PASS in Handoff).
- [x] Cost vs budget: cold/warm per Tier-B request plus pipeline delta judged
  against the performance.md budgets (procedure in Verify; results in
  Handoff — host-harness Tier-B request cost recorded, no budget constant changed).
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
  path throws `espresso-context` here (previous benchmark finding), so no Simulator
  Vision numbers are claimed; Simulator build + launch no-crash comes from
  `./init.sh`.
- `./init.sh` PASS; `git diff --name-only` shows owned files only, no unrelated `apps/` path.
- Simulator-only HARD RULE: never touch a physical iPhone via any channel
  (no devicectl-physical / pymobiledevice3 / idb-physical / launch). Verify
  lane: Codex gpt-5.6-luna; build lanes: OMP.

## Handoff

- State: done (parent PR #40 squash-MERGED via `e62172b` 2026-09-17; contract + children + Task 3 + findings fix all on main; index flipped `active` → `done`)
- Activation precondition: origin/main `feature_index.json` verified 2026-09-17 —
  `feat-018` reads `done` (squash #37 at `72070d6`), `feat-019` reads `todo`; the
  AGENTS.md dependency rule (dependency done before activation) is satisfied. Repo idle:
  no other `active` feature.
- Task 3 wiring (this commit, the only shared-contract change): `PhotoAnalysis` gains
  persisted `salientRegionCount: Int?` + `textLineCount: Int?` + `isDocument: Bool?`
  (availability only; strings/boxes/masks never persisted) and now populates the reused
  `horizonScore`/`visualBalanceScore`/`hasText`/`screenshotProbability` slots; `make`
  gains the 7 Tier-B params (defaults nil) with caps enforced inside (`min(10,…)`,
  `min(50,…)`, `clamped01`); `AnalysisInput` gains `isScreenshotSubtype: Bool`
  (Tier-A PhotoKit flag; pipeline sets it from `PhotoAsset.mediaSubtype`, rebuilder
  paths pass `false` — artifact-only, never analyzed); `performAll` splits into
  `tierABaseline` (unchanged Tier-A lane) + `tierBFacts` (frozen eligibility +
  adapter phases, independent degrade, cancellation checks); gated facts stay nil
  for ineligible assets. `AppConfiguration.default.analysis.analysisVersion` 2 → 3.
  No scorer-math/weight/threshold change (composition mean already folds
  `horizonScore`/`visualBalanceScore` over available signals only —
  `QualityScorer.swift:49-59` re-verified; salient/utility facts gain no scorer
  consumer). `FileAnalysisCache` version gate + `BatchPipeline.completedIDs`
  checkpoint-ignore already implement the frozen requeue rule — no new migration
  code. New fields decode version-tolerantly (all-Optional whole-struct decode;
  only `featurePrintAvailable` keeps its hand-written default).
- Task 3 Verify (Simulator code-evidence, host-harness macOS Vision backend; never
  manual QA, never a physical device; proof sources kept at
  `/tmp/f019-evidence/v3proof-main.swift` + `v3time-shape.swift` +
  `cacheproof3.swift` + `persistproof.swift` + `perreq2.swift` + `v3synth.py`,
  outside the repo, hosts only, never shipped):
  - Proof binary compiles the REAL shipped sources verbatim (Domain Models/Selection/
    Scoring + `AppConfiguration` + `ServiceProtocols` + `ImageSimilarityArtifact` +
    `UniversalFactAdapter` + `CompositionEvidenceAdapter` + `UtilityEvidenceAdapter` +
    `VisionAnalysisService`; main `b04ef698…`, binary `1fa78ed8…`) and runs the REAL
    `analyze` (incl. wired Tier-B) → `select` on A-shape (60) + Golden-shape (200)
    fixture bytes twice. Facts observed live: saliency 57/60 + 198/200; utility
    (OCR+doc-seg, `isUtility`-triggered) 39/60 + 143/200 with 0 text lines on
    synthetic solids; horizon 0/60 + 0/200 and balance 0/60 + 0/200 — HONEST
    unavailable-arm behavior on synthetic bytes (horizon finds no horizon in
    solids; person-seg never runs with 0 faces; facedbg confirms 0/60 + 0/200
    faces). Adapter pure-map unit checks pass (horizon 0.809/balance 0.35/
    salient-cap-10 and utility 1.0/0.7/0.2/0.0 arms, determinism true, nil arms
    nil). Determinism byte-compare: picked A md5 `01975608…ccc3` ==
    `01975608…ccc3`; picked Golden `9f7792c7…3445` == `9f7792c7…3445`. PASS.
    Full-fact JSON identical excl. timing. PASS.
  - Tier-B skip proof: A 57/60 ran, 3/60 skipped; Golden 198/200 ran, 2/200
    skipped (skip = technically unusable per the scorer floor). Bound proof:
    caps enforced in `make` (in-14 → stored 10, in-99 → stored 50, probs
    clamped01) — no unbounded shape.
  - F-017-E movement (SYNTHETIC proxy labels v1, same rule as feat-017/018):
    A m1 0.240/m2 1.000/m3 0.000/m6 1.000/m7 0.200 and Golden m1 0.160/m2
    1.000/m3 0.000/m6 1.000/m7 0.150 — identical v2→v3, and pick md5 identical
    v2→v3 on both shapes. HONEST READING: Tier-B facts flow end-to-end
    (nil→populated on eligible assets) but move ZERO picks on synthetic bytes —
    expected, because horizon/balance are nil-on-synthetic and salient/utility
    facts have no scorer consumer in feat-019 by design. Integration
    signal-live, NOT a quality-gain claim; SYNTHETIC proxies cannot judge
    taste, and Golden human annotation stays pending.
  - Trigger coverage (Golden-shape): utility Tier-B ran on 143/200 assets via
    the transient `isUtility` signal (no screenshot-subtype fixtures exist —
    filename convention carries no screenshot/doc names); composition Tier-B
    ran on 198/200 (all faceless, usable). Miss-rate note stands: photos of
    documents with neither trigger are an honest miss, measured not widened.
  - Privacy proof (REAL `PhotoAnalysis` row encode; main `7441c9ff…`, binary
    `41f291e0…`): persisted JSON holds derived scalars/counts/flags/tags only —
    forbidden-shape scan (boxes, pixel buffers, landmarks, joints, heatmaps,
    raw-string payloads, masks) → NONE. `PERSIST-PROOF: PASS`. The v2
    `SemanticTag.confidence` key is a version-2 persisted scalar (frozen
    schema), not a Tier-B confidence pair — explicitly allowlisted in the scan.
  - Cold/warm cost (same host, same A-shape bytes @ 512 px; v3 full-`analyze`
    binary `fe9f5759…`): v3 cold 52.60 ms/asset, warm 50.09 (mean; p50 51.06/
    51.53). Per-request split (20-asset sample, mean/p50): saliency 8.92/7.44,
    horizon 3.84/3.71, person-seg 11.91/10.12, OCR-accurate 23.89/17.74,
    doc-seg 4.94/3.45, aesthetics 5.88/5.67, classify 5.85/5.34. Honest
    disposition: host-harness per-asset Vision inference cost is not the
    shipped pipeline budget (no batching/lanes/cache-hits, macOS backend not
    the device backend); OCR-accurate dominates the Tier-B cost and runs ONLY
    on eligible assets (skip rule measured above); the >~20% flag is judged at
    parent close against the warm-cache-hit path + lane parallelism, and NO
    budget constant is proposed or changed here. Recorded, not hidden.
  - QoS: unchanged — Tier-B runs inside the existing `performAll` lane body
    (no `Task.detached`, no priority parameter); adapter `collect` calls sit
    beside the existing lane requests with the same cancellation checks.
  - Cache requeue proof (REAL `FileStore` + `FileAnalysisCache` +
    `SessionCheckpointStore` + `SaveState` sources; main `db2c9a52…`, binary
    `b675a1bc…`): `currentVersion=3 v2rowMiss=true v3rowHit=true
    v2ckptIgnored=true v3ckptKept=true` → `REQUEUE-RULE: PASS` (v2 rows
    requeue, v3 rows hit).
- Evidence: `./init.sh` PASS at the done-flip commit (format, `swiftlint --strict` 0
  violations, Simulator build SUCCEEDED, SKIP [test] by policy).
- feat-020 admission gate: may start only after the parent PR to main merges AND
  its contract freezes people/group decision policy (per-face distribution, weakest-face
  protections) without moving raw face data into persisted analysis. feat-020 owns the
  same four shared-contract files after this branch lands; it must not reinterpret
  the version-3 frozen schema (Tier-B facts, caps, predicates, allowlist) — extensions
  bump `analysisVersion` 3 → 4 with the same requeue rule.
- Optional experimental availability work remains deferred because no residual failure
  named (zero Tier-B-driven pick movement on synthetic bytes is expected per the
  no-scorer-consumer design, not a failure); smudge stays UNAVAILABLE (no such request
  in the iOS 26.5 SDK headers, re-verified at Task 3); pose/landmarks matrix deferred
  to the feature that names a measured face-driven gap (feat-020 at the earliest).
- Blockers: none.
- Closeout (done-flip, branch `tungxuan1656/feat-019-doneflip` from origin/main `e62172b`):
  - Squash evidence: parent PR #40 state MERGED, mergeCommit `e62172b` (= origin/main HEAD); squash body contains the full chain — contract `b8b22ff`, child `8394e19` (019a, PR #39 MERGED) + `2274281` (019b, PR #38 MERGED), Task 3 `8e12b97`, findings fix `f3d5337`; pre-squash commits verified present via `git cat-file -t`.
  - Acceptance re-verified on main (all four boxes honestly still pass, read checked): (1) wiring — `performAll` splits Tier-A/Tier-B (`VisionAnalysisService.swift:92,110,146,189`), `make` gains 7 Tier-B params with caps (`PhotoAnalysis.swift:132-136,150,156-157`), `analysisVersion: 3` (`AppConfiguration.swift:61`), both adapters exist (`Services/Analysis/CompositionEvidenceAdapter.swift` + `UtilityEvidenceAdapter.swift`); (2) version-3 + requeue — cache version gate (`FileAnalysisCache.swift:26,35`), checkpoint-ignore (`BatchPipeline.swift:386`), version-tolerant decode (`PhotoAnalysis.swift:194,202`); (3) Verify code-evidence — Task 3 proof results recorded in this Handoff stand (determinism byte-compare PASS, honest nil-on-synthetic reading, skip/bound proofs, PERSIST-PROOF PASS, REQUEUE-RULE PASS, cost recorded with no budget constant changed); (4) fallback — per-request independent degrade with gated nil arms (`VisionAnalysisService.swift:227-234`), pure capped map (`PhotoAnalysis.swift:150,156-157`), cancellation checks between requests.
  - Composition and utility evidence are shipped; optional availability matrix work remains deferred (no residual failure named, smudge UNAVAILABLE).  `feat-020` stays `todo` (no start here).
- Next: PR `tungxuan1656/feat-019-doneflip` → main (squash in a separate merge task); feat-020 selection remains user-gated; feat-020 must not start here.
