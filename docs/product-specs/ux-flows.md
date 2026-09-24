# UX Flows

**Status:** Intended organization-first UX · 2026-09-23.
Owns navigation, visible states, inspection, and accessibility.
Current code remains session-oriented until the [pivot features](../exec-plans/roadmap.md) land.

## Primary navigation

```text
Access education → Library / Discover
  ├─ Similar groups → Group → Compare / Photo detail
  ├─ Labels → Filtered photos ↔ Matching groups
  ├─ All photos → Photo detail
  ├─ Analysis status → Pause / Resume / Retry unavailable work
  └─ Saved work → Album drafts / Staged deletion / Operation outcomes

Any result → Select photos → Label / Add to album / Stage deletion
Staged deletion → Exact-set review → Confirmation → Outcome
```

Discovery opens without a cleanup/album intent choice.
Similar groups receive the primary discovery entry. Label shortcuts and All Photos remain directly reachable.
Group cards never appear only after the complete photo grid.
The exact visual layout is implementation work; these routes are required behavior.

## Browsing before analysis

Show accessible photos after metadata loading, before all analysis completes.
Keep browsing active while bounded analysis enriches the catalog.
Show separate photo-analysis and grouping coverage, with pause/resume and iCloud states.
Do not describe a partial catalog as a fully analyzed phone library.

## Screen states

| Surface | Normal | Incomplete or unavailable | Empty |
|---|---|---|---|
| Library / Discover | Groups, label shortcuts, All Photos | Index loading, partial access, paused analysis | No accessible photos |
| Similar groups | Cards with representative, count, relation | Grouping pending or stale | No similar groups found in analyzed photos |
| Label browser | Supported facets and contextual counts | Unsupported labels absent; coverage visible | No supported labels found yet |
| Filter result | Active chips, count, Photos/Groups view | Partial analysis, refreshing snapshot | No matches; clear filters action |
| Group | All members and relation reason | Missing member or revised group | Group no longer available |
| Detail / Compare | Bounded zoomable image, labels, evidence | Loading, iCloud wait, preview failure with retry | Asset no longer accessible |
| Label editor | Automatic labels and user overrides | Save failure retains committed state | Add personal label |
| Action selection | Exact selected count and named actions | Stale set requires review | Actions disabled |
| Album destination | New album or supported writable existing album | Access/load/save failure | No writable albums; new-album path |
| Deletion review | Exact staged assets | Limited access blocks start | Nothing staged |
| Operation outcome | Per-asset result and explicit recovery | Partial or unresolved | No work dispatched |

## Photo interaction contract

- Tapping a photo opens detail on every surface, including suggestion and group thumbnails.
- A distinct selection control toggles the temporary action set.
- Opening detail does not add the photo to an album or stage it for deletion.
- Detail supports zoom, scoped previous/next, and a direct return to the originating result.
- Comparison exposes evidence beside the relevant photos, rather than only a numerical score.
- Explain unavailable evidence and omit unsupported conclusions.
- Preserve the active photo and viewport when new analysis arrives.

The existing `PhotoDetail`, `PhotoInspectionCanvas`, and bounded image loader are reuse candidates.
Their session/album coupling must not define the new interaction semantics.

## Filters and groups

Show facet choices, readable AND/OR meaning, result count, and Clear Filters.
Photos and Matching Groups are views of the same query.
Full-group expansion marks members outside the filter and follows [organization rules](organization-rules.md#groups-inside-a-filtered-result).

New analysis shows an update indicator. Applying an update never silently enlarges selection.
Changing the query exits selection mode.
Select All names the complete current result count, not only loaded thumbnails.

## Actions and recovery

Only selection mode exposes bulk action controls.
Album selection is a destination choice after photo selection, not a permanent checkbox on every photo.
An operation preview names exact photos and the action. Rules belong to [review rules](review-rules.md).

Saved album drafts, staged deletion, and unresolved operations remain reachable across app launches.
Their recovery does not require the old discovery query to still match.
Storage failure shows the last committed state and explicit retry.
Opening a result or accepting a suggested comparison never dispatches a Photos mutation.

## Accessibility and language

Use text and VoiceOver paths for every photo action.
Expose photo position, selection state, relevant labels, relation, and available actions without relying on color.
Support Dynamic Type, 44-point controls, Reduce Motion, and English/Vietnamese copy.
Strings and plural forms belong to [ui-copy.md](ui-copy.md).

## Acceptance

- A user reaches groups or labels without starting a selection session.
- Every displayed photo has a working inspection path.
- A user can browse while analysis remains partial.
- Filters and group expansion preserve exact action scope.
- Album and deletion outcomes remain independently recoverable.
