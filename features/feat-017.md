# feat-017 — V2 baseline and failure inventory

## Status and kind

- Status: `done`
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
`ebb0a50` stale-line fix. Index: `mini-017a` `done` (merged); `mini-017b`/`mini-017c`
`done` via the SYNTHETIC nine-metric baseline on branch `tungxuan1656/feat-017-synthetic` (this commit; every value computed IN CODE, labeled SYNTHETIC, never human).
The full 12-field admission card lives in each mini file.

- [x] Nine manual-QA metrics have a SYNTHETIC code-evidence baseline: denominator, config, fixture record, and artifact values, every value labeled SYNTHETIC (deterministic proxies defined IN CODE — LABEL/MOMENT/BEST-SHOT/REVIEWER rules v1, synth-labels.py `409601a1…` — computed against the ALREADY-MEASURED REAL-engine outputs of 06da3e8 with NO app re-run; per-shape values in mini-017a ledger + mini-017b rows; Row D honestly NOT RUN with reason; physical-device numbers are optional future work, not gates; never human taste, never physical proof).
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
- State: done (synthetic-proxy policy amendment 2026-09-16 per user directive: human taste judgments are replaced by deterministic SYNTHETIC proxies for this baseline — LABEL/MOMENT/BEST-SHOT/REVIEWER rules v1 defined IN CODE in mini-017a (synth-labels.py sha256 `409601a182b6121d04eaa1a59af2c546f9f1738d89271389b67cac5aacb0745c`, synth-metrics.json `bb2dbdf9…`); every proxy labeled SYNTHETIC, never human; physical numbers optional future work, NOT gates. `mini-017a`/`mini-017b`/`mini-017c` all `done` via the SYNTHETIC nine-metric baseline on branch `tungxuan1656/feat-017-synthetic` (this commit; computed against the ALREADY-MEASURED REAL-engine outputs of 06da3e8 with NO app re-run; owned-files-only diff, no `apps/` path).)
- Evidence: `./init.sh` PASS at this commit (format, `swiftlint --strict`, Simulator build SUCCEEDED, SKIP [test] by policy); tracker-docs scope only, no `apps/` paths.
- Simulator code-evidence method (2026-09-16, branch `tungxuan1656/feat-017-evidence`): seeded fixtures via `simctl addmedia` to booted iPhone 17 Pro (iOS 26.5, UDID BE48CD78…AF29E); Simulator library verified via Photos.sqlite COUNT (70 pre-existing + 1630 seeded = 1700); app `com.tungxuan.photo-curator` rebuilt, installed, launched (PID 36576, no crash) with Photos access granted; pipeline measured in two code layers — (1) host harness decoding identical fixture bytes with the frozen config constants verbatim + byte-derived luma heuristics (same formulas as `VisionAnalysisService.scores`) for stage timing/cache/selection-count behavior, (2) proof binary compiling the REAL shipped Domain sources verbatim (`AssetIDs/PhotoAsset/PhotoAnalysis/SelectionGrouping/SelectionResult/AppConfiguration/QualityScorer/DuplicateResolver/MomentBuilder/DiversitySelector/FinalAlbumBuilder/SelectionEngine`) running `SelectionEngine.select` on the harness-derived analyses (deterministic: repeat A-small run gives identical picked set md5 `6f848be171ad4991720c3be1ada9c12f`). Vision face/VNFeaturePrint stages run on-device in the app (synthetic solids: 0 faces, scene `.unknown`); host uses deterministic byte-derived stand-ins for edges — honestly labeled, never presented as on-device Vision proof. No `OSSignposter` spans exist in app code (grep: only OSLog in `AppModel`/`PhotoLibraryPermissionService`/`SelectionSessionCoordinator`); stage timing below is the code-captured performance §7 equivalent. Build: macOS 26.5.1, Xcode 26.6 (17F113), `analysisVersion 1 / engineVersion 2 / configVersion 1 / cache schemaVersion 1`.
- SYNTHETIC nine-metric values (code-evidence; computed IN CODE 2026-09-16 by synth-labels.py `409601a1…` against the ALREADY-MEASURED REAL-engine outputs of 06da3e8 — picked-*.json IDs + out-*.json.analyses.json q values; NO app re-run; every value SYNTHETIC proxy-label agreement, NEVER human taste; per-row detail in mini-017b, ledger in mini-017a):
  - A-small (60 synthetic solids+shapes, manifest `33bf85cfc4674caa2368c895bf319c869c86c75e48f17e7f645f5c743f5f2f4b`): input 60 / final 12 / m1 recall 12/50 = 0.240 / m2 good 1.000 / m3 bad 0.000 / m4 leakage 0.000 (no identical groups; edges=[] caveat) / m5 best-shot n/a (no groups) / m6 coverage 4/4 = 1.000 / m7 compression 0.200 / m8 edit proxy 3.17 (0+38/12) / m9 subjective proxy 4. Timing (already-measured): total 0.474 s, metadata 0.014 s, cheap-analysis 0.460 s, clustering 0.0001 s, ranking 0.0001 s, avg 7.90 ms/asset, p50 quality 0.878, p95 0.921; cold cacheHitRate 0.0; usable 57 / target 30 / shortlist 11 / clusters 2 (replica) / moments 4 / failed 0.
  - B-dup (40 = 10 groups × 4 byte-identical copies, manifest `fb7319f02e6d71815063e1cdc64b0b93c500f6773201062da4f630d103ba1949`): input 40 / final 8 / m1 8/36 = 0.222 / m2 1.000 / m3 0.000 / m4 5/8 = 0.625 (3 of 10 quad-groups leaked extras under edges=[] degraded config — NOT on-device duplicate performance) / m5 2/10 = 0.200 (edges=[] caveat) / m6 3/3 = 1.000 / m7 0.200 / m8 3.50 (0+28/8) / m9 3. Timing: total 0.240 s; usable 12 / target 30 / shortlist 7 / clusters 11 (replica) / moments 3 / failed 0.
  - C-moment (100 = 60 A + 40 G with trip gaps, manifest `96f8189f551b3ee8bcb5ef43b288ea43898313bb7194b98d693aa7d6e1cff5dc`): input 100 / final 18 / m1 18/89 = 0.202 / m2 1.000 / m3 0.000 / m4 0.000 / m5 n/a / m6 6/6 = 1.000 (10 A-picks + 8 G-picks) / m7 0.180 / m8 3.94 (0+71/18) / m9 4. Timing: total 0.598 s; usable 94 / target 30 / shortlist 18 / clusters 5 / moments 6 / failed 0.
  - E-context (60, same bytes as A relabeled — E_A_001 sha == A_001 sha `bac1f98739b2…`, 0 faces, manifest `579807d4107ff4ecbe54aa73885ad07c35e71ab550fc10ef7797b7055732904f`): input 60 / final 12 / values identical to A (m1 0.240 / m2 1.000 / m3 0.000 / m4 0.000 / m5 n/a / m6 1.000 / m7 0.200 / m8 3.17 / m9 4). 0-face set proves no-face handling only — SYNTHETIC proxies cannot judge face bias. Timing: total 0.481 s.
  - F-bad (20 dark/bright defects, manifest `1e8ad06a88f74c505041ba878821ab5abb17e9de4fb18c5300f476bd2364df4c`): input 20 / final 0 / m1 n/a (0 proxy-MUST_KEEP — degenerate, NOT a pass) / m2 n/a / m3 n/a (0 REJECT picked is engine behavior) / m4 n/a (denominator 0, undefined — NOT 0.000) / m5 n/a / m6 0/2 = 0.000 / m7 0.000 / m8 n/a (no album) / m9 1 (empty album). REAL engine behavior: all q below frozen `lowQualityThreshold 0.5` (p50 0.436, p95 0.474) → empty shortlist → empty album; `FinalAlbumBuilder.verify` allows 0 selected. Edge finding, NOT a pass. Timing: total 0.022 s.
  - G-reduced (150 with trip gaps, manifest `efd86379097f2aebfcb0bda3125d1e09ca5b2e007417de0056b69832c814ed00`; REDUCED SCALE — spec 500–1,500 honestly labeled, full scale optional future NOT a gate): input 150 / final 24 / m1 24/145 = 0.166 / m2 1.000 / m3 0.000 / m4 0.000 / m5 n/a / m6 8/8 = 1.000 / m7 0.160 / m8 5.04 (0+121/24) / m9 4. Timing: total 0.297 s; usable 131 / target 30 / shortlist 24 / clusters 15 / moments 8 / failed 0.
  - Golden-shape (200 = 150 G + 50 A stable set, manifest `e61200e01993a990258a196869cf8352647ac746982311f1538bd1ed17c2826d`; SYNTHETIC proxy labels replace §3.2 annotation for this baseline only): input 200 / final 30 (5 A-part + 25 G-part picks) / m1 30/187 = 0.160 / m2 1.000 / m3 0.000 / m4 0.000 / m5 n/a / m6 11/11 = 1.000 / m7 0.150 / m8 5.23 (0+157/30) / m9 4. Timing: total 0.722 s; usable 180 / target 30 / shortlist 33 / clusters 15 / moments 11 / failed 0; deterministic repeat confirmed. Set stable across runs, never retuned.
  - H-1000 (1000 trip-gapped, manifest `5a165b85f61e9dbc64a14ec66af6ed1cf06b973b840a31be1a88bf7c3b62dbf8`; SYNTHETIC structural proxies = behavior signal, NEVER taste): input 1000 / final 100 (REAL engine; replica 85) / m1 100/994 = 0.101 / m2 1.000 / m3 0.000 / m4 0.000 / m5 n/a / m6 53/53 = 1.000 / m7 0.100 / m8 8.94 (0+894/100) / m9 4. Timing: total 1.186 s, metadata 0.069 s, cheap-analysis 1.113 s, clustering 0.0024 s, ranking 0.0006 s, avg 1.19 ms/asset; rerun (page-cache warm) 1.275 s; host peakRSS 63.2 MB (host metric only, NOT a device-memory claim); cold cacheHitRate 0.0; usable 846 / target 85 / shortlist 159 / clusters 128 / moments 53 / failed 0; no crash/hang; determinism verified. 3,000/5,000 scales NOT RUN — optional future, NOT a gate.
  - Cancel behavior (code proof via REAL `FileStore` + `SessionCheckpointStore` + `SaveState` sources): cancel-ack primitive 0.0002 s (Task cancellation round-trip; on-device UI-ack < 250 ms budget NOT measured — device run optional future); checkpoint round-trip 250/250 IDs preserved (`match=true`); cancel→checkpoint→resume-skip path code-verified, device cancel run optional future.
  - D-shape (People/Groups) NOT RUN — honestly-unmeasurable with reason: synthetic solids contain no faces and the Vision face path needs real faces; inventing face fixtures would be dishonest. Optional future, NOT a gate.
- Nine-metric audit (2026-09-16, SYNTHETIC path A): all nine metrics carry computed SYNTHETIC code-evidence values with rule text + code hash + manifest per shape (mini-017a ledger + mini-017b rows; `synth-metrics.json` `bb2dbdf9…`); the nine-metrics acceptance box is CHECKED as a SYNTHETIC baseline — every value is proxy-label agreement, NEVER human taste, NEVER physical proof. Metrics 4/5 carry the edges=[] degraded-config caveat. Row D honestly NOT RUN with reason.
- Blockers: none for close (Row D + full-scale G 500–1,500 + H 3,000/5,000 + on-device cancel-ack/UI-alive/heat/RSS/thermal + app-level cached-rerun reuse are optional future work, NOT gates; human annotation stays pending as optional future).
- feat-018 admission gate: UNCHANGED (baseline exists with nine denominators frozen, failures classified with candidate remedies F-017-B/C/D/E/F/G/GLD/H; SYNTHETIC nine-metric values recorded above). feat-018 may start only after its recorded gate; feat-018 must not start here.
- Next: merge this branch (squash in a separate merge task), then feat-018 selection (user-gated).
