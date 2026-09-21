# feat-036 — Confirmed original deletion plan

## Scope and dependency

After feat-035, add the separate, explicit original-deletion lane. This is a
safety-sensitive feature and must not share the album-save mutator. Contracts
are owned by [review-rules.md](../product-specs/review-rules.md),
[apple-frameworks.md](../design-docs/apple-frameworks.md),
[privacy.md](../ship-gates/privacy.md), and
[data-model.md](../design-docs/data-model.md).

## Anticipated code areas

Existing areas to reshape: `apps/photo-curator/Services/ServiceProtocols.swift`,
`App/AppContainer.swift`, `App/AppModel.swift`, `App/AppRoute.swift`,
`App/RootView.swift`, `Features/Review/ReviewModel.swift`,
`Features/Onboarding/AccessGuidanceSheet.swift`, `Features/Onboarding/HomeView.swift`,
`Features/Onboarding/PermissionEducationView.swift`,
`Infrastructure/SessionCheckpointStore.swift`, and `Localizable.xcstrings`.

Anticipated new areas: `Services/Deletion/PhotoDeletionService.swift`,
`Services/Deletion/DeletionOperation.swift`,
`Features/Cleanup/CleanupReview.swift`,
`Features/Cleanup/DeleteConfirmation.swift`, and
`Features/Cleanup/DeletionOutcome.swift`. Exact names may be adjusted only
with owner-doc updates; `PhotoDeletionService` remains a distinct boundary.
`DeletionOperation` and its state schema are owned exclusively by feat-036.

## API and safety constraints

Only a user-reviewed exact staged set may proceed. Persist a canonical digest,
confirmation, authorization snapshot, and per-ID outcomes before PhotoKit
mutation. Require full Photos read-write access at confirmation and operation
start; limited access may retain staging but cannot begin. Re-resolve exact IDs;
an absent limited-access ID is `accessUnknown`. There is no automatic retry.
Disclose iCloud synchronization, Recently Deleted, and no guaranteed immediate
recovered bytes. Deletion never changes album membership or suggestion records.

Data safety: pending state and exact digest precede mutation. UX safety: the
confirmation names the exact set and explains iCloud/Recently Deleted without
promising immediate space. API safety: only `PhotoDeletionService` may call
the original-deletion PhotoKit API, after full-access preflight. The operation
entity/state must be introduced through an explicit SwiftData schema migration
owned by feat-036; feat-033 must not create or migrate it.

## Work steps

1. Define operation state, canonical exact-set digest, and per-ID outcome
   transitions in the data model, including the feat-036 SwiftData schema
   migration and rollback path.
2. Add the service boundary and authorization/exact-set checks before any
   `PHPhotoLibrary.performChanges` call.
3. Persist pending state before mutation and outcome updates during/after the
   PhotoKit transaction; make reconciliation explicit and idempotent.
4. Add cleanup review, exact-set confirmation, limited-access block, and
   truthful partial/failure outcome routes in en/vi.
5. Wire interruption/relaunch reconciliation and ensure album save remains
   untouched and independently resumable.
6. Review logs and errors for IDs, pixels, and false storage claims.

## Validation

Run `./init.sh` after implementation. No tests, test targets, test files, proof
harnesses, or automatic deletion retries may be added. Verify `git diff --check`
and the owner privacy/API acceptance through the automated gate.

## Rollback and migration

Do not delete or reinterpret legacy choices during this feature. If an
operation schema cannot decode, preserve staged choices and route to safe
reconciliation. Rollback disables the deletion start action while retaining
operation records and never calls compensating automatic deletion. PhotoKit's
Recently Deleted behavior remains external truth.

## Acceptance mapping

- Exact set/digest/confirmation → feat-036-owned operation model and
  confirmation gate.
- Schema evolution → explicit SwiftData migration added and rolled back by
  feat-036, not feat-033.
- Full-access-only → permission service and deletion service preflight.
- Reconciliation/no retry → persisted state machine and explicit recovery.
- Truthful API/privacy UX → cleanup screens, copy, Apple framework boundary.
- Gate → feature acceptance and `./init.sh` with no tests/harnesses.
