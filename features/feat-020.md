# feat-020 — People and group selection

## Status and kind

- Status: `active`
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

- [ ] B-shape + Golden-shape proof binary (REAL shipped sources verbatim, run
  twice, byte-compare) shows per-face distribution and weakest-face
  protections resolving the named group failures (Task 3 results in Handoff —
  D-shape faces where available, else synthetic face-bearing fixtures).
- [ ] Candid-guard proof: valid non-portrait moments survive people policy
  (no candid/laughing/sleeping/downward-gaze discard; no non-people moment
  pushed below the floor by the people term).
- [ ] Privacy no-persist proof: persisted rows hold derived distributions
  only — no face boxes, landmarks, or pixels in analysis or diagnostics.
- [ ] Cost vs budget: calculator + scoring delta judged against the
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

- State: active (sole integration parent; contract commit only, no `apps/` change)
- Activation precondition: origin/main `feature_index.json` verified 2026-09-17 —
  `feat-019` reads `done` (squash #41 at `00c62e2`), `feat-020` reads `todo`; the
  AGENTS.md dependency rule (dependency done before activation) is satisfied. Repo idle:
  no other `active` feature.
- Evidence: `./init.sh` result recorded at commit; `git diff --name-only` =
  `features/feat-020.md` + `feature_index.json` + `docs/plans/feat-020.md` +
  `features/mini-020a.md` + `progress.md` only, no `apps/` path.
- Blockers: none.
- Next: dispatch `mini-020a`; merge with independent review; then parent Task 3
  (wire + version 4 + Verify, gate feat-021).
