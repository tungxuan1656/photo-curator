# AGENTS.md

photos-curator is an iPhone app that turns a large photo set (100–2,000) into a smaller quality-adaptive curated album (size adapts to usable-quality moment count; ~10% with 30–40..120–150 clamps are default starts per 03). Flow is Select→Analyze→Review→Save to an Apple Photos album; processing is on-device only and never deletes originals.

Detected stack: `Swift 5 / SwiftUI, PhotoKit, Vision, Core ML — Xcode project apps/photo-curator.xcodeproj (scheme photo-curator); SwiftLint + SwiftFormat; fastlane present but stale (ignore)`

Product docs: start at `docs/index.md` for task routes and the doc ownership table.

## Assess the task

Before creating or updating feature, plan, or progress artifacts, assess the task's project scale, complexity, and impact. Use no feature for lightweight work, an inline feature plan for bounded tracked work, and a separate linked plan only for substantial work.

For work that does not need a feature, read only the relevant sources and run proportional verification without updating feature or progress state.

## Start feature work

1. Run `./init.sh`.
2. Read `feature_index.json`.
3. Read the selected feature file in `features/`.
4. Read the latest relevant block in `progress.md`.
5. Load only the documents linked by the selected feature.

If baseline verification fails, record the failure. Fix it only when the current scope includes it.

## Working rules

- An integration feature owns the merge order and shared contracts. Keep at most one
  integration feature `active` at a time. It can admit at most four active mini-features.
  A mini-feature has one parent, an exclusive seam, and an explicit merge gate. Zero
  active integration features means the repository is idle.
- Use only `todo`, `active`, `blocked`, or `done` as feature status.
- Start `todo` work only after the user selects or approves it.
- Keep feature work inside the active parent feature's scope and acceptance criteria.
- Complete every dependency before activating its dependent integration feature. A
  detached mini-feature may run before its parent only when its record says so and it
  does not read or change a shared contract.
- A mini-feature must declare `parent`, `seam`, `exclusive_owns`, and `merge_gate`.
  It must not edit parent-owned contracts, pipeline wiring, cache/version policy, or
  another mini-feature's files. The integration owner makes those changes after review.
- Record scope, acceptance, evidence, and handoff in the feature file.
- Record a feature result in `progress.md` only when the result, blocker, handoff, or next action materially changes. Do not copy feature scope there.
- Update `init.sh` when verification commands or workspace modules change.
- Do not create automated tests for this project: no test targets, no `*Test*.swift` files, no test frameworks or test-only architecture. Validation is manual only; `./init.sh` reports `SKIP [test]` by policy.

## Plans

- Keep a readiness plan inside every `features/feat-<id>.md`. A mini-feature uses an
  inline plan and the `features/mini-feat-template.md` admission card.
- Before activating an integration feature, create `docs/plans/feat-<id>.md` when it
  changes a shared contract, has >=4 files or >=2 workspaces, needs rollback/phases,
  or has two or more independent risk signals. Link it from the feature file.
- The active integration feature records the exact child files and merge order before
  admitting a mini-feature. Reserved mini-feature definitions in a parent plan are
  not active work and do not require an index record yet.
- Use the active feature's owns list before work starts.

## Escalation

- Read the relevant project document before making an architecture or product decision.
- Ask the user when requirements, scope, ownership, or a repeated verification failure remain unclear.

## Feature done

A feature is done only when:

- [ ] Every acceptance criterion passes.
- [ ] Every admitted mini-feature is merged or explicitly rejected with evidence.
- [ ] `./init.sh` passes.
- [ ] The feature file records verification evidence.
- [ ] `progress.md` records the result and next action.

## End feature session

1. Update the feature status and handoff.
2. When state materially changed, add a new block below the final template note in `progress.md`; do not edit older blocks.
3. Record blockers and one next action when they exist.

## Verification

- Full: `./init.sh`

<!-- harness-slim 1.4.0 · generated 2026-09-10 · managed sections above; check drift with skill CHANGELOG.md -->
