# feat-022 execution plan

Goal: semantic moment segmentation that splits real activity transitions in the middle time band via conservative change-points, keeps dense continuity together, and degrades to deterministic legacy grouping when semantic evidence is missing.

## Scope

Owns: moment boundaries, continuity policy, `MomentBuilder` changes, in-feature change-point evidence.

Explicitly NOT: cluster membership (`DuplicateResolver`, feat-021 frozen), embeddings (feat-024), global shortlist/diversity (feat-023), specialist models, uncertainty UI, jury, ranker, new Vision requests, new persisted fields, new config keys, unrelated cleanup.

## Contract (frozen)

Inputs: duplicate representatives in time order, version-4 `PhotoAnalysis` rows (frozen schema untouched), transient `SimilarityEdge` distances (run-local prints, never persisted), `SelectionConfiguration` (no new keys; `momentSoftGap` ~3 min / `momentHardGap` ~15 min stay the only gap cutoffs, `nearDuplicateSimilarityThreshold` still the only distance cutoff).

Outputs: `PhotoMoment` list only (members, deterministic IDs, representative, scene distribution). Downstream rank/shortlist/diversity untouched.

Version: `analysisVersion` stays 4. No persisted-shape change, so no requeue/migration change. No new Vision request, model, or dependency.

## Invariants (explicit)

- M1 people presence: middle-band neighbours split when one side bears faces (`faceCount > 0`) and the other does not (street frames vs group at table). Count differences alone never split.
- M2 document/framing: a middle-band pair splits on `isDocument` true-vs-false or panorama/screenshot-vs-known-other only when BOTH sides are known; either nil/`.unknown` defers to legacy (bilateral, both argument orders).
- M3 scene: two known differing `sceneType` values split; either `.unknown` defers (existing rule, kept).
- M4 continuity: a close visual edge continues the moment before any semantic check; sub-`momentSoftGap` density never splits (even across mixed scenes — dense bursts stay together); gaps at or above `momentHardGap` always split.
- M5 single-vs-group counts and orientation alone never split (one event can hold a portrait plus a group; selection-rules §12).
- M6 missing evidence: no analysis or nil facts on either side continues the moment — byte-identical to the legacy oracle on nil-evidence arms.
- M7 determinism: canonical chrono+ID order, stable UUIDv5 moment IDs over ordered members, no randomness, no date-now.

Deliberate ceiling (conservative change-points): sub-soft-gap activity transitions (e.g. one photo per minute across street → cafe → food → group) stay one moment. Splitting dense timelines needs embedding/jury evidence — feat-024/feat-027 admission material, not a feat-022 gap.

## Named trip cases

| Case | Verdict |
|---|---|
| Street block → group-at-table block (5 min gap, unknown scenes, faces appear) | M1 splits; legacy scene-only merges |
| Food block → night-street block (6 min gap, known differing scenes) | M3 splits (both old and new) |
| Document photo amid scene photos (4 min gap, Tier-B both sides) | M2 splits |
| Panorama amid standard frames (4 min gap, known subtypes) | M2 splits |
| Dense mixed-scene burst (30 s gaps) | M4 holds one moment, no over-split |
| Middle-band gap + close visual edge + scene change | Edge continuity wins, one moment |
| Gap ≥ hard gap with identical scenes | Always splits |
| Nil analyses / unknown scenes / unknown subtypes | M6 continues, identical to legacy oracle |
| Single portrait + group, same event, middle-band gap | M5 stays together |

Split direction is recall-preserving throughout: a wrong split keeps both frames (diversity can still drop one); a wrong merge loses a memory.

## Determinism

Canonical chrono+ID input order; pairwise decisions depend only on persisted facts and the edge set; stable UUIDv5 moment IDs; double-run byte-compare equal on picked IDs plus moment member lists.

## Verification and rollback

Proof binary compiles the REAL shipped Domain + configuration sources verbatim and runs smoke (24) + Golden-shaped (200) + trip-shaped (7-block chain) + 1k-scale (1000) synthetic shapes through REAL `SelectionEngine.select` twice with byte-compare, plus injected named-case asserts (M1–M7, legacy-oracle identity on nil arms). Pass bar: trip chain gains ≥1 boundary over the legacy oracle with zero continuity violations; nil-evidence outputs identical to the proof-local legacy oracle; double-run byte-compare equal; 1k completes without critical fail; `./init.sh` PASS; `git diff --name-only` shows owned files only.

Rollback: revert `MomentBuilder.swift` (plus this plan and the feature/progress records). No migration exists to undo — version never moved, no persisted shape changed.
