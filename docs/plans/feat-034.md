# feat-034 — Shared grouped review plan

## Scope and dependency

After feat-033, build one review workspace for **Clean Up Photos** and
**Build an Album**. The feature owns review navigation, grouped presentation,
compare/Needs Review actions, and state binding; persistence and album/deletion
side effects remain in their owner features. See
[ux-flows.md](../product-specs/ux-flows.md), [ui-copy.md](../product-specs/ui-copy.md),
and [review-rules.md](../product-specs/review-rules.md).

## Anticipated code areas

Existing areas to reshape: `apps/photo-curator/App/AppModel.swift`,
`App/AppRoute.swift`, `App/RootView.swift`, `Features/Onboarding/HomeView.swift`,
`Features/Review/ReviewModel.swift`, `Features/Review/ReviewOverview.swift`,
`Features/Review/CuratedGrid.swift`, `Features/Review/SimilarGroups.swift`,
`Features/Review/NeedsReview.swift`, `Features/Review/PhotoDetail.swift`,
`Features/Review/RemovedPhotos.swift`, `Features/Review/FinalReview.swift`,
`Features/Processing/ProcessingModel.swift`,
`Features/Processing/ProcessingView.swift`,
`SharedUI/SelectionToggle.swift`, `SharedUI/AsyncPhotoThumbnail.swift`, and
`Localizable.xcstrings`.

Anticipated new areas: `Features/Review/ReviewWorkspace.swift` and, if
needed, `Features/Review/ReviewFilter.swift` for shared shell and typed filter
state. Reuse existing PhotoKit/image/analysis/inspection building blocks; do
not create a second cleanup workflow or dashboard.

## UX and safety constraints

Both intents route to one workspace and one authoritative state source.
Album membership, cleanup disposition, review progress, and analysis
availability render independently. Suggestions remain advisory and an
analysis refresh must not reset or silently reorder reviewed content; changed
groups enter Needs Review. Use en/vi owner strings and accessibility labels
from [ui-copy.md](../product-specs/ui-copy.md). No deletion operation starts
from a review action.

Data safety: bind the four dimensions independently and persist user actions
through the workspace. UX safety: one shared route, accessible state labels,
and no hidden suggestion action. API safety: views call coordinator/service
intents rather than PhotoKit, Vision, or model APIs directly.

## Work steps

1. Define the workspace route and intent handoff from Home.
2. Bind ReviewModel to durable workspace state and preserve resume ownership.
   Implement the canonical [action transitions](../product-specs/review-rules.md#review-action-transitions), including explicit Mark Reviewed and persistence-failure recovery.
3. Replace separate review assumptions with the shared grid, filters, group
   cards, compare route, and bounded Needs Review queue.
4. Define the minimum [suggestion input contract](../design-docs/photo-intelligence.md#shared-review-input-contract)
   and adapt existing native analysis/grouping outputs. Add preview and explicit
   acceptance; keep dimension mutations separate. No feat-037 dependency or
   automatic application of legacy selected/rejected output is allowed.
5. Add loading, unavailable, empty, limited-access, interruption, and partial
   analysis states without fake scores or hidden choices.
6. Verify navigation and relaunch restore through the existing coordinator.

## Validation

Run `./init.sh` at feature completion. It is the required automated evidence;
do not add tests, proof harnesses, or test-only UI. Confirm `git diff --check`
and the en/vi catalog remains complete through repository checks.

## Rollback and migration

Keep the prior review route behind a migration-compatible adapter until the
workspace route is proven. A rollback returns to the last safe workspace
snapshot without rewriting choices. Never migrate album exclusion into cleanup
staging or treat missing analysis as a user decision.

## Acceptance mapping

- Shared intents/surface → App routes, Home, ReviewWorkspace, ReviewModel.
- Independent state → workspace bindings and action dispatch.
- Group/compare/Needs Review → Review feature files and immutable suggestion
  display.
- UX safety/accessibility → `ui-copy.md`, localization, recoverable states.
- Gate → `./init.sh`, no tests/proof harnesses, and feature acceptance.
