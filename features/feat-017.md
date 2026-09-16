# feat-017 — V2 baseline and failure inventory

## Status and kind

- Status: `active`
- Kind: `integration`
- Depends on: `feat-016` (done on origin/main `dd7193a`; verified before activation)

## Goal

Make the current curator measurable before V2 behavior changes. This feature does not
ship a new scoring signal or model.

## Contract boundary

The parent owns the metric ledger, failure taxonomy, and acceptance baselines. Children
may collect independent evidence only; they do not change production scoring or QA gates.

## Frozen baseline contract (locked 2026-09-16, base `dd7193a`)

This commit freezes without changing: no production scoring, threshold, weight,
version, config, budget-constant, or QA-policy change.

### Fixture versions

- `analysisVersion 1` (`AppConfiguration.default.analysis.analysisVersion`)
- `engineVersion 2` (`FinalAlbumBuilder`: first real pipeline)
- `configVersion 1` (`AppConfiguration.default.configVersion`)
- Cache `schemaVersion 1` (`CacheConfiguration`)

### Metric definitions and denominators

The nine `manual-qa.md` §4 metrics at `dd7193a`, frozen as denominators (values not
yet measured):

| # | Metric | Denominator |
|---|---|---|
| 1 | Must-Keep Recall | total MUST_KEEP |
| 2 | Good Selection Rate | total selected |
| 3 | Bad Pick Rate | total selected |
| 4 | Duplicate Leakage | total selected |
| 5 | Best-Shot Accuracy | clusters judged |
| 6 | Moment Coverage | total important moments |
| 7 | Compression Ratio | input count (track only, no target) |
| 8 | Human Edit Rate | final album size (track only; removals vs add-backs split) |
| 9 | Subjective score 1–5 | reviewer judgment (4+ on unseen trips) |

Metric definitions stay parent-owned; no mini may redefine a metric or denominator.

### Devices

Physical iPhone only: the daily driver plus an older device when available
(oldest-supported first for budget work). The Simulator is UI work only, never
pipeline proof. Dataset H (1,000 / 3,000 / 5,000) claims stability, memory, cancel,
progress, and thermal behavior only; it is never hand-scored for taste.

### Evidence locations

- `features/mini-017a.md` — Golden labels and ledger skeleton
- `features/mini-017b.md` — one reproducible §8.2 row per dataset
- `features/mini-017c.md` — §7 budget rows with full conditions

## Admitted mini-features (merge order: 017a → 017b → 017c)

| Order | Mini | Exclusive owns | Merge gate |
|---|---|---|---|
| 1 | `mini-017a` — Golden labels and metric ledger | `features/mini-017a.md` | Denominators match this freeze; no `apps/`/shared-contract diff; `./init.sh` passes |
| 2 | `mini-017b` — A–H, Golden, Real Trip baseline runs | `features/mini-017b.md` | §8.2 rows reproducible per dataset; no `apps/` diff; `./init.sh` passes |
| 3 | `mini-017c` — 1k-photo device budget inventory | `features/mini-017c.md` | Perf §7 conditions recorded; no budget-constant change; `./init.sh` passes |

Ownership is non-overlapping: each mini owns exactly its own file; no mini touches a
shared contract, a sibling file, or any `apps/` path. Children merged in order with
independent reviews: `mini-017a` via `0967d2d` (PR #27, APPROVED), `mini-017b` via
`bdfa595` (PR #28, APPROVED), `mini-017c` via `e7143bc` (PR #29, APPROVED) plus
`ebb0a50` stale-line fix. Index: `mini-017a` `done`; `mini-017b`/`mini-017c`
`blocked` with recorded pending-physical reasons (row values honestly `pending`).
The full 12-field admission card lives in each mini file.

- [ ] Nine manual-QA metrics have a Simulator code-evidence baseline: denominator, config, fixture record, and artifact values. (SIMULATOR code-evidence per 2026-09-16 user directive: agents measure by running the pipeline on Simulator with seeded fixtures, captured via code, zero user intervention, nothing invented. Physical-device numbers are optional future work, not gates. Label-dependent metric values that need human ground truth stay pending until annotated.)
- [x] A-H, Golden, and Real Trip failures are classified with candidate V2 remedies (F-017-B/C/D/E/F/G/GLD/H in `curation-intelligence.md` §14).
- [x] Dataset H is used only for stability and performance claims.
- [x] No production selection behavior changes.

## Relevant docs

- `docs/ship-gates/manual-qa.md`
- `docs/design-docs/curation-intelligence.md`
- `docs/exec-plans/curation-intelligence-v2-parallel-delivery.md`

## Plan

Plan: `docs/plans/feat-017.md`

1. Freeze fixture versions, nine metrics, devices, and evidence locations. (done, contract commit)
2. Admit evidence-only children; merge their ledgers without changing shared QA policy. (done: merged in order 017a → 017b → 017c, each with independent review)
3. Consolidate failures into the V2 design document and choose the feat-018 admission gate. (done, this commit: pending-baseline IDs F-017-B/C/D/E/F/G/GLD/H in `curation-intelligence.md` §14; gate in Handoff)

## Verify

- Run the manual baseline procedure in `manual-qa.md` section 4.
- `./init.sh`
## Handoff
- State: active (evidence-policy amendment 2026-09-16 per user directive: the feat-017 baseline evidence policy changes from physical-device manual QA to Simulator code-evidence. Agents measure by running the pipeline on Simulator with seeded fixtures via `simctl addmedia` (exact count + synthetic provenance + fixture hashes recorded), captured via code, zero user intervention, nothing invented. Manual-QA physical rows are replaced by Simulator code-evidence for this baseline; physical numbers are optional future work, not gates. `mini-017a` stays `done` (ledger skeleton + denominator freeze unchanged); `mini-017b`/`mini-017c` stay `blocked` until their Simulator rows below are filled.)
- Evidence: `./init.sh` PASS at this commit (format, `swiftlint --strict`, Simulator build SUCCEEDED, SKIP [test] by policy); tracker-docs scope only, no `apps/` paths.
- Simulator code-evidence method (2026-09-16, branch `tungxuan1656/feat-017-evidence`): seeded fixtures via `simctl addmedia` to booted iPhone 17 Pro (iOS 26.5, UDID BE48CD78…AF29E); Simulator library verified via Photos.sqlite COUNT (70 pre-existing + 1630 seeded = 1700); app `com.tungxuan.photo-curator` rebuilt, installed, launched (PID 36576, no crash) with Photos access granted; pipeline measured in two code layers — (1) host harness decoding identical fixture bytes with the frozen config constants verbatim + byte-derived luma heuristics (same formulas as `VisionAnalysisService.scores`) for stage timing/cache/selection-count behavior, (2) proof binary compiling the REAL shipped Domain sources verbatim (`AssetIDs/PhotoAsset/PhotoAnalysis/SelectionGrouping/SelectionResult/AppConfiguration/QualityScorer/DuplicateResolver/MomentBuilder/DiversitySelector/FinalAlbumBuilder/SelectionEngine`) running `SelectionEngine.select` on the harness-derived analyses (deterministic: repeat A-small run gives identical picked set md5 `6f848be171ad4991720c3be1ada9c12f`). Vision face/VNFeaturePrint stages run on-device in the app (synthetic solids: 0 faces, scene `.unknown`); host uses deterministic byte-derived stand-ins for edges — honestly labeled, never presented as on-device Vision proof. No `OSSignposter` spans exist in app code (grep: only OSLog in `AppModel`/`PhotoLibraryPermissionService`/`SelectionSessionCoordinator`); stage timing below is the code-captured performance §7 equivalent. Build: macOS 26.5.1, Xcode 26.6 (17F113), `analysisVersion 1 / engineVersion 2 / configVersion 1 / cache schemaVersion 1`.
- Simulator measured values (code-evidence; input/final via REAL engine proof binary; timing via host harness on identical bytes):
  - A-small (60 synthetic solids+shapes, manifest `33bf85cf…`): input 60 / final 12 / compression 0.200 / usable 57 / target 30 / shortlist 11 / clusters 2 (replica) / moments 4 / failed 0; total 0.474 s, metadata 0.014 s, cheap-analysis 0.460 s, clustering 0.0001 s, ranking 0.0001 s, avg 7.90 ms/asset, p50 quality 0.878, p95 0.921; cold cacheHitRate 0.0.
  - B-dup (40 = 10 groups × 4 byte-identical copies, manifest `fb7319f0…`): input 40 / final 8 / compression 0.200 / usable 12 / target 30 / shortlist 7 / clusters 11 (replica; 10 near-identical groups + 1 cross-group merge) / moments 3 / failed 0; total 0.240 s; one-pick-per-cluster invariant held (proof exit 0). Duplicate-leakage RATE stays pending (needs human needless-repeat judgment).
  - C-moment (100 = 60 A + 40 G with trip gaps, manifest `96f8189f…`): input 100 / final 18 / compression 0.180 / usable 94 / target 30 / shortlist 18 / clusters 5 / moments 6 / failed 0; total 0.598 s. Moment-COVERAGE rate stays pending (needs important-moment labels).
  - E-context (60, same bytes as A relabeled, 0 faces, manifest `579807d4…`): input 60 / final 12 / compression 0.200; total 0.481 s. Face-bias judgment stays pending (needs human review; 0-face synthetic set only proves no-face handling, not bias).
  - F-bad (20 dark/bright defects, manifest `1e8ad06a…`): input 20 / final 0 / compression 0.000 / usable 0 / shortlist 0 / clusters 5 / moments 2 / failed 0; total 0.022 s. REAL engine behavior: all quality scores below the frozen `lowQualityThreshold 0.5` (p50 0.436, p95 0.474) → empty shortlist → empty album; `FinalAlbumBuilder.verify` allows 0 selected (no min-count guard). Bad-pick RATE stays pending (needs human REJECT judgment); edge finding recorded honestly, not as a pass.
  - G-reduced (150 with trip gaps, manifest `efd86379…`; REDUCED SCALE — spec is 500–1,500, honestly labeled): input 150 / final 24 / compression 0.160 / usable 131 / target 30 / shortlist 24 / clusters 15 / moments 8 / failed 0; total 0.297 s. Full-scale G (500–1,500) NOT RUN — stays pending with reason (time-boxed baseline; reduced scale honestly labeled).
  - Golden-shape (200 = 150 G + 50 A stable set, manifest `e61200e0…`; labels NOT annotated): input 200 / final 30 / compression 0.150 / usable 180 / target 30 / shortlist 33 / clusters 15 / moments 11 / failed 0; total 0.722 s; deterministic repeat confirmed. Label-dependent Golden metrics (recall/good/bad/leakage/best-shot/moment-coverage) stay pending (annotation per §3.2 not performed — synthetic set has no human ground truth).
  - H-1000 (1000 trip-gapped, manifest `5a165b85…`): input 1000 / final 100 (REAL engine; replica 85) / compression 0.100 / usable 846 / target 85 / shortlist 159 / clusters 128 / moments 53 / failed 0; total 1.186 s, metadata 0.069 s, cheap-analysis 1.113 s, clustering 0.0024 s, ranking 0.0006 s, avg 1.19 ms/asset; rerun (page-cache warm) 1.275 s; host peakRSS 63.2 MB (host metric only, NOT a device-memory claim); cold cacheHitRate 0.0; no crash/hang; determinism verified. 3,000/5,000 scales NOT RUN — stay pending with reason (Simulator time-box; 1,000-scale only).
  - Cancel behavior (code proof via REAL `FileStore` + `SessionCheckpointStore` + `SaveState` sources): cancel-ack primitive 0.0002 s (Task cancellation round-trip; on-device UI-ack < 250 ms budget NOT measured on Simulator — stays pending); checkpoint round-trip 250/250 IDs preserved (`match=true`); cancel→checkpoint→resume-skip path is code-verified, device cancel run stays pending.
  - D-shape (People/Groups) NOT RUN — stays pending with reason: synthetic solids contain no faces and the Vision face path needs real faces; inventing face fixtures would be dishonest.
- Nine-metric honesty audit (2026-09-16): fully Simulator-measured with code values = 1 of 9 (metric 7 Compression Ratio across A/B/C/E/F/G-reduced/Golden/H). The other 8 (recall, good rate, bad-pick, leakage, best-shot, moment coverage, human edit rate, subjective) need human ground truth (labels/judgments/edits) that code cannot invent — they stay pending. The nine-metrics acceptance box therefore stays UNCHECKED; feat-017 stays `active`. No status flip, no PR (per task acceptance path B).
- Blockers: label-dependent metric values need human annotation/judgment (Golden 200–500 MUST_KEEP/ACCEPTABLE/REJECT per §3.2; A–G taste judgments; Human Edit Rate needs real review edits; Subjective needs a reviewer); D-shape needs face fixtures; full-scale G (500–1,500) + H 3,000/5,000 + on-device cancel-ack + device memory/thermal need physical-device or extended-Simulator follow-ups (optional future work, not gates).
- feat-018 admission gate: UNCHANGED (baseline exists with nine denominators frozen, failures classified with candidate remedies F-017-B/C/D/E/F/G/GLD/H; Golden annotation plus physical measurement outstanding as optional follow-ups). feat-018 may start only after its recorded gate; feat-018 must not start here.
- Next: coordinator decision — accept this Simulator code-evidence baseline as the feat-017 record (leave `active` with 8 label-dependent values pending), or direct follow-up measurements; feat-018 selection remains user-gated.
