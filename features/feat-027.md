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
2. Implement the isolated provider/policy/adapter and proof harness with no persistence or telemetry.
3. Integrate only validated same-cluster choices, then record iOS 26 and failure-path evidence.

## Verify

- Reproducible automated evidence for every behavior change (Simulator permitted): Golden-shaped jury evidence on the iOS 27 seam plus deterministic fallback evidence on the iOS 26 path; record commands, fixtures, and outputs in the handoff.
- `./init.sh`
- Manual QA is not required and is never an acceptance criterion, blocker, or release gate (DEC-040). No test targets, no `*Test*.swift`, no test frameworks.

## Handoff

- State: done (review fixes implemented and verified; parent PR not yet opened)
- Evidence: `scripts/proof/feat-027.sh` EXIT 0 — `STAGED-MATCH 26` compiles real shipped jury, request factory/image lease seam, `SelectionEngine`, and `SelectionSessionCoordinator`; request-factory ordering, iOS 26 `providerCalls=0 imageLoads=0`, iOS 27 coordinator image-backed requests, same-cluster-only swaps, unrelated selected-ID preservation, generic provider failure, strict schema, safe choices, bounds, unavailable, cancellation, non-cooperative timeout elapsed 2,073 ms under the 2.75 s proof bound with image leases released, and Golden-shaped deterministic cap all PASS; `RESULT PASS`. The current iOS 26.5 SDK compile exercises the typed-unavailable adapter seam; the real `Attachment(CGImage)` branch is selected only by the iOS 27 SDK capability condition.
- `./init.sh` EXIT 0 — format PASS, SwiftLint strict 0 violations, Simulator build SUCCEEDED, test SKIP per DEC-040. `git diff --check` PASS; no `*Test*.swift` files; no test target/framework.
- Decisions: DEC-047 bounded iOS 27 semantic jury; DEC-048 image-backed in-place integration and hard timeout; DEC-049 explicit SDK capability seam for Foundation Models `Attachment`; engine version remains 3 and no persistence/schema migration is introduced.
- Blockers: none
- Next: parent PR `tungxuan1656/feat-027-integration` → main (squash in a separate merge task).
