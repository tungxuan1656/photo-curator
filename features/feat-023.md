# feat-023 — Global diversity shortlist

## Status

- Status: `done` (DEC-032 automated gate: four acceptance boxes pass on DEC-037 proof + `./init.sh`; sole integration; feat-022 stays `done`, feat-024 stays `done`)
- Depends on: `feat-022` (`done`), `feat-024` (`done`)

## Goal

Use an embedding-backed global shortlist of about 150–250 candidates to balance novelty
and saturation across moments without regressing selection quality or the 1k-photo budget.

## Contract boundary

The feature owns shortlist size, graph construction policy, `DiversitySelector` integration,
selection ordering, fallback, and `engineVersion`. Implementation keeps those shared
selection contracts compatible (no frozen-contract change: clusters/moments/weights untouched).

## Acceptance

- [x] Global novelty and saturation correct the named baseline failures.
- [x] Candidate graph stays within the approved 150–250 bound and 1k-photo-scale budget.
- [x] Missing embeddings retain deterministic pre-graph selection behavior.
- [x] Golden-shaped, trip-shaped, and 1k-scale reproducible automated evidence passes (Simulator permitted).

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/product-specs/selection-rules.md`
- `docs/design-docs/decision-log.md` (DEC-036, DEC-037)

## Inline plan

1. Lock engine-version and embedding-fallback behavior using feat-024 output.
2. Admit graph calculation only with a non-overlapping source path.
3. Integrate shortlist and diversity policy; validate quality and scale gates.

## Verify

- Reproducible automated evidence for every behavior change (Simulator permitted): smoke plus Golden-shaped plus trip-shaped plus 1k-scale; record commands, fixtures, and outputs in the handoff.
- `./init.sh`
- Manual QA is not required and is never an acceptance criterion, blocker, or release gate (DEC-040). No test targets, no `*Test*.swift`, no test frameworks.

## Coordination plan

- `docs/plans/feat-023.md` (shared selector/engine contract change: frozen graph scope, ordering, fallback, determinism, verification/rollback).

## Handoff

- State: done (PR #50 MERGED into main via `96a75a94c2f31dfe962c1375d9009e4a42882545`; feat-023 confirmed done; deps feat-022 done + feat-024 done preserved; no other feature touched)
- Implementation (owned `apps/` files): `Domain/Selection/GlobalDiversityGraph.swift` (new: `GlobalDiversityGraph` + `GlobalDiversityGraphBuilder` member-only scope, 4,000-pair cap, canonical order, `isFallback` flag, `minGraphMembers` 150 informational / `maxGraphMembers` 250 / `maxGraphPairs` 4000); `Domain/Selection/DiversitySelector.swift` (graph + edge-list `select` overloads, graph + edge-list `utilityStatic`/`utilityOrderStatic` overloads over one shared formula, `fillGreedily` reads the graph; phases/coverage/category/saturation/weights/tie-breaks unchanged); `Domain/Scoring/QualityScorer.swift` (250 ceiling in shortlist order, no sub-150 padding; rank/cap/round-robin unchanged); `Domain/Selection/SelectionEngine.swift` (`diversityGraph` assembly helper + `shortlistScope(similarityEdges:)` Tier-C routing helper (DEC-037: accepts the same FeaturePrint edges `select` uses; deterministic `[]` default is the fallback arm only), graph entry point; clusters + moments stay FeaturePrint-only); `Domain/Selection/FinalAlbumBuilder.swift` (`engineVersion` 2 to 3 only); `Services/Session/SelectionSessionCoordinator.swift` (both production paths compute bounded FeaturePrint edges first and pass those same edges into `shortlistScope` via `tierCEdges(forShortlistOf:configuration:similarityEdges:)`, same provider + noop fallback). Owner-doc updates: `docs/plans/feat-023.md` (new, linked; DEC-037 exact-shortlist wording), `docs/design-docs/data-model.md` (`engineVersion` 3 line), `docs/design-docs/decision-log.md` (DEC-036 + DEC-037 + index rows, append-only).
- Acceptance evidence (proof binary compiles the REAL shipped Domain + configuration sources verbatim — staged md5-match shipped; host-harness macOS Vision backend; fixtures SYNTHETIC solids /tmp/f017-evidence): proof sources at `/tmp/f023-evidence/src/v23proof-main.swift` (`e27d2ee1…`), binary `/tmp/f023-evidence/v23proof` (`1dd58aba…`), staged engine `a48e8ccb…`/graph `cee94c5e…`/selector `9c5f40fa…`/scorer `a6ab3f1a…`/builder `c7a2e7f8…`, outputs `/tmp/f023-evidence/out/` run1+run2: Smoke 60→6 (moments 4, graphMembers 6, graphEdges 0/0/15 per arm fallback/noop/tierc; tierCPairs 15) + Golden 200→15 (moments 11, graphMembers 15, graphEdges 0/0/105; tierCPairs 105) + Trip G 150→24 (moments 8, graphMembers 24, graphEdges 0/0/276; tierCPairs 276) + H 1000→56 (clusters 81, moments 56, graphMembers 60, graphEdges 0/0/1770; tierCPairs 1770); exact-shortlist coverage guard true all four shapes (every routed Tier-C pair inside the FP-pruned scope); picked byte-compare == across BOTH runs AND fallback==noop exactly all four shapes (Smoke `0a1068c4…`, Golden `07d20b69…` — matches feat-024 baseline, Trip `0f55281f…`, H `9de46dd7…` — matches feat-024 baseline); all arms report `engineVersion` 3; 13 named cases ALL PASS (N0 utility movement 1.633→0.205; N1 landmark base [n1a,n1b] graph [n1a,n1c]; N2 portrait base [n2a,n2b] graph [n2a,n2c]; N3 composition base [n3a,n3b] graph [n3a,n3c]; N4 variation-hold 2+2; S1 rare survives heavy 1=1; S2 identical count 3; S3 poor rejected both arms; F1 fallback flag true + graph==edge picks; F2 merge identity; F3 deterministic; G1 caps 250/4000 + router-refuses-300 + no-pad-4 + member-only-scope; X1 scope 3 pairs 3 covered true). `./init.sh` PASS once after final edits (format PASS, `swiftlint --strict` 0 violations, Simulator BUILD SUCCEEDED, SKIP [test] per policy; log `/tmp/f023-init.log`).
- Ceilings (deliberate, documented in `docs/plans/feat-023.md` + DEC-036): synthetic solids carry no pixel texture so Tier-C moves zero fixture picks at scale (improvement proven by injected N1–N3 cases); pixel-level distinctions (day/night, formal/candid same-face-count, framing magnitude, dense-timeline activity) still need FastViT pixel evidence or feat-027 jury; graph window floor 150 informational only.
- Blockers: none.
- Next: feat-025 is the next approved feature (depends on feat-023, done); it can activate after this closeout is merged; feat-023 must not be reactivated here.
