# Product

**Status:** Phase 1 pivot contract · 2026-09-21
**Platform:** iPhone 14+ / iOS 26+
**Languages:** English and Vietnamese

This doc owns product purpose, scope, invariants, and gates. User-visible flow
is in [ux-flows.md](ux-flows.md), choice/deletion semantics in
[review-rules.md](review-rules.md), and strings in [ui-copy.md](ui-copy.md).

## Definition

Photos Curator is an on-device iPhone assistant for reviewing a large personal
photo set. It classifies and groups photos, records immutable analysis facts,
and offers quality or album suggestions while the user decides what to keep,
what belongs in an album, and what—after a separate confirmation—may be
removed from the original library.

## Product promise

The app reduces repetitive review without taking authority away from the
owner. **Clean Up Photos** and **Build an Album** are two entry intents into the
same shared workspace. A suggestion is never a hidden action.

## Scope

In scope:

- read authorized Photos content and analyze it on device;
- incrementally classify and group photos with resumable progress;
- present one shared, grouped review workspace;
- preserve independent cleanup disposition, album membership, review progress,
  and immutable facts/suggestions;
- save an independently reviewed album;
- optionally stage and, only after the deletion gate, delete exact original
  assets through a separate operation;
- support limited/full/denied Photos access, iCloud delays, interruption, and
  truthful partial outcomes;
- ship English and Vietnamese copy.

Out of scope: accounts, cloud photo processing, social features, editing,
video workflows, identity naming, automatic cleanup, automatic deletion,
server-side inference, and a metrics dashboard. The app never silently deletes
or modifies originals.

## Invariants

1. User choices are authoritative and suggestions never mutate them.
2. Cleanup disposition, album membership, review progress, and analysis facts
   are independent dimensions.
3. Original deletion requires exact-set staging, review, explicit confirmation,
   full Photos read-write access, and a persisted operation digest. Limited
   access can review/stage but cannot begin deletion.
4. Album save is separate from deletion and never clears workspace or cleanup
   state.
5. Core photo processing is on device; no photo pixels, faces, embeddings, or
   asset IDs are uploaded to a Photos Curator server.
6. The app does not claim immediate recovered bytes after deletion.
7. The baseline remains iPhone 14+, iOS 26+, on-device, en/vi.

## Core loop

```text
Choose intent → choose source → incremental analysis/resume
→ shared grouped workspace → independent album save or cleanup review
→ explicit deletion confirmation (if eligible) → truthful outcome
```

## Launch gates

- A large source set can be analyzed and resumed without losing choices.
- The shared workspace serves both intents and keeps state dimensions separate.
- Album save and cleanup deletion report complete, partial, and failed outcomes
  accurately.
- Limited access cannot start deletion; full access is checked at the gate.
- No photo data leaves the device through the app's normal flow.
- Evidence is reproducible automated evidence plus `./init.sh`; no test target,
  test file, test framework, or standalone proof harness is added.

## Canonical links

- Flow/states: [ux-flows.md](ux-flows.md)
- Rules and deletion: [review-rules.md](review-rules.md)
- Copy: [ui-copy.md](ui-copy.md)
- Storage: [data-model.md](../design-docs/data-model.md)
- Privacy: [privacy.md](../ship-gates/privacy.md)
- Build order: [roadmap.md](../exec-plans/roadmap.md)
