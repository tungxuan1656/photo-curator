# Product

**Status:** Accepted direction, intended product contract · 2026-09-23.
Implementation status belongs to the [roadmap](../exec-plans/roadmap.md), not this specification.

## Purpose

Photos Curator is an on-device companion to Apple Photos.
It helps users find related photos, compare similar shots, and organize their library without inspecting every photo individually.

The primary capabilities are **similar-photo grouping** and **useful labels**.
Album creation and cleanup are downstream actions on photos the user chooses.
The app is not a photo editor or a replacement for everyday Photos viewing.

## Core loop

```text
Authorize Photos → browse accessible library immediately
  → incremental analysis → discover similar groups or labels
  → combine filters → inspect / compare → select photos
  → assign labels / add to album / stage deletion
```

Analysis enriches the library progressively. Users do not need to choose cleanup or album intent before discovery.
The app indexes references to Photos assets. It does not import a second copy of the original library.

## Priority

1. Find duplicates, near-duplicates, and comparable retakes without merging unrelated scenes.
2. Assign understandable, overlapping labels that help users find photos.
3. Explain results through accessible groups, photo detail, and combined filters.
4. Apply explicit actions to an exact selected set.

Shared subject matter alone does not justify a comparison group.
The [organization rules](organization-rules.md) own that distinction and the label/query vocabulary.

## Scope

Included:

- The authorized photo library, including limited-access subsets.
- Metadata-first browsing, incremental analysis, interruption recovery, and library reconciliation.
- On-device image understanding, technical evidence, and visual similarity.
- Multiple labels per photo, user corrections, and personal labels.
- Faceted filtering, similar-group discovery, zoomable detail, and comparison.
- Explicit album operations and separately confirmed original deletion.
- English and Vietnamese UI on the iPhone 14+ / iOS 26+ planning baseline.

Excluded:

- Photo editing, camera capture, video analysis, cloud backup, and cross-device catalog sync.
- Accounts, social features, cloud photo inference, and automatic deletion.
- Automatic family identity claims, a universal beauty score, and automatic best-album generation.
- Natural-language chat/search and persistent face identity recognition in this pivot.

Labels help users find photos. They do not claim to describe every aspect of every image.

## Product outcomes

| User need | Expected outcome |
|---|---|
| Compare repeated shots | Open a useful group directly, inspect all members, and choose any number |
| Find documents | Open the document label, select the result, and add it to a chosen album |
| Review weak landscape shots | Combine landscape with blur/underexposure signals and inspect the result |
| Organize selfies | Filter selfie candidates, view similar groups, then select explicit photos for an action |
| Resume later | Recover analysis progress and user corrections without repeating valid work |

Useful discovery is the success criterion. An analysis count, label count, or successful build does not establish image accuracy.
Evidence vocabulary and quality limitations belong to [photo intelligence](../design-docs/photo-intelligence.md).

## Invariants

- Originals remain in Apple Photos. Analysis never mutates originals or user choices.
- Selection means a temporary action set, not album membership or deletion intent.
- User label corrections survive re-analysis and model updates.
- Unknown, unavailable, and not-yet-analyzed results remain distinguishable.
- Album and deletion operations follow [review rules](review-rules.md).
- Local processing follows [privacy](../ship-gates/privacy.md).
- Background completion is opportunistic, never promised after app suspension.

## Contract boundaries

| Question | Owner |
|---|---|
| What is a label, group, or filter? | [Organization rules](organization-rules.md) |
| Where does the user go? | [UX flows](ux-flows.md) |
| What does an action change? | [Review rules](review-rules.md) |
| What exists today? | [Architecture](../design-docs/ios-architecture.md) |
| What work implements this direction? | [Roadmap](../exec-plans/roadmap.md) |
