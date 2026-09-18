# feat-029 — Immersive photo inspection

## Status

- Status: `done`
- Depends on: `feat-028` (done/merged)

## Goal

Make every review thumbnail open a fullscreen S11 inspector where users can see a photo at useful size, zoom into details, and safely keep or remove it.

## Contract boundary

This feature owns S11 presentation, inspection gestures, bounded preview lifetime, and automated interaction evidence. It preserves the existing scoped pager order, `ReviewModel` selection source of truth, and PhotoKit service boundary. The accepted UX contract is in `docs/product-specs/ux-flows.md`; execution detail is in [`docs/plans/feat-029.md`](../docs/plans/feat-029.md).

## Acceptance

- [x] S11 is fullscreen and exposes Back, position, explicit In Album/Removed state, previous/next, and View Analysis over any image.
- [x] Pinch and double-tap provide bounded zoom up to 6×; zoomed drags pan within bounds, and Fit restores centering.
- [x] At Fit, horizontal swipe pages only inside the entry context. At zoom, the same drag pans and never pages.
- [x] Back and a deliberate downward swipe at Fit dismiss only S11 and return to the originating photo list; a downward drag while zoomed pans instead.
- [x] Paging resets the transform, keeps first/last boundaries non-wrapping, and preserves selection edits through S21 and the source grid.
- [x] The inspector retains only the current bounded preview, cancels superseded loads, and presents retry/back for unavailable assets without treating cancellation as failure.
- [x] S11 chrome is photo-first and visually polished: compact material islands, clear action hierarchy, responsive press feedback, and smooth chrome/image transitions that respect Reduce Motion.
- [x] Back responds without a tap-delay; inspection gestures are scoped to the image surface and do not arbitrate with chrome buttons.
- [x] Reproducible interaction/accessibility evidence and `./init.sh` pass. No test target, `*Test*.swift` file, test framework, original-pixel persistence, or manual-QA gate is added.

## Relevant docs

- `docs/plans/feat-029.md`
- `docs/product-specs/ux-flows.md`
- `docs/design-docs/apple-frameworks.md`
- `docs/ship-gates/performance.md`
- `docs/ship-gates/privacy.md`

## Verify

- `./scripts/proof/feat-029.sh`
- `./init.sh`

## Handoff

- State: done
- Evidence: `./scripts/proof/feat-029.sh` EXIT 0 — zoom, Fit-page, swipe-down dismissal, zoom-pan, accessibility controls, current-only lifecycle, and service-boundary checks PASS. `./init.sh` EXIT 0 — SwiftFormat PASS, SwiftLint strict 0 violations in 70 files, Simulator build `SUCCEEDED`, policy test `SKIP` per DEC-040. Simulator install/launch PASS on `iPhone 17 Pro` (`com.tungxuan.photo-curator: 30051`); CUA smoke reached S11, exposed Back/Analysis/Previous/Next controls individually, exposed Fit after zoom, and returned to Selection from Back. `git diff --check` and no-test-artifact checks pass.
- Next: feat-030 remains user-gated and `todo`.
