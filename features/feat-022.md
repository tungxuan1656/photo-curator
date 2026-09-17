# feat-022 — Semantic moments

## Status

- Status: `done` (DEC-032 automated gate: four acceptance boxes pass on proof + `./init.sh`; sole integration; parent PR NOT yet opened)
- Depends on: `feat-021`

## Goal

Build coherent moments from change points and continuity, while retaining a deterministic
fallback for sparse or unavailable semantic evidence.

## Contract boundary

The feature owns `MomentBuilder`, moment boundaries, continuity policy, and fallback.
Calculate boundary evidence inside this feature after its input and output types are fixed.

- [x] Change points improve named trip moment boundaries over feat-017 baseline (M1 street→table splits 2 vs legacy 1; M2 document/panorama split; M3 food→night-street split; exact lines below).
- [x] Continuity avoids over-splitting and respects chronological fallback behavior (M4 dense/edge/hard-gap + M5 single-vs-group + M7 missing-date stable; exact lines below).
- [x] Missing semantic facts produce deterministic legacy-compatible grouping (M6 nil/unknown arms byte-identical to the proof-local legacy oracle; double-run byte-compare equal all shapes; exact lines below).
- [x] Golden-shaped, trip-shaped, and 1k-scale reproducible automated evidence passes — Simulator-permitted proof through REAL analyze → candidates → REAL feature-print edges → build/select twice with byte-compare, plus named-case asserts (M1–M7); exact shape counts below.

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/product-specs/selection-rules.md`

## Inline plan

1. Specify boundary and continuity invariants from the failure ledger.
2. Implement the isolated evidence calculation behind the fixed source path.
3. Integrate moment policy and fallback; record Golden-shaped, trip-shaped, and 1k-scale automated evidence.

## Coordination plan

- `docs/plans/feat-022.md` (shared moment-contract change: frozen contract, change-point invariants, named-case verdicts, continuity rule, determinism, verification/rollback).

## Verify

- Reproducible automated evidence for every behavior change (Simulator permitted): smoke plus Golden-shaped plus trip-shaped plus 1k-scale; record commands, fixtures, and outputs in the handoff.
- `./init.sh`
## Handoff

- State: done (sole integration; proof + `./init.sh` below; feat-021 stays `done`, feat-023/feat-024 stay `todo`)
- Implementation (only shared-contract change; one `apps/` file): `Domain/Selection/MomentBuilder.swift` — middle-band conservative change-points via `semanticChangeSplits` (M1 people-presence, M2 bilateral document/framing, M3 scene kept; M4 edge-continuity/soft-hold/hard-split; M5 single-vs-group merge; M6 nil/unknown legacy-continue; M7 chrono+ID order); close-edge continuity checked before semantics; no new config key, no new persisted field, `analysisVersion` stays 4.
- Acceptance evidence (proof binary compiles the REAL shipped Domain + configuration sources verbatim; host-harness macOS Vision backend; fixtures SYNTHETIC solids, honestly faceless — 0 faces all shapes — so face/people/doc veto coverage comes from injected named cases through the same code path): proof sources at `/tmp/f022-evidence/src/v22proof-main.swift` (`bd15e5f6…`), binary `/tmp/f022-evidence/v22proof` (`6970b0de…`), staged MomentBuilder `93b89d6f…`, run through REAL analyze → candidates → REAL feature-print edges → build/select twice: Smoke 60→6 (6 clusters, moments 4/4 new/legacy, incoherent 0), Golden 200→15 (14 clusters, moments 11/11, incoherent 0), Trip 150→10 (9 clusters, moments 8/8, incoherent 0), H 1000→56 (81 clusters, moments 56/56, incoherent 0); picked byte-compare Smoke `0a1068c4…` ==, Golden `07d20b69…` ==, Trip `b33f0fb7…` ==, H `9de46dd7…` == (PASS); moments byte-compare all four shapes == (PASS). Named M1–M7 ALL PASS incl. M1 new=2/legacy=1 improvement and M6 legacy-oracle identity. Synthetic-fixture caveat: uniform 60 s-step timelines never enter the middle band, so shape-level moment counts are identical new/legacy by construction — the trip-boundary improvement is proven by the injected M1–M3 chain cases, not by shape counts.
- Ceilings (deliberate, documented in `docs/plans/feat-022.md`): sub-soft-gap activity transitions stay one moment (needs feat-024 embedding or feat-027 jury); day/night, formal/candid same-face-count, framing-magnitude distinctions not separated — no persisted fact distinguishes them.
- Blockers: none.
- Next: PR `tungxuan1656/feat-022-integration` → main (squash in a separate merge task); feat-024 selection remains user-gated; feat-023 must wait for feat-024.
