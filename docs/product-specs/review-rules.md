# Review Rules (choices, cleanup, and deletion owner)

**Status:** Phase 1 contract · 2026-09-21

This document owns user-choice semantics, review rules, cleanup staging, and
original-deletion safety. `ux-flows.md` owns screen flow and states;
`ui-copy.md` owns strings. `data-model.md` owns storage shape.

## Product contract

Photos Curator assists with photo review: it classifies, groups, and offers
quality or content suggestions. The user remains authoritative. **Clean Up
Photos** and **Build an Album** are two entry intents into one shared,
photo-first workspace; they are not separate pipelines.

The following dimensions are independent and must never be inferred from one
another:

1. **Cleanup disposition:** `undecided`, `keep`, or `stagedForDeletion`.
2. **Album membership:** `included`, `excluded`, or `unset` for the current
   album draft.
3. **Review progress:** `unseen`, `inProgress`, or `reviewed`.
4. **Analysis facts and suggestions:** immutable facts plus advisory candidate
   suggestions, each with provenance and analysis version.

Suggestions never mutate a user choice. Analysis availability is separate from
classification and membership. A later analysis pass must not reset or silently
reorder reviewed work; new or revised groups enter **Needs Review**.

## Choice rules

- A user action is authoritative immediately and survives navigation, resume,
  re-analysis, album save, and cleanup staging.
- Grouping, quality, face, content, and AI signals explain or suggest; they do
  not decide on the user's behalf.
- Review may include, exclude, keep both, restore, or leave an asset
  undecided. No rule forces one winner when the user wants more than one.
- `stagedForDeletion` is reversible until explicit confirmation. It is not a
  deletion result and does not remove an asset from the library.
- Album save is independent: saving an album never clears the workspace,
  album membership, review progress, or cleanup disposition.
- Cleanup staging is exact-asset work. A suggestion, group, score, missing
  asset, or unavailable permission can never create a deletion operation.

## Deletion gate

Original library deletion is allowed only when all conditions hold:

1. the user staged the exact assets;
2. the user reviewed the exact set and explicitly confirmed deletion;
3. the app currently has full Photos read-write access; and
4. a persisted operation records the exact-set digest before PhotoKit mutation.

Limited access may review and retain staged choices, but it cannot begin
deletion. The app must route to access recovery or let the user keep the staged
set. An asset absent under limited access is `accessUnknown`, never deletion
confirmed.

`PhotoDeletionService` is separate from album saving. It resolves the exact
IDs again, records per-ID outcomes before and during mutation, and has no
automatic retry. Recovery of an interrupted operation is an explicit,
authorization-aware reconciliation; it must not silently retry deletion.

PhotoKit and iCloud behavior, including Recently Deleted, must be disclosed
truthfully. The app must not claim that deletion immediately freed a byte
count: iCloud synchronization, storage optimization, and Recently Deleted
retention affect the result.

## User-visible outcome rules

- Album save reports created, partial, or failed truthfully and leaves cleanup
  state untouched.
- Deletion reports per-asset success, unavailable/access-unknown, or failure;
  an operation is not presented as complete when outcomes are unresolved.
- Failure never converts an asset to `keep`, `undecided`, or deleted-by-inference.
- Reopening a workspace shows the persisted exact choices and operation state.

## Legacy migration rule

Migration is one-way and idempotent. A legacy `selected` or `restored` value
imports as album `included`; legacy `rejected` or `removed` imports as album
`excluded`. Every legacy cleanup disposition becomes `undecided`; review
progress becomes `unseen`. No deletion intent, review progress, or certainty is
inferred from legacy reasons, unavailability, or old output state.

The legacy source remains until a committed migration marker is durable. A
crash before that marker repeats the import safely; it never partially deletes
legacy data.

## Acceptance

- Every review surface reads and writes the same four independent dimensions.
- Suggestions are immutable advisory records and cannot mutate user choices.
- Limited access cannot begin deletion; full read-write is checked again at
  confirmation and operation start.
- Album save and original deletion are separate services and state machines.
- Exact-set digest, per-ID outcomes, interruption reconciliation, and no
  automatic retry are durable requirements.
