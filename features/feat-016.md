# feat-016 — Per-photo analysis transparency

## Goal

Let people compare every reviewed photo by its local Technical score and see
the saved analysis and original decision for one photo.

## Scope

- Update S10, S12, S13, S11, and new S21 behavior in `ux-flows.md`.
- Load saved analysis lazily through `ReviewModel`.
- Add the reusable score badge and the S21 analysis detail screen.
- Add the score badge to every Review grid and link S11 to S21.

## Non-goals

- No selection-rule, threshold, ranking, cache-shape, or pipeline change.
- No face boxes, identity, location, embeddings, full EXIF, or remote data.
- No score sorting, filtering, or scoring controls.

## Acceptance

- [ ] S10, S12, and S13 show a numeric Technical score and meter for every visible analyzed photo. (S10/S13 verified 2026-09-16; S12 pending similar-groups fixture.)
- [x] S21 shows available saved signals, original decision reasons, and current Selected or Removed state.
- [ ] Missing analysis is explicit and does not block review or restart processing. (Pending missing-cache-row fixture.)
- [x] Scores load only for visible review cells and no pixels enter persistent state.
- [x] `./init.sh` passes. (2026-09-16.)

## Relevant docs

- `docs/product-specs/ux-flows.md` (§2, §8, §13, §15)
- `docs/product-specs/selection-rules.md` (§1, §9, §16)
- `docs/ship-gates/privacy.md` (§2–§6)

## Plan

Plan: `docs/plans/feat-016.md`

## Handoff

- State: active
- Done: S10/S12/S13 use a lazy, accessible Technical score footer; S11 opens
  S21, which shows saved signals, original selection reasons, and current
  inclusion state. Thumbnail navigation is direct because the root stack holds
  `AppRoute` values, not `AssetID` values.
- Evidence: `./init.sh` passed on 2026-09-16 after the implementation
  (SwiftFormat 0/57 changed, SwiftLint strict 0 violations/57 files, iOS
  Simulator build succeeded). The current app installed and launched in the
  iPhone 17 Pro Simulator without a crash (PID 74689). S10 rendered 84/100,
  83/100, and 77/100; its thumbnail opened S11, and **View Analysis** opened
  S21 with the saved Technical, People, Composition, Content, and Selection
  result values. A temporary S13 removal displayed 84/100, opened S11, and
  was restored to the observed **Nothing removed** state.
- Blocker: the simulator result has no similar groups and no intentionally
  missing cache row, so S12 and the explicit analysis-unavailable state need
  a representative fixture for final manual validation.
- Next: run those two fixture-dependent manual cases, then close feat-016.
