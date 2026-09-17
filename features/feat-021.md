# feat-021 — Variant-aware clustering

## Status

- Status: `done` (DEC-032 automated gate: four acceptance boxes pass on preserved proof + fresh `./init.sh`; Codex review accepted after fix wave; parent PR NOT yet opened)
- Depends on: `feat-020` (`done` on origin/main `4613afe`; verified before activation)

## Goal

Keep perceptually similar but semantically different photos from collapsing into one
cluster, then select representatives by the moment context.

## Contract boundary

The feature owns cluster membership, representative contract, and any change to
`DuplicateResolver` or `SelectionGrouping`. Calculate coherence evidence inside this feature.

## Acceptance

- [x] Semantic variation resists transitive union-find collapse in named cases (proof named cases I1–I8 + burst control ALL PASS, exact lines below).
- [x] Representative scoring uses context rather than only pairwise similarity (I7 winner follows `QualityScorer` context, exact line below).
- [x] Existing duplicate removal behavior stays deterministic when evidence is missing (double-run byte-compare equal on all three shapes; nil-evidence arms merge like legacy, exact lines below).
- [x] B-shape (40) + Golden-shape (200) automated evidence passes — Simulator-permitted proof through REAL analyze → candidates → REAL feature-print edges → resolve/select twice with byte-compare, plus named-case asserts (I1–I8 + burst control); exact shape counts below.

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/product-specs/selection-rules.md`

## Inline plan

1. Convert baseline collapse cases into explicit cluster invariants.
2. Implement the evidence calculator after its contract is fixed.
3. Integrate resolver and representative changes, then run cluster QA.

## Verify

- Reproducible automated evidence (Simulator permitted): proof binary (REAL shipped sources verbatim) runs A-shape (60) + Golden-shape (200) + B-shape (40) fixture bytes through REAL analyze → candidates → REAL feature-print edges → resolve/select twice with byte-compare, plus injected named-case asserts (I1–I8 + burst control). Exact counts in Handoff.
- Manual QA per `docs/ship-gates/manual-qa.md` is optional non-blocking exploratory guidance only, never an acceptance blocker (DEC-032). No test targets, no `*Test*.swift`, no test frameworks.

## Coordination plan

- `docs/plans/feat-021.md` (shared selection-contract change: frozen contract, I1–I8 invariants, named-case verdicts, representative rule, determinism, verification/rollback).

## Handoff

- Implementation (only shared-contract change; one `apps/` file): `Domain/Selection/DuplicateResolver.swift` — (1) closest-first canonical edge order (distance ascending, then canonical member-pair order; merge outcome independent of caller edge order); (2) pairwise variant gate inside union (`VariantMergeGate` + `DuplicateResolver.variantCompatible`, `DuplicateResolver.swift:134-187`): people-presence, single-vs-group (2-vs-3 group counts stay mergeable, detection-jitter safe), panorama/screenshot framing class BILATERAL (`.unknown` on either side defers, `framingClassDiffers`, `DuplicateResolver.swift:174-180`), document true-vs-false BILATERAL (either nil defers in both argument orders, `documentDiffers`, `DuplicateResolver.swift:182-187`), known-differing scene (either `.unknown` defers) — every veto needs positive evidence on both sides (unknown/nil/matching defers), categorical equality only, no new threshold/key/model; stray nil-asset/analysis arm defers to the legacy-compatible merge (`DuplicateResolver.swift:138-144`); (3) coherence: union joins only when every member across both components stays pairwise compatible, so incompatible endpoints never merge behind an intermediate; vetoed proposal leaves both components untouched, later edges still process; (4) context-aware representative: winner is the shared `QualityScorer.score` rank through configured weights (technical + subject-specific + composition + user intent) with the legacy tie chain (edited, favorite, pixel area, asset ID — same field order as `QualityScorer.compareRank`, `QualityScorer.swift:140-156`) — missing evidence reduces to the legacy order exactly. No `SelectionGrouping` shape change (cluster/moment/edge structs untouched), no `SelectionEngine`/`MomentBuilder` change, `analysisVersion` stays 4 (no requeue/migration change).
- Scope: cluster membership, representative contract, `DuplicateResolver` changes, in-feature coherence evidence. NOT in scope (untouched): semantic moments (`MomentBuilder`, feat-022), embeddings (feat-024), global shortlist (feat-023), specialist models, uncertainty UI, jury, ranker, new Vision requests, new persisted fields, new config keys, unrelated cleanup.
- Acceptance evidence (proof binary compiles the REAL shipped Domain + calculator + service sources verbatim; host-harness macOS Vision backend; fixtures SYNTHETIC solids, honestly faceless — 0/60 A + 0/200 Golden + 0/40 B faces — so face/people/scene veto coverage comes from injected named cases through the same code path): proof sources kept at `/tmp/f021-evidence/src/v21proof-main.swift` (`a36e89bd…`), binary `/tmp/f021-evidence/v21proof` (`64c92bf5…`), run with REAL analyze → candidates → REAL feature-print edges → resolve/select twice: A 60→6 (6 clusters, incoherent 0), Golden 200→15 (14 clusters, incoherent 0), B 40→3 (3 clusters, incoherent 0); picked byte-compare A `0a1068c4…` ==, Golden `07d20b69…` ==, B `13eb627b…` == (PASS). Legacy-baseline movement honestly reported: HEAD-baseline picks (same harness, legacy union-find + legacy rank) are A `b05f86c2…`, Golden `76705d64…`, B `f6c8c1c7…` — feat-021 moves 1 A pick (A_058→A_059), 5 Golden picks, 1 B pick (B_08_0→B_09_0) via closest-first ordering + context-aware representative, NOT a quality-gain claim (no annotated labels run). Named cases ALL PASS: I1 people-presence splits wide-vs-portrait (2 clusters); I2 single-vs-group splits (2) while 2-vs-3 jitter merges (1); I3 bilateral framing class — known panorama-vs-standard and screenshot-vs-standard stay singletons (0 clusters each), unknown-vs-panorama/unknown-vs-screenshot/unknown-vs-unknown each merge (1 cluster each); I4 document-vs-scene splits (0) while nil-vs-false AND true-vs-nil each defer (1 each); I5 known-differing scenes split (0) while unknown defers (1); I6 chain and fully-witnessed triple each keep incompatible endpoints apart (1 cluster each, cA∉cC group, compat triple merges to 1); I7 same-group different-light winner follows context not similarity (glow0); I8 nil-evidence output identical to the proof-local legacy oracle (members + reps equal) and empty edges give 0 clusters + all singletons; static burst control merges (1). Coherence scan over all three shapes: zero clusters contain an incompatible pair. B/Golden-shaped automated-evidence status: the Simulator-permitted runs above are the feat-021 acceptance record per DEC-032 — all four acceptance boxes CHECKED; physical-device runs, annotated Golden labels, and real-trip hand review are optional non-blocking follow-up only. `./init.sh` PASS (format PASS, `swiftlint --strict` 0 violations/61 files, Simulator build SUCCEEDED, SKIP [test] by policy); `git diff --name-only` shows owned files only (`DuplicateResolver.swift`, `feature_index.json`, `docs/plans/feat-021.md`, `features/feat-021.md`, `progress.md`) with the plan newly tracked (was untracked).
- Ceilings (deliberate, documented in `docs/plans/feat-021.md`): day-vs-night, same-light front-vs-rear landmark, same-face-count formal-vs-candid, and people-neutral wide-vs-close are NOT separated — no persisted fact distinguishes them; needs feat-024 embedding or feat-027 jury. Face-detection-miss splits whole groups (accepted: split keeps both, merge loses a memory). Only new per-pair cost is the ~5-equality veto on edges that pass the threshold; no new timings recorded beyond the shape select runs (budgets unchanged, no constant changed).
- Proposed decisions for the coordinator (no doc update made here — coordinator owns `docs/design-docs/decision-log.md`): (D1) accept the I6 chain reading (incompatible endpoints kept apart even when no direct edge witnessed the pair — split direction, recall-preserving) as the feat-021 chain policy; (D2) accept the day/night + formal/candid + framing-magnitude ceilings as feat-024/feat-027 admission evidence rather than feat-021 gaps; (D3) accept `analysisVersion` staying 4 (no persisted-shape change, no migration).
- Blockers: none.
- Next: PR `tungxuan1656/feat-021-integration` → main (squash in a separate merge task); feat-022 selection remains user-gated; feat-022 must not start here. Physical-device or hand-review runs are optional non-blocking follow-up only.
