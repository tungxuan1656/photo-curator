# feat-027 — Semantic jury

## Status

- Status: `done`
- Depends on: `feat-026`

## Goal

Use the iOS 27 semantic jury only behind an availability gate and validate every decision
against a small, recoverable schema; iOS 26 remains deterministic.

## Contract boundary

The feature owns the iOS gate, provider protocol, bounded request policy, exact response schema, deterministic fallback, privacy-safe diagnostics, and validated selection integration. The readiness and rollback plan is `docs/plans/feat-027.md`.

## Acceptance

- [x] iOS 27 jury work is opt-in and bounded to the approved ambiguity cases.
- [x] The schema accepts only `chooseA`, `chooseB`, `keepBoth`, or `abstain`.
- [x] Invalid, unavailable, timed-out, or iOS 26 requests use deterministic fallback.
- [x] Golden-shaped automated evidence explains jury and fallback outcomes (Simulator permitted).

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/product-specs/ux-flows.md`

## Inline plan

1. Lock availability, schema, ambiguity admission, request bounds, and deterministic fallback in `docs/plans/feat-027.md` and DEC-047.
2. Implement the isolated provider/policy/adapter with no persistence or telemetry.
3. Integrate only validated same-cluster choices, then record iOS 26 and failure-path evidence.

## Verify

- `./init.sh`
- Manual QA is not required and is never an acceptance criterion, blocker, or release gate (DEC-040). No test targets, no `*Test*.swift`, no test frameworks.

## Handoff

- State: done/merged — PR #57 (`https://github.com/tungxuan1656/photo-curator/pull/57`) is merged into `main` at `2e57ecbfa65eb12fff51d0c6af96d9da69b5fd85`, confirmed on `origin/main`; `feature_index.json` confirms `feat-027` status `done`.
- Evidence: all acceptance criteria are checked. `./init.sh` EXIT 0 — SwiftFormat PASS, SwiftLint strict 0 violations, Simulator build SUCCEEDED, test SKIP per DEC-040; `git diff --check` PASS; no standalone proof files, `*Test*.swift` files, test target, or test framework. Manual QA remains removed and non-gating per DEC-040.
- Decisions: DEC-047 bounded iOS 27 semantic jury; DEC-048 image-backed in-place integration and hard timeout; DEC-049 explicit SDK capability seam for Foundation Models `Attachment`; engine version remains 3, with no persistence/schema, contract, or data-model change.
- Blockers: none
- Next: feat-028 (Ranker decision gate), activated from the latest `origin/main` after this closeout.
