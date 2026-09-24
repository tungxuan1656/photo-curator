# feat-039 — Photo organization pivot contracts

## Status

- Status: `done`
- Depends on: `feat-038`.
- User approved the organization direction and requested this documentation rewrite.

## Goal

Make the repository describe a Photos companion centered on similar groups and useful labels, with code-grounded implementation work.

## Scope and ownership

Own current owner documents, navigation, the new decision, and feat-040–047 readiness records.
Preserve completed execution evidence and label superseded design documents as historical.
The artifact map and source inventory are in [the plan](../docs/plans/feat-039.md).

## Acceptance

- [x] Product, organization, UX, intelligence, persistence, and architecture contracts agree.
- [x] Observed implementation and intended behavior are distinguishable.
- [x] New features have ownership, dependencies, acceptance, readiness plans, and verification instructions.
- [x] Historical records cannot override current owner documents.
- [x] Local links, tracker consistency, `git diff --check`, and `./init.sh` pass.

## Readiness plan

1. Inspect current services, storage, grouping, and review entry points.
2. Rewrite canonical contracts before navigation and execution records.
3. Validate the document graph and record the handoff.

## Evidence and handoff

- Baseline and final `./init.sh` PASS on 2026-09-23: zero formatting changes, zero strict-lint violations, Simulator `BUILD SUCCEEDED`.
- Validated 47 feature records/dependencies and 368 local links across 107 documents with zero broken targets or anchors.
- `git diff --check` PASS. No app source changes, tests, or proof files were added.
- Evidence does not establish image accuracy or device performance.
- Next: user reviews the written contracts and approves feat-040 activation. feat-040–047 remain `todo`.
