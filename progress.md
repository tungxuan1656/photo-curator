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
