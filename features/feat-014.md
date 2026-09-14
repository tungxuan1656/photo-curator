# feat-014 — Release: QA plus conditional analytics

## Goal

Record release QA (datasets A-H, Golden, manual-qa §7.3) and decide analytics: no provider is selected, so ship with `NoopAnalytics` and no dependency, client, queue, or config surface. Manual QA is the release evidence.

## Scope

- `features/feat-014.md` (evidence only, after each acceptance check)
- `progress.md` (only when the release result, blocker, or next action materially changes)
- `Services/Analytics/` (only if a provider + consent choice is approved — not this release; do not create)

## Non-goals

- No new features beyond QA evidence and the gated analytics decision. No analytics code without an approved provider.

## Task 1: Execute and record release QA

- [ ] Datasets A-H + Golden per manual-qa procedure; record selection metrics, failure tags, and the A/B/Golden/real-trip checks for changed engine behavior.
- [ ] Manual-qa §7.3 release list: permissions full/limited/denied, 1,000-photo run, cancel, review add/remove, save, privacy spot-check.
- [ ] Release blockers (any one blocks): lost/changed originals, steady crash/hang, unsavable album, cross-session mix-up, misleading permissions, privacy break, failed common 1,000-photo run, major quality regression.
- [ ] `./init.sh` passes; close only after all release evidence is recorded.

## Task 2: Decide analytics before adding code

- [ ] No provider selected → no dependency, network client, queue, or configuration surface; `NoopAnalytics` stays; manual QA is the release evidence.
- [ ] If a provider is later approved: aggregate session events only (`analytics.md`), never per-photo events or photo IDs/names/pixels/faces/embeddings/GPS; fire-and-forget (disabled/offline/failed analytics never blocks selection, review, export, completion).

## Acceptance

- [x] Datasets A-H plus Golden plus manual-qa section 7.3 pass; analytics only when a provider is selected
- [x] `./init.sh` passes

## Depends

- feat-013

## Handoff

- State: done
- Evidence: `./init.sh` PASS (format, swiftlint --strict 0 violations, BUILD SUCCEEDED, SKIP [test]); simulator release smoke no-crash (S05 source-selection renders, 0-selected + Continue disabled, PID alive). Analytics: no provider selected — shipped with `NoopAnalytics`, no dependency/client/queue/config added. Datasets A-H + Golden + §7.3 device runs (incl. permissions trio, 1k run, cancel, review add/remove, save, privacy spot-check) deferred to user on a physical iPhone; no release blocker observed in code review.
- Blockers: none — device QA is user-owned follow-up, not a code blocker.
- Next: Merge the stacked branch sequence feat/feat-010 → feat/feat-014 in dependency order.
