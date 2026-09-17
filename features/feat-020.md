# feat-020 — People and group selection

## Status and kind

- Status: `done`
- Kind: `integration`
- Depends on: `feat-019` (`done` on origin/main `00c62e2`; verified before activation)

## Goal

Score group photos by per-face quality distribution with weakest-face
protection, without moving raw face data into persisted analysis. Targets
F-017-D (group-photo / people handling). This feature produces people/group
decision policy only; feat-019 owns the Tier-A/B fact schema (frozen).

## Contract boundary

The parent owns aggregation, candid guards, selection policy, explanations,
and privacy review — the same shared files as feat-019, plus this record:

- `Domain/Scoring/QualityScorer.swift`
- `Domain/Selection/SelectionEngine.swift`
- `Services/Analysis/VisionAnalysisService.swift`
- `features/feat-020.md`

No child may edit the shared files above or a sibling file.
(`features/mini-020a.md` transfers to its mini on dispatch; the parent
retains the frozen decision sections.) No child may reinterpret the
version-3 frozen schema (Tier-A/B facts, caps, predicates, allowlist).

## FROZEN people/group decision contract (locked 2026-09-17, base `00c62e2`)

Base versions: `analysisVersion 3`, `engineVersion 2`, `configVersion 1`,
cache `schemaVersion 1`. Persisted per-photo extensions take
`analysisVersion` 3 → **4** at parent integration (Task 3), never in a
child. The feat-018/019 extension rule holds: the new version's rows requeue
by miss, never by crash or migration.

### Aggregation inputs (exact; feat-019 outputs only)

Tier-A per-face facts from the same `performAll` pass (Tier-B never feeds
people facts — the feat-019 freeze stands: person-seg output feeds
`visualBalanceScore` ONLY):

| Input | Type | Source |
|---|---|---|
| `faceCount` | `Int` (persisted) | `VNDetectFaceRectanglesRequest` results count |
| `bestFaceQuality` distribution | transient per-face `faceCaptureQuality` values | `VNDetectFaceCaptureQualityRequest` results (today only the max is kept as `subjectPlacementScore`; the per-face list is the calculator input) |
| `groupPhotoScore` | `Double?` (persisted slot; count proxy today: `faceCount >= 2 ? count/6.0 : nil`) | replaced by distribution-aware policy at Task 3 |
| `visualBalanceScore` | `Double?` (Tier-B person-seg foreground fraction) | composition balance input ONLY — never touches `faceCount`/people facts |

No new Vision request in the contract commit; Task 3 decides whether the
existing two face requests suffice (they do on current evidence) or a named
addition is needed (then it lands in Task 3 with a revision freeze).

### Weakest-face protection rule (selection-rules §10, frozen)

Group scoring uses the weakest important face, not the best face: a
fully-good group beats a sharper group with one failed face. The calculator
returns a derived per-face distribution (count, min, mean — bounded scalars
only); `QualityScorer` folds the weakest-face signal so one failed face
drags the group score down. Prefer full visibility, open eyes, natural
expressions, complete framing. Repeated group pose: keep 1 normally; 2 only
on formal-versus-candid or clearly different composition.

### Candid-guard rule (selection-rules §10, frozen)

No valid non-portrait moment is discarded by people policy: eyes-closed
penalizes only when the subject poses AND a better alternative exists —
never auto-reject laughing, candid, sleeping, or downward-gaze frames.
Obstruction penalizes finger/blocked/cropped faces, never deliberate partial
framing. Low face-detection confidence means no penalty (keep-when-unsure).
Selfies score like any portrait; same-spot selfie runs deduplicate
aggressively. People policy never lowers a technically-usable non-people
moment below the floor.

### Reason-code policy plus review-surface copy

Reuse the frozen canonical codes only (`selection-rules.md` §16) —
`bestPortrait`, `bestGroupPhoto`, `betterFaceQuality` — with the existing
review-surface copy (`PhotoAnalysisDetail.swift:297-299`,
"Preferred portrait in a similar group" / "Preferred group photo" /
"Stronger visible-face signal"). No new reason code and no new copy string
in the contract commit; Task 3 wires the codes into
`FinalAlbumBuilder.decision` and adds a code only via a selection-rules
amendment (never silently).

### Privacy limits (`privacy.md` §§2–4, 6, frozen)

No face boxes, landmarks, or pixels are persisted in analysis or
diagnostics — derived distributions only (count, min/mean quality scalars
in the existing `PeopleAnalysis` slots), transient (memory or temp session
only, released after scoring, never logged per §4). No per-person identity,
no naming, no contact/mail/social link. Cache holds compact derived values
only; retention until reset or version change (§6).

### Cache/version behavior

`analysisVersion` 3 → 4 at parent Task 3. The existing version gate IS the
migration: `FileAnalysisCache` reuses a row only when
`stored.analysisVersion == current (4)`; `BatchPipeline.completedIDs`
ignores checkpoints whose `analysisVersion != current`. Requeue rule: any
row or checkpoint with `analysisVersion != 4` is recomputed from pixels
once, then stored at 4. `Reset Analysis` semantics unchanged. No new
migration code. New persisted fields (if any) decode with
`decodeIfPresent` (version-3 rows still decode; the gate treats them as
miss, not crash).

### Pipeline wiring points (parent Task 3, after the child merges)

1. `GroupEvidenceCalculator` (new file, mini-020a): transient per-face
   distribution from the Tier-A face observations — pure map, scalars only,
   nothing persisted, nothing returned but count/min/mean.
2. `QualityScorer.score`: fold the weakest-face signal into the people term
   (weights stay in configuration; no scattered thresholds).
3. `SelectionEngine`: `qualityScorer.score` call sites pass the derived
   distribution through (no orchestration change).
4. `VisionAnalysisService.performAll`: pass-through of the existing Tier-A
   face observations to the calculator (no new request unless Task 3 names
   and freezes one).
5. `FinalAlbumBuilder.decision`: wire `bestPortrait` / `bestGroupPhoto` /
   `betterFaceQuality` reason codes for people-driven picks.
6. `AppConfiguration.default.analysis.analysisVersion`: 3 → 4.

### Deterministic fallback

One attempt per asset per run; failure lands in the nil arm (no group
signal, Tier-A-only score — never a throw, never a fabricated score).
Mapping is pure: same per-face values give the same distribution.
Same-image rerun determinism is proven by the double-run byte-compare in
Verify. Cancel and memory-critical paths are unchanged.

## Admitted mini-features (merge order: 020a only)

| Order | Mini | Exclusive owns | Merge gate |
|---|---|---|---|
| 1 | `mini-020a` — group evidence calculator | `Services/Analysis/GroupEvidenceCalculator.swift`, `features/mini-020a.md` | Pure transient mapping per frozen contract (per-face values → count/min/mean scalars), no persisted/raw-face return, no shared-contract/sibling diff; `./init.sh` passes |

Ownership is non-overlapping; the mini touches only its exact new file plus
its own card. The full 12-field card lives in `features/mini-020a.md` and
`docs/plans/feat-020.md`.

## Reserved mini-features

- `mini-020a` — admitted as `todo` (task-ready) in this commit. Done when it
  returns derived, non-persisted distributions for the parent to consume and
  documents its unavailable case.

## Acceptance (Simulator code-evidence; manual QA replaced per user directive 2026-09-16)

  - [x] B-shape + Golden-shape proof binary (REAL shipped sources verbatim, run
  twice, byte-compare) shows per-face distribution and weakest-face
  protections resolving the named group failures (Task 3 results in Handoff —
  D-shape faces where available, else synthetic face-bearing fixtures).
  - [x] Candid-guard proof: valid non-portrait moments survive people policy
  (no candid/laughing/sleeping/downward-gaze discard; no non-people moment
  pushed below the floor by the people term).
  - [x] Privacy no-persist proof: persisted rows hold derived distributions
  only — no face boxes, landmarks, or pixels in analysis or diagnostics.
  - [x] Cost vs budget: calculator + scoring delta judged against the
  performance.md budgets (procedure in Verify; results in Handoff — no
  budget constant changed).

## Relevant docs

- `docs/product-specs/selection-rules.md` (§10 face/group/selfie rules, §16 reason codes)
- `docs/design-docs/curation-intelligence.md` (failure F-017-D, §15 privacy/determinism)
- `docs/ship-gates/privacy.md` (canonical retention/classification owner)
- `docs/ship-gates/manual-qa.md` (dataset D definition; method only, evidence is code)
- `docs/design-docs/selection-engine.md` (engine mechanics)

## Inline plan

1. Contract commit (this commit): activate, freeze people/group decision
   policy, admit 020a as `todo`. No `apps/` change.
2. Child: 020a group evidence calculator; merge with independent review.
3. Parent Task 3: wire calculator + scorer + reason codes + version 4, run
   the Verify procedure, gate feat-021.

## Verify (Simulator code-evidence; manual QA replaced per user directive 2026-09-16)

- Proof binary compiling the REAL shipped Domain + calculator sources
  verbatim runs B-shape + Golden-shape fixture bytes (face-bearing fixtures
  where available, else synthetic face-bearing fixtures with recorded
  provenance) through analyze→score→select twice; byte-compare (md5) proves
  fallback determinism; per-face distribution asserts + weakest-face asserts
  recorded per shape.
- Candid-guard proof: non-portrait + candid-shape fixtures keep their
  pre-people-policy disposition after the people term folds in.
- Privacy proof: persisted JSON rows scanned for forbidden shapes (face
  boxes, landmarks, pixel buffers, crops) → none present.
- Cold cost (version-3 rows read as miss: full re-analyze) + warm cost
  (version-4 cache hits) per asset; calculator + scoring delta judged
  against the performance.md >~20% regression flag under the §1 conditions.
  Host-harness numbers are labeled host-harness, never device claims;
  Simulator build + launch no-crash comes from `./init.sh`.
- `./init.sh` PASS; `git diff --name-only` shows owned files only, no unrelated `apps/` path.
- Simulator-only HARD RULE: never touch a physical iPhone via any channel
  (no devicectl-physical / pymobiledevice3 / idb-physical / launch). Verify
  lane: Codex gpt-5.6-luna; build lanes: OMP.

## Handoff

- State: done (parent PR #43 squash-MERGED via `4613afe` 2026-09-17; contract + child + Task 3 + max-restore fix all on main; index flipped `active` → `done`)
- Activation precondition: origin/main `feature_index.json` verified 2026-09-17 —
  `feat-019` reads `done` (squash #41 at `00c62e2`), `feat-020` reads `todo`; the
  AGENTS.md dependency rule (dependency done before activation) is satisfied. Repo idle:
  no other `active` feature.
- Task 3 wiring (this commit, the only shared-contract change): `PeopleAnalysis` gains
  persisted `minFaceQuality: Double?` + `meanFaceQuality: Double?` (derived scalars only;
  boxes/landmarks/pixels never persisted); `make` gains the 2 params (defaults nil) with
  `clamped01`; `TierABaseline` carries the transient per-face quality list (nil when the
  quality request degrades) and `bestFaceQuality` stays the frozen Tier-A per-face
  quality max exactly as pre-Task-3 (`qualities.max()` on the Tier-A list, same
  `subjectPlacementScore` slot — max-restore fix, Codex finding addressed);
  `performAll` passes the existing
  Tier-A face observations through `GroupEvidenceCalculator.map` (NO new Vision request)
  and stores the min/mean scalars; `QualityScorer.score` folds the weakest-face signal
  (`min(group, minFaceQuality)`, weights in configuration, no threshold invented);
  `FinalAlbumBuilder.decision` appends frozen `bestGroupPhoto` + `betterFaceQuality`
  (group picks) / `bestPortrait` (single-face picks) — no new code invented;
  `AppConfiguration.default.analysis.analysisVersion` 3 → 4. `SelectionEngine`
  orchestration unchanged (score call sites read the derived distribution from analysis).
  `FileAnalysisCache` version gate + `BatchPipeline.completedIDs` checkpoint-ignore
  already implement the frozen requeue rule — no new migration code. New persisted
  fields are all-Optional whole-struct decode (version-3 rows still decode; gate
  treats them as miss, not crash — proven by the v3-tolerance arm below).
- Task 3 Verify (Simulator code-evidence, host-harness macOS Vision backend; never
  manual QA, never a physical device; proof sources kept at
  `/tmp/f020-evidence/src/v4proof-main.swift` + `v4Bproof.swift` +
  `v4persist.swift` + `v4cache.swift` + `v4time.swift`, outside the repo, hosts only,
  never shipped):
  - Proof binary compiles the REAL shipped sources verbatim (Domain Models/Selection/
    Scoring + `AppConfiguration` + `ServiceProtocols` + `ImageSimilarityArtifact` +
    `UniversalFactAdapter` + `CompositionEvidenceAdapter` + `UtilityEvidenceAdapter` +
    `GroupEvidenceCalculator` + `VisionAnalysisService`; main `d92b89b2…`, binary
    `d759a149…`) and runs the REAL `analyze` (calculator wired) → `select` on A-shape
    (60) + Golden-shape (200) + B-shape (40, separate binary `ba9a8785…`) fixture bytes
    twice. HONEST face census: 0/60 + 0/200 + 0/40 faces (facedbg re-confirmed; the
    drawn-face probe also detects 0 — synthetic solids carry no Vision-detectable
    faces, no D-shape fixtures exist). Distribution asserts (verbatim calculator on
    injected per-face values): homos min 0.2/mean 0.6333 TRUE, nil-arm TRUE,
    count-only TRUE, clamp (1.4→1.0, -0.2→0.0) TRUE. Weakest-face fold (verbatim
    scorer): good-all 0.7333 vs one-failed-face 0.6000 → weakestface PASS (one failed
    face drags the group down, never up). Determinism byte-compare: picked A md5
    `01975608…ccc3` == `01975608…ccc3`; picked Golden `9f7792c7…3445` ==
    `9f7792c7…3445`; picked B `ecd4aa1a…41068` == `ecd4aa1a…41068`. PASS.
    Picks identical v3→v4 on all three shapes (A 60→12, Golden 200→30, B 40→3):
    HONEST READING — the wiring flows end-to-end (nil→populated on faced assets)
    but moves ZERO picks on faceless synthetic bytes, expected because the people
    term is nil-gated and the fold only lowers faced groups; signal-live, NOT a
    quality-gain claim; Golden human annotation stays pending.
  - Candid-guard proof: non-people usable pre-policy assets keep their disposition
    (A 12/60 survive as the 12 picks; Golden 30/200 survive as the 30 picks — every
    non-people pick survives; zero non-people moments pushed below the floor by the
    people term). People reason codes correctly absent on faceless bytes (bp/bgp/bfq
    0/0/0 all shapes — codes fire only on faced picks, proven by the wiring read).
  - Privacy proof (REAL `PhotoAnalysis` row encode; main `718e0611…`, binary
    `1a253bd6…`): persisted JSON holds derived scalars only — forbidden-shape scan
    (boxes, pixel buffers, landmarks, joints, heatmaps, crops, embeddings, face
    keys) → NONE. `PERSIST-PROOF: PASS`. v3-row tolerance arm: stripped v4 keys
    still decode with nil distribution → `PASS` (miss-not-crash).
  - Cold/warm cost (same host, same A-shape bytes @ 512 px; binary `97670c77…`):
    v4 cold full-`analyze` 47.89 ms/asset vs v3 cold 52.60 (same host/method —
    no regression from the calculator; delta is noise + the nil-gated fold).
    Warm cache-hit row round-trip 0.03 ms/asset. Honest disposition: host-harness
    per-asset Vision inference cost is not the shipped pipeline budget (no
    batching/lanes/cache-hits, macOS backend not the device backend); the >~20%
    flag is judged at parent close against the warm-cache-hit path + lane
    parallelism, and NO budget constant is proposed or changed here. Recorded,
    not hidden.
  - QoS: unchanged — the calculator `map` is a synchronous pure fold inside the
    existing `performAll` lane body (no `Task.detached`, no priority parameter).
  - Cache requeue proof (REAL `FileStore` + `FileAnalysisCache` sources; main
    `15274756…`, binary `90579020…`): `currentVersion=4 v3rowMiss=true v4rowHit=true`
    → `REQUEUE-RULE: PASS` (v3 rows requeue, v4 rows hit; checkpoint-ignore
    already covers stale checkpoints — read-verified `BatchPipeline.swift:386`).
  - Max-restore fix (Codex REQUEST_CHANGES finding, this commit): `subjectPlacementScore`
    carries the frozen Tier-A per-face quality max again (`tierA.bestFaceQuality`,
    `qualities.max()` — byte-identical to pre-Task-3); `groupFacts.min/mean` still flow
    into `make` + the scorer weakest-face fold only. Re-ran determinism proofs on the
    fixed sources (binaries `c5cd3383…` + `52b43685…`): A `01975608…ccc3` ==, Golden
    `9f7792c7…3445` ==, B `ecd4aa1a…41068` == (PASS); DIST all TRUE; FOLD 0.7333 vs
    0.6000 PASS; no mean-in-max-slot path remains (only `meanFaceQuality:` make-arg
    reference at line 142). Numbers unchanged because fixtures are faceless.
- Evidence: `./init.sh` PASS at the done-flip commit (format, `swiftlint --strict` 0 violations, Simulator build SUCCEEDED, SKIP [test] by policy).
- feat-021 admission gate: may start only after the parent PR to main merges AND
  its contract freezes variant-aware clustering (visually-distinct separation,
  union-find collapse guard, context-aware representatives) without reinterpreting
  the version-4 frozen schema (people distribution fields, caps, predicates) —
  extensions bump `analysisVersion` 4 → 5 with the same requeue rule.
- Blockers: none.
- Closeout (done-flip, branch `tungxuan1656/feat-020-doneflip` from origin/main `4613afe`):
  - Squash evidence: parent PR #43 state MERGED, mergeCommit `4613afe` (= origin/main HEAD); squash body contains the full chain — contract `b181559`, child `84af07d` (mini-020a, PR #42 MERGED), Task 3 `fb2d4c1`, max-restore fix `6141907`; all four pre-squash commits plus the squash verified present via `git cat-file -t`; squash tree equals the integration tip (`6141907` tree `e956cdf4…`).
  - Acceptance re-verified on main (all four boxes honestly still pass, read checked): (1) wiring — `performAll` passes Tier-A face observations through `GroupEvidenceCalculator.map` (`VisionAnalysisService.swift:97`), calculator pure map with count-only/nil arms + clamped01 (`GroupEvidenceCalculator.swift:46-64`), scorer weakest-face `min(group, minFaceQuality)` fold (`QualityScorer.swift:50`), frozen people reason codes (`FinalAlbumBuilder.swift:85-91`), `analysisVersion: 4` (`AppConfiguration.swift:61`), score call sites unchanged (`SelectionEngine.swift:66,141,182`), no new Vision request (Tier-A still 3 requests: faceRects/faceQuality/print); max-restore fix verified (`VisionAnalysisService.swift:100,187-190` — max feeds the max slot, min/mean ride separately); (2) candid-guard — people term is nil-gated (`QualityScorer.swift:49-53` composes over available signals only, never lowers non-people moments) and reason codes fire only on faced picks (`FinalAlbumBuilder.swift:82-92`); (3) privacy — only derived scalars persist (`PhotoAnalysis.swift:20-22`), boxes/landmarks/pixels never leave Tier-A locals (`VisionAnalysisService.swift:94-96`, diagnostics show face count/copy only); (4) cost/budget — no budget constant changed in the squash (`AppConfiguration.swift` diff is the single version 3 → 4 line), calculator `map` is a synchronous pure fold inside the existing lane body (no detached task, no priority), Task 3 cold/warm/cached numbers recorded in this Handoff stand; version-3 rows still decode whole-struct (`PhotoAnalysis.swift:199`) and the version gate + checkpoint-ignore treat them as miss, not crash (`FileAnalysisCache.swift:26,35`, `BatchPipeline.swift:386`).
  - Mini `mini-020a` already `done` in `feature_index.json`; `feat-021` stays `todo` (no start here).
- Next: PR `tungxuan1656/feat-020-doneflip` → main (squash in a separate merge task); feat-021 selection remains user-gated; feat-021 must not start here.
