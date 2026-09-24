# Review and Action Rules

**Status:** Intended action-selection contract with existing deletion safeguards · 2026-09-23.
Owns the meaning of user actions and mutation gates.
[Organization rules](organization-rules.md) own queries and groups; [data model](../design-docs/data-model.md) owns persistence.

## Independent state

| Dimension | Authority | Meaning |
|---|---|---|
| Action selection | User, temporary result snapshot | Photos targeted by the next explicit action |
| Label override | User, durable | Confirmed/rejected automatic label or personal assignment |
| Album draft membership | User, durable per draft | Included/excluded/unset for that destination |
| Cleanup disposition | User, durable staging context | Undecided/keep/staged for deletion |
| Review progress | User/opening history | Unseen/in progress/reviewed; retained for compatible saved work |
| Analysis and groups | Versioned derived evidence | Explain or suggest, never imply a choice |
| Operation outcome | Persisted service evidence | Actual album/deletion result, not inferred intent |

None of these dimensions is inferred from another.
Selecting a thumbnail is not album inclusion. Excluding from an album is not deletion.
Group membership is not evidence that every other member is disposable.

## Action selection

Selection records exact IDs and the query/group revision visible when selection began.
Select All captures every current matching accessible ID, including results outside the loaded viewport.
It does not select future matches or hidden full-group context.

- Filter changes clear the temporary selection.
- New analysis does not enlarge the selected set.
- Leaving selection mode clears only temporary selection, not saved drafts or staging.
- Changed access or a changed preflight set requires an updated preview before mutation.
- Bulk writes commit atomically where local state is involved. On failure, retain the last committed state.
- A repeated tap must not create duplicate mutation operations.

## Review action transitions

| Action | Effect | Preserved state |
|---|---|---|
| Select / Deselect | Change temporary action set | All durable choices and facts |
| Open photo / compare | Inspect exact opened assets; retain compatible progress semantics | Selection, album, cleanup, labels |
| Confirm / Reject label | Save that label override | Other labels, album, cleanup |
| Add personal label | Save assignment for exact chosen IDs | Other dimensions |
| Restore automatic label | Remove only that label override | Other corrections and facts |
| Add to Album | Choose destination and prepare an exact-set draft/operation | Cleanup, labels, facts |
| Remove from draft | Change that draft membership only | Photos library, cleanup, labels |
| Keep Photo | Cleanup → keep for the explicit staging context | Album, labels, facts |
| Stage for Deletion | Cleanup → staged for deletion for exact IDs | Originals and album choices |
| Unstage | Cleanup → undecided | All other dimensions |
| Mark Reviewed | Progress → reviewed for explicit IDs | Choices and evidence |
| Select suggested candidates | Preview exact candidates, then update temporary selection on confirmation | All durable choices |

Opening or scrolling a grid never marks all visible photos reviewed.
An existing legacy suggestion can still update its named draft dimension after explicit preview.
It cannot stage deletion or acquire authority over the new catalog selection.

## Album operations

The user chooses a new album or a supported writable existing album after choosing photos.
The destination name alone is not an identity. Existing albums require their resolved Photos identifier.
New-album creation retains collision-safe naming and its created identifier for retry.

Persist destination, exact IDs, digest, progress, and per-ID outcomes before reporting saved work.
Retry adds only unresolved/missing members after reconciliation; it does not create another destination automatically.
Album operations do not clear labels, other drafts, staging, or analysis.
Removing an item from a draft does not remove it from an already saved Photos album.

## Deletion gate

Original deletion requires all four conditions:

1. The user staged the exact assets.
2. The user reviewed that set and explicitly confirmed deletion.
3. Current authorization is full Photos read-write access.
4. A durable operation records the exact-set digest before dispatch.

Limited access permits browsing and staging but cannot start deletion under this product policy.
Scores, labels, groups, album exclusion, or missing IDs never create deletion intent.
Suggestion acceptance never stages deletion.

Before dispatch, a changed set invalidates confirmation.
After dispatch, the operation set is immutable. Later staging belongs to another operation.
The service resolves IDs and rechecks access at the mutation boundary.
Deletion has no automatic retry, including after relaunch.

Only persisted successful PhotoKit completion for the submitted set proves deletion.
An absent asset does not prove successful deletion, even with full access.
Lost completion evidence remains unresolved. Read-only reconciliation never dispatches another deletion.
See the [state machine](../design-docs/data-model.md#deletion-operation-state-machine).

Disclose iCloud synchronization and Recently Deleted.
Never claim immediate recovered bytes.

## Recovery and migration

Partial and unresolved outcomes remain distinct from success.
Dismissal does not erase unresolved operations.
An access change cannot rewrite an earlier known success as unknown.
Persistent save failures never display a saved-choice claim.

Legacy scopes retain their draft, staging, progress, and operation identities.
The catalog does not union conflicting per-scope choices into a global decision.
Historical picks never become labels, current action selection, or permission to delete.
Migration details belong to [data model](../design-docs/data-model.md#migration).

## Acceptance

- The same selected photos can receive a label or album action without implicit cleanup changes.
- Full-group context never silently enters a filtered action set.
- Changed preflight sets require renewed review.
- Existing album/deletion safeguards remain valid after session-independent entry.
