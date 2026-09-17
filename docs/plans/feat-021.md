# feat-021 execution plan

Goal: variant-aware clustering that keeps semantically distinct photos separate and picks representatives by context, with deterministic legacy behavior whenever evidence is missing.

## Scope

Owns: cluster membership, representative contract, `DuplicateResolver` changes, in-feature coherence evidence.

Explicitly NOT: semantic moments (`MomentBuilder`, feat-022), embeddings (feat-024), global shortlist (feat-023), specialist models (feat-025), uncertainty UI (feat-026), jury (feat-027), ranker (feat-028), new Vision requests, new persisted fields, new config keys, unrelated cleanup.

## Contract (frozen)

Inputs: session assets, version-4 `PhotoAnalysis` rows (frozen schema untouched), transient `SimilarityEdge` distances (run-local prints, never persisted), `SelectionConfiguration` (no new keys; `nearDuplicateSimilarityThreshold` still the only distance cutoff).

Outputs: `.nearDuplicate` clusters only (exact/burst still cannot be inferred — no burst identifier, location, or file-identity signal), one representative plus up to two alternatives per cluster, singletons pass through.

Version: `analysisVersion` stays 4. No persisted-shape change, so no requeue/migration change. No new Vision request, model, or dependency.

## Invariants (explicit)

- I1 people presence: a cluster never mixes face-bearing (`faceCount > 0`) with faceless frames (wide beach vs traveler portrait; person+landmark vs landmark-only).
- I2 single vs group: a cluster never mixes a 1-face portrait with a 2+ group (different subject state). Differing group counts (2 vs 3) stay mergeable — detection-jitter safe.
- I3 framing class: a cluster never mixes panorama with known non-panorama, nor screenshot with known non-screenshot (PhotoKit subtype, categorical, bilateral: `.unknown` on either side defers to legacy).
- I4 document: a cluster never mixes `isDocument true` with `isDocument false` when Tier-B produced both (either nil defers to legacy, in both argument orders).
- I5 scene: a cluster never mixes two known differing `sceneType` values (either `.unknown` defers to legacy).
- I6 coherence: every pair inside a cluster is pairwise compatible — no transitive chain merges incompatible endpoints that never met directly (outside the candidate window) behind a nil-asymmetric middle.
- I7 representative: winner is the shared `QualityScorer` rank over available signals through configured weights (technical + subject-specific + composition + user intent), never pairwise similarity. Missing evidence reduces to the legacy order exactly.
- I8 missing evidence: no analysis, no edges, unknown scenes, nil facts, unknown media subtype → legacy-compatible merge plus legacy rank, byte-identical on the proof's nil-evidence arms.

## Named collapse cases

| Case | Verdict |
|---|---|
| Wide beach + traveler portrait kept apart | I1 separates |
| Person+landmark vs landmark-only | I1 separates |
| Single portrait vs group retake | I2 separates |
| Panorama vs standard of one scene | I3 separates |
| Document/screenshot vs scene photo | I3/I4 separates |
| Static burst frames stay merged | No veto fires; I8 holds |
| A≈B≈C chain with incompatible endpoints | I6 splits |
| Day vs night skyline | NOT separated — no day/night fact persisted (ceiling; needs embedding/jury) |
| Front vs rear landmark view, same light | NOT separated unless people/scene differ (ceiling) |
| Formal vs candid with same face count | NOT separated — no expression fact persisted (ceiling) |
| Wide vs close with no people change | NOT separated — no framing-magnitude fact persisted (ceiling) |

Split direction is recall-preserving throughout: a wrong split keeps both frames (diversity can still drop one); a wrong merge loses a memory. Face-detection-miss splits are accepted on the same ground — near-identical frames detect consistently in practice.

## Representative rule

`rank` scores each member with the verbatim `QualityScorer.score` (configured weights, favorite/edited bonuses, clamp) and orders by score desc, then the legacy tie chain (edited, favorite, pixel area, asset ID — the same field order as `QualityScorer.compareRank`) exactly. `clusterID` nil, `momentID` a deterministic constant (score math never reads it; moments do not exist yet at dup time). When people/composition facts are nil and bonuses are zero, score equals `qualityScore` and the order is exactly legacy.

## Determinism

Closest-first canonical edge order (distance ascending, then canonical member-pair order) drives gated union; candidate generation and assembly stay in canonical chrono+ID order; stable UUIDv5 cluster IDs over sorted members; no randomness, no date-now, no dictionary-order dependence in output paths.

## Verification and rollback

Proof binary compiles the REAL shipped Domain + calculator + service sources verbatim and runs B-shape (40) + Golden-shape (200) + A-shape (60) fixture bytes through REAL analyze → candidates → REAL feature-print edges → resolve twice with byte-compare, plus injected named-case asserts (I1–I8, representative-context flip, legacy-oracle identity). Pass bar: coherence scan finds zero incompatible pairs in every cluster; double-run byte-compare equal; nil-evidence outputs identical to the proof-local legacy oracle; `./init.sh` PASS; `git diff --name-only` shows owned files only.

Rollback: revert `DuplicateResolver.swift` (plus this plan and the feature/progress records). No migration exists to undo — version never moved, no persisted shape changed.
