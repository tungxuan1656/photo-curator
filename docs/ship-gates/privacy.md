# Privacy and Safety Gate

**Status:** Phase 1 pivot contract · privacy owner

Photos Curator processes photo content on device. No account, photo backend,
cloud inference, or tracking is required. The planning baseline is iPhone 14+
and iOS 26+ with English/Vietnamese UI.

## Data boundary

Photo bytes, thumbnails, faces, embeddings, GPS, full EXIF, filenames, and
`PHAsset.localIdentifier` values stay on device. PhotoKit may retrieve iCloud
bytes as part of the user's library behavior; that is not a Photos Curator
upload. Logs and optional analytics contain only approved aggregates and no
photo-linked identifiers.

SwiftData stores only scopes, independent workspace choices, migration markers,
and album/deletion operation state. Analyses, suggestions, thumbnails,
checkpoints, and model artifacts use local files/cache as defined in
[data-model.md](../design-docs/data-model.md). Retention and eviction never
remove originals from Apple Photos.

## Access policy

Read-write access is requested in context because the app can review, save an
album, and—only after a separate confirmation—delete originals. Limited access
is valid for review and cleanup staging. It cannot begin deletion. Recheck
authorization at operation start and offer access recovery without prompt
loops.

## Deletion disclosure

Deletion is never automatic or inferred from a suggestion, album exclusion,
missing asset, or legacy reason. The user must stage exact assets, review them,
confirm explicitly, and have full read-write access. `PhotoDeletionService`
persists an exact-set digest and per-ID outcomes; no automatic retries occur.
The app discloses PhotoKit/iCloud synchronization and Recently Deleted and does
not claim immediate recovered bytes.

Album save is independent and does not clear workspace or cleanup choices.
Partial saves and deletions are reported as partial; unresolved outcomes are
not presented as complete.

## Manifest and logging

`NSPhotoLibraryUsageDescription` must match actual read/write behavior. Privacy
manifest and store disclosures must match the shipped binary. Logs exclude
pixels, file paths, IDs, faces, precise location, full EXIF, and model output.
No photo data is placed in crash attachments or analytics.

## Gate

Pass only when access states, retention, migration, exact deletion confirmation,
limited-access blocking, truthful outcomes, and on-device boundaries are
covered by reproducible automated evidence plus `./init.sh`. No test targets,
test files, test frameworks, or proof harnesses are added.
