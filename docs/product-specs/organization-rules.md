# Photo Organization Rules

**Status:** Intended contract · 2026-09-23.
Owns label meaning, comparison-group meaning, and filter semantics.
The user approved the group-versus-topic distinction. Detailed behavior here is the implementation contract for the planned pivot.

## Vocabulary

| Term | Meaning |
|---|---|
| Catalog | Local index of authorized Photos references and derived organization data |
| Label | One named property of a photo, independent of other labels |
| Facet | A dimension containing related labels, such as content or technical condition |
| Comparison group | Photos worth inspecting together because they repeat an image or capture |
| Filter result | Distinct accessible asset IDs satisfying the current query |
| Action selection | Explicit temporary subset of one result snapshot |
| Suggestion | Evidence-backed advice, never an automatic user action |

## Overlapping labels

A photo can carry labels from multiple facets and multiple compatible labels within a facet.
An outdoor landscape photo can carry labels from Content and Setting when each
has evidence; native technical scalars remain separate evidence, not labels.
Labels reference the same asset; they never duplicate the photo.

| Facet | Admitted semantic vocabulary | Interpretation |
|---|---|---|
| Image kind | Screenshot, document | Admitted semantic IDs; source attribution remains explicit |
| Content | People, group, landscape, architecture, food, animal | Visible content, not personal identity |
| Setting | Indoor, outdoor | Context evidence |
| Technical condition | None | Native blur/underexposure scalars are unsupported pending label-specific evaluation and never appear as labels or chips |
| Personal | User-created labels | User meaning, such as children or work documents |

The semantic rows above are the exact labels admitted by feat-044. Other
candidate labels remain unavailable rather than acquiring guessed heuristic
labels. Technical scalars are evidence inputs only until a separate
label-specific evaluation admits a label.

- A face count alone does not prove selfie, full-body, or family identity.
- Darkness alone does not prove an unusable photo.
- Native blur and underexposure scalars remain separate unsupported properties;
  neither is a label or chip.
- “Beautiful” and “keep” are not factual labels. Comparative advice names its evidence and limits.
- Raw provider identifiers are not user-facing label IDs.

## Label authority

Automatic assignments record source, revision, evidence, and availability.
User actions can confirm, reject, or add a label.
An explicit rejection suppresses that automatic label until the user restores automatic assignment.
Re-analysis does not overwrite corrections. Personal labels never become model output.

No label result means “no supported label found” only after successful analysis.
Pending, failed, unsupported, and stale analysis cannot be interpreted as a negative classification.

## Comparison groups

| Relationship | Group? | Evidence requirement |
|---|---|---|
| Identical or near-identical image | Yes | Visual evidence; exact equality requires stronger evidence than a similarity threshold |
| Same scene/capture with expression, framing, or exposure variations | Yes | Visual relation plus available capture context |
| Same subject category across unrelated scenes | No | Use labels to connect these photos |
| Nearby timestamps without visual similarity | No | Time proposes candidates, never establishes membership |
| Insufficient similarity evidence | No forced group | Keep the photo browsable outside groups |

Small coherent groups take priority over broad semantic clusters.
Transitive chains cannot merge unrelated endpoints without group-consistency evidence.
Cross-date near-copies need a retrieval path separate from time-local retakes.
Missing dates cannot become a fabricated same-moment claim.

Each group exposes members, relation kind, grouping revision, and a readable reason.
A representative is a navigation cover, not a selected keeper.
Ranking is optional and can abstain. Users can keep any number of group members.

The initial presentation uses one primary comparison group per photo in each grouping snapshot.
Exact-copy subrelationships can be explained inside that group without duplicating action counts.
This restriction does not limit overlapping labels.

## Filter semantics

- Combine different facets with **AND**.
- Combine selected labels within one facet with **OR**.
- An empty facet adds no restriction.
- Date/source restrictions intersect the label query.
- Personal labels form their own facet.
- Deduplicate every result by asset ID.
- The first release has positive inclusion filters; arbitrary Boolean nesting and negation are outside this pivot.

```text
Content = landscape
Setting = indoor OR outdoor
Result = landscape AND (indoor OR outdoor)
```

Only current effective assignments match a label filter.
Show pending/unavailable coverage beside results so zero matches does not imply complete analysis.
Facet counts are contextual: count the distinct result after applying that proposed facet choice and all other active facets.
Counts across overlapping labels must not be summed as a library total.

## Groups inside a filtered result

Show groups with at least one matching member, including matched/total member counts.
Opening the full group can reveal nonmatching alternatives for comparison.
Reveal those alternatives as context, not as selected query results.

Example: two landscape matches belong to a five-photo group.
The user can inspect all five, but Select All in the filter still targets only its matching assets.
Selecting outside-filter context requires an explicit new group selection context.

## Stable browsing

Each visible query/group result has a revision and deterministic ordering. A
query snapshot atomically binds one catalog generation to one effective-label
projection revision; no result or count may mix revisions.
Analysis can announce new results without reordering an open comparison or expanding an action selection.
Changing filters clears the temporary selection. A newer analysis snapshot never silently adds selected IDs. Temporary selection is a non-mutating frozen snapshot of exact result IDs and its query/revision identity.
Unavailable assets leave actionable results; their loss invalidates affected action previews.

## Acceptance examples

- A landscape photo appears under landscape and outdoor only when each has evidence.
- Two unrelated beach photos share labels but do not become a comparison group solely for that reason.
- A user-rejected vehicle label stays rejected after model revision changes.
- Zero matches with pending analysis shows incomplete coverage, not “no such photos.”
- Full-group comparison never expands an existing filtered deletion set.
