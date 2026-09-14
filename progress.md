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
