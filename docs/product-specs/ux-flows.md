# UX Flows

**Status:** Phase 1 pivot contract · 2026-09-21

This doc owns screens, navigation, visible states, accessibility, and recovery
flow. [ui-copy.md](ui-copy.md) owns all strings. [review-rules.md](review-rules.md)
owns what actions mean; this document does not duplicate those rules.

## Entry and shared workspace

```text
Home
 ├─ Clean Up Photos ─┐
 └─ Build an Album ──┴→ Choose Photos → Analyze / Resume → Review Photos
                                         ├→ Group / Compare / Needs Review
                                         ├→ Save Album
                                         └→ Cleanup review → Confirm deletion (eligible only)
```

Both intents use one photo-first workspace: a compact intent/progress/filter
header, one grid, group cards, compare route, and selection-only action tray.
There is no separate cleanup workflow and no metrics dashboard.

## Screen/state inventory

| Screen | Normal | Loading/paused | Empty/recovery |
|---|---|---|---|
| Home | Two entry intents and resume card | Restoring workspace | No accessible photos / access guidance |
| Choose Photos | Source count and access state | Fetching metadata | No photos; Continue disabled |
| Analyze | Stable incremental progress | iCloud wait, pause, resume | Recoverable asset/session failure |
| Review Photos | One grouped grid and filters | Thumbnail/analysis availability | Nothing needs review |
| Group / Compare | Alternatives and suggestion provenance | Loading bounded previews | No comparable group |
| Needs Review | Bounded uncertain queue | Refreshing suggestions | Queue clear |
| Album Draft | Membership and save action | Preparing save | No album members |
| Save Album | Progress and outcome | Interrupted/partial recovery | Explicit retry or finish |
| Cleanup Review | Reversible staged set | Access recheck | Nothing staged |
| Delete Confirmation | Exact count/set and disclosures | Authorization check | Limited access blocks start |
| Deletion Outcome | Per-asset result | Reconciliation | Partial/failure outcome |
| Settings / Access | Full, limited, denied guidance | Reading permission | Settings recovery |

Normal, loading, empty, and recoverable-error states are distinct. A missing
analysis is shown as unavailable, not as a zero score. A single missing
thumbnail never blocks the workspace.

## Navigation and resume

Home routes either intent to the same workspace. Leaving after analysis begins
preserves a resumable scope. Relaunch restores the last safe state and the
same user choices. Analysis never silently resets or reorders reviewed content;
new or revised groups appear in Needs Review.

The workspace exposes album membership, cleanup disposition, review progress,
and analysis availability separately. Suggestions show their advisory nature
and offer an explicit choice; opening a suggestion never changes state.

Detail/compare opening and Mark Reviewed follow the
[action transition table](review-rules.md#review-action-transitions).
Use Suggestion opens a preview showing exact photos, target dimension and
proposed values. Confirmation applies only that proposal; cancellation preserves choices.
Album and cleanup actions use distinct labels even when both act on two photos.

If saving a choice fails, retain the last committed state, identify the failed
action, and offer Retry. Do not show “choices are saved” on this path.

## Access and destructive flow

Limited Photos access remains useful for review and staging. The cleanup
confirmation route is disabled for deletion and offers **Get Full Photos
Access to Delete**. Full read-write access is rechecked immediately before an
operation starts. Denied/restricted states provide recovery without prompt
loops.

Deletion confirmation shows the exact staged set and the iCloud/Recently
Deleted disclosure. It is never bundled with Save Album. Outcome screens
separate resolved assets from unresolved or failed assets and never claim
immediate storage recovery.

## Accessibility and recovery

Every photo action has a text and VoiceOver path. Labels expose position,
album membership, cleanup disposition, review progress, and suggestion state;
color is never the only signal. Dynamic Type, 44-point controls, and Reduce
Motion are required.

Recoverable errors preserve the workspace and choices. Retry is explicit and
operation-specific; deletion has no automatic retry. Partial album or deletion
outcomes remain visible until the user dismisses them.

Dismissal does not erase unresolved operation records. Reconciliation shows
unresolved/access-unknown outcomes separately from confirmed deletion. A changed
pre-start set returns to exact-set review and requires fresh confirmation.

## Acceptance

- Both intents reach the same workspace and shared state source.
- Every state in the table has an en/vi owner string in [ui-copy.md](ui-copy.md).
- Limited access can review/stage but cannot begin deletion.
- Save and deletion have separate routes, progress, and outcomes.
