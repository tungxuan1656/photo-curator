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

- Keep at most one feature `active` at a time. Finish that feature before starting its
  dependent feature. The active feature owns its full implementation and verification.
- Use only `todo`, `active`, `blocked`, or `done` as feature status.
- Start `todo` work only after the user selects or approves it.
- Keep feature work inside the active parent feature's scope and acceptance criteria.
- Complete every dependency before activating its dependent feature.
- Record scope, acceptance, evidence, and handoff in the feature file.
- Record a feature result in `progress.md` only when the result, blocker, handoff, or next action materially changes. Do not copy feature scope there.
- Update `init.sh` when verification commands or workspace modules change.
- Do not create automated tests for this project: no test targets, no `*Test*.swift` files, no test frameworks or test-only architecture. Every behavior-changing feature MUST provide reproducible automated evidence (Simulator-based proof permitted) and `./init.sh` MUST pass (it reports `SKIP [test]` by policy). Manual QA is not required and is never an acceptance criterion, blocker, or release gate (DEC-040).

## Plans

- Keep a readiness plan inside every `features/feat-<id>.md`. Create
  `docs/plans/feat-<id>.md` when the feature
  changes a shared contract, has >=4 files or >=2 workspaces, needs rollback/phases,
  or has two or more independent risk signals. Link it from the feature file.
- Use the selected feature's scope and ownership section before work starts.

## Escalation

- Read the relevant project document before making an architecture or product decision.
- Ask the user when requirements, scope, ownership, or a repeated verification failure remain unclear.

## Feature done

A feature is done only when:

- [ ] Every acceptance criterion passes.
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
