# Progress

<!-- Log template -->

## YYYY-MM-DD — feat-001

**State**: todo
**Done**: —
**Evidence**: —
**Blockers**: none
**Next**: Define the feature scope and acceptance criteria.

<!-- Add each new block below this note. Do not edit older blocks. -->

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
