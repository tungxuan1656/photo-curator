# feat-024 — Visual embedding foundation

## Status

- Status: `done` (DEC-032 automated gate: four acceptance boxes pass on proof + `./init.sh`; sole integration; feat-022 stays `done`)
- Depends on: `feat-022`

## Goal

Choose and safely route the smallest viable on-device visual embedding before global
diversity relies on it.

## Contract boundary

The feature owns `VisualEmbeddingProvider`, model selection, Tier-C routing, schema,
cache/version policy, and pipeline integration. It records license and checksum evidence.
This feature owns model consumers and shared contracts.

- [x] A selected embedding candidate is measured via reproducible automated benchmarks (Simulator permitted) and retains a fallback.
- [x] Tier-C routing is bounded and does not silently force model work for every photo.
- [x] Model license, source/version, and checksum are recorded before inclusion.
- [x] Golden-shaped plus 1k-scale automated evidence meets the parent budget.

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/design-docs/curation-runtime-stack.md` (Tier-C record, §6)
- `docs/design-docs/decision-log.md` (DEC-034, DEC-035)

## Inline plan

1. Use feat-022 evidence to lock the provider contract and benchmark protocol.
2. Implement the provider and benchmark as slices of this feature.
3. Integrate the accepted candidate, version/cache policy, routing, and fallback.

## Coordination plan

- `docs/plans/feat-024.md` (shared model-contract change: frozen routing, provider contract, FastViT benchmark-only record, determinism, verification/rollback).

## Verify

- Reproducible automated evidence for every behavior change (Simulator permitted): Golden-shaped plus 1k-scale, on every supported routing fallback; record commands, fixtures, and outputs in the handoff.
- `./init.sh`
- Manual QA per `docs/ship-gates/manual-qa.md` is optional non-blocking exploratory guidance only, never an acceptance blocker (DEC-032). No test targets, no `*Test*.swift`, no test frameworks.

## Handoff

- State: done (sole integration; review-fix wave: DEC-033 sentence + DEC-032 row restored byte-exact, DEC-035 production wiring live, re-proven + single final `./init.sh` below; feat-022 stays `done`, feat-023 stays `todo`)
- Implementation (owned `apps/` files): `Domain/Selection/VisualEmbeddingProvider.swift` (new: `TierCRoutingPolicy` ≤ 250 assets / ≤ 4,000 pairs, `VisualEmbeddingRouter`, `VisualEmbeddingProvider` protocol, `NativeDerivedEmbeddingProvider` 8-dim persisted-scalar vector + scene penalty, `NoopVisualEmbeddingProvider`, `VisualEmbeddingEdges` union-min merge with empty fast path); `Domain/Selection/SelectionEngine.swift` (only shared-contract change: optional `tierCEdges: []` param feeding diversity novelty only, clusters + moments stay FeaturePrint-only; `SelectionLookups` + `targetCount` helpers keep `select` within lint limits); `Services/Session/SelectionSessionCoordinator.swift` (DEC-035: injected `tierCProvider` defaulting to `NativeDerivedEmbeddingProvider`, private `tierCEdges(for:analyses:)` over analyzed assets with `NoopVisualEmbeddingProvider` fallback on router refusal/empty output, wired into BOTH `selectResult` + `finalizeAvailable`; FeaturePrint rebuild untouched; clusters + moments still FeaturePrint-only); `App/AppContainer.swift` (`tierCProvider` defaulting to native derived, no state); `App/AppModel.swift` (passes `container.tierCProvider` through). `analysisVersion` stays 4 (no persisted-shape change, no migration); no new Vision request/model/dependency/field/config key; no cloud AI; iOS 26 deterministic path preserved.
- Acceptance evidence (proof binary compiles the REAL shipped Domain + configuration sources verbatim — staged `SelectionEngine.swift`/`VisualEmbeddingProvider.swift` md5-match shipped; host-harness macOS Vision backend; fixtures SYNTHETIC solids): proof sources at `/tmp/f024-evidence/src/v24proof-main.swift` (`a34b7b36…`), binary `/tmp/f024-evidence/v24proof` (`4bba357e…`), staged provider `94b5de2a…`, staged engine `0e17e9a2…`, wiring re-run `/tmp/f024-evidence/out-wiring` run1+run2: Golden-shaped 200→15 (clusters 14, moments 11, tierCPairs 4000, tierCEdges 0/0/4000 per arm fallback/noop/tierc) + H 1000→56 (clusters 81, moments 56, tierCPairs 4000, tierCEdges 0/0/4000); picked byte-compare == across BOTH runs AND all three arms per shape (Golden `07d20b69…`, H `9de46dd7…`); 14 named cases ALL PASS incl. N1 fallback-equals-noop + N2 clusters-moments-frozen (production paths reuse the same router/provider/merge/engine-param); honestly faceless fixtures (0 faces all shapes — face/people coverage comes from injected named cases through the same code path). Production wiring compiles: Simulator `BUILD SUCCEEDED`; `swiftlint --strict` 0 violations/62 files; `./init.sh` PASS (format PASS, lint PASS, build SUCCEEDED, SKIP [test] per policy).
- License/source/version/checksum evidence: no model vendored — N/A by construction (derived from persisted facts, no weights file, no redistribution). FastViT headless stays BENCHMARK-ONLY per plan model record + runtime-stack §6 (source Apple ml-fastvit, version unpinned, license re-review required at vendoring time, checksum N/A, reconsider trigger recorded).
- Ceilings (deliberate, documented in `docs/plans/feat-024.md`): persisted-fact-identical frames never separate (needs FastViT pixel evidence or feat-027 jury); day/night, formal/candid same-face-count, framing-magnitude distinctions not separated — no persisted fact distinguishes them.
- Blockers: none.
- Next: PR `tungxuan1656/feat-024-integration` → main (squash in a separate merge task); feat-023 selection remains user-gated (live bounded production consumer contract ready: native Tier-C diversity edges on both selection paths with noop fallback).
