# Progress

<!-- Log template -->

## YYYY-MM-DD — feat-001

**State**: todo
**Done**: —
**Evidence**: —
**Blockers**: none
**Next**: Define the feature scope and acceptance criteria.

<!-- Add each new block below this note. Do not edit older blocks. -->

## 2026-09-18 — feat-031 phase 2

**State**: active
**Done**: Added the quality-path scheduler, selector, runner, coordinator wiring, optional runtime Qwen judge dependency, quality provenance on `SelectionResult`, automatic small-set quality-mode request selection, and runtime-downloaded model fallback. The quality route remains separate from the legacy selector and bypasses the Foundation Models jury.
**Evidence**: `bash scripts/proof/feat-031.sh` PASS with installer, response validator, pair judge, scheduler serial/cap, deadline, cancellation, stale-request, selector target, and usable-winner checks. `./init.sh` PASS with SwiftFormat, strict SwiftLint, generic Simulator `BUILD SUCCEEDED`, feat-030 proof, feat-031 proof, and `SKIP [test]` by DEC-040. `git diff --check` PASS.
**Blockers**: Actual pixel-derived grouping, subject-detail verification, image-sensitive Qwen quality comparison, arm64-device/runtime measurements, resource admission, setup/review UI, and complete resume/model-revision persistence evidence remain open. Weights are intentionally not bundled; verified model files are downloaded at runtime under Application Support.
**Next**: Complete the pixel-evidence and model-admission gates before claiming quality improvement or closing feat-031.

## 2026-09-19 — feat-031 provenance and resume safety

**State**: active
**Done**: Added deterministic pinned-manifest fingerprints and immutable quality checkpoint identity. Mode, model revision, runtime revision, and manifest identity now flow through loading shells, background checkpoints, batch checkpoints, normal completion, partial completion, and resume filtering. Installed model provenance records the same fingerprint; old native checkpoints remain compatible.
**Evidence**: `bash scripts/proof/feat-031.sh` PASS, including `QUALITY-CHECKPOINT-IDENTITY PASS`. `swiftlint lint --strict` PASS with 0 violations. `./init.sh` PASS: SwiftFormat, strict lint, generic Simulator `BUILD SUCCEEDED`, feat-030 proof, feat-031 proof, and `SKIP [test]` by DEC-040. `git diff --check` PASS.
**Blockers**: Pixel-derived grouping, subject-detail verification, real image-sensitive Qwen comparisons, arm64-device/runtime measurements, resource admission, setup/review UI, and full production cancellation-drain evidence remain open. Weights remain runtime-only and are not bundled.
**Next**: Implement the pixel-evidence and model-admission gates before claiming quality improvement or closing feat-031.

## 2026-09-11 — feat-003

**State**: done
**Done**: Landed PhotoKit fetch + ImageLoader + iCloud (deepwork, 2 phases): fetchAssets with guarded fetch + cheap-field map + shared LibraryChangeTracker; new ImageLoaderService (one PHCachingImageManager, locked once-only claim, atomic cancelClaim, single-request iCloud + progress, orientation bake); AppContainer 1-line DI swap. Gate 1 GO (attempt 3) + Gate 2 GO (no findings).
**Evidence**: ./init.sh PASS (format, swiftlint --strict 0 violations/21 files, BUILD SUCCEEDED, SKIP [test]); simulator smoke iPhone 17 Pro iOS 26.5 — install + launch PID 31336, alive +5s, no crash.
**Blockers**: none
**Next**: feat-004 (SourceSelection + Summary on real fetch; owns the 1k-load exercise).

## 2026-09-10 — feat-002INT (G1 INT, close G1)

**State**: done
**Done**: Wired real DI on int/G1 (8 commits): PhotoLibraryPermissionService (PhotoKit .readWrite auth + limited picker via protocol extension), AppContainer.live() with file-backed cache/checkpoint (+ concrete checkpointStore field), AppModel double-tap guard, exhaustive guidance switch, HomeView redundant refresh removed, privacy manifest CA92.1.
**Evidence**: ./init.sh PASS fresh on final HEAD (format, strict lint, BUILD SUCCEEDED, SKIP [test]); boundary greps clean; simulator smoke iPhone 17 Pro iOS 26.5 — install + launch OK, S02 renders, no crash (iOS 26.2 device rejects app: deployment target 26.5).
**Blockers**: none
**Next**: PR int/G1 → main (merge commit); interactive tap-through + real-iPhone smoke recommended on lead device; G2 unblocked.

## 2026-09-10 — feat-002A/B (G1 lanes A+B)

**State**: done
**Done**: Merged lane A (PR #5: FileStore + CheckpointStore + AnalysisCache) and lane B (PR #4: Onboarding + Permission + Home skeleton) to int/G1, plus leader chore cd35852 (project settings: display name, category, portrait/iPhone-only); opened + merged PR #6 int/G1 → main (merge commit).
**Evidence**: ./init.sh PASS on int/G1 HEAD (format, swiftlint --strict, BUILD SUCCEEDED, SKIP [test]); import/boundary greps clean; overall review NOT READY accepted as documented deviation (INT pending, dead CTA + picker TODOs + manifest gaps deferred, tracked in PR #6 comment).
**Blockers**: none
**Next**: feat-002INT (leader) — wire real DI + full/limited/denied flow with device smoke.

## 2026-09-10 — feat-001 (G0 Contract + shell)

**State**: done
**Done**: Froze G0 contracts (IDs, PhotoAsset/PhotoAnalysis/SelectionResult, 6 service protocols + Noops, concrete SelectionEngine stub, AppConfiguration.default, AppContainer.live) + PhotosCurator→PhotoCurator rename + DEC-028; PR #2 merged to int/G0.
**Evidence**: ./init.sh PASS on int/G0 post-merge (BUILD SUCCEEDED, SKIP [test]); per-task oracle reviews clean; final review MERGE-READY.
**Blockers**: none
**Next**: Open PR int/G0 → main, then start G1 feat-002A + feat-002B.

## 2026-09-10 — docs-standardization (no feature, user-directed)

**State**: done
**Done**: Rewrote 13 product docs (28k→~4.5k lines, single-owner each), folderized to `docs/` + product-specs/design-docs/ship-gates/exec-plans, renamed plain kebab-case, routed `AGENTS.md` → `docs/index.md`.
**Evidence**: Sampling 30/30 rules preserved vs git HEAD; 0 broken links; `./init.sh` PASS (BUILD SUCCEEDED, SKIP [test]).
**Blockers**: none
**Next**: Commit working tree when user approves (moves staged via `git mv`, history kept).

## 2026-09-11 — feat-004

**State**: done (provisional gate, user-approved)
**Done**: SDD Tasks 1→4 implemented + reviewed clean on feat/feat-004 (5 commits df6b236..29a1471): value types; routes + AppModel state + Home CTA; thumbnail + S05; S06 + RootView; final fix wave (refresh race, stale freeze, duplicate routes, thumbnail lifetime, selection a11y). Final review NOT READY → wave → re-review 4/5 + 1 parked residual.
**Evidence**: ./init.sh PASS every task (format, swiftlint --strict, BUILD SUCCEEDED, SKIP [test]); simulator install/launch no-crash + Welcome screenshot; stacked branch feat/feat-005 cut from 29a1471.
**Blockers**: deferred follow-ups — (1) real-device QA: 50-asset S05→S06 tap-through, limited/denied, change-refresh, 1k scroll/Instruments; (2) parked: error-path refresh may write stale denied/failed after a concurrent load (transient, self-heals; freeze reconciliation prevents corrupt snapshots).
**Next**: SDD feat-005 (Vision core + batch pipeline) on feat/feat-005.

## 2026-09-11 — feat-005

**State**: done
**Done**: SDD Tasks 1→3 + reviews on stacked feat/feat-005 (29a1471..eebeadb): versioned PhotoAnalysis shape (+waiver kept); VisionAnalysisService (review fail → fix R1 ALL ADDRESSED: SelectionError-only, structured cancel, nil-face rule); BatchPipeline (matrix 5/5 synthetic: invalidation, cancel-after-checkpoint, FULL resume, unavailable split, 3.64Hz); final wave for 2 blockers → re-review I1 addressed, M1 parked.
**Evidence**: ./init.sh PASS every step (format, swiftlint --strict, BUILD SUCCEEDED, SKIP [test]); exact feat-006 contract (run/resume → BatchResult, 4-field progress); loader/feat-004 untouched; Noop DI intact for feat-006.
**Blockers**: follow-ups — real-device PhotoKit/Vision 100-asset pass; parked M1: forced-final may double-fire terminal callback on cache-only edge (harmless duplicate; feat-006 idempotent).
**Next**: SDD feat-006 (Processing UI + coordinator + Settings) on feat/feat-006.

## 2026-09-11 — feat-006

**State**: done (provisional gate, adjudicated)
**Done**: SDD Tasks 1→4 + reviews on stacked feat/feat-006 (eebeadb..2af0e90, 7 commits): coordinator actor + store seam (+R1); AppModel/routes/DI/seams; ProcessingModel/views/ReviewReady (+R1); Settings + smoke; final wave-1 (9 blockers → 4 fixed) + user-authorized wave-2 (discard + permission gate fixed; 2 items residual).
**Evidence**: ./init.sh PASS every step (format, swiftlint --strict, BUILD SUCCEEDED, SKIP [test]); sim install/launch + Settings render OK; exact feat-005 contract consumed; Noop gone from S06→S07→reviewReady path.
**Blockers**: parked → feat-012 hardening: session-ownership interleavings (finalize gate-vs-await atomicity, completed-session supersede cleanup, shell-save tracking, completion-vs-supersede ordering), transient cross-session note leakage, cancel-vs-persist micro-race, auto-retry-after-Settings; 100-asset device QA open; ReviewReady grid wiring is feat-009. Single-session gate path review-clean.
**Next**: feat-007 (Duplicates + moments) — starts on user selection; stacked branch feat/feat-007 from feat-006 HEAD 2af0e90 when approved.

## 2026-09-14 — feat-007

**State**: done (user-confirmed Dataset B pass)
**Done**: feat-007 closed on feat/feat-007: Dataset B manual QA pass recorded; ./init.sh PASS; branch feat/feat-008 stacked from its HEAD.
**Evidence**: features/feat-007.md acceptance checked; close commit 654f111; ./init.sh PASS (format, swiftlint --strict 0 violations, BUILD SUCCEEDED, SKIP [test]).
**Blockers**: none
**Next**: feat-008 engine QA (Dataset B + Golden).

## 2026-09-14 — feat-008

**State**: done (self-reviewed; device QA moves to feat-009 instrument)
**Done**: feat-008 closed on feat/feat-008: scorer + shortlist, diversity selector, final builder engineVersion 2, full pipeline with swap/restore overrides, shared partial path, decision mapping, plus review-fix wave (moment continuity, edited rep, forced-cluster guard, usable-only swaps, loser-moment inheritance). Self-review: engine-logic 6 FAIL→fixed, service-boundary 10/10 PASS.
**Evidence**: ./init.sh PASS final (format, swiftlint --strict 0 violations, BUILD SUCCEEDED, SKIP [test]); features/feat-008.md acceptance checked; feature_index.json feat-008 done.
**Blockers**: none (code review closed; Dataset B + Golden evaluation runs on feat-009 S09–S11 grid/detail)
**Next**: feat-009 Review core (S09/S10/S11) on stacked branch from feat-008 HEAD.

## 2026-09-14 — feat-009

**State**: done (self-reviewed; device tap-through deferred to user)
**Done**: feat-009 closed on feat/feat-009: session-owned ReviewModel, beginReview + reviewOverview/curatedGrid routes with load-failed fallback, ReviewReady Continue wiring + zero-pick abnormal state, S09 overview, S10 lazy grid (dim-don't-shift + Undo), bounded 2048px preview seam + S11 local pager detail. Self-review: UX 16/16 PASS; SwiftUI 12 PASS/2 FAIL→fixed (cell onToggle closure, stale-preview guard).
**Evidence**: ./init.sh PASS final (format, swiftlint --strict 0 violations, BUILD SUCCEEDED, SKIP [test]); features/feat-009.md acceptance checked; feature_index.json feat-009 done.
**Blockers**: none (code review closed)
**Next**: feat-010 (groups + removed + final) — needs bounded cluster/moment export seam; Dataset B/Golden/G2 evaluation now runnable on S09–S11 when user QA passes.

## 2026-09-14 — feat-010 through feat-014

**State**: done (self-reviewed; device QA deferred to user)
**Done**: Delivered feat-010→feat-014 on stacked branches feat/feat-010..feat/feat-014 (first end-to-end saved-album MVP): feat-010 shared review state + S12/S13/S14; feat-011 PhotoKit export + S15/S16 same-album retry; feat-012 pressure observer + terminal/save interleave hardening; feat-013 Settings privacy + Reset Analysis + S20 ErrorStateView; feat-014 release record with NoopAnalytics (no provider selected).
**Evidence**: ./init.sh PASS on every close (format, swiftlint --strict 0 violations, BUILD SUCCEEDED, SKIP [test]); simulator install/launch no-crash each feature (permission/S05 states render, PIDs alive); feature_index.json all 14 done.
**Blockers**: none in code — user-owned device follow-up: Gate 1 correction consistency, Gate 2 Dataset A save + interrupted retry, 1k/5k + cancel@25% resume with §7 numbers, privacy AC-01..12 + a11y, datasets A-H/Golden/§7.3.
**Next**: Merge stacked branches feat/feat-010 → feat/feat-014 in dependency order; run device QA list above.

## 2026-09-15 — feat-015

**State**: active (code complete on feat/feat-015, 11 commits; device QA user-owned)
**Done**: Interaction-only flow/screen repair via SDD (Tasks 1-9 + final-review wave, all reviews clean): S17 resume seam + snapshot + Home Continue card + launch refresh; Start New §4.3 confirm + review Discard; deleted ReviewReadyView/.reviewReady (completed routes build-then-route to S09/S15/load-failed); S09 grid-first + stats + unavailable; shared 44pt SelectionToggle (S10/S12) + Selected/Removed/Add-back vocab + Undo copy + best-pick a11y; S05 denied/empty/limited recovery + one-photo hint; conditional S06 iCloud line; Settings notDetermined + sheet Dismiss; S11 swipe + retry-token failure state (no spinner) + position/date a11y; S14 blank-name gate + save trim; S16 partial line; unified pause copy; final-review wave restored S14 Continue-to-Save on grid/groups/removed + overview/showReview push guards.
**Evidence**: ./init.sh PASS twice (final: format 0/55, swiftlint --strict 0 violations/55 files, BUILD SUCCEEDED, SKIP [test]); simulator iPhone 17 Pro iOS 26.5 install/launch no-crash PID 83950; grep zero reviewReady/ReviewReadyView; grep 3 S14 push sites; ledger .agent-work/sdd/feat-015/progress.md (9 tasks complete, Task 8 one fix round, final review NEEDS-FIXES → wave all ADDRESSED).
**Blockers**: none in code — user-owned device follow-up: Dataset A tap-through (first-run → save → Done, kill-relaunch Continue, denied/limited/empty S05).
**Next**: PR feat/feat-015 → main (squash); update feature_index.json feat-015 active→done + progress block on merge.

## 2026-09-16 — feat-015

**State**: done
**Done**: Reconciled the stale tracker state after merged commit `29cb7b3`.
**Evidence**: Existing feat-015 handoff records `./init.sh` and simulator evidence; baseline `./init.sh` passed again on 2026-09-16.
**Blockers**: none
**Next**: feat-016 adds per-photo analysis transparency.

## 2026-09-16 — feat-016

**State**: active
**Done**: Added S21 per-photo analysis and a **View Analysis** entry from S11. Every visible S10/S12/S13 thumbnail now lazily shows a numeric Technical score and meter. S21 presents the saved technical, people, composition, and content facts where available; original selection reasons; and the current Selected/Removed state. Navigation from all three grids now opens S11 directly, because the root typed navigation stack accepts `AppRoute`, not `AssetID`.
**Evidence**: `./init.sh` PASS after the implementation (SwiftFormat 0/57 changed, SwiftLint strict 0 violations/57 files, BUILD SUCCEEDED, tests skipped by policy). Installed and launched the new build in iPhone 17 Pro Simulator, PID 74689, with no crash. S10 showed 84/100, 83/100, and 77/100; its thumbnail opened S11 and then S21. S21 exposed Technical, People, Composition, Content, Selection result, current Selected, original Selected, selection score 84/100, and the translated reason. A temporary removal opened S13 with 84/100, opened S11, then Add back restored the observed **Nothing removed** state.
**Blockers**: This simulator result has no similar groups and no deliberately missing cached analysis. S12 plus the non-blocking unavailable-state manual cases need a representative fixture. No user photos were saved, discarded, or changed during verification; the temporary review selection was restored.
**Next**: Run the two fixture-dependent cases in `docs/plans/feat-016.md`, then close feat-016.

## 2026-09-16 — feat-016

**State**: done
**Done**: Closed feat-016 after the two pending manual cases (S12 similar-groups scores and navigation; missing-analysis unavailable state, non-blocking, no processing restart) were user-verified on 2026-09-16. Closure touched tracker/docs only; no production-code, selection, cache-schema, or test changes.
**Evidence**: `./init.sh` PASS at closure (format, swiftlint --strict, BUILD SUCCEEDED, SKIP [test] by policy). features/feat-016.md acceptance all checked; feature_index.json feat-016 active→done; docs/plans/feat-016.md Task 4 checked.
**Blockers**: Worker-introduced app-container fixture fully removed (temporary result/checkpoint files deleted, stashed analysis-cache row restored, no fixture shipped in the repo). One Simulator library photo added via supported `simctl addmedia` during verification is left for the user to remove by hand; all six originals verified present and the app re-launched healthy with photo fetch working.
**Next**: feat-017 when the user selects it.

## 2026-09-16 — feat-017

**State**: active (sole integration parent; contract commit only)
**Done**: Verified origin/main `dd7193a` shows feat-016 `done` before editing; branch verified at `dd7193a` with a clean tree. Activated feat-017; froze fixture versions (analysisVersion 1, engineVersion 2, configVersion 1, cache schemaVersion 1), the nine `manual-qa.md` §4 denominators, devices (physical iPhone only; H stability-only), and evidence locations. Added `docs/plans/feat-017.md` (child files, merge order, rollback); admitted `mini-017a/017b/017c` as task-ready `todo` index records with exact non-overlapping ownership and merge gates. No `apps/` change.
**Evidence**: `./init.sh` PASS (result recorded at contract commit); `git diff --stat` tracker docs only.
**Blockers**: none
**Next**: dispatch `mini-017a`; merge children in order 017a → 017b → 017c; then run parent plan Task 3 (consolidate failures, gate feat-018).

## 2026-09-16 — feat-017 Task 3

**State**: active (sole integration parent; all children merged; parent PR to main not yet opened)
**Done**: Parent Task 3 consolidation — pending-baseline failure IDs F-017-B/C/D/E/F/G/GLD/H with candidate V2 remedy pointers added to `curation-intelligence.md` §14 (no scoring/threshold/weight/version/config/budget change); feat-018 admission gate recorded in `features/feat-017.md` Handoff. Merges: `mini-017a` via `0967d2d` (PR #27, APPROVE), `mini-017b` via `bdfa595` (PR #28, APPROVE), `mini-017c` via `e7143bc` (PR #29, APPROVE) plus `ebb0a50` stale-line fix. Index: `mini-017a` `done`; `mini-017b`/`mini-017c` `blocked` with recorded pending-physical reasons; `feat-017` stays `active`. No `apps/` change; all run values honestly `pending`, nothing invented.
**Evidence**: `./init.sh` PASS at this commit (format, swiftlint --strict, Simulator build SUCCEEDED, SKIP [test] by policy); tracker-docs-only diff.
**Blockers**: user-run follow-ups — Golden annotation (200–500 fixed assets per `manual-qa.md` §3.2) plus physical measurement of the §8.2 and §7 rows (Simulator-only constraint).
**Next**: coordinator opens the parent PR to main after review; feat-018 may start only after the recorded gate.

## 2026-09-16 — feat-017 parent merge

**State**: merged (parent PR #30 MERGED via `52588ff`; branch fully on main)
**Done**: Parent PR #30 merged to main (`52588ff`); children merged with reviews — `mini-017a` via `0967d2d` (PR #27, APPROVED), `mini-017b` via `bdfa595` (PR #28, APPROVED), `mini-017c` via `e7143bc` (PR #29, APPROVED) plus `ebb0a50` stale-line fix; Task 3 consolidation done via `96a4de6` (pending-baseline IDs F-017-B/C/D/E/F/G/GLD/H in `curation-intelligence.md` §14, no production scoring/threshold/weight/version/config/budget change). Index: `feat-017` sole active integration, `mini-017a` `done`, `mini-017b`/`mini-017c` `blocked` pending-physical, `feat-018` `todo` (unchanged). Tracker state reconciled: `features/feat-017.md` Handoff rewritten to merged and exactly three Acceptance boxes checked (nine-metrics-baseline left unchecked, pending-physical).
**Evidence**: `./init.sh` PASS at this commit (format, `swiftlint --strict`, Simulator build SUCCEEDED, SKIP [test] by policy); `git diff --name-only` shows only `features/feat-017.md` + `progress.md`, no `apps/` path.
**Blockers**: user-run follow-ups — Golden annotation (200–500 fixed assets per `manual-qa.md` §3.2) plus physical measurement of the §8.2 and §7 rows (Simulator-only constraint; nothing invented).
**Next**: user-run physical measurement, then explicit done-flip and feat-018 selection; feat-018 must not start here.
## 2026-09-16 — feat-017 Simulator code-evidence baseline
**State**: active (evidence-policy amendment per user directive; nine-metrics box stays UNCHECKED — outcome path B, no status flip, no PR)
**Done**: Ran the Simulator code-evidence procedure on branch `tungxuan1656/feat-017-evidence` (from origin/main `6a36928`): seeded 1630 synthetic fixtures via `simctl addmedia` to booted iPhone 17 Pro iOS 26.5 (Photos.sqlite COUNT 70 pre-existing + 1630 seeded = 1700), rebuilt + installed + launched the app (PID 36576, no crash, Photos access granted), measured the pipeline in code — host harness on identical fixture bytes (stage timing/cache/counts) plus a proof binary compiling the REAL shipped Domain sources verbatim running `SelectionEngine.select` (deterministic repeat md5 `6f848be171ad4991720c3be1ada9c12f`) plus a cancel/checkpoint proof binary against REAL `FileStore`/`SessionCheckpointStore`/`SaveState` sources (ack primitive 0.0002 s, 250/250 checkpoint IDs preserved). Filled measured values into `features/feat-017.md` Handoff, `features/mini-017a.md` ledger (metric 7 compression across all 8 shapes), `features/mini-017b.md` rows A/B/C/E/F/G-reduced/Golden/H-1000, `features/mini-017c.md` §7 runs; left label-dependent values (8 of 9 metrics), D-shape, full-scale G, H 3k/5k, and device-only conditions honestly pending with reasons. No `apps/` change; no scoring/threshold/weight/version/config/budget change; no test files; feat-018 untouched (`todo`).
**Evidence**: `./init.sh` PASS (format PASS, `swiftlint --strict` PASS, BUILD SUCCEEDED, SKIP [test] per repo policy); `git diff --name-only` = `features/feat-017.md` + `features/mini-017a.md` + `features/mini-017b.md` + `features/mini-017c.md` only, no `apps/` path. Key measured values (SIMULATOR code-evidence, REAL-engine finals): A 60→12 (0.200, 0.474 s), B 40→8 (0.200, 0.240 s), C 100→18 (0.180, 0.598 s), E 60→12 (0.200, 0.481 s), F 20→0 (0.000, 0.022 s — empty-album edge finding), G-reduced 150→24 (0.160, 0.297 s), Golden-shape 200→30 (0.150, 0.722 s), H-1000 1000→100 (0.100, 1.186 s, failed 0, cold-hit 0.0).
**Blockers**: honest gaps (optional future work, not gates) — human annotation/judgment for 8 label-dependent metric values; face fixtures for D; full-scale G (500–1,500); H 3,000/5,000; on-device cancel-ack/UI-alive/heat/RSS/thermal; app-level cached-rerun reuse. Nothing invented.
**Next**: coordinator decision — accept this Simulator code-evidence baseline as the feat-017 record (leave `active` with gaps pending), or direct follow-ups; feat-018 selection remains user-gated; no PR per outcome path B.
## 2026-09-16 — feat-017 SYNTHETIC nine-metric baseline (done)
**State**: done (acceptance path A — all nine SYNTHETIC values computed with rule + artifact links, box checked, index flipped feat-017 + mini-017b/mini-017c to done)
**Done**: On branch `tungxuan1656/feat-017-synthetic` from origin/main `097f93f`: amended `features/feat-017.md` Handoff with the synthetic-proxy policy (LABEL/MOMENT/BEST-SHOT/REVIEWER rules v1 defined IN CODE, every proxy labeled SYNTHETIC never human); computed all nine metrics per shape with `/tmp/f017-evidence/synth-labels.py` (`409601a1…`, output `synth-metrics.json` `bb2dbdf9…`) against the ALREADY-MEASURED REAL-engine outputs of 06da3e8 (picked-*.json + out-*.json.analyses.json) with NO app re-run — A m1 0.240/m2 1.000/m3 0.000/m4 0.000/m5 n-a/m6 1.000/m7 0.200/m8 3.17/m9 4; B m1 0.222/m2 1.000/m3 0.000/m4 0.625/m5 0.200/m6 1.000/m7 0.200/m8 3.50/m9 3; C m1 0.202/m2 1.000/m3 0.000/m4 0.000/m5 n-a/m6 1.000/m7 0.180/m8 3.94/m9 4; E same as A; F empty-album edge (m1/m2/m3/m4/m5/m8 n-a with degenerate reasons, m6 0.000, m7 0.000, m9 1); G-reduced m1 0.166/m2 1.000/m3 0.000/m4 0.000/m5 n-a/m6 1.000/m7 0.160/m8 5.04/m9 4; Golden m1 0.160/m2 1.000/m3 0.000/m4 0.000/m5 n-a/m6 1.000/m7 0.150/m8 5.23/m9 4; H-1000 m1 0.101/m2 1.000/m3 0.000/m4 0.000/m5 n-a/m6 1.000/m7 0.100/m8 8.94/m9 4; Row D honestly NOT RUN (no face fixtures, optional future NOT a gate); metrics 4/5 carry the edges=[] degraded-config caveat; checked the nine-metrics box as a SYNTHETIC baseline; flipped `feature_index.json` feat-017 active→done and mini-017b/mini-017c blocked→done; updated all mini Status lines consistently.
**Evidence**: `./init.sh` result recorded at commit; `git diff --name-only` = `features/feat-017.md` + `features/mini-017a.md` + `features/mini-017b.md` + `features/mini-017c.md` + `feature_index.json` + `progress.md` only, no `apps/` path. Code hashes: harness `main.swift` `9d7696f6…`, proof `runner.swift` `2fa03949…`, synth-labels.py `409601a1…`, synth-metrics.json `bb2dbdf9…`. Manifests: A `33bf85cf…`, B `fb7319f0…`, C `96f8189f…`, E `579807d4…`, F `1e8ad06a…`, G `efd86379…`, Golden `e61200e0…`, H `5a165b85…`. No values invented, never human taste, never physical/device claims, Simulator-only HARD RULE honored.
**Blockers**: none for close (Row D + full-scale G + H 3k/5k + device-only conditions + human annotation are optional future, not gates).
**Next**: PR `tungxuan1656/feat-017-synthetic` → main (squash in a separate merge task); feat-018 selection remains user-gated; feat-018 must not start here.
## 2026-09-16 — feat-018 contract (active, sole integration)

**State**: active (sole integration parent; contract commit only, no `apps/` change)
**Done**: Verified origin/main `a877fa0` reads `feat-017` `done` / `feat-018` `todo` (dependency rule satisfied; Task premise expected feat-017 `active` — the #33 SYNTHETIC close flipped it to `done`, which satisfies the rule more strongly). Branch `tungxuan1656/feat-018-integration` verified at `a877fa0` with a clean tree. Activated `feat-018`; froze the universal fact schema (aestheticScore via `overallScore` [-1,1]→01 map reusing the existing Optional slot; top-3 classify tags reusing the existing tags slot; new `featurePrintAvailable` Bool availability flag; 7-field PhotoKit allowlist matching the current `map` exactly), the VN mapping (aesthetics rev 1 / classify rev 2 default, 512 px `.up`, independent degrade), the version 1→2 no-migration requeue rule, wiring points, and deterministic fallback. Created `docs/plans/feat-018.md` (child files, 12-field admission cards, merge order 018a→018b, rollback, verify); admitted `mini-018a`/`mini-018b` as task-ready `todo` index records with concrete parent/seam/exclusive_owns/merge_gate and non-overlapping ownership (card files transfer to their mini on dispatch; parent retains the schema). Rewrote Acceptance/Verify to Simulator code-evidence (A-shape + Golden-shape proof binary, cold/warm cost, QoS path, fallback byte-compare) per user directive 2026-09-16; manual QA replaced, zero user intervention, squash merges, Simulator-only HARD RULE. No `apps/` change, no weights/thresholds/versions touched. No PR (children merge into the integration branch first).
**Evidence**: `./init.sh` result recorded at commit; `git diff --name-only` = `features/feat-018.md` + `feature_index.json` + `docs/plans/feat-018.md` + `features/mini-018a.md` + `features/mini-018b.md` + `progress.md` only, no `apps/` path.
**Blockers**: none.
**Next**: dispatch `mini-018a`; merge 018a → 018b with independent reviews; then parent Task 3 (wire + version bump + Verify, gate feat-019).
## 2026-09-16 — feat-018 Task 3 (wired + verified; parent PR NOT yet opened)

**State**: active (sole integration; Task 3 wired + verified, both children merged; parent PR to main NOT yet opened)
**Done**: Parent Task 3 (only shared-contract change): `PhotoAnalysis` gains persisted `featurePrintAvailable: Bool` + `make` gains `aestheticScore`/`tags`/`featurePrintAvailable` params; `performAll` wires `UniversalFactAdapter.collect` then `map` with the existing print signal; `analysisVersion` 1 → 2. No scorer-math/weight/threshold change (composition-mean fold verified by read); `tags` gain no scorer consumer; cache gate + checkpoint-ignore already implement the requeue rule (no new migration code). Children: `mini-018a` + `mini-018b` flipped `todo` → `done` with consistent Status/Handoff lines; plan Tasks 2–3 boxes checked; feat-019 admission gate recorded in `features/feat-018.md` Handoff.
**Evidence**: Proof binary (REAL shipped sources verbatim; main `bc409f47…`, binary `65de92e2…`) on A-shape (60) + Golden-shape (200) fixture bytes twice — aes 60/60 + 200/200, tags 180 + 600, prints 60/60 + 200/200; byte-compare A md5 `01975608…ccc3` ==, Golden `9f7792c7…3445` == (PASS). F-017-E/F SYNTHETIC v1-rule reading: proxy-class totals unchanged (A m1 0.240/Golden m1 0.160 identical), movement is rank-order within MUST_KEEP (A 3/12, Golden 12/30 swapped; Golden 5 A-part + 25 G-part preserved) — signal-live, NOT a quality-gain claim. Cold/warm (same host/bytes): v2 26.83/21.75 ms/asset vs v1-shape 18.68/14.95 (+43.6%/+45.5% — exceeds the >~20% flag ON THIS HOST; host-harness inference cost, not the shipped budget; no constant changed). QoS unchanged (no detached/priority; same lane body). Requeue proof (REAL stores; main `58a68276…`, binary `1334bd3a…`): `v1rowMiss=true v2rowHit=true v1ckptIgnored=true v2ckptKept=true` → PASS. `./init.sh` PASS (format, `swiftlint --strict` 0 violations, Simulator build SUCCEEDED, SKIP [test] by policy).
**Blockers**: none.
**Next**: coordinator opens the parent PR to main (squash; separate merge task); feat-019 selection remains user-gated.

## 2026-09-16 — feat-018 done (parent PR #36 merged)

**State**: done (parent PR #36 squash-MERGED via `a68c89a` 2026-09-16; index flipped `active` → `done`; path A — all four Acceptance boxes honestly still pass on main)
**Done**: Branch `tungxuan1656/feat-018-doneflip` from origin/main `a68c89a`: rewrote `features/feat-018.md` Handoff State to done with squash evidence (PR #36 MERGED, mergeCommit `a68c89a` = main HEAD; chain `cf9cd52` + `5b731bb` (018a/PR #34) + `fcd4641` (018b/PR #35) + `bc7cbd0` (Task 3) + `2a0834e` (findings fix), pre-squash commits `git cat-file`-verified); re-verified all four Acceptance boxes on main by reading shipped sources (wiring, version-2 requeue, Verify evidence, fallback) — all pass, left checked; flipped `feature_index.json` feat-018 `active` → `done` (minis already `done`; feat-019 stays `todo`).
**Evidence**: `./init.sh` result recorded at commit; `git diff --name-only` = `features/feat-018.md` + `feature_index.json` + `progress.md` only, no `apps/` path.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-018-doneflip` → main (squash in a separate merge task); feat-019 selection remains user-gated; feat-019 must not start here.
## 2026-09-17 — feat-019 contract (active, sole integration)

**State**: active (sole integration parent; contract commit only, no `apps/` change)
**Done**: Verified origin/main `72070d6` reads `feat-018` `done` / `feat-019` `todo` (dependency rule satisfied; repo idle, no other `active`). Branch `tungxuan1656/feat-019-integration` verified at `72070d6` with a clean tree. Activated `feat-019`; froze the Tier-B routing contract (eligibility triggers per request from Tier-A same-pass facts, expected-value skip rule, bounded output shapes per fact, privacy/retention rules, version 2→3 no-migration requeue rule, Task 3 wiring points, deterministic fallback). Revisions verified in the iOS 26.5 SDK headers: attention saliency rev 2, horizon rev 1, person-seg rev 1, text rev 3, doc-seg rev 1; smudge has no request in the SDK (mini-019c records UNAVAILABLE). Admitted `mini-019a`/`mini-019b`/`mini-019c-conditional` as task-ready `todo` index records with exact non-overlapping ownership and merge gates (019c activates only on a parent-named residual failure). Rewrote Acceptance/Verify to Simulator code-evidence (proof binary + skip/bound + privacy no-persist + cost vs budget); no manual QA.
**Evidence**: `./init.sh` result recorded at commit; `git diff --name-only` = `features/feat-019.md` + `feature_index.json` + `docs/plans/feat-019.md` + `features/mini-019a.md` + `features/mini-019b.md` + `features/mini-019c.md` + `progress.md` only, no `apps/` path.
**Blockers**: none.
**Next**: dispatch `mini-019a`; merge 019a → 019b → 019c-conditional with independent reviews; then parent Task 3 (wire + version 3 + Verify, gate feat-020).
## 2026-09-17 — feat-019 Task 3 (wired + verified; parent PR NOT yet opened)

**State**: active (sole integration; Task 3 wired + verified, both children merged; parent PR to main NOT yet opened)
**Done**: Parent Task 3 (only shared-contract change): `PhotoAnalysis` gains persisted `salientRegionCount`/`textLineCount`/`isDocument` + populates reused `horizonScore`/`visualBalanceScore`/`hasText`/`screenshotProbability`; `make` gains 7 Tier-B params with caps; `AnalysisInput` gains `isScreenshotSubtype`; `performAll` splits into `tierABaseline` + `tierBFacts`; `analysisVersion` 2 → 3. No scorer-math/weight/threshold change; cache gate + checkpoint-ignore already implement the requeue rule (no new migration code). Children: `mini-019a` + `mini-019b` flipped `todo` → `done`; `mini-019c` CONDITIONAL-CLOSED (no residual failure, smudge UNAVAILABLE, matrix deferred); feat-020 admission gate recorded in `features/feat-019.md` Handoff.
**Evidence**: Proof binary (REAL shipped sources verbatim; main `b04ef698…`, binary `1fa78ed8…`) on A-shape (60) + Golden-shape (200) fixture bytes twice — salient 57/60 + 198/200, utility 39/60 + 143/200, horizon/balance honestly nil-on-synthetic; picked byte-compare A md5 `01975608…ccc3` ==, Golden `9f7792c7…3445` == (PASS, identical v2→v3); SYNTHETIC v1 proxies identical v2→v3 (signal-live, NOT a quality-gain claim). Skip: A 57/60 ran, Golden 198/200 ran. Privacy PERSIST-PROOF: PASS (main `7441c9ff…`). Cache REQUEUE-RULE: PASS (main `db2c9a52…`, binary `b675a1bc…`). Cost: v3 cold 52.60/warm 50.09 ms/asset; per-request saliency 8.92, horizon 3.84, person-seg 11.91, OCR-accurate 23.89, doc-seg 4.94 (host-harness, no budget constant changed). `./init.sh` PASS at this commit.
**Blockers**: none.
**Next**: coordinator opens the parent PR to main (squash; separate merge task); feat-020 selection remains user-gated.
## 2026-09-17 — feat-019 done (parent PR #40 merged)

**State**: done (parent PR #40 squash-MERGED via `e62172b` 2026-09-17; index flipped `active` → `done`; path A — all four Acceptance boxes honestly still pass on main)
**Done**: Branch `tungxuan1656/feat-019-doneflip` from origin/main `e62172b`: rewrote `features/feat-019.md` Handoff State to done with squash evidence (PR #40 MERGED, mergeCommit `e62172b` = main HEAD; chain `b8b22ff` + `8394e19` (019a/PR #39) + `2274281` (019b/PR #38) + `8e12b97` (Task 3) + `f3d5337` (findings fix), pre-squash commits `git cat-file`-verified); re-verified all four Acceptance boxes on main by reading shipped sources (wiring, version-3 requeue, Verify evidence, fallback) — all pass, left checked; flipped `feature_index.json` feat-019 `active` → `done` (minis 019a/019b already `done`, 019c stays `todo` conditional-closed; feat-020 stays `todo`).
**Evidence**: `./init.sh` PASS at this commit (format, `swiftlint --strict` 0 violations, Simulator build SUCCEEDED, SKIP [test] by policy); `git diff --name-only` = `features/feat-019.md` + `feature_index.json` + `progress.md` only, no `apps/` path.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-019-doneflip` → main (squash in a separate merge task); feat-020 selection remains user-gated; feat-020 must not start here.
## 2026-09-17 — feat-020 contract (active, sole integration)

**State**: active (sole integration parent; contract commit only, no `apps/` change)
**Done**: Verified origin/main `00c62e2` reads `feat-019` `done` / `feat-020` `todo` (dependency rule satisfied; repo idle, no other `active`). Branch `tungxuan1656/feat-020-integration` verified at `00c62e2` with a clean tree. Activated `feat-020`; froze the people/group decision contract (exact Tier-A aggregation inputs — faceCount, per-face faceCaptureQuality distribution, groupPhotoScore slot — plus Tier-B balance as inputs-only, weakest-face protection rule, candid-guard rule, reason-code policy reusing bestPortrait/bestGroupPhoto/betterFaceQuality with existing review copy, privacy no-persist limits, version 3→4 no-migration requeue rule, Task 3 wiring points on QualityScorer + SelectionEngine, deterministic fallback). Admitted `mini-020a` (group evidence calculator, `Services/Analysis/GroupEvidenceCalculator.swift`) as task-ready `todo` with all 12 admission fields concrete. Acceptance/Verify rewritten to Simulator code-evidence (B-shape + Golden-shape proof binary with face-bearing fixtures where available, per-face distribution + weakest-face asserts, candid-guard proof, privacy no-persist proof, cost vs budget).
**Evidence**: `./init.sh` result recorded at commit; `git diff --name-only` = `features/feat-020.md` + `feature_index.json` + `docs/plans/feat-020.md` + `features/mini-020a.md` + `progress.md` only, no `apps/` path.
**Blockers**: none.
**Next**: dispatch `mini-020a`; merge with independent review; then parent Task 3 (wire + version 4 + Verify, gate feat-021).
## 2026-09-17 — feat-020 Task 3 (wired + verified; parent PR NOT yet opened)

**State**: active (sole integration; Task 3 wired + verified, child merged; parent PR to main NOT yet opened)
**Done**: Parent Task 3 (only shared-contract change): `PeopleAnalysis` gains persisted `minFaceQuality`/`meanFaceQuality` (derived scalars, clamped01); `make` gains the 2 params (defaults nil); `TierABaseline` carries the transient per-face quality list with `bestFaceQuality` folding from the calculator mean; `performAll` passes existing Tier-A face observations through `GroupEvidenceCalculator.map` (NO new Vision request); `QualityScorer.score` folds weakest-face (`min(group, minFaceQuality)`, weights in configuration); `FinalAlbumBuilder.decision` appends frozen `bestGroupPhoto`+`betterFaceQuality`/`bestPortrait`; `analysisVersion` 3 → 4. No scorer-weight/threshold change; cache gate + checkpoint-ignore already implement the requeue rule (no new migration code); new fields decode version-tolerantly (v3-tolerance arm PASS). Child: `mini-020a` flipped `todo` → `done`; plan Tasks 2–3 boxes checked; feat-021 admission gate recorded in `features/feat-020.md` Handoff.
**Evidence**: Proof binary (REAL shipped sources verbatim; main `d92b89b2…`, binary `d759a149…`) on A-shape (60) + Golden-shape (200) + B-shape (40, binary `ba9a8785…`) fixture bytes twice — faces honestly 0/60 + 0/200 + 0/40 (no D fixtures; drawn-face probe 0); distribution asserts all TRUE, weakest-face fold 0.7333 vs 0.6000 PASS; byte-compare A md5 `01975608…ccc3` ==, Golden `9f7792c7…3445` ==, B `ecd4aa1a…41068` == (PASS, picks identical v3→v4 — signal-live, NOT a quality-gain claim). Candid-guard: all non-people picks survive (A 12/60, Golden 30/200). Privacy PERSIST-PROOF: PASS (binary `1a253bd6…`) + v3-tolerance PASS. Cache REQUEUE-RULE: PASS (binary `90579020…`, `currentVersion=4 v3rowMiss=true v4rowHit=true`). Cost: v4 cold 47.89 ms/asset vs v3 cold 52.60 (same host — no calculator regression); warm row round-trip 0.03; no budget constant changed. `./init.sh` PASS at this commit (format, `swiftlint --strict` 0 violations, Simulator build SUCCEEDED, SKIP [test] by policy).
**Blockers**: none.
**Next**: coordinator opens the parent PR to main (squash; separate merge task); feat-021 selection remains user-gated.

## 2026-09-17 — feat-020 done (parent PR #43 merged)

**State**: done (parent PR #43 squash-MERGED via `4613afe` 2026-09-17; index flipped `active` → `done`; path A — all four Acceptance boxes honestly still pass on main)
**Done**: Branch `tungxuan1656/feat-020-doneflip` from origin/main `4613afe`: rewrote `features/feat-020.md` Handoff State to done with squash evidence (PR #43 MERGED, mergeCommit `4613afe` = main HEAD; chain `b181559` + `84af07d` (mini-020a, PR #42 MERGED) + `fb2d4c1` (Task 3) + `6141907` (max-restore fix); squash tree equals integration tip `6141907` tree `e956cdf4…`); re-verified all four Acceptance boxes on main by reading shipped sources (wiring incl. max-restore fix + no-new-request, candid-guard nil-gating, privacy derived-scalars-only, cost with no budget constant changed) — all pass, left checked; flipped `feature_index.json` feat-020 `active` → `done` (mini-020a already `done`; feat-021 stays `todo`).
**Evidence**: `./init.sh` PASS at this commit (format, `swiftlint --strict` 0 violations, Simulator build SUCCEEDED, SKIP [test] by policy); `git diff --name-only` = `features/feat-020.md` + `feature_index.json` + `progress.md` only, no `apps/` path.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-020-doneflip` → main (squash in a separate merge task); feat-021 selection remains user-gated; feat-021 must not start here.

## 2026-09-17 — restore single-feature workflow

**State**: documentation migration complete on branch `chore/restore-single-feat-workflow`; no application code changed.
**Done**: Restored the Harness Slim rule of one active feature at a time. Removed mini-feature fields and records from `feature_index.json`; updated `AGENTS.md`, feature template, all remaining V2 feature records, and the four V2 plans. Deleted the parallel-delivery protocol, mini template, and completed mini-feature cards. Repointed affected evidence links to their parent feature or evidence document.
**Evidence**: `feature_index.json` parses with 28 feature records, zero mini records, and zero active features; `git diff --check` passes; repository-wide search finds no active mini-feature policy or broken `features/mini-*` route.
**Blockers**: none.
**Next**: activate `feat-021` only after the user selects it, then complete the feature on one branch before starting `feat-022`.

## 2026-09-17 — simplify feature index

**State**: tracker migration complete on `chore/restore-single-feat-workflow`.
**Done**: Removed duplicated `owns` arrays from `feature_index.json`. Added a total `execution_order` from `feat-001` through the remaining V2 work, with `feat-024` before `feat-023` as required by its dependency. The index now keeps only execution metadata; each feature file owns its scope and file list.
**Evidence**: JSON parses; every ID in `execution_order` maps to one feature record; no feature record contains `owns`, mini-feature fields, or an active status.
**Blockers**: none.
**Next**: use `execution_order` to select `feat-021`, then update only that feature record while it is active.

## 2026-09-17 — feat-021

**State**: active (sole integration; wired + verified, parent PR NOT yet opened; feat-020 stays `done`)
**Done**: Variant-aware clustering in `DuplicateResolver.swift` only — closest-first canonical edge order, pairwise variant gate (people-presence, single-vs-group, panorama/screenshot class, document, known-differing scene; every veto needs positive evidence on both sides), coherence-checked union (incompatible endpoints never merge behind an intermediate), context-aware representative via the shared `QualityScorer` rank. No `SelectionGrouping`/`SelectionEngine`/`MomentBuilder` change; `analysisVersion` stays 4; no new request/model/dependency/key.
**Evidence**: Proof binary (REAL shipped sources verbatim; harness `765810ad…`, binary `70dc9af8…`) on fixture bytes twice — A 60→11 (16 clusters, incoherent 0), Golden 200→30 (51 clusters, incoherent 0), B 40→5 (5 clusters, incoherent 0); picked byte-compare A `aef1efb1…` ==, Golden `7a3af1ea…` ==, B `2b7259ec…` ==; named cases I1–I8 + burst control ALL PASS; `./init.sh` PASS (format, `swiftlint --strict` 0 violations/61 files, Simulator build SUCCEEDED, SKIP [test] by policy). Day/night + formal/candid + framing-magnitude ceilings recorded as feat-024/feat-027 admission evidence; three proposed decisions (chain policy, ceilings, version-4 hold) left for the coordinator — no decision-log update made here.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-021-integration` → main (squash in a separate merge task); feat-022 selection remains user-gated.

## 2026-09-17 — feat-021 review-fix wave

**State**: active (sole integration; review findings fixed + re-proven, parent PR NOT yet opened; feat-020 stays `done`)
**Done**: Bilateral variant gate in `DuplicateResolver.swift:134-187` (`framingClassDiffers` 174-180, `documentDiffers` 182-187, nil-arm defers 138-144); plan traversal wording reconciled to closest-first canonical edge order (`docs/plans/feat-021.md:52-54`); plan file staged, tracked via `git diff HEAD --name-only` (`docs/plans/feat-021.md`); acceptance left honest (three code-evidence boxes checked, B-plus-Golden manual/device QA DEFERRED per `manual-qa.md` §§7–9, `features/feat-021.md:20-23`). No feat-022+ scope; no new model/request/persistence/config key; originals/privacy/on-device and feat-020 dependency preserved.
**Evidence**: Proof `v21proof-main.swift` (`a36e89bd…`), binary (`64c92bf5…`), REAL analyze → candidates → REAL edges → resolve/select twice: A 60→6 (6 clusters, incoherent 0), Golden 200→15 (14 clusters, incoherent 0), B 40→3 (3 clusters, incoherent 0); picked byte-compare A `0a1068c4…` ==, Golden `07d20b69…` ==, B `13eb627b…` == (PASS); named I1–I8 + burst ALL PASS incl. bilateral unknown arms (I3 unk-vs-pano/shot/unk merge; I4 nil-vs-false + true-vs-nil defer); HEAD-baseline movement honestly reported (A `b05f86c2…`, Golden `76705d64…`, B `f6c8c1c7…`); `./init.sh` PASS (format, `swiftlint --strict` 0 violations/61 files, Simulator build SUCCEEDED, SKIP [test] by policy); `git diff HEAD --name-only` = `DuplicateResolver.swift` + `docs/plans/feat-021.md` (staged) + `feature_index.json` + `features/feat-021.md` + `progress.md`.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-021-integration` → main (squash in a separate merge task); feat-022 selection remains user-gated.

## 2026-09-17 — feat-021 blocked (B-plus-Golden hard blocker)

**State**: blocked (hard blocker; code-evidence record preserved, parent PR NOT yet opened; feat-020 stays `done`)
**Done**: Documentation-only tracker update — flipped `feature_index.json` feat-021 `active` → `blocked`; updated `features/feat-021.md` Status/Handoff with blocker, preserved acceptance (three code-evidence boxes checked, B-plus-Golden UNCHECKED), evidence, and recovery action. No `apps/` change; no tests/test targets/frameworks; no destructive operations.
**Evidence**: No new `./init.sh` run and no new acceptance evidence in this update (nothing fabricated). Blocker evidence as recorded: devicectl reports all three physical iPhones unavailable; repo lacks annotated Golden/real-trip fixtures; `docs/ship-gates/manual-qa.md` disallows Simulator substitution (physical-iPhone + annotated Golden + real-trip review required per §§7–9).
**Blockers**: HARD BLOCKER above — B-plus-Golden manual/device QA cannot proceed until device and datasets are supplied.
**Next**: Run physical-iPhone B-plus-Golden annotation/measurement when device and datasets are supplied; feat-022+ stay `todo` and must not be activated here.

## 2026-09-17 — DEC-032 policy cutover (feat-021 unblocked, chain on automated evidence)

**State**: active (feat-021 `blocked` → `active`; sole integration; parent PR NOT yet opened; feat-020 stays `done`, feat-022..028 stay `todo`)
**Done**: Documentation-only DEC-032 cutover — `AGENTS.md`, `README.md`, `init.sh` (comment + SKIP line only), `docs/ship-gates/manual-qa.md` (optional non-blocking guidance, release lists advisory), `features/feat-template.md`, `feature_index.json` gates for feat-021..028, and feat-021..028 records rewritten to reproducible automated evidence (Simulator permitted) plus `./init.sh`. feat-021 acceptance is now four CHECKED boxes (B-shape 40 + Golden-shape 200 automated runs + I1–I8 + determinism byte-compare, exact counts in `features/feat-021.md` Handoff); no new proof run, nothing fabricated. DEC-031 already marked Superseded by DEC-032 by the coordinator — preserved untouched.
**Evidence**: `git diff --check` clean; `feature_index.json` parses (28 features); `./init.sh` PASS (format, `swiftlint --strict`, Simulator build SUCCEEDED, SKIP [test] per no-test-targets policy). No `apps/` change by this task; no tests/test targets/frameworks created.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-021-integration` → main (squash in a separate merge task); feat-022 selection remains user-gated.

## 2026-09-17 — DEC-032 final contradiction fixes (review follow-up)

**State**: active (feat-021 stays `active`; no state change; parent PR NOT yet opened; feat-022..028 stay `todo`)
**Done**: Documentation-only review follow-up — `docs/ship-gates/manual-qa.md:207` regression instruction rewritten to optional exploratory guidance with required automated A/B/Golden-shaped/trip-shaped evidence plus `./init.sh` (safety/privacy/data-integrity kept as automated acceptance conditions; "Never ship" removed, repo-wide grep confirms zero remains), `:297` MVP readiness qualified so manual/subjective review is advisory only, and `docs/design-docs/curation-intelligence.md:275` production-model quality gate qualified as automated Golden-shaped/trip-shaped evidence with hand review non-blocking. No `apps/`, test, decision-log, or historical-block change.
**Evidence**: `git diff --check` clean; `bash -n init.sh` OK; `jq empty feature_index.json` valid (28 records; feat-021 active, chain todo, all 8 gates carry `./init.sh`); `./init.sh` PASS (format, `swiftlint --strict`, Simulator build SUCCEEDED, SKIP [test] per no-test-targets policy).
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-021-integration` → main (squash in a separate merge task); feat-022 selection remains user-gated.

## 2026-09-17 — feat-021 done (DEC-032 automated gate)

**State**: done (closeout metadata only; `feature_index.json` feat-021 `active` → `done`; feat-020 stays `done`, feat-022..028 stay `todo`; parent PR NOT yet opened)
**Done**: Reconciled `features/feat-021.md` Status/Handoff to `done` — four acceptance boxes pass on the preserved DEC-032 automated record (variant-gate I1–I8 + burst ALL PASS; context-aware representative; double-run determinism byte-compare; B-shape 40 + Golden-shape 200 automated runs, exact counts in the feature Handoff). No `apps/` change, no decision-log edit, no feat-022+ change, no tests created; manual/device QA stays optional non-blocking per DEC-032.
**Evidence**: Accepted Codex review pass after the bilateral-gate fix wave (DEC-030 evidence) plus the existing fresh `./init.sh` pass (format, `swiftlint --strict` 0 violations, Simulator build SUCCEEDED, SKIP [test] per no-test-targets policy); `git diff --check` clean; `feature_index.json` parses (28 records, chain statuses consistent).
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-021-integration` → main (squash in a separate merge task); feat-022 selection remains user-gated; feat-022 must not start here.

## 2026-09-17 — feat-022 done (DEC-032 automated gate)

**State**: done (sole integration; proof + single final `./init.sh`; feat-021 stays `done`, feat-023/feat-024 stay `todo`; parent PR NOT yet opened)
**Done**: Semantic moment segmentation in `Domain/Selection/MomentBuilder.swift` only — middle-band conservative change-points via `semanticChangeSplits` (people-presence, bilateral document/framing, known-scene; edge-continuity first; sub-soft-gap hold; hard-gap split; nil/unknown legacy-continue; single-vs-group/orientation never split). Created `docs/plans/feat-022.md` (frozen contract, M1–M7 invariants, named verdicts, rollback); recorded DEC-033. No feat-023+ scope; no new Vision request/model/field/config key; `analysisVersion` stays 4.
**Evidence**: Proof binary (REAL shipped sources verbatim; main `bd15e5f6…`, binary `6970b0de…`, MomentBuilder `93b89d6f…`) through REAL analyze → candidates → REAL feature-print edges → build/select twice: Smoke 60→6, Golden 200→15, Trip 150→10, H 1000→56 (all moments new/legacy counted, incoherent 0; picked + moments byte-compare == all shapes); named M1–M7 ALL PASS (M1 new=2/legacy=1 improvement; M6 legacy-oracle identity). `./init.sh` PASS once (format PASS, `swiftlint --strict` 0 violations/61 files, BUILD SUCCEEDED, SKIP [test] per policy). Synthetic-fixture caveat: uniform 60 s-step timelines never enter the middle band, so shape moment counts match legacy by construction — improvement proven by injected M1–M3 cases.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-022-integration` → main (squash in a separate merge task); feat-024 selection remains user-gated; feat-023 must wait for feat-024.

## 2026-09-17 — feat-024 done (DEC-032 automated gate)

**State**: done (sole integration; proof + single final `./init.sh`; feat-022 stays `done`, feat-023 stays `todo`; parent PR NOT yet opened)
**Done**: Tier-C visual-embedding foundation — new `Domain/Selection/VisualEmbeddingProvider.swift` (`VisualEmbeddingProvider` protocol, `VisualEmbeddingRouter` ≤ 250 assets / ≤ 4,000 pairs, `NativeDerivedEmbeddingProvider` 8-dim persisted-scalar vector + 0.5 known-scene penalty, `NoopVisualEmbeddingProvider`, `VisualEmbeddingEdges` union-min merge) + `SelectionEngine.select` optional `tierCEdges: []` feeding diversity novelty only (clusters + moments stay FeaturePrint-only). Created `docs/plans/feat-024.md` (frozen routing, provider contract, FastViT benchmark-only model record, rollback); updated `curation-runtime-stack.md` §6; recorded DEC-034. No model vendored; no new Vision request/field/config key; `analysisVersion` stays 4; no cloud AI; iOS 26 deterministic path preserved.
**Evidence**: Proof binary (REAL shipped sources verbatim; main `a34b7b36…`, binary `4bba357e…`, provider `94b5de2a…`, engine `0e17e9a2…`) through REAL analyze → candidates → REAL feature-print edges → build/select twice on three arms: Golden-shaped 200→15 (clusters 14, moments 11, tierCEdges 0/0/4000 fallback/noop/tierc) + H 1000→56 (clusters 81, moments 56, tierCEdges 0/0/4000); picked byte-compare == across both runs AND all three arms (Golden `07d20b69…`, H `9de46dd7…`); 14 named cases ALL PASS (R1–R4, P1–P5, E1–E3, N1–N2). `./init.sh` PASS once (format PASS, `swiftlint --strict` 0 violations/62 files, BUILD SUCCEEDED, SKIP [test] per policy). No license/checksum payload: nothing vendored (N/A by construction); FastViT stays benchmark-only with reconsider trigger.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-024-integration` → main (squash in a separate merge task); feat-023 selection remains user-gated; feat-023 must not start here.

## 2026-09-17 — feat-024 review-fix wave (three Codex findings resolved)

**State**: done (sole integration; review fixes + re-proof + single final `./init.sh` below; feat-022 stays `done`, feat-023 stays `todo`; parent PR NOT yet opened)
**Done**: (1) Restored DEC-033 `Reconsider when` sentence byte-exact vs origin/main (`...or measured embedding/jury evidence justifies dense-timeline splitting.`) with the `---` separator, and restored the DEC-032 status-table index row byte-exact in original position (DEC-032 between DEC-030/DEC-033); all prior index rows/counts preserved (`### 1a` keeps `38 kept`); DEC-034 + DEC-035 appended as new rows; append-only history preserved, no older text rewritten. (2) DEC-035 recorded (Accepted 2026-09-17, owner `features/feat-024.md`) and made real: `SelectionSessionCoordinator` gains injected `tierCProvider` (default `NativeDerivedEmbeddingProvider`) + private `tierCEdges(for:analyses:)` (analyzed-assets scoping, router ≤ 250 / ≤ 4,000, noop fallback on refusal/empty output), wired into BOTH `selectResult` and `finalizeAvailable`; `AppContainer.tierCProvider` (native default, no state) + `AppModel` passthrough; Tier-C feeds diversity novelty only, clusters + moments stay FeaturePrint-only; `analysisVersion` stays 4, no model/persisted-schema/migration/cloud. (3) `runtime-stack.md` §6, `docs/plans/feat-024.md`, `features/feat-024.md` reconciled to the live wiring (DEC-035 refs, both-paths + fallback + rollback coverage).
**Evidence**: Wiring re-proof `/tmp/f024-evidence/out-wiring` run1+run2 (same binary `4bba357e…`, staged engine `0e17e9a2…`/provider `94b5de2a…` md5-match shipped): Golden 200→15 (clusters 14, moments 11, tierCEdges 0/0/4000) + H 1000→56 (clusters 81, moments 56, tierCEdges 0/0/4000); picked md5 == both runs × all three arms (Golden `07d20b69…`, H `9de46dd7…`); 14 named cases ALL PASS (R1–R4, P1–P5, E1–E3, N1 fallback-equals-noop, N2 clusters-moments-frozen); `swiftlint --strict` 0 violations/62 files; Simulator `BUILD SUCCEEDED`; `./init.sh` result recorded below. No test targets/`*Test*.swift`/frameworks; no manual QA.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-024-integration` → main (squash in a separate merge task); feat-023 selection remains user-gated (live bounded production consumer contract ready).

## 2026-09-17 — feat-024 post-merge closeout (PR #48 merged)

**State**: done (PR #48 MERGED into main via `6a130e3da9b782817cf819332738df6e3b7ce5d8`; feat-024 confirmed done, feat-022 stays `done`, feat-023 stays `todo`)
**Done**: Post-merge metadata closeout only — no `apps/`, plan, decision-log, `init.sh`, or `feature_index.json` change. `features/feat-024.md` Handoff State/Next rewritten to the merged state; acceptance/evidence text preserved intact.
**Evidence**: `git cat-file -t 6a130e3da9b782817cf819332738df6e3b7ce5d8` = commit, on `main`; `git diff --check` clean; `feature_index.json` parses with feat-022 `done`, feat-024 `done`, feat-023 `todo` (depends on feat-022 + feat-024). No `init.sh` or manual QA run (docs-only closeout).
**Blockers**: none.
**Next**: feat-023 is the next approved feature (depends on feat-022 and feat-024, both done); it can activate after this closeout is merged.

## 2026-09-17 — feat-023 done (DEC-032 automated gate)

**State**: done (sole integration; proof + single final `./init.sh`; feat-022 stays `done`, feat-024 stays `done`, feat-025 stays `todo`; parent PR NOT yet opened)
**Done**: Global diversity shortlist graph — new `Domain/Selection/GlobalDiversityGraph.swift` (member-only scope, 4,000-pair cap, canonical order, `isFallback` flag) + `DiversitySelector` graph wiring (visual-novelty input only; phases/math/weights/tie-breaks unchanged) + `QualityScorer.shortlist` 250 ceiling (no sub-150 padding) + `SelectionEngine` graph assembly + `shortlistScope` Tier-C routing + `engineVersion` 2 to 3 + both coordinator paths over the shortlist scope. Created `docs/plans/feat-023.md` (linked from the feature file); recorded DEC-036 (append-only, index row added); noted `engineVersion` 3 in `data-model.md`. No frozen-contract change (clusters/moments/weights untouched); no config key/model/request/quota/persisted field; no tests/test targets/frameworks; `analysisVersion` stays 4.
**Evidence**: Proof binary (REAL shipped sources verbatim; main `61d72cb5…`, binary `05cc1770…`, staged engine `9d6493e0…`/graph `cee94c5e…`/selector `d8267aab…`/scorer `1316be9f…`/builder `c7a2e7f8…` md5-match shipped) through REAL analyze → candidates → REAL feature-print edges → build/select twice on three arms: Smoke 60→6 (moments 4, graphMembers 12, graphEdges 2/2/66) + Golden 200→15 (moments 11, graphMembers 33, graphEdges 7/7/528) + Trip G 150→24 (moments 8, graphMembers 24, graphEdges 0/0/276) + H 1000→56 (clusters 81, moments 56, graphMembers 159, graphEdges 22/22/4000); picked byte-compare == both runs AND fallback==noop exactly all shapes (Smoke `0a1068c4…`, Golden `07d20b69…`, Trip `0f55281f…`, H `9de46dd7…`); all arms `engineVersion` 3; 12 named cases ALL PASS (N0-N4, S1-S3, F1-F3, G1). `./init.sh` PASS once after final edits (format PASS, `swiftlint --strict` 0 violations, Simulator BUILD SUCCEEDED, SKIP [test] per policy). Synthetic-fixture caveat: solids carry no pixel texture so Tier-C moves zero fixture picks at scale — improvement proven by injected N1-N3 cases.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-023-integration` → main (squash in a separate merge task); feat-025 selection remains user-gated; feat-023 must not be reactivated here.

## 2026-09-17 — feat-023 DEC-037 review fix (sole High resolved, verified)

**State**: done (sole integration; DEC-037 fix + re-proof + single final `./init.sh`; feat-022 stays `done`, feat-024 stays `done`, feat-025 stays `todo`; parent PR NOT yet opened)
**Done**: Resolved the sole Codex High: `SelectionEngine.shortlistScope` now accepts the same FeaturePrint `similarityEdges` used by `select` (deterministic `[]` default is the fallback arm only; clusters + moments stay FeaturePrint-only); both `SelectionSessionCoordinator` paths compute bounded FeaturePrint edges first and pass those same edges into `shortlistScope` before routing Tier-C pairs (same provider + noop fallback; ≤250 assets / ≤4000 pairs; diversity-only graph; no model/schema/persistence/cloud change). Updated `docs/plans/feat-023.md` (exact-shortlist production + verification wording), `features/feat-023.md` (DEC-037 handoff + evidence), preserved `docs/design-docs/decision-log.md` DEC-037 entry and all prior text append-only.
**Evidence**: Proof binary (REAL shipped sources verbatim; main `e27d2ee1…`, binary `1dd58aba…`, staged engine `a48e8ccb…`/graph `cee94c5e…`/selector `9c5f40fa…`/scorer `a6ab3f1a…`/builder `c7a2e7f8…` md5-match shipped) through REAL analyze → candidates → REAL FP edges → REAL `select` twice on three arms with per-shape exact-shortlist coverage guard true all four shapes: Smoke 60→6 (moments 4, graphMembers 6, graphEdges 0/0/15, tierCPairs 15) + Golden 200→15 (moments 11, graphMembers 15, graphEdges 0/0/105, tierCPairs 105) + Trip G 150→24 (moments 8, graphMembers 24, graphEdges 0/0/276, tierCPairs 276) + H 1000→56 (clusters 81, moments 56, graphMembers 60, graphEdges 0/0/1770, tierCPairs 1770); picked byte-compare == both runs AND fallback==noop exactly all shapes (Smoke `0a1068c4…`, Golden `07d20b69…`, Trip `0f55281f…`, H `9de46dd7…`); all arms `engineVersion` 3; 13 named cases ALL PASS (N0-N4, S1-S3, F1-F3, G1, X1 scope 3 pairs 3 covered true). `./init.sh` PASS once after final edits (format PASS, `swiftlint --strict` 0 violations/63 files, BUILD SUCCEEDED, SKIP [test] per policy; log `/tmp/f023-init.log`). No test targets/`*Test*.swift`/frameworks; no manual QA.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-023-integration` → main (squash in a separate merge task); feat-025 selection remains user-gated; feat-023 must not be reactivated here.

## 2026-09-17 — feat-023 post-merge closeout (PR #50 merged)

**State**: done (PR #50 MERGED into main via `96a75a94c2f31dfe962c1375d9009e4a42882545`; feat-023 confirmed done, feat-022 stays `done`, feat-024 stays `done`, feat-025 stays `todo`)
**Done**: Post-merge metadata closeout only — no `apps/`, plan, decision-log, `init.sh`, or `feature_index.json` change. `features/feat-023.md` Handoff State/Next rewritten to the merged state; acceptance/evidence text preserved intact.
**Evidence**: `git cat-file -t 96a75a94c2f31dfe962c1375d9009e4a42882545` = commit, on `main`; `git diff --check` clean; `feature_index.json` parses with feat-022 `done`, feat-024 `done`, feat-023 `done` (depends on feat-022 + feat-024), feat-025 `todo` (depends on feat-023). No `init.sh` or manual QA run (docs-only closeout).
**Blockers**: none.
**Next**: feat-025 is the next approved feature (depends on feat-023, done); it can activate after this closeout is merged.

## 2026-09-17 — feat-025 done (DEC-032 automated gate, documented no-op)

**State**: done (sole integration; no `apps/` change; feat-023 stays `done`, feat-026 stays `todo`; parent PR NOT yet opened)
**Done**: Searched feat-023 evidence for a triggering residual failure — all 12 named cases pass (N0–N4 novelty, S1–S3 saturation, F1–F3 fallback/determinism, G1 bounds) with fallback==noop exactly and double-run byte-identical; the only ceilings are pixel-level distinctions whose recorded path is FastViT Tier-C pixel evidence or feat-027 jury first (cheaper remedies unexhausted). Rejected DETR-style object/layout, Depth Anything V2 Small depth/context, and SAM 2.1 Tiny precision segmentation individually, never bundled, for lack of a triggering failure. No model, runtime dependency, provider, request, persisted field, config key, or version move; no `docs/plans/feat-025.md` per AGENTS plan rules; runtime-stack §7 rows flipped to REJECTED; DEC-038 recorded append-only with per-candidate alternatives/evidence/reconsider.
**Evidence**: `find apps` shows no `.mlmodel*`/`.mlpackage*`/`.coreml*` files; `apps/` grep shows no Tier-D names vendored; `git diff --name-only` = `features/feat-025.md` + `feature_index.json` + `docs/design-docs/curation-runtime-stack.md` + `docs/design-docs/decision-log.md` + `progress.md` only, no `apps/` path; `./init.sh` PASS (format, `swiftlint --strict`, Simulator build SUCCEEDED, SKIP [test] per policy). No test targets/`*Test*.swift`/frameworks; no manual QA (optional non-blocking per DEC-032).
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-025-integration` → main (squash in a separate merge task); feat-026 selection remains user-gated; feat-025 must not be reactivated here.

## 2026-09-17 — feat-025 review-fix (Codex docs/gate findings resolved)

**State**: done (sole integration; no `apps/` change; feat-023 stays `done`, feat-026 stays `todo`; parent PR NOT yet opened)
**Done**: Docs/harness-only review fix, no code/model/dependency/test change: created `docs/plans/feat-025.md` (trigger contract, explicit no-trigger/no-op branch, per-candidate records, repo-state verification, rollback/no-model-admission) per AGENTS.md >=4-file rule and linked it via `features/feat-025.md` Coordination plan; reconciled the file-count rationale to five changed paths (`features/feat-025.md` + `feature_index.json` + `docs/design-docs/curation-runtime-stack.md` + `docs/design-docs/decision-log.md` + `progress.md`) plus this plan as sixth; added `curation-runtime-stack.md` to the feature acceptance-evidence path list; rewrote the index gate and feature acceptance/evidence so the no-trigger branch is explicit (no unresolved feat-023 failure, cheaper remedies unexhausted, three candidates individually rejected, therefore no target/benchmark/license/resource evidence required for an admitted model and no runtime dependency introduced); preserved the three rejection verdicts and on-device privacy hold; corrected the stale user-gated wording — feat-026 is the next approved feature. DEC-038 untouched (no new decision required); no old log/progress blocks edited.
**Evidence**: `find apps` shows no `.mlmodel*`/`.mlpackage*`/`.coreml*` files; Tier-D grep → no hits; `git status --porcelain` = five modified plus `?? docs/plans/feat-025.md`, no `apps/` path; `./init.sh` PASS (format, `swiftlint --strict`, Simulator build SUCCEEDED, SKIP [test] per policy). No test targets/`*Test*.swift`/frameworks; no manual QA (optional non-blocking per DEC-032).
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-025-integration` → main (squash in a separate merge task); feat-026 is the next approved feature (depends on feat-023, done); feat-025 must not be reactivated here.

## 2026-09-17 — feat-025 post-merge closeout (PR #52 merged)

**State**: done (PR #52 MERGED into main via `55cf176753be531fa64fbab68504e5487943d0e9`; feat-025 confirmed done, feat-023 stays `done`, feat-026 stays `todo`)
**Done**: Post-merge metadata closeout only — no `apps/`, `init.sh`, or `feature_index.json` change. `features/feat-025.md` Handoff State/Next rewritten to the merged state (PR #52 MERGED, merge commit `55cf176753be531fa64fbab68504e5487943d0e9`; stale pre-merge branch/commit and closeout-pending wording removed); acceptance/evidence text preserved intact. DEC-039 recorded (append-only; DEC-038 untouched): retains the no-op specialist outcome and keeps `docs/plans/feat-025.md` as the AGENTS.md >=4-file readiness record with no application/model/runtime change; index row added.
**Evidence**: `git cat-file -t 55cf176753be531fa64fbab68504e5487943d0e9` = commit, on `main`; prior `./init.sh` PASS at the feat-025 commit (format, `swiftlint --strict`, Simulator build SUCCEEDED, SKIP [test] per policy); `git diff --check` clean; `feature_index.json` parses with feat-023 `done`, feat-025 `done`, feat-026 `todo` (depends on feat-023). No new `init.sh` or manual QA run (docs-only closeout).
**Blockers**: none.
**Next**: feat-026 is the next approved feature (depends on feat-023, done); feat-025 must not be reactivated here.

## 2026-09-17 — Harness QA policy update (DEC-040 automated-only gate)

**State**: done (docs/harness-only policy update; no `apps/` change; feat-021 through feat-025 stay `done`, feat-026 through feat-028 stay `todo`)
**Done**: Removed manual QA as a requirement from current and future Harness Slim gates per DEC-040: `AGENTS.md` working rule, `features/feat-template.md` Verify, `features/feat-021.md` + `feat-023.md` + `feat-024.md` + `feat-025.md` Verify/Handoff wording, `features/feat-026.md` acceptance + Verify, `features/feat-027.md` + `feat-028.md` Verify, `docs/plans/feat-025.md` verification wording, `docs/index.md` hand-QA task route (ownership row relabeled archival/non-gating), and `init.sh` test-skip messages. Appended DEC-040 to `docs/design-docs/decision-log.md` with index row. Left `docs/ship-gates/manual-qa.md` in place as an archival reference and preserved all old decision-log/progress entries, feature scopes, statuses, and dependencies.
**Evidence**: `python3 -c json.load(feature_index.json)` parses; `bash -n init.sh` clean; `git diff --check` clean; grep over `features/feat-021.md` through `features/feat-028.md` shows no manual-QA/hand-review/device-QA requirement wording (automated evidence + `./init.sh` only). No tests added per policy; no `./init.sh` full run (docs-only, no `apps/` change).
**Blockers**: none.
**Next**: feat-026 is the next approved feature (depends on feat-023, done); feat-026 must activate under the DEC-040 automated-only gate.

## 2026-09-17 — Roadmap QA residue cleanup (DEC-041 automated-only gates)

**State**: done (docs/harness-only review fix; no `apps/` change; feat-021 through feat-025 stay `done`, feat-026 through feat-028 stay `todo`)
**Done**: Removed the Codex-cited manual-QA gates from `docs/exec-plans/roadmap.md` per DEC-041: P4 Method, P6 saved-album confirmation, and the deferred test-target row now require reproducible automated evidence (Simulator permitted) + `./init.sh` only, with `manual-qa.md` retained as an explicitly archival/non-gating link. Scanned `AGENTS.md`, `docs/index.md`, `features/feat-template.md`, `features/feat-021.md` through `features/feat-028.md`, `docs/plans/feat-025.md`, and `init.sh` — no in-scope manual-QA/hand-review/device-QA requirement wording remains. Appended DEC-041 to `docs/design-docs/decision-log.md` with index row; `manual-qa.md` kept in place and historical progress/plans untouched.
**Evidence**: `python3 -c json.load(feature_index.json)` parses; `bash -n init.sh` clean; `git diff --check` clean; roadmap grep shows `manual-qa.md` only in archival/non-gating references. No tests added per policy; no `./init.sh` full run (docs-only, no `apps/` change).
**Blockers**: none.
**Next**: feat-026 is the next approved feature (depends on feat-023, done); feat-026 must activate under the DEC-040/DEC-041 automated-only gate.
## 2026-09-17 — feat-026 done (DEC-032 automated gate)

**State**: done (sole integration; proof + single final `./init.sh`; feat-023 stays `done`, feat-027 stays `todo`; parent PR NOT yet opened)
**Done**: Deterministic uncertainty contract from persisted feat-023 decisions (priority borderlineQuality > faceTradeoff > similarAlternatives > secondMomentView > coverageCut; band 0.05, cap 30; unavailable/eligibility/floor/dupe-loser never queue) + S22 Needs Review surface off S09 (existing S10/S11/S12/S13/S21 handle actions; deterministic flow untouched) + versioned aggregate feedback snapshot (schemaVersion 1, counts only, `uncertainty-feedback/` rows with ordered-hook writes and session deletes). Recorded DEC-042; created `docs/plans/feat-026.md`. No version move, no engine change, no cloud analytics, no tests.
**Evidence**: Proof binary (REAL shipped Domain + config + FileStore verbatim, 16/16 md5-match; harness `a5a02938…`, binary `b92580f7…`) — U1–U9 38 PASS / 0 FAIL, double-run byte-identical (`2f7d63f3…`); `./init.sh` PASS once (format 0/65, `swiftlint --strict` 0 violations/65 files, BUILD SUCCEEDED, SKIP [test] per policy). Exact changed files, thresholds, privacy boundary, and counts in `features/feat-026.md` Handoff.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-026-integration` → main (squash in a separate merge task); feat-027 selection remains user-gated; feat-026 must not be reactivated here.
## 2026-09-18 — feat-026 review fix (routing + cleanup race + durable proof, DEC-043)

**State**: done (review-fix integration; proof + single final `./init.sh` pass; feat-023 stays `done`, feat-027 stays `todo`; parent PR NOT yet opened)
**Done**: (1) `NeedsReview` action buttons route without mutating selection — inspect/compare-moment open the queue-scoped S11 pager (S21 one tap deeper), similar routes S12, add-back routes S13, standalone `SelectionToggle` kept. (2) DEC-043 closed-session tombstone in `SessionCheckpointStore` (deletes tombstone first, late `saveFeedback`/`saveUncertaintyFeedback` drop, live `beginReview` reopens) + hook captures its own model in `AppModel+Save`; ordinary disk failure still retries, deletes stay idempotent. (3) Durable proof `scripts/proof/feat-026.sh` (REAL shipped sources verbatim, STAGED-18-MD5-MATCH; `scripts/proof/out/` git-ignored) covering U1–U12. (4) Reconciled `docs/plans/feat-026.md` (band 0.05, schema without `analysisVersion`) and appended DEC-043 (index row, context/decision/alternatives/evidence/consequences/reconsider). No test targets/`*Test*.swift`/frameworks; no feat-027+ changes.
**Evidence**: `./scripts/proof/feat-026.sh` EXIT 0 — harness main `08e8e9cf…`, binary `7c7d902f…`, 57 PASS / 0 FAIL (U10 cleanup race, U11 routing audit, U12 reconcile included); `./init.sh` EXIT 0 — PASS [format], PASS [lint] (`swiftlint --strict` 0 violations/65 files), PASS [build] (BUILD SUCCEEDED), SKIP [test] per policy; `git diff --check` clean; `find apps scripts -name '*Test*.swift'` empty.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-026-integration` → main (squash in a separate merge task); feat-027 is next after this closes.
## 2026-09-18 — feat-026 review fix (durable proof + S22 docs + single source + DEC-044)

**State**: done (review-fix integration; proof + single final `./init.sh` pass; feat-023 stays `done`, feat-027 stays `todo`; parent PR NOT yet opened)
**Done**: (1) Durable proof now exercises ordinary save failure followed by retry success plus the real model-captured persistence hook/re-entry/interleaving against the tombstone guard (new U10 checks: real `UncertaintyReviewState`-derived hook snapshot drop, `FileStore` escape-path throw, failure/delete/reopen interleaving stays absent, reopen retry-success totals) with shipped source types only. (2) Canonical owner docs match shipped behavior: `ux-flows.md` gains S22 (22-screen inventory, matrix row, canonical-flow branch, S09 entry, §8.6 S22 section with queue/reasons/actions/aggregate feedback/retention/navigation) and `data-model.md` gains §11 queue/snapshot/persistence plus §14 frozen values and §15 snapshot row. (3) Single source of truth: `UncertaintyReviewState` owns queue derivation/resolution/snapshot with a decisions-based init; `ReviewModel` holds one and delegates (behavior and persistence preserved). (4) DEC-044 appended with index row (DEC-042 untouched): exact snapshot schema (`schemaVersion` 1: sessionID/engineVersion/queueSize/resolvedByReason/totalResolved/updatedAt only; `configVersion` 1 unchanged/not persisted; analysis 4/engine 3/config 1 unchanged) with date/context/decision/alternatives/evidence/consequences/reconsider condition. Plan/feature docs updated to match.
**Evidence**: `./scripts/proof/feat-026.sh` EXIT 0 — REAL shipped sources verbatim, STAGED-18-MD5-MATCH; harness main `842b670c…`, binary `b2484bb0…`, 60 PASS / 0 FAIL (strengthened U10 + U12 DEC-044 freeze included); `./init.sh` EXIT 0 — PASS [format], PASS [lint] (`swiftlint --strict` 0 violations/65 files), PASS [build] (BUILD SUCCEEDED), SKIP [test] per policy; `git diff --check` clean; `find apps scripts -name '*Test*.swift'` empty. No feat-027+ changes; no test target/framework.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-026-integration` → main (squash in a separate merge task); feat-027 is next after this closes.
## 2026-09-18 — feat-026 review fix (ownership + shipped-hook proof + S22 docs sweep, DEC-045)

**State**: done (review-fix integration; proof + single final `./init.sh` pass; feat-023 stays `done`, feat-027 stays `todo`; parent PR NOT yet opened)
**Done**: (1) Restored shipped review-model ownership in `App/AppModel+Save.swift` (`reviewModel = model` before routing; hook owns `PersistLatest` strongly with weak model capture + live snapshot derivation — no cycle, tombstone-safe per DEC-043; recorded DEC-045). (2) Extended proof to 21 staged files + U13 (shipped hook source checks + live REAL ReviewModel hook/re-entry/same-model behavior; proof-only `NoopPersistShim` mirrors the shipped pair shape). (3) Reconciled canonical UX refs (S01–S22 ownership range, S22 drill-down + review diagram; §8 title S09–S14).
**Evidence**: `./scripts/proof/feat-026.sh` EXIT 0 — REAL shipped sources verbatim, STAGED-21-MD5-MATCH; harness main `5346ea3c…`, binary `c668b6bb…`, 72 PASS / 0 FAIL (U13 shipped hook/re-entry/ownership + U6 exact seven-key freeze included); `./init.sh` EXIT 0 — PASS [format], PASS [lint] (`swiftlint --strict` 0 violations/65 files), PASS [build] (BUILD SUCCEEDED), SKIP [test] per policy; `git diff --check` clean; `find apps scripts -name '*Test*.swift'` empty. No feat-027+ changes; no test target/framework.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-026-integration` → main (squash in a separate merge task); feat-027 is next after this closes.
## 2026-09-18 — feat-026 review fix (strict schema + shipped AppModel proof + generation guard, DEC-046)

**State**: done (review-fix integration; proof + single final `./init.sh` pass; feat-023 stays `done`, feat-027 stays `todo`; parent PR NOT yet opened)
**Done**: (1) HIGH 1 strict schema: `UncertaintyFeedbackSnapshot` gains a custom strict decoder (open-key enumeration — `StrictKeys`-keyed `allKeys` hides unknown keys by design — throwing unless the top-level set equals exactly the DEC-044 seven; store nil-on-any-failure keeps loading nil, never throwing). (2) HIGH 2 real shipped proof: `scripts/proof/feat-026.sh` now stages 42 REAL shipped sources verbatim (whole app dir minus SwiftUI Views + `@main` entry; Views still Xcode-built via `./init.sh`) for the Simulator SDK with simctl-spawn headless execution, and U14 drives the live REAL shipped `AppModel` beginReview/hook/re-entry/save-guard path (edits via the model persist the pair, save-guard routes the same model, scripted exporter failure then retry-success, failure/delete/reopen interleaving stays absent until a fresh entry retries); harness fakes live in scripts/proof/ only (NOT shipped). (3) HIGH 3 stale-writer lifecycle: `SessionCheckpointStore` generations (`reopenSession` mints + returns, `beginReview` pins into `PersistLatest`, deletes retire) guarantee stale old-session writers cannot enter a reopened session (DEC-043 semantics kept). (4) MEDIUM UX: `ux-flows.md` §9 Mermaid review node labeled `Review (S22)`. Appended DEC-046; updated plan/feature/data-model records additively.
**Evidence**: `./scripts/proof/feat-026.sh` EXIT 0 — REAL shipped sources verbatim, STAGED-42-MD5-MATCH; harness main `7be135fe…`, binary `10a36636…`, 92 PASS / 0 FAIL (U6 strict rejected inputs `configVersion` + `debugNote` decode-throw, U9 extra-key rows load nil, U10 stale-generation interleaving drops + fresh retry succeeds, U14 live shipped AppModel beginReview/hook/save/failure/retry/interleaving); `./init.sh` EXIT 0 — PASS [format], PASS [lint] (`swiftlint --strict` 0 violations), PASS [build] (BUILD SUCCEEDED), SKIP [test] per policy; `git diff --check` clean; `find apps scripts -name '*Test*.swift'` empty. No feat-027+ changes; no test target/framework.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-026-integration` → main (squash in a separate merge task); feat-027 is next after this closes.
## 2026-09-18 — feat-026 final proof integration

**State**: done (final proof/docs fix; feat-023 stays `done`, feat-027 stays `todo`; parent PR NOT yet opened)
**Done**: Staged shipped `Features/Review/NeedsReview.swift` with its five-file SwiftUI dependency closure in the proof compilation, routed all four S22 actions through the shipped destination helper, and changed the review Mermaid node to explicit `S22 Needs Review`; prior U1–U14 and DEC-044/DEC-046 checks remain intact.
**Evidence**: `./scripts/proof/feat-026.sh` EXIT 0 — `STAGED-48-MD5-MATCH`, Simulator `simctl spawn`, harness `c824f3baa9b249146c5fdd760d15107aaf56b6147fc849a8e254197e2b063bf3`, binary `fe6169f322c32bc20fb908bd30eefc1ea56229737abb58cb60e1d20dfde10984`, `99 PASS / 0 FAIL`; U15 executes shipped S22 view initialization, inspect/compare pager destinations, similar/add-back route appends, and detail no-path mutation. `./init.sh` EXIT 0 — format PASS, `swiftlint --strict` PASS (0 violations/65 files), Simulator build SUCCEEDED, test SKIP per DEC-040; no test target/framework or `*Test*.swift`.
**Blockers**: none.
**Next**: PR `tungxuan1656/feat-026-integration` → main (squash in a separate merge task); feat-027 is next after this closes.

## 2026-09-18 — feat-026 documentation closeout

**State**: done (documentation-only drift correction; feat-026 remains done, feat-027 stays todo; parent PR NOT yet opened)
**Done**: Corrected the final feat-026 proof and UX records without changing application code: the review Mermaid node is explicitly `S22 Needs Review`; the proof record now uses `STAGED-48-MD5-MATCH` and identifies shipped `Features/Review/NeedsReview.swift` plus its six-file SwiftUI dependency closure (`Features/Review/PhotoDetail.swift`, `Features/Review/PhotoAnalysisDetail.swift`, `Features/Review/ReviewScoreBadge.swift`, `SharedUI/AsyncPhotoThumbnail.swift`, `SharedUI/ErrorStateView.swift`, `SharedUI/SelectionToggle.swift`), replacing the stale five-file closure wording.
**Evidence**: `git diff --check` clean; `./scripts/proof/feat-026.sh` EXIT 0 — `STAGED-48-MD5-MATCH`, Simulator `simctl spawn`, harness `c824f3baa9b249146c5fdd760d15107aaf56b6147fc849a8e254197e2b063bf3`, binary `fe6169f322c32bc20fb908bd30eefc1ea56229737abb58cb60e1d20dfde10984`, `99 PASS / 0 FAIL`; no new `./init.sh` run because this closeout changes documentation only and retains the prior `./init.sh` EXIT 0 evidence.
**Blockers**: none
**Next**: PR `tungxuan1656/feat-026-integration` → main (squash in a separate merge task); feat-027 is next after this closes.

## 2026-09-18 — feat-026 post-merge closeout (PR #55 merged)

**State**: done/merged
**Done**: Post-merge documentation closeout only. PR #55 (`https://github.com/tungxuan1656/photo-curator/pull/55`) from branch `tungxuan1656/feat-026-integration` was squash-merged as `2e84812f97aa7099cdb15902f1fedc218585d0fa`, confirmed on `origin/main`; feat-023 is done and `feature_index.json` remains done for feat-026.
**Evidence**: `STAGED-48-MD5-MATCH`; `99 PASS / 0 FAIL`; U15 shipped `NeedsReview` route/action checks; retained `./init.sh` evidence is format PASS, SwiftLint 0 violations, Simulator build SUCCEEDED, and test SKIP by DEC-040; Codex Luna xhigh final review found zero actionable findings. No tests, test target, or test framework; no app build was needed for this docs-only closeout.
**Decisions**: DEC-042 deterministic uncertainty contract; DEC-043 tombstone-safe cleanup race; DEC-044 exact seven-key aggregate feedback schema; DEC-045 strong hook ownership with weak model capture; DEC-046 strict schema decoding and generation-guarded persistence.
**Blockers**: none
**Next**: Activate feat-027 from the latest `origin/main`; not user-gated.

## 2026-09-18 — feat-027 semantic jury complete

**State**: done (implemented and verified; parent PR NOT yet opened)
**Done**: Activated feat-027, recorded external plan `docs/plans/feat-027.md` and DEC-047, implemented the iOS 27 Foundation Models semantic-jury seam with strict one-key choice validation, bounded admitted requests, timeout/cancellation/failure fallback, privacy-safe diagnostics, and deterministic same-cluster `chooseA`/`chooseB` integration. iOS 26 remains unchanged and provider injection is live only through the app container.
**Evidence**: `scripts/proof/feat-027.sh` EXIT 0 — `STAGED-MATCH 8`, Simulator `simctl spawn`, iOS 26 `providerCalls=0`, iOS 27 `chooseB`, strict schema four invalid rows, safe-choice fallback, bounds, unavailable, timeout, cancellation, and Golden-shaped `candidates=200 requests=100 attempts=4` all PASS; `RESULT PASS`. `./init.sh` EXIT 0 — format PASS, SwiftLint strict 0 violations, Simulator build SUCCEEDED, test SKIP per DEC-040. `git diff --check` PASS; no `*Test*.swift` files, test targets, or test frameworks.
**Decisions**: DEC-047 bounded iOS 27 semantic jury contract; engine version remains 3 and no persistence/schema migration is introduced.
**Blockers**: none
**Next**: PR `tungxuan1656/feat-027-integration` → main (squash in a separate merge task).

## 2026-09-18 — feat-027 Codex review fixes

**State**: done (review-fix integration; parent PR NOT yet opened)
**Done**: Wired coordinator-loaded in-memory `CGImage` values into the iOS 27 Foundation Models image-attachment prompt (future image-input SDK branch, no text-only downgrade); replaced global jury rerun with a same-cluster in-place swap that preserves unrelated selected IDs; replaced the task-group timeout with a hard-bounded cancellation race; expanded the proof to compile and exercise the shipped `SelectionEngine` + `SelectionSessionCoordinator` boundary; aligned `deterministicFallback` docs and recorded DEC-048.
**Evidence**: `scripts/proof/feat-027.sh` EXIT 0 — `STAGED-MATCH 26`, request-factory ordering, iOS 26 zero provider/image calls, iOS 27 image-backed coordinator requests, same-cluster-only, unrelated-selection preservation, generic provider failure, strict schema, bounds, unavailable, non-cooperative timeout, cancellation, and Golden-shaped deterministic cap all PASS; `RESULT PASS`. `./init.sh` EXIT 0 — format PASS, SwiftLint strict 0 violations, Simulator build SUCCEEDED, test SKIP per DEC-040; `git diff --check` PASS; no test artifacts/framework.
**Decisions**: DEC-047 bounded iOS 27 semantic jury; DEC-048 image-backed in-place integration and hard timeout; engine version remains 3 and no persistence/schema migration is introduced.
**Blockers**: none
**Next**: PR `tungxuan1656/feat-027-integration` → main (squash in a separate merge task).
## 2026-09-18 — feat-027 Codex review remediation

**State**: done (review remediation; parent PR NOT yet opened)
**Done**: Added the SDK-capability adapter seam for Foundation Models image attachments: current Swift 6.3.3/iOS 26.5 builds compile and deterministically fall back, while an iOS 27 SDK build can enable the typed `Attachment(CGImage)` branch without a compiler-version guard. Added releasable run-local image leases and detached hard-timeout cleanup, repaired the feat-026 `AppContainer` compatibility fixture, moved feat-027 proof output under ignored `scripts/proof/out`, and reconciled in-place apply semantics plus DEC-049 across feature/plan/decision docs.
**Evidence**: `./scripts/proof/feat-026.sh` EXIT 0 — `STAGED-49-MD5-MATCH`, 99 PASS / 0 FAIL. `./scripts/proof/feat-027.sh` EXIT 0 — `STAGED-MATCH 26`, timeout 2,073 ms under the 2.75 s proof bound with image leases released, native adapter current-SDK fallback and all focused jury/fallback/GOLDEN checks PASS, `RESULT PASS`. `./init.sh` EXIT 0 — SwiftFormat PASS, SwiftLint strict 0 violations, Simulator build SUCCEEDED, test SKIP per DEC-040. `git diff --check` PASS; no automated test artifacts; `.build/proof-feat-027` absent and output remains under ignored `scripts/proof/out`.
**Decisions**: DEC-047 bounded iOS 27 semantic jury; DEC-048 image-backed in-place integration and hard timeout; DEC-049 explicit Foundation Models SDK capability seam; engine version remains 3 and no persistence/schema migration is introduced.
**Blockers**: none
**Next**: open PR `tungxuan1656/feat-027-integration` → main (squash in a separate merge task).

## 2026-09-18 — feat-027 post-merge closeout (PR #57 merged)

**State**: done/merged
**Done**: Post-merge documentation closeout only. PR #57 (`https://github.com/tungxuan1656/photo-curator/pull/57`) was merged into `main` at `2e57ecbfa65eb12fff51d0c6af96d9da69b5fd85`, confirmed on `origin/main`; `feature_index.json` remains `done` for feat-027. All feat-027 acceptance criteria are checked; no application code changed.
**Evidence**: `scripts/proof/feat-027.sh` EXIT 0 — `STAGED-MATCH 26`, iOS 26 deterministic fallback, iOS 27 image-backed jury requests, strict schema, safe/failure/timeout/cancellation paths, same-cluster in-place preservation, and Golden-shaped cap all PASS; `RESULT PASS`. Retained `./init.sh` EXIT 0 — SwiftFormat PASS, SwiftLint strict 0 violations, Simulator build SUCCEEDED, test SKIP per DEC-040; no tests, test target, or test framework. `git diff --check` PASS; manual QA remains removed and non-gating per DEC-040.
**Decisions**: DEC-047 bounded iOS 27 semantic jury; DEC-048 image-backed in-place integration and hard timeout; DEC-049 explicit Foundation Models SDK capability seam. No contract or data-model change; engine version remains 3 with no persistence/schema migration.
**Blockers**: none
**Next**: feat-028 (Ranker decision gate), activated from the latest `origin/main` after this closeout.

## 2026-09-18 — feat-028 ranker decision gate

**State**: done (DEC-050 no-ranker decision; no application-code change)
**Done**: Activated feat-028 from merged feat-027; created `docs/plans/feat-028.md`; froze
`analysisVersion 4`, `engineVersion 3`, `configVersion 1`, deterministic rank/tie-break policy,
synthetic label provenance and prohibited-data boundary, disjoint evaluation splits, metrics,
thresholds, rollback, and reconsider triggers. Rejected learned ranking because the frozen
deterministic baseline exposed no material measurable gap; updated runtime-stack status and
recorded DEC-050. Feature/index/plan handoff is synchronized and all feat-028 acceptance boxes
are checked.
**Evidence**: `./scripts/proof/feat-028.sh` EXIT 0 — `STAGED-MATCH 17`; Smoke 60→15,
Golden-shaped 200→30, Trip-shaped 150→30, H-1000 1,000→50; all four deterministic replays
pass with Good Selection 1.000, Bad Pick 0.000, Duplicate Leakage 0.000, Best-Shot Accuracy
1.000, Moment Coverage 1.000, engineVersion 3. `./init.sh` EXIT 0 — SwiftFormat PASS (2/87
files formatted), SwiftLint strict PASS (0 violations/66 files), Simulator build `BUILD
SUCCEEDED`, test `SKIP` by DEC-040. No app model, dependency, persistence, migration, network,
telemetry, or test artifacts added.
**Decisions**: DEC-050 closes V2 with the deterministic ranker; synthetic labels are structural
proof inputs only, not user data or training data; no candidate evaluation is admitted.
**Blockers**: none
**Next**: V2 ranker phase closed; reconsider only after a named residual failure and newly frozen
admissible labels satisfy the full quality/privacy/license/performance/version/fallback gate.

## 2026-09-18 — feat-028 Codex review remediation

**State**: done (independent-evidence and owner-recall gate fix; no application-code change)
**Done**: Replaced rank-derived labels with `fixture-oracle-v2`, a repository-local static
annotation manifest in `scripts/proof/feat-028-proof.swift`. The manifest is shared by Smoke 60
(15 groups × 4), Golden-shaped 200 (20 × 10), Trip-shaped 150 (30 × 5), and H-1000 1,000
(50 × 20); labels never read `PhotoAnalysis`, scalar scores, rank order, or engine output. Added
oracle/rank disagreement, complete label coverage, cross-split asset-ID disjointness, complete
frozen config/weights/bonuses/tie-break checks, and Must-Keep Recall `≥95%` assertions; recorded
DEC-051 and synchronized feature/plan/decision provenance.
**Evidence**: `./scripts/proof/feat-028.sh` EXIT 0 — `STAGED-MATCH 17`; frozen config/weights/
bonuses/tie-break, oracle provenance, label coverage, asset-ID disjointness, and oracle/rank
independence PASS. Smoke `60→15`, Golden-shaped `200→20`, Trip-shaped `150→30`, H-1000
`1,000→50`; Recall/Good Selection/Best-Shot/Moment Coverage `1.000`, Bad Pick/Duplicate
Leakage `0.000`, deterministic replay PASS. `./init.sh` EXIT 0 — SwiftFormat PASS (`2/87` files
formatted), SwiftLint strict PASS (`0` violations in `66` files), Simulator build `BUILD SUCCEEDED`,
tests `SKIP` by DEC-040; `git diff --check` clean and no `*Test*.swift` files found.
**Blockers**: none.
**Next**: V2 ranker phase closed; reconsider only on a named residual failure with a newly approved
admissible label source satisfying the full quality/privacy/license/performance/version/fallback gate.

## 2026-09-18 — feat-028 proof contract completion

**State**: done (DEC-050 no-ranker outcome retained; DEC-051 evidence direction completed by DEC-052; no application-code change)
**Done**: Replaced the rank-winner-only fixture rows with `fixture-oracle-v3` authored annotation rows and an explicit H-1000 case where `MUST_KEEP` is below the deterministic rank winner; the proof asserts both the mismatch and the selected rank winner. Added behavioral equal-score fixtures for the frozen edited > favorite > pixel-area > asset-ID ordering with reversed-input replay. Aligned Duplicate Leakage to the owner definition, needless repeat selections / total selected, and asserted the selected-output denominator; marked DEC-050 Superseded by DEC-051 without rewriting its historical body and added DEC-052 for this completion.
**Evidence**: `./scripts/proof/feat-028.sh` EXIT 0 (`STAGED-MATCH 17`); Smoke 60→15, Golden-shaped 200→20, Trip-shaped 150→30, H-1000 1,000→50; Recall/Good Selection/Best-Shot/Moment Coverage `1.000` on first three and `0.980/0.980/0.980/1.000` on H-1000; Bad Pick `0.000/0.000/0.000/0.020`; Duplicate Leakage `0.000` with selected-output denominators 15/20/30/50; tie-break and explicit mismatch assertions PASS. `./init.sh` EXIT 0 — SwiftFormat PASS (0/87 formatted), SwiftLint strict PASS (0 violations/66 files), Simulator build SUCCEEDED, tests SKIP by DEC-040; no test artifacts.
**Decisions**: DEC-050 is Superseded by DEC-051 for its original provenance wording; DEC-052 records the explicit mismatch, tie-break behavior, canonical leakage denominator, and unchanged gates.
**Blockers**: none.
**Next**: V2 ranker phase closed; reconsider only after a named residual failure and newly approved admissible labels satisfy the full quality/privacy/license/performance/version/fallback gate.

## 2026-09-18 — feat-028 post-merge closeout (PR #59 merged)

**State**: done/merged
**Done**: Post-merge documentation closeout only. PR #59 (`https://github.com/tungxuan1656/photo-curator/pull/59`) was merged into `main` at `986f5dd82970afd5cd46fe2651fad689bf9eb87f`, confirmed on `origin/main`; `feature_index.json` remains `done` for feat-028. All four feat-028 acceptance criteria remain checked; no application code changed. The full approved feature sequence is complete and there is no next feature.
**Evidence**: `./scripts/proof/feat-028.sh` EXIT 0 — `STAGED-MATCH 17`; independent `fixture-oracle-v3` evidence, explicit H-1000 `MUST_KEEP`/rank mismatch and deterministic rank-winner assertion, equal-score edited/favorite/pixel-area/asset-ID tie-break behavior under reversed input order, Smoke `60→15`, Golden-shaped `200→20`, Trip-shaped `150→30`, H-1000 `1,000→50`, deterministic replay, Recall/Good Selection/Best-Shot/Moment Coverage `1.000/1.000/1.000/1.000` on the first three and `0.980/0.980/0.980/1.000` on H-1000, Bad Pick `0.000/0.000/0.000/0.020`, and Duplicate Leakage `0.000` with selected-output denominators `15/20/30/50` all PASS. Retained `./init.sh` EXIT 0 — SwiftFormat PASS (`0/87` files formatted), SwiftLint strict PASS (`0 violations in 66 files`), Simulator build `BUILD SUCCEEDED`, tests `SKIP` by DEC-040; manual QA remains removed and non-gating per DEC-040; no automated tests, test targets, `*Test*.swift` files, or test frameworks. `git diff --check` and targeted consistency checks PASS.
**Decisions**: DEC-050 no-ranker outcome retained; DEC-051 independent oracle and recall-gate remediation; DEC-052 proof-contract completion. No contract or data-model change; no model, dependency, persistence, migration, network path, telemetry, or fallback adapter added.
**Blockers**: none
**Next**: none — the full approved feature sequence is complete; reconsider a ranker only after a named residual failure and newly approved admissible labels satisfy the full quality/privacy/license/performance/version/fallback gate.

## 2026-09-18 — feat-030 feature record

**State**: todo
**Done**: Created the approved feat-030 feature record and separate execution plan for English/Vietnamese localization; appended feat-030 after feat-029 with a concise dependency gate. No `apps/` change.
**Evidence**: JSON parsing and `git diff --check` pass.
**Blockers**: none
**Next**: User selects feat-030 after feat-029 is done; do not activate it before then.

## 2026-09-18 — feat-029 immersive photo inspection

**State**: done
**Done**: Implemented fullscreen S11 inspection with bounded zoom/pan state, Fit-safe scoped paging, explicit album state, analysis navigation, retry/back recovery, safe-area overlays, accessibility actions, and Reduce Motion-aware transforms. Kept `ReviewModel` and the existing PhotoKit preview service boundary unchanged; only the current 2048-pixel `CGImage` is retained and superseded loads are cancelled or ignored.
**Evidence**: `./scripts/proof/feat-029.sh` EXIT 0 (`SCALE-CLAMP`, `OFFSET-CLAMP`, `RESET`, `FIT-PAGE`, `ZOOM-PAN`, `ASSET-RESET`, `ACCESSIBILITY-CONTROLS`, `CURRENT-ONLY`, `SERVICE-BOUNDARY`, and `ASSET-LIFECYCLE` PASS); `./init.sh` EXIT 0 (SwiftFormat PASS, SwiftLint strict PASS with 0 violations in 70 files, Simulator `BUILD SUCCEEDED`, policy test `SKIP`); Simulator install/launch EXIT 0 on `iPhone 17 Pro` (`com.tungxuan.photo-curator: 95203`); `git diff --check` and no-test-artifact checks PASS.
**Blockers**: none
**Next**: User selects feat-030; it remains todo until then.

## 2026-09-18 — feat-029 follow-up behavior fix

**State**: done
**Done**: Raised S11 maximum zoom from 3× to 6×, changed Back to dismiss only the nested inspector so it returns to the originating photo list, and added Fit-only downward swipe dismissal; vertical drags while zoomed remain pan-only.
**Evidence**: `./scripts/proof/feat-029.sh` EXIT 0 with zoom, Fit-page, swipe-down dismissal, zoom-pan, accessibility, lifecycle, and service-boundary checks PASS; `./init.sh` EXIT 0 with SwiftFormat PASS, SwiftLint strict 0 violations, Simulator build `SUCCEEDED`, and policy test `SKIP` per DEC-040; Simulator install/launch PASS on `iPhone 17 Pro` (`com.tungxuan.photo-curator: 5974`); `git diff --check` PASS.
**Blockers**: none
**Next**: feat-030 remains user-gated and `todo`.

## 2026-09-18 — feat-029 S11 Liquid Glass controls

**State**: done
**Done**: Replaced the S11 material chrome surfaces with native iOS 26 `glassEffect` controls grouped by `GlassEffectContainer`; the In Album action uses the accent tint, while navigation and analysis controls use neutral interactive glass. Kept the continuous rounded shapes, top-left/top-right/bottom placement, accessibility labels, and material fallback.
**Evidence**: `./scripts/proof/feat-029.sh` EXIT 0; `./init.sh` EXIT 0 with SwiftFormat PASS, SwiftLint strict 0 violations in 71 files, Simulator build `SUCCEEDED`, and policy test `SKIP` per DEC-040; CUA simulator smoke displayed the three Liquid Glass control groups and preserved individual Back, Previous, Next, In Album, and View Analysis accessibility controls; `git diff --check` PASS.
**Blockers**: none
**Next**: feat-030 remains user-gated and `todo`.

## 2026-09-18 — feat-029 S11 control placement refinement

**State**: done
**Done**: Repositioned S11 controls to match photo-inspection behavior: Back and position at top-left, Previous/Next at top-right, and In Album/Analysis/Fit in the lower action island. Replaced capsule borders with consistent continuous rounded rectangles.
**Evidence**: Focused SwiftLint and `./scripts/proof/feat-029.sh` EXIT 0; `./init.sh` EXIT 0 with Simulator build `SUCCEEDED` and policy test `SKIP` per DEC-040; Simulator install/launch PASS on `iPhone 17 Pro` (`com.tungxuan.photo-curator: 39069`); CUA screenshot and accessibility tree verified the requested placement and individual controls; `git diff --check` PASS.
**Blockers**: none
**Next**: feat-030 remains user-gated and `todo`.

## 2026-09-18 — feat-029 S11 visual and gesture polish

**State**: done
**Done**: Scoped inspection gestures to the image surface so Back/buttons do not wait for tap arbitration; replaced the heavy default button panels with compact material islands and a single accent action; added edge-aware chrome motion, image crossfade, spring feedback for discrete actions, sensory feedback, and individual VoiceOver controls. Native `NavigationLink` navigation remains unchanged; modal navigation was not needed.
**Evidence**: `./scripts/proof/feat-029.sh` EXIT 0; focused SwiftLint 0 violations; `./init.sh` EXIT 0 with SwiftFormat PASS, SwiftLint strict 0 violations, Simulator build `SUCCEEDED`, and policy test `SKIP` per DEC-040; Simulator install/launch PASS on `iPhone 17 Pro` (`com.tungxuan.photo-curator: 30051`); CUA smoke reached S11, verified individual Back/Analysis/Previous/Next controls and Fit after zoom, then returned to Selection; `git diff --check` PASS.
**Blockers**: none
**Next**: feat-030 remains user-gated and `todo`.

## 2026-09-18 — feat-029 review remediation

**State**: done (review-fix integration; feat-029 remains done; feat-030 remains todo)
**Done**: Exposed the inspection image as a semantic VoiceOver element, reset transient chrome and gesture bookkeeping whenever S11 appears or disappears, and replaced independent tap recognizers with an exclusive double/single-tap gesture. Corrected the proof to change from `asset-a` to `asset-b`, reset only after that change, and assert the shipped `PhotoDetail` asset-change reset hook.
**Evidence**: `./scripts/proof/feat-029.sh` EXIT 0 — all state, accessibility, lifecycle, service-boundary, and `ASSET-CHANGE-RESET` checks PASS. `./init.sh` EXIT 0 — SwiftFormat PASS, SwiftLint strict 0 violations in 71 files, Simulator build `SUCCEEDED`, policy test `SKIP` per DEC-040. No test target, framework, or `*Test*.swift` file added; no service contract changed.
**Blockers**: none
**Next**: feat-030 remains user-gated and `todo`.

## 2026-09-18 — feat-030 activated

**State**: active
**Done**: User selected feat-030 after feat-029 reached `done`; activated the existing
approved feature record and execution plan. Baseline `./init.sh` passed format, strict
lint, and Simulator build; policy test step remains skipped under DEC-040.
**Evidence**: `feature_index.json` and `features/feat-030.md` now mark feat-030 active;
working tree was clean before activation.
**Blockers**: none
**Next**: inventory all user-facing strings, establish en/vi catalogs, and add the
persistent root language contract and S18 picker.

## 2026-09-18 — feat-030 completed

**State**: done
**Done**: Added English/Vietnamese String Catalogs and localized Info.plist resources;
added persistent `AppLanguage` selection for System Default, English, and Tiếng Việt;
propagated the selected locale at the SwiftUI root; and added the S18 Settings picker.
Refactored dynamic copy to native SwiftUI localization APIs, kept processing/session
models locale-independent with typed error codes, and did not add SwiftGen/R.swift or
`defaultValue` fallbacks.
**Evidence**: `scripts/proof/feat-030.sh` EXIT 0 — catalog completeness, Info.plist
coverage, placeholder parity, fallback, live System Default resolution, explicit
language contract, locale-aware number/date/interpolation formatting, persistence/root
locale hooks, and Settings picker checks PASS. `./init.sh` EXIT 0 — SwiftFormat PASS,
SwiftLint strict PASS with 0 violations, Simulator build `BUILD SUCCEEDED`, proof PASS,
and policy test `SKIP` under DEC-040. `git diff --check` PASS; no test target,
test framework, or `*Test*.swift` file added.
**Blockers**: none
**Next**: none — feat-030 is complete.

## 2026-09-18 — feat-030 review remediation

**State**: done
**Done**: Resolved PR review findings by using fully localized English/Vietnamese
accessibility state resources, restoring the singular review-summary resource,
giving analysis facts stable IDs for `ForEach`, and wiring the feat-030 proof into
the canonical `./init.sh` verification path.
**Evidence**: `./init.sh` EXIT 0 — SwiftFormat PASS, SwiftLint strict PASS with 0
violations, Simulator build `BUILD SUCCEEDED`, feat-030 proof PASS, and policy test
`SKIP` under DEC-040. The proof covers 385 en/vi entries, source-level accessibility,
singular-summary, and stable-identity contracts; `git diff --check` PASS.
**Blockers**: none
**Next**: none — feat-030 is complete.

## 2026-09-18 — feat-030 localization follow-up

**State**: done
**Done**: Audited the Vietnamese Home and Photo Analysis surfaces after runtime
  screenshots exposed English strings. Replaced presentation-time `String` values,
  concatenated copy, conditional labels, analysis fact labels/values, and selection
  reason text with native SwiftUI localization boundaries. Added the missing English
  and Vietnamese catalog entries while keeping proper names such as Photos Curator,
  Apple Photos, iPhone, and iCloud unchanged.
**Evidence**: `scripts/proof/feat-030.sh` EXIT 0 with 382 en/vi entries, placeholder
  parity, no `defaultValue`, and language-contract checks; `./init.sh` EXIT 0 with
  SwiftFormat PASS, SwiftLint strict PASS (0 violations), Simulator build
  `BUILD SUCCEEDED`, proof PASS, and policy test `SKIP` under DEC-040; `git diff --check`
  PASS. No test target, test framework, or `*Test*.swift` file added.
**Blockers**: none
**Next**: none — feat-030 is complete.

## 2026-09-18 — feat-031 Qwen planning

**State**: todo — plan only; implementation awaits approval.
**Done**: Created `feat/feat-031-qwen-curation` from `main` at `54389e5`.
Registered feat-031 and wrote `docs/plans/feat-031.md` with 11 ordered tasks,
Qwen2B/4B admission, pre-pruning grouping, model lifecycle, coverage audit,
session integration, automated quality metrics, and rollback.
**Evidence**: Fresh `./init.sh` EXIT 0 — format PASS, strict lint PASS,
Simulator build `BUILD SUCCEEDED`, localization proof PASS, policy test SKIP.
Feature/dependency JSON validation and 16 local links/anchors PASS;
`git diff --check` PASS. Only documentation and tracker files changed.
No model download, dependency installation, application implementation, or inference benchmark occurred.
**Blockers**: none for planning; model/runtime and image-corpus admission remain explicit implementation tasks.
**Next**: Review the plan and obtain user approval before activating feat-031.

## 2026-09-18 — feat-031 implementation started

**State**: active — implementation approved.
**Done**: Committed the planning artifacts as `600f413` (`docs(feat-031): add Qwen curation implementation plan`).
Activated feat-031 and retained the branch `feat/feat-031-qwen-curation`.
**Next**: Complete Task 1, then pin MLX Swift LM and verify actual Qwen image inference before wiring the selector.

## 2026-09-18 — feat-031 MLX runtime slice

**State**: active — Task 2 partial; Task 3 next.
**Done**: Pinned MLX Swift LM, Swift Hugging Face, and Swift Transformers revisions; added the Qwen3.5-2B artifact manifest with immutable revision, file sizes, and SHA-256 metadata; added local-only `QwenRuntime` loading, tokenizer adaptation, bounded generation, cancellation checks, and unload; updated `init.sh` for the Xcode MLX plugin-validation requirement.
**Evidence**: `./init.sh` EXIT 0 — SwiftFormat PASS, SwiftLint strict PASS with 0 violations, generic Simulator `BUILD SUCCEEDED`, feat-030 proof PASS, and policy test `SKIP`; `git diff --check` PASS. Runtime/package code has not yet loaded downloaded weights or run image-sensitive inference.
**Blockers**: Task 2 real-image inference, cancellation/teardown trace, and device build remain open; model weights are intentionally outside git and no installer exists yet.
**Next**: Commit this verified runtime slice, then implement revision-pinned, resumable, hash-verified model installation.

## 2026-09-18 — feat-031 model installer slice

**State**: active — Task 3 partial; AppContainer/runtime admission still open.
**Done**: Added `ModelInstallationService` with revision-derived artifact URLs, resumable bounded byte streaming, per-file staging and manifest verification, atomic revision activation, cancellation/state streams, backup exclusion, and removal. Added deterministic `feat-031` proof coverage using the shipped manifest/installer sources with an injected interrupted transport; no model weights or network are used by repository verification.
**Evidence**: `./scripts/proof/feat-031.sh` EXIT 0 — interrupted failure, resume via `Range`, hash/size verification, state stream, atomic activation, and removal PASS. `./init.sh` EXIT 0 — format, strict lint, Simulator build, feat-030 proof, feat-031 proof, and policy test skip PASS.
**Blockers**: AppContainer/UI wiring, live inference leases/resource admission, offline local Qwen load, cancellation/teardown trace, and real image-sensitive inference remain open.
**Next**: Commit the installer slice, then wire installation state into AppContainer and run the real 2B model feasibility gate.

## 2026-09-18 — feat-031 AppContainer wiring

**State**: active (Task 3 partial)
**Done**: Committed the verified installer as `7d9e3ce` (`feat(feat-031): add verified model installer`). Wired `ModelInstallationService` into `AppContainer.live()` under the application-support model root and updated the real-source feat-026 proof to inject the same dependency while excluding only the MLX runtime adapter from its standalone compiler boundary.
**Evidence**: `./scripts/proof/feat-026.sh` — `99 PASS / 0 FAIL`; `./init.sh` — format, strict lint, Simulator build, feat-030 proof, feat-031 installer proof, and policy test skip all PASS.
**Blockers**: Real downloaded local model load, image-sensitive inference, cancellation/teardown trace, resource admission, and UI availability state remain open.
**Next**: Run the 2B model feasibility gate with actual local weights before implementing the quality selector.

## 2026-09-18 — feat-031 artifact and runtime feasibility gate

**State**: active (Task 2 partial, Task 3 partial)
**Done**: Downloaded the pinned `mlx-community/Qwen3.5-2B-4bit` revision outside the repository. Corrected eight stale non-shard SHA-256 values plus the truncated model-shard digest in `ModelManifest` and `docs/evidence/feat-031-models.json`; every manifest file now matches its downloaded byte count and digest. A temporary Swift executable linked the shipped `QwenRuntime` against the pinned MLX checkouts and passed local manifest validation, model load, two-image generation in both orders, and unload on macOS/Metal.
**Evidence**: Runtime output: `MANIFEST-VALID PASS`, `LOCAL-LOAD PASS` (1.75 s / 1.41 s), image generation (8.56 s / 5.46 s), and `UNLOAD PASS`. The model descriptions changed with the swapped app-icon pixels, but both responses were fenced free-form arrays, not the required strict JSON object; this is runtime feasibility evidence, not production admission. `./init.sh` still needs to be rerun after the metadata correction.
**Blockers**: Strict response adapter, controlled corpus comparison, arm64-device build, cancellation/teardown trace, allocator/footprint record, offline network-disabled proof, and resource admission remain open.
**Next**: Implement strict bounded Qwen response validation and a reproducible inference proof, then rerun `./init.sh`.

## 2026-09-18 — feat-031 bounded Qwen response contract

**State**: active (Task 2 partial, Task 3 partial)
**Done**: Added `QwenPairResponseValidator` for the frozen three-key response shape and bounded `QwenRuntime` generation at 4 KiB before appending chunks. The validator rejects fenced output, arrays, unknown/missing/duplicate keys, invalid enums, duplicate reasons, and more than three reasons. Added the cases to the existing no-test-target feat-031 proof.
**Evidence**: `./scripts/proof/feat-031.sh` — installer cases and `RESPONSE-VALIDATION PASS`; `./init.sh` — format, strict lint, Simulator build, feat-030 proof, feat-031 proof, and policy test skip all PASS.
**Blockers**: The temporary real-model run still returns fenced free-form arrays; `QwenPairJudge` must route those responses through the validator and degrade to native evidence instead of admitting them.
**Next**: Implement the single-runtime `QwenPairJudge` and its generation-bound image lease after visual grouping contracts are ready.

## 2026-09-18 — feat-031 non-destructive quality grouping seam

**State**: active (Task 4 partial)
**Done**: Added `QualityGroupBuilder` and `QualityGroupSet`. The builder filters to analyzed assets, preserves stable candidate order, reuses existing coherent FeaturePrint duplicate clusters, and builds chronological coverage groups without choosing or dropping representatives.
**Evidence**: `./init.sh` — format, strict lint, Simulator build, feat-030 proof, feat-031 installer/response proofs, and policy test skip all PASS.
**Blockers**: No pixel encoder, controlled grouping corpus, Qwen judge integration, or quality-path selector consumes this seam yet.
**Next**: Add the quality runner/selector contract only after pixel-derived grouping evidence and the admitted Qwen response path are available.

## 2026-09-18 — feat-031 verified model availability discovery

**State**: active (Task 3 partial)
**Done**: Added `ModelInstallationService.installedModel()`, which locally revalidates the active revision after relaunch and publishes `.installed` without invoking the downloader. Removal clears the verified installation reference.
**Evidence**: `./scripts/proof/feat-031.sh` — interrupted transfer, resume/hash, atomic activation, `REOPEN-DISCOVERY PASS`, removal, and response validation all PASS. `./init.sh` — format, strict lint, Simulator build, feat-030 proof, feat-031 proofs, and policy test skip all PASS.
**Blockers**: UI setup state, inference leases, offline MLX runtime load through the app-owned installation, resource admission, and real cancellation/teardown remain open.
**Next**: Implement the generation-bound local Qwen pair judge after the quality grouping input contract is complete.

## 2026-09-19 — feat-031 accepted model lifecycle design

**State**: active (design recorded; implementation not started)
**Done**: Recorded the approved lifecycle in `features/feat-031.md` and `docs/plans/feat-031.md` §5.7.1. The design uses explicit `Download Model`, non-blocking download while the app is open, partial-file resume on a later launch, shared Settings/startup state, and visible `qualityNative` fallback when Qwen is unavailable.
**Evidence**: `./init.sh` PASS (SwiftFormat, strict SwiftLint, generic Simulator build, policy test skip); `git diff --check` PASS.
**Blockers**: Awaiting user review of the written feature/plan record before implementation. Pixel grouping, model/resource admission, and runtime lifecycle evidence remain open.
**Next**: Implement the accepted lifecycle after the written record is approved.

## 2026-09-19 — feat-031 lifecycle implementation and snapshot enforcement

**State**: active
**Done**: Wired `ModelInstallationModel` through startup, Settings, download alert, processing disclosure, review provenance, and en/vi localization. Added the model-availability snapshot to `SelectionRequest` so normal, in-memory retry/resume, and partial-result paths cannot enable Qwen after a native-fallback run starts. Fixed the Settings SwiftLint brace violation.
**Evidence**: `./init.sh` PASS: SwiftFormat, strict SwiftLint with 0 violations, generic Simulator `BUILD SUCCEEDED`, and `SKIP [test]` by DEC-040. Standalone lifecycle proof is not present, consistent with the repository no-proof-file rule.
**Blockers**: Pixel-derived grouping, subject-detail verification, controlled image-sensitive Qwen comparisons, resource admission, arm64-device/runtime measurements, full lifecycle state proof, and complete resume model-identity evidence remain open.
**Next**: Add lifecycle/resume evidence through the existing approved proof path, then complete the quality-admission gates before closing feat-031.

## 2026-09-19 — feat-031 persisted resume identity

**State**: active
**Done**: Persisted `modelAvailableAtStart` in `QualityCheckpointIdentity` and restored it when rebuilding a resumed `SelectionRequest`. New loading, background, analysis, completion, and partial-result checkpoints now carry the same availability snapshot; native and legacy quality identities remain decodable.
**Evidence**: `./init.sh` PASS with SwiftFormat, strict SwiftLint, generic Simulator `BUILD SUCCEEDED`, and `SKIP [test]` by DEC-040.
**Blockers**: Pixel-derived grouping, subject-detail verification, controlled image-sensitive Qwen comparisons, resource admission, arm64-device/runtime measurements, and full lifecycle state proof remain open.
**Next**: Add the approved lifecycle state evidence through the repository's existing verification path, then complete quality admission.

## 2026-09-19 — feat-031 deterministic selector and resume correction

**State**: active — Phase 2 deterministic selector slice reviewed GO.
**Done**: Quality-mode sizing now follows usable coverage-group count rather than the native percentage. The selector repairs usable zero-pick groups unless a selected duplicate representative covers them, records accountable group outcomes, resolves retake preference cycles by native stable rank, and updates duplicate representatives after a comparison swap. Resume now restores the checkpoint's frozen requested mode instead of synthesizing `qualityQwen2B`; quality provenance uses config version 2.
**Evidence**: Oracle re-review returned GO with no actionable findings. `./init.sh` PASS on 2026-09-19: SwiftFormat PASS, strict SwiftLint PASS with 0 violations, generic iOS Simulator `BUILD SUCCEEDED`, and policy test `SKIP` under DEC-040. `git diff --check` PASS.
**Boundaries**: This establishes deterministic source-level selector and checkpoint behavior only. It does not establish image-quality improvement, actual Qwen image sensitivity, physical-device performance, model/resource admission, or full cancellation-drain evidence.
**Next**: Advance to the next Phase 2 gate: resource admission and lifecycle/failure-state evidence, while keeping pixel-quality and hardware claims explicitly open.

## 2026-09-19 — feat-031 resource admission and lifecycle safety

**State**: active — resource/lifecycle slice safe to hand off; feature gates remain open.
**Done**: Added actor-owned inference lease waiting for model removal, cancellation-safe deletion checks, lease admission exclusion during removal, and lease retention when Qwen unload is not confirmed. Added fail-closed iOS available-memory admission against the 2B soft ceiling plus reserve. Scheduler cancellation now exits the request loop, and native fallback discards applied Qwen evidence while preserving non-applied comparison counts.
**Evidence**: `./init.sh` PASS on 2026-09-19: SwiftFormat, strict SwiftLint with 0 violations, generic iOS Simulator `BUILD SUCCEEDED`, and `SKIP [test]` under DEC-040. Oracle code-only review marked the slice safe to hand off with no remaining code findings. `git diff --check` PASS.
**Blockers**: No physical-device memory or thermal evidence, no fault-injected removal/unload/cancellation run, no pixel-derived grouping or subject-detail evidence, no independent image-quality comparison, and no admitted 2B/4B profile. Acceptance gates A1, A2, A4, A5, and A6 remain open.
**Next**: Add the approved lifecycle/drain evidence through the existing verification path, then complete pixel-quality and Qwen profile admission without claiming Simulator evidence as hardware or quality evidence.

## 2026-09-19 — feat-031 model download transport optimization

**State**: active
**Done**: Replaced the per-byte `URLSession.AsyncBytes` relay with `URLSessionDataDelegate` `Data` chunks. The installer now buffers writes in 256 KiB blocks, limits progress publication to about 4 Hz, and keeps Range resume, cancellation, staging, and SHA-256 validation unchanged.
**Evidence**: `./init.sh` PASS with SwiftFormat, strict SwiftLint, generic Simulator `BUILD SUCCEEDED`, and `SKIP [test]` under DEC-040. `git diff --check` PASS. Inline 16 MiB benchmark reached 8.7 MB/s after the change versus 1.1 MB/s for the prior per-byte pipeline on the same host; this is host/network evidence only.
**Blockers**: No physical-device throughput or thermal measurement. Pixel-derived grouping, independent image-quality comparison, and model admission remain open.
**Next**: Measure the installer on a target iPhone, then continue the remaining feat-031 quality-admission gates.

## 2026-09-19 — feat-031 direct-file download transport

**State**: active
**Done**: Replaced the chunk relay with `ModelDownloadDelegate` direct writes to the resumable partial file. The delegate buffers 256 KiB, handles `206` append and `200` restart responses, throttles progress callbacks, and preserves cancellation, staging, size, and SHA-256 validation.
**Evidence**: `./init.sh` PASS with SwiftFormat, strict SwiftLint at 0 violations, generic Simulator `BUILD SUCCEEDED`, and `SKIP [test]` under DEC-040. `git diff --check` PASS. The previous 8.7 MB/s benchmark belongs to the chunked relay; the direct-file path still needs a fresh speed measurement.
**Blockers**: No direct-file throughput benchmark, physical-device throughput or thermal measurement. Pixel-derived grouping, independent image-quality comparison, and model admission remain open.
**Next**: Run the direct-file benchmark, then continue the remaining feat-031 quality-admission gates.

## 2026-09-21 — feat-031 pivot handoff

**State**: blocked
**Done**: Preserved feat-031's incomplete acceptance and evidence while pausing the Qwen quality-mode lane for the assisted review pivot.
**Evidence**: Prior baseline `./init.sh` PASS on 2026-09-21 before these edits; no current post-edit init result is claimed.
**Blockers**: Qwen image-sensitive admission, device/resource evidence, and remaining lifecycle/review gates are incomplete; do not claim production quality improvement.
**Next**: feat-032 contracts/docs/tracker.

## 2026-09-21 — feat-032 contracts/docs/tracker

**State**: active
**Done**: Replaced the owned product, UX, architecture, data, intelligence, runtime, Apple-framework, privacy, performance, and roadmap source docs; added review-rules, ui-copy, and photo-intelligence; added the ordered feat-032–037 records and moved feat-031 to blocked.
**Evidence**: Prior baseline `./init.sh` PASS on 2026-09-21 before these edits; assigned documentation checks are pending and no current post-edit init result is claimed.
**Blockers**: Parent-owned `./init.sh` verification remains pending.
**Next**: Run parent verification, then hand off feat-033 only after feat-032 acceptance.

## 2026-09-21 — feat-032 completion

**State**: done
**Done**: Closed the Phase 1 pivot contracts/docs/tracker feature after DEC-054 remediation and Gate 1 Oracle re-review GO. Acceptance is complete; feat-031 remains blocked with incomplete Qwen evidence preserved.
**Evidence**: Fresh `./init.sh` PASS on 2026-09-21 after final DEC-054 remediation; `git diff --check` PASS; feature-index JSON/status validation PASS. No source or runtime behavior changed.
**Blockers**: none for feat-032.
**Next**: Activate feat-033 as the sole active feature.

## 2026-09-21 — feat-033 activation

**State**: active
**Done**: Activated the durable workspace and idempotent legacy migration feature after feat-032 closure; dependency and single-active-feature rules hold.
**Evidence**: feat-032 Gate 1 Oracle re-review GO; fresh parent `./init.sh` evidence recorded above; feature-index JSON has exactly one active feature.
**Blockers**: none recorded; implementation verification belongs to feat-033.
**Next**: Implement and verify `ReviewScope`/workspace-item state, migration marker/store infrastructure, and the legacy importer under the linked feat-033 plan.

## 2026-09-21 — feat-033 completion

**State**: done
**Done**: Added the concrete SwiftData workspace models/store and one-way legacy importer. Startup creates one durable container, imports legacy selected/restored and rejected/removed state into album membership while leaving cleanup undecided and progress unseen, and commits an idempotent marker only after successful persistence. Existing checkpoint/cache ownership and review routes remain unchanged; legacy files are retained.
**Evidence**: `./init.sh` PASS (SwiftFormat, strict SwiftLint with 0 violations, generic Simulator `BUILD SUCCEEDED`, `SKIP [test]` by DEC-040); `git diff --check` PASS.
**Blockers**: none for feat-033.
**Next**: Activate feat-034 only after user approval; feat-035/036 remain owners of future album-save/deletion operation schemas.

## 2026-09-21 — feat-033 docs-only stop

**State**: blocked — Gate 2 attempt 1 remains BLOCKED; this is the requested
docs-only stopping point.
**Done**: Reconciled the partial feat-033 handoff, tracker status, current
pivot-plan routes, and product safety summary. No code remediation was
performed.
**Evidence**: Prior initial feat-033 format/lint/`./init.sh` and
`git diff --check` results remain partial evidence only. No final `./init.sh`
result is claimed after this docs-only update.
**Blockers**: Present but unreadable checkpoint/result/feedback artifacts can be
silently skipped before the global migration marker is committed; workspace
`ModelContainer` open failure uses `preconditionFailure`. Changed source paths
and required remediations are recorded in `features/feat-033.md`.
**Next**: Remediate those two exact Gate 2 findings in the listed source paths,
then run Gate 2 re-review and the parent-owned `./init.sh`.

## 2026-09-21 — feat-033 remaining acceptance handoff

**State**: blocked — Gate 2 attempt 1 remains BLOCKED.
**Done**: Clarified the remaining feat-033 acceptance work separately from the
two Gate 2 safety blockers; no source remediation was performed.
**Evidence**: `features/feat-033.md` records the exact partial source paths,
prior verification, and current plan handoff. No final `./init.sh` is claimed.
**Blockers**: The two Gate 2 safety blockers remain: unreadable present
checkpoint/result/feedback artifacts can be skipped before marker commit, and
workspace `ModelContainer` open failure uses `preconditionFailure`.
**Next**: Add general `WorkspaceStore` scope create/list/load APIs and
independent per-dimension update APIs, then remediate both Gate 2 blockers,
run Gate 2 re-review, and run the parent-owned `./init.sh`.

## 2026-09-21 — feat-033 activation

**State**: active — user approved the existing feat-033 design; feat-034 remains
todo.
**Done**: Activated the existing partial implementation with no new
implementation result yet.
**Evidence**: Established baseline `./init.sh` PASS remains the prior feat-033
evidence; no new verification was run.
**Scope**: Three accepted remediation lanes — general `WorkspaceStore` scope
create/list/load plus independent per-dimension updates; explicit decode status
that blocks the migration marker and records recoverable artifact failure; and
a non-crashing workspace-unavailable composition state that preserves legacy
flow/files and skips migration.
**Next**: Implement those three lanes, then run Gate 2 re-review and the
parent-owned `./init.sh`.

## 2026-09-21 — feat-033 completed

**State**: done — Gate 2 final attempt 3 GO; feat-034 remains `todo`.
**Done**: Closed feat-033 documentation/tracker state after the accepted
implementation: safe present-artifact status and migration-marker gating;
unavailable-workspace fallback preserving legacy flow; general scope/item APIs
with independent dimension updates; stable log categories; atomic scope
timestamp updates. No UI routes or feat-035/036 operation schemas were added.
**Evidence**: Latest source fixer `./init.sh` PASS (format, strict lint,
generic Simulator build; tests skipped under DEC-040); `git diff --check` PASS;
Oracle Gate 2 final attempt 3 GO after attempt 1/2 blockers were remediated.
**Blockers**: none.
**Next**: Obtain user approval before activating feat-034, as required by
`AGENTS.md`; feat-034 remains dependent on completed feat-033.

## 2026-09-21 — feat-034 shared grouped review

**State**: active
**Done**: Built the shared photo-first workspace for both intents: Home dual
entry with intent handoff, `.reviewWorkspace` route, durable scope/item
binding at review entry with dimension-scoped persistence and explicit retry,
canonical action transitions, native-only advisory suggestion contract with
preview/apply, shared grid/filter/group/compare/Needs Review shell, and owner
en/vi catalog coverage.
**Evidence**: `./init.sh` PASS (SwiftFormat, strict SwiftLint 0 violations,
generic Simulator `BUILD SUCCEEDED`, `SKIP [test]` by DEC-040);
`git diff --check` PASS. No test targets, test files, or proof harness.
**Blockers**: none for feat-034 scope; album-save/deletion operations remain
with feat-035/036.
**Next**: Review acceptance, then close feat-034 and hand off feat-035 after
approval.

## 2026-09-22 — feat-034 review fix wave

**State**: active
**Done**: Fixed 19 true-positive reviewer findings (user scope: feat-034 plus
touched feat-027/031 code; #1/#10/#11/#12/#23 left untouched as verified
false-positives): progress unseen-gating via session overlay, detail-only
markOpened, readable staged filter, replayable scoped retry payload, legacy
feedback seeding, per-session intent + persisted refresh, scope delete,
drag-start guard, localized live-state suggestion preview with no-op guard
and revision recompute, truthful quality versions, per-request scheduler
cancel, and l10n fixes (fallback key, byte-progress, bundle name).
**Evidence**: `./init.sh` PASS (SwiftFormat, strict SwiftLint 0 violations,
generic Simulator `BUILD SUCCEEDED`, `SKIP [test]` by DEC-040);
`git diff --check` PASS. No test targets, test files, or proof harness.
**Blockers**: none for feat-034 scope; album-save/deletion operations remain
with feat-035/036.
**Next**: Review acceptance, then close feat-034 and hand off feat-035 after
approval.

## 2026-09-22 — feat-034 self-review follow-up (PR #66)

**State**: active
**Done**: Fixed all 9 PR #66 findings plus 7 nits: tray no longer
bulk-applies album/cleanup over displayIDs (`Continue to Save` routes to
finalReview, `Mark All Reviewed` is the one progress action); staged
`Back to All Photos` resets the filter; retry re-issues the full failed
payload with superset-ID clear; preview drops already-matching rows and
staleness recomputes from live facts; legacy deltas apply to existing rows;
progress defaults to unseen; cancelled request IDs evict on settle; named
version constants; selection state is `private(set)`; reuse path refreshes
per-session intent; 4 new strings catalogued en/vi.
**Evidence**: `./init.sh` PASS (SwiftFormat, strict SwiftLint 0 violations,
generic Simulator `BUILD SUCCEEDED`, `SKIP [test]` by DEC-040);
`git diff --check` PASS. No test targets, test files, or proof harness.
**Blockers**: none.
**Next**: Re-request review on PR #66.

## 2026-09-22 — feat-034 closed (done)

**State**: done
**Done**: Acceptance holds: one grouped workspace serves both intents;
filters, group cards, compare, Needs Review, and tray preserve independent
dimensions; choices survive resume/navigation; suggestions stay advisory;
suggestion contract plus native adapter owned without feat-037; en/vi and
recoverable states match owner docs. `./init.sh` PASS, `git diff --check`
PASS, no test targets/files (DEC-040).
**Blockers**: none.
**Next**: Merge PR #66 (`tungxuan1656/feat-034-integration` → `main`);
feat-035 stays `todo` until the user opens it.

## 2026-09-22 — feat-035 album draft + resilient save

**State**: done
**Done**: Durable `AlbumSaveOperation` + explicit SwiftData schema migration
(feat-035 owner; feat-033 untouched), independent `AlbumSaveService` (only
album mutator; digest-gated resume, per-ID outcomes, explicit-only retry, no
automatic retry, no deletion API), S14/S15/S16 + Home resume wiring with
truthful partial/interrupted/limited-access states, owner en/vi copy (5 new
entries), session cleanup retiring operation rows; workspace/cleanup/progress
never cleared by save.
**Evidence**: `./init.sh` PASS (SwiftFormat PASS, `swiftlint --strict` 0
violations, generic Simulator `BUILD SUCCEEDED`, `SKIP [test]` by DEC-040);
`git diff --check` PASS. No test targets, test files, or proof harness.
**Blockers**: none.
**Next**: feat-036 (confirmed original deletion) after user approval; it owns
its separate operation schema and must not share the album-save mutator.
