# feat-023 execution plan

Goal: bounded global novelty/saturation shortlist over a 150-250 candidate graph that
improves cross-time redundancy without regressing the frozen pipeline, the 1k budget,
or deterministic fallback. Uses the feat-024 provider/router contract only.

## Scope

Owns: `GlobalDiversityGraph` policy (new file), `DiversitySelector` graph wiring
(visual-novelty source only — category math, protected/core passes, phases unchanged),
`QualityScorer.shortlist` cap policy (150-250 window only — rank/round-robin unchanged),
`SelectionEngine` assembly order (graph input source + shortlistScope helper + engineVersion bump 2->3),
`SelectionSessionCoordinator` Tier-C graph supply source change, this plan, the
feature/progress records, and the DEC entry.

Explicitly NOT: cluster membership (`DuplicateResolver`, feat-021 frozen),
moment boundaries (`MomentBuilder`, feat-022 frozen), scorer weights/math/thresholds,
new Vision requests, new persisted fields/shapes, `analysisVersion` bump (stays 4 —
no persisted-shape change, no migration), new config keys (all bounds are policy
constants — see Sec 17 note), specialist models (feat-025), review/jury/ranker
(feat-026/027/028), Core ML vendoring, cloud AI, fixed per-category quotas.

## Contract (frozen)

Inputs: shortlist `[ScoredCandidate]` (≤ 250 graph scope; QualityScorer caps to the
150-250 window), FeaturePrint `[SimilarityEdge]`, Tier-C `[SimilarityEdge]`
(supplier merges with `VisualEmbeddingEdges.merged` — union-min, empty = FeaturePrint
exactly).

Outputs: `GlobalDiversityGraph` (canonical member order + capped edge list +
fallback flag); engine consumes the precomputed graph distances for diversity
visual-novelty only.

Graph construction: members = shortlist in canonical engine order (chrono + ID,
never re-sorted by score); edges = merged FP+Tier-C restricted to member pairs only
(non-overlapping by construction: no outside pair may contribute a graph edge);
hard cap 4,000 canonical lexicographic pairs (`VisualEmbeddingRouter`-scale cost,
reuses `TierCRoutingPolicy.maxTierCPairs`); member cap 250
(`TierCRoutingPolicy.maxShortlistForTierC`); below 150 members the window floor is
informational only — the graph still builds over all members (never pads with
duplicates, low-quality, or out-of-shortlist assets to hit 150).

Fallback: missing/empty merged edges ⇒ graph marks `isFallback = true` and emits
no distances ⇒ `DiversitySelector` runs the exact pre-feat-023 FeaturePrint path
(byte-identical picks to `engineVersion 2` on the same shortlist — proven by the
F1/G1 arms).

Version: `engineVersion` 2->3 (data-model.md Sec 8/10: choice change —
visual-novelty now reads the bounded graph; `analysisVersion` stays 4, no
persisted-shape change, no re-analyze; stale `engineVersion 2` decisions re-rank
from stored analyses per the standard rule).

Production: both `SelectionSessionCoordinator` paths keep the identical provider
call (`AppContainer.tierCProvider`, default native; router refusal/empty ⇒ noop).
Tier-C pairs route over the exact FP-pruned shortlist the selector consumes
(DEC-037): each path computes its bounded FeaturePrint edges first, passes those
same edges into `SelectionEngine.shortlistScope(similarityEdges:)`, and routes
pairs only over that returned scope — a non-overlapping source fix, not a scope
expansion (pair count can only shrink). `shortlistScope` keeps a deterministic
`[]` default for the fallback arm only; production never relies on it.

## Selection-ordering contract (adds Sec 10 precedence)

Protected sole-moment picks, then one core representative per remaining moment,
then greedy marginal-utility fill (unchanged phases). Inside the greedy fill, the
graph changes only the *visual-novelty* input (precomputed graph distance replaces
the raw merged-edge scan); base score, coverage, category-novelty, saturation, and
`QualityScorer.compareRank` tie-breaks are untouched. Quality floor holds:
`.lowQuality`/`.hardRejected` never enter the pool (selection-rules Sec 5 > Sec 13);
protected sole picks may exceed target (unchanged). No per-category quota exists
anywhere in this feature (selection-rules Sec 13).

## Shortlist-window policy (selection-rules Sec 17 note)

`QualityScorer.shortlist` keeps rank -> per-moment cap -> round-robin -> rank-1
backfill exactly, then applies a window: pools above 250 truncate to 250 in
shortlist order (coverage-first, deterministic); pools below 150 pass through
unchanged (no padding — Sec 14 forbids inventing candidates). The 150 floor is a
graph *operating-range label* (curation-intelligence Sec 11), not a pool-size
requirement; the 250 ceiling is the enforced bound (router-scale + 1k-budget
gate). No config key is added: the window lives as two policy constants beside
the router constants, per the Sec 17 small-knob rule.

## Named baseline cases (acceptance Sec 1)

Novelty (cross-time repetition the temporal window cannot see):

- N1 landmark-repeat: two landmarks hours apart (Tier-C near, FP far) — graph
  supply keeps one; the FP-only baseline keeps both.
- N2 portrait-repeat: same-setting portraits across blocks (Tier-C near, FP far)
  — graph keeps one; baseline keeps both.
- N3 composition-repeat: identical composition across blocks (Tier-C near,
  FP far) — graph keeps one; baseline keeps both.
- N4 meaningful-variation hold: landmark wide + traveler portrait (people gate
  differs) — graph keeps both (no collapse), same as baseline.

Saturation (moment-balance under a fixed target):

- S1 heavy-vs-rare: heavy moment (6 usable) + rare moment (1 usable), target
  forces a choice — rare-moment pick survives in both arms (protected), and the
  graph arm holds fewer heavy-moment seconds than the FP arm.
- S2 second-pick cost: rich moment (2 distinct) + singletons — the graph arm
  pays the second-pick saturation cost identically to baseline (no quota fill).
- S3 floor hold: unique moment whose only candidate is `.lowQuality` — rejected
  in both arms (floor beats coverage, selection-rules Sec 5/13 test).

Fallback/determinism (acceptance Sec 3):

- F1 missing-embeddings identity: no Tier-C supply ⇒ arm picks byte-identical
  to `engineVersion 2` on the same shortlist (graph `isFallback` true).
- F2 empty-merge passthrough: merged FP + [] == FP exactly (reuses feat-024 E1).
- F3 determinism: every shape × arm runs twice; picked-ID bytes identical.
- G1 bounds: member count ≤ 250 on all shapes; edge count ≤ 4,000; H-shape
  completes inside the 1k budget with no new requests/models/threads.

## Determinism

Canonical member order (engine chrono + ID); canonical capped edge order
(lexicographic, min-distance union); provider pure map; merge canonical;
double-run byte-compare equal on picks per arm; graph inputs are the exact
shortlist the selector consumes (no second ordering).

## Verification and rollback

Proof binary compiles the REAL shipped Domain + configuration sources verbatim
and runs Smoke (60) + Golden-shaped (200) + trip-shaped G (150, 7-block chain)
+ H 1k-scale (1000) synthetic shapes through REAL `SelectionEngine.select` on
three arms (fallback = default `tierCEdges: []`; noop = explicit Noop supply over
the exact FP-pruned scope; tierc = bounded router + native provider over the exact
FP-pruned scope) twice with byte-compare, plus a per-shape exact-shortlist coverage
guard (every routed Tier-C pair lies inside the scope the selector consumes) and
named-case asserts (N0-N4, S1-S3, F1-F3, G1, X1). Pass bar:
N1-N3 graph keeps one where baseline keeps both; N4 keeps both; S1 rare
survives + fewer heavy seconds in graph arm; S2/S3 identical to baseline; F1
fallback == engineVersion-2 path exactly; F3 byte-compare equal all arms; G1
bounds hold all shapes; X1 scope/pairs covered + bounded; exact-shortlist guard
true all four shapes; H completes without critical fail; `./init.sh` PASS;
`git diff --name-only` shows owned files only.

Rollback: revert `GlobalDiversityGraph.swift` (new) + `DiversitySelector.swift`
graph wiring + `QualityScorer.swift` window + `SelectionEngine.swift` assembly (graph helper + shortlistScope) +
`FinalAlbumBuilder.swift` version constant + `SelectionSessionCoordinator.swift`
supply-source change (plus this plan and the feature/progress/decision records).
No migration exists to undo — `analysisVersion` never moved, no persisted shape
changed, no model vendored. Stale `engineVersion 3` decisions re-rank from
stored analyses per data-model.md Sec 10.
