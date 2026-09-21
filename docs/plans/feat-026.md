# feat-026 execution plan

Goal: expose uncertain selection decisions as a small, actionable Needs Review queue and capture
bounded on-device feedback, without changing picks, the privacy promise, or any versioned
analysis/choice contract.

## Scope

Owns: `Domain/Selection/UncertaintyReview.swift` (new: reason/action vocabularies, deterministic
classifier, `UncertaintyReviewState` single source of truth for queue derivation/resolution/snapshot, versioned feedback snapshot with strict seven-key read — DEC-044/DEC-046), `Features/Review/NeedsReview.swift` (new view),
`SessionCheckpointStore` uncertainty-feedback paths (strict read + generation-guarded writes — DEC-046), `ReviewModel` queue ownership (holds one `UncertaintyReviewState`, delegates resolution/snapshot) + snapshot,
`AppModel+Save` review-model ownership + hook/delete wiring (assigns `reviewModel = model` before routing; hook owns generation-pinned `PersistLatest` strongly with a weak model capture, tombstone-safe per DEC-043/DEC-045, stale-writer-safe per DEC-046), `AppRoute`/`RootView`/`ReviewOverview` review integration,
this plan, the feature/progress records, and DEC-042/DEC-043/DEC-044/DEC-045/DEC-046.

Explicitly NOT: pick changes (`SelectionEngine`, scorer, diversity, clusters, moments untouched),
new Vision requests/models, new persisted analysis/decision fields (`analysisVersion` stays 4,
`engineVersion` stays 3, `configVersion` stays 1 — no migration), new config keys (band/cap are
policy constants beside the classifier, per the selection-rules §17 small-knob precedent),
cloud/network analytics, test targets/`*Test*.swift`/frameworks, feat-027+ scope.

## Uncertainty contract (frozen)

Inputs: persisted `SelectionResult.decisions` only (reason codes per selection-rules §16, optional
score). No new signals, no analysis reads, no cluster/moment objects (review-time derivation;
clusters/moments are not persisted).

Queue rules (one primary reason per item; `assetUnavailable` never queues — the unavailable
bucket owns it; clean `bestInMoment`-only keeps and duplicate/floor losers never queue):

| Priority | Reason | Triggers on | Action |
|---|---|---|---|
| 0 | `borderlineQuality` | non-nil score within band of the floor | inspect / add-back |
| 1 | `faceTradeoff` | selected `bestGroupPhoto` | inspect faces |
| 2 | `similarAlternatives` | selected `nearDuplicateRepresentative` | open Similar |
| 3 | `secondMomentView` | selected `secondaryMomentRepresentative` | compare moment |
| 4 | `coverageCut` | rejected diversity cut above the band | add-back if needed |

Frozen thresholds: score band `±0.05` around the live `SelectionConfiguration.lowQualityThreshold`
(read from config at the call site, never redefined — DEC-042, `UncertaintyClassifier.scoreMargin`
0.05, double-run byte-identical on the deterministic payload); queue cap `30` items, truncated in
(priority, source-order) sequence. Order is deterministic: priority, then decision index
(source order), then asset ID. Double-run byte-identical.

Action vocabulary (fixed): `inspectDetail`, `considerAddBack`, `viewSimilar`, `compareMoment`.
Each maps to an existing surface (S10/S11/S21, S13, S12); no new selection behavior.

## Feedback schema (frozen, versioned, aggregate-only)

```swift
struct UncertaintyFeedbackSnapshot: Codable, Sendable {  // schemaVersion 1
    schemaVersion, sessionID, engineVersion,
    queueSize, resolvedByReason: [String: Int], totalResolved, updatedAt
}
```

Resolution is derived, never stored per photo: queue IDs ∩ persisted edit sets
(`removedIDs`/`restoredIDs`/`swapWinner` values from the existing `SelectionFeedback` file).
The snapshot carries counts only. Prohibited in snapshot and logs: image bytes, face data,
embeddings, GPS, full EXIF, asset identifiers, free text (fixed vocabularies only).
`sessionID` is the existing ephemeral per-run ID (analytics §2). Old/corrupt/version-mismatched
snapshots load as nil (fresh), never throw — same rule as existing feedback.

## Review integration

S09 gains a `Needs Review` entry (count; hidden when empty, same rule as Similar). New
`NeedsReview` view lists queue items in queue order with reason copy + per-item action into the
existing surfaces without mutating selection: inspect/compare-moment open the queue-scoped
detail pager (S11, with S21 one tap deeper), similar routes to Similar (S12), add-back routes
to Removed (S13); the standalone selection toggle stays separate.
Deterministic decisions keep the existing S10/S12/S13 flow untouched. Copy avoids scores,
Vision terms, and deletion vocabulary (ux-flows §13).

## Persistence and recovery

New `uncertainty-feedback/<session>.json` via `SessionCheckpointStore`
(strict seven-key read: unknown or missing top-level keys decode-throw so the row loads nil — DEC-046; save/load-nil-on-any-failure/delete-absent-is-success, DEC-043 closed-session tombstone plus DEC-046 generation owner: deletes retire first, late hook writes and stale old-session writers pinned to a retired generation drop instead of recreating rows or entering a reopened session; live `beginReview`
re-entry reopens with a fresh generation and installs a fresh hook). Written on each feedback mutation
through the existing ordered `PersistLatest` hook (feedback first, snapshot second — one
actor, newest always lands last; hook owns the generation-pinned `PersistLatest` strongly with a weak model
capture so live writes fire without a retain cycle — DEC-045/DEC-046; the model is assigned to
`reviewModel` before routing so RootView destinations and save guards see the same model).
Deleted with the session (`deleteSessionData`, incl. Reset).
Save failure (e.g. disk) is `try?`: in-memory review continues, the next mutation retries.
Partial results (`Continue Without Them`) derive the queue from `assetUnavailable`-marked
decisions the same way (`assetUnavailable` never queues). Review routes without a model show
the existing recoverable `ReviewLoadFailedView`.

## Verification and rollback

The shipped review sources are compiled by the repository's Simulator build. The affected
dependency closure includes `Features/Review/NeedsReview.swift`, `Features/Review/PhotoDetail.swift`,
`Features/Review/PhotoAnalysisDetail.swift`, `Features/Review/ReviewScoreBadge.swift`,
`SharedUI/AsyncPhotoThumbnail.swift`, `SharedUI/ErrorStateView.swift`, and `SharedUI/SelectionToggle.swift`.
The remaining excluded SwiftUI views are still Xcode-built via `./init.sh`. Review the decision matrix, 30-cap truncation, resolution derivation, and persistence boundaries in the implementation record;
partial-result unavailable exclusion, store round-trip + corrupt/version-mismatch/extra-key/absent recovery (DEC-046 strict rejected inputs: `configVersion` + `debugNote` rows load nil), U6 strict decode-throw cases for both rejected inputs, DEC-043 cleanup-race (late writes + real model-captured hook snapshot drop, ordinary save
failure still throws, interleaved failure/delete/reopen stays absent until reopen, double-delete idempotent, reopen re-enables with retry-success totals) plus DEC-046 stale-generation interleaving (stale pinned writer drops after delete + reopen, fresh retry succeeds with identical totals), NeedsReview routing
audit, plan/DEC-042 reconcile + DEC-044 exact-schema freeze, U13 shipped hook/re-entry + strong ownership (REAL ReviewModel hook fires while live, re-entry mints a new generation and installs a fresh hook, saves see the same model — DEC-045/DEC-046), U14 live REAL shipped `AppModel` path (beginReview builds the shipped model + installs the shipped hook, edits persist the pair, save-guard routes the same model, scripted exporter failure then retry-success, failure/delete/reopen interleaving stays absent until a fresh entry retries — DEC-045/DEC-046).
`./init.sh` PASS (format, `swiftlint --strict`, Simulator build, SKIP [test] per policy).

Rollback: delete the two new files and revert `ReviewModel`, `AppModel+Save`,
`SessionCheckpointStore`, `AppRoute`, `RootView`, `ReviewOverview` (plus tracker/plan/decision
records). No migration to undo — no version moved, no persisted shape changed, old sessions
derive an empty-or-fresh state and keep working.
