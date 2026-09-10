# Privacy, Permissions, Retention, and Disclosure Rules (Canonical Owner)

**Doc:** `privacy.md` (native filename kept)
**Status:** MVP specification
**Role:** Single owner of privacy and redaction rules. Other docs link here. This doc does not copy them.

**Ownership (per blueprint + Oracle):**
This doc owns data classification, on-device flow and what never leaves device, permission policy, retention and deletion, network and logging and crash redaction, and manifest and store disclosures.

This doc does not own UX copy and state flow (02), PhotoKit API mechanics (07), perf checkpoint mechanics (08), QA checklists (10), or analytics events (11).

**Incoming links:** 01, 02, 04, 05 link here for privacy rules. They do not restate them.
**Outgoing links:** This doc links to 02, 03, 07, 08, 10, 11. It does not copy their content.

Related docs:

- `product.md` — product scope
- `ux-flows.md` — screen wording and permission state flow
- `selection-rules.md` — face, quality, and moment categories
- `selection-engine.md` — engine inputs
- `ios-architecture.md` — app structure
- `apple-frameworks.md` — PhotoKit and Vision API use
- `performance.md` — checkpoints, resume, background work
- `manual-qa.md` — release checklists
- `analytics.md` — event names and aggregates

---

## 1. Core promise

The user keeps control of their photos. Analysis runs on the iPhone. Originals stay safe.

MUST invariants (only use of MUST in this doc):

- The app MUST never delete an original photo on its own.
- The app MUST never upload photo pixels to Photos Curator servers.
- The app MUST never upload face data off device.
- The app MUST never upload embeddings, GPS, or asset IDs off device.

Other sections use plain verbs. Only the four lines above are invariants.

MVP has no account. It has no login. It has no photo backend. It has no ads. It has no cross-app tracking. It has no cloud AI. It works with no Photos Curator server.

---

## 2. On-device data flow

Flow for MVP:

```text
Apple Photos Library (PhotoKit / iCloud Photos)
  | user-authorized read
  v
Photos Curator app: PhotoKit + Vision + Core ML + Selection Engine + local cache
  | anonymous counts only, if enabled
  v
Optional metrics endpoint (no photo data)
```

There is no app-server path for pixels or face data. The pipeline has no network need. Selection runs offline once assets are local.

What never leaves the device:

```text
UIImage / CGImage / CIImage bytes
PHAssetResource bytes and thumbnail bytes
face crops, boxes, landmarks, quality notes
face embeddings, templates, clusters
visual embeddings for identity
GPS coordinates and full EXIF blobs
PHAsset.localIdentifier and filenames
```

Apple iCloud retrieval is an exception. iOS may fetch an asset from iCloud. That is Apple behavior. It is not a Photos Curator upload. The app keeps no cloud copy.

ML contract: Vision, bundled Core ML models, and local checks are allowed. Remote scoring, remote face calls, and remote vector stores are blocked. A remote AI plan needs a new review first.

Model training: user photos do not train models. This covers images, crops, faces, and embeddings. Local taste settings stay local.

---

## 3. Data classification (canonical)

This table is the single source for sensitivity and handling. Other docs link here.

| Data | Sensitivity | Stored | Sent off device |
|---|---|---|---|
| Original photo or video | Very high | No app copy, ref by ID only | Never |
| Thumbnail | High | Short cache only | Never |
| Capture date, size, orientation | High | Local if needed | Never by default |
| GPS, precise location | Very high | Avoid; do not keep | Never |
| Full EXIF blob | High | Do not keep | Never |
| Face box, landmarks | Very high | Memory or temp session only | Never |
| Face embedding, template, cluster | Very high | Not stored in MVP | Never |
| Face count, face quality score | Sensitive | Local if needed | Never at photo level |
| Sharpness, exposure, aesthetic scores | Moderate | Local | Never at photo level |
| Similarity features | High | Local temp | Never |
| Duplicate cluster ID, moment ID | Moderate | Local | Never at photo level |
| Selection choice (keep or skip) | Moderate | Local | Counts only, see 11 |
| Counts and time buckets | Low | Optional | Anonymous counts only, see 11 |
| Logs and crash notes | Low-moderate | Short local | No photo data, see §8 |

Rules behind the table:

- Keep only fields the picker needs. Drop the rest.
- Read only needed EXIF fields. Useful: time, orientation, size. Skip: serial, precise GPS, comments, maker notes.
- Prefer time, visual match, and order for moments. Avoid precise GPS. Do not build a place history.
- Store scores by `PHAsset.localIdentifier`. Do not copy full images into app files.
- Tag cached analysis with a version. Drop old results when the model changes.

Face detail categories live in `selection-rules.md`. This doc does not repeat them. It sets only the privacy limit: use faces to judge clarity and group strength. Do not name people. Do not link faces to contacts, mail, phones, or social IDs.

---

## 4. Logging redaction (sole owner)

09 is the only owner of logging redaction. No other doc defines log rules. 10 and 11 link here.

Blocked from all logs (prod and debug where possible):

```text
image data and thumbnail bytes
file paths and filenames
face crops, boxes, landmarks, embeddings, scores tied to a photo
GPS, place strings, full EXIF
full PHAsset.localIdentifier (log a short hash or index only)
```

Allowed style:

```text
"Analysis stage done"
"Batch size: 64"
"Vision request failed"
"Asset not available"
"ProcessingBatch(index: 7)"
```

Never log `Processing IMG_3812.JPG`. Never log asset IDs. Never log pixels.

Crash tools: turn off screenshots, view snaps with thumbs, and file-path capture. Check each SDK before release. Keep crumbs to app state. See §8 for network limits.

Debug screens (face boxes, scores, rule notes) are dev tools. Ship them only if they are real features. Else keep them `DEBUG`-only.

---

## 5. Permission policy

### 5.1 What access the app asks for

The app reads photos the user picks. It also saves the final album. So it asks for read-write library access. Add-only access is not enough.

Exact key (in app `Info.plist`):

- `NSPhotoLibraryUsageDescription`

Suggested text (short, true, calm):

```text
Photos Curator needs access to your photo library to analyze and select your best photos. Photo analysis is performed on your device.
```

No other permission is needed for MVP. Do not add camera, mic, contacts, location, motion, or tracking strings unless a feature needs them. API call shape and auth call details live in `apple-frameworks.md`.

### 5.2 When to ask

Do not ask at launch. Ask when the user taps Start or Select Photos. Show a short clear note first. Then show the system prompt.

The note says analysis runs on device. It does not push full access. Limited access stays valid.

Screen wording and full state flow live in `ux-flows.md`. This doc sets only timing and pressure rules.

### 5.3 Permission states (canonical)

This table is the single source for state handling. 02 and 07 link here.

| Status | Meaning | App action |
|---|---|---|
| `notDetermined` | Not asked yet | Explain, then ask once |
| `authorized` | Full access | Run curation |
| `limited` | Some photos only | Run on shared set; stay useful |
| `denied` | User said no | Show help with Settings path; do not loop prompts |
| `restricted` | System blocked | Show plain note; no fake retry |
| future value | Unknown | Fail safe; keep app stable |

Notes:

- Limited is a full state. It is not an error.
- Do not nag for full access. A quiet note is enough.
- Full access may find more moments. Say it as a gain. Never say it as a must.
- Re-check status on each run. Users can change it in Settings.
- Restricted often comes from device or family rules. Do not show Settings loop if the app cannot fix it.

UX copy for denied, restricted, and limited lives in 02. PhotoKit call patterns live in 07. This doc does not repeat them.

Single owner for auth code: one service owns status checks and asks. Screens call it. They do not copy logic. Shape lives in 07.

---

## 6. Retention and deletion (canonical)

This table is the single source for how long data lives. 08 links here for resume caches.

| Data | Where | Kept until | Delete action |
|---|---|---|---|
| Original photos | Apple library | Always kept by app rule | App never deletes them |
| Analysis cache (scores, clusters, moments) | App local store | Until reset or version change | Reset Analysis clears it |
| Thumbnails | Bounded cache | Short time, auto clear | Evict on pressure or session end |
| Session work (ranks, picks) | Memory or temp | Session end, cancel, or stale assets | Drop on close or cancel |
| Resume stub | App local | Short time, least fields only | Drop when done or stale |
| Logs | Local then service | Short time | Strip IDs first, see §4 |
| Metrics | Aggregates only | Per 11 | Per 11 |

Rules:

- Selected and Removed are picks (vocabulary in `ux-flows.md` §3). They are not delete orders.
- The app holds no delete-asset path in normal runs. AI suggests. The user acts.
- Reset Analysis clears cache, moments, dup groups, and history. It keeps originals.
- Session delete clears picks and temp files. It keeps originals.
- Uninstall clears app files per iOS rules. The photo library stays whole.
- Resume stubs hold IDs and progress only. No image copies. Full resume steps live in `performance.md`.
- The local store holds refs, scores, groups, picks, taste flags, versions, and times. It does not hold image blobs, face blobs, full EXIF, or embedding blobs.

---

## 7. Network, crash, and SDK limits

App networking never carries items in §2. The build should show this by design. Not just by care.

Crash reports carry no photo data. No thumbs in snaps. No paths. No IDs. No face notes. See §4.

Third-party SDKs: add as few as possible. Before each add, note why it is needed, what it sends, what domains it hits, if it has a privacy manifest, and if Apple code can do the job. Store answers with the release notes.

Ads: none in MVP. Tracking: none in MVP. Accounts: none in MVP. Backend for photos: none in MVP. A light backend for flags or anonymous counts is allowed only if it stays apart from image data.

Clipboard: do not copy image data, paths, face notes, or IDs there. Screenshots: no block needed. Keep sensitive app facts off photo screens.

Alerts: keep them plain. Good: "Your pick is ready." Bad: naming a person or count tied to identity. Full alert copy lives in 02.

---

## 8. Manifest and store disclosures (canonical paths)

Exact paths and keys. Use these strings in review.

- App permission key: `NSPhotoLibraryUsageDescription` in `apps/photo-curator/Info.plist` (app target `Info.plist`).
- Privacy manifest file: `PrivacyInfo.xcprivacy` at the app target root. Ship it when APIs or SDKs need it.
- Mirror the manifest to real use. Do not copy sample files. Do not claim false reasons.
- Before submit: build the Xcode privacy report. List each required-reason API. Keep only true reasons. Drop unused SDKs.
- App Store Connect answers must match the binary. Local-only photo use is not "collection" by itself. Include SDK acts too.
- Privacy policy URL is required. Link it in Settings and About. Cover: what the app reads, why, local-only face work, metrics per 11, third parties, keep times per §6, delete steps, how to revoke access, contact, and change date.
- Privacy claims must stay true. Allowed while true: "Runs on your device." "Photos are not sent to Photos Curator." Drop these lines if remote use starts.
- Watch for risky product shifts: cloud AI, CloudKit sync, face naming, lasting person groups, contact link, public share, ads, tracking, auto delete, GPS history, training on user photos. Each needs a doc update before code.

Privacy screen and onboarding copy live in 02. This doc owns only the facts they state.

---

## 9. Explicit exceptions

Narrow cases where the rule bends. Nothing else bends.

1. iCloud fetch: iOS may pull asset bytes from iCloud to finish a read. Allowed. The app still keeps no server copy.
2. Anonymous counts: input count, pick count, time bucket, and fail reason may leave device per 11. No IDs, no pixels, no faces, no GPS.
3. Crash service: stack and state may leave device. Stripped per §4. No photo content.
4. Album save: the app writes the final user-approved album to the library. This is a user act. Not auto delete.
5. Dev datasets: QA uses owned or licensed sets only. Never copy a real user library for tests. Full QA rules live in `manual-qa.md`.

---

## 10. Acceptance checks (privacy only)

Pass when all hold. Full test steps live in 10. Event names live in 11.

- AC-01: Fresh launch shows a clear note before the system ask. No ask at launch.
- AC-02: Full access runs a full session.
- AC-03: Limited access runs on the shared set. No block.
- AC-04: Denied shows help and a Settings path. No prompt loop.
- AC-05: A Settings change shows on next open.
- AC-06: No pixel or thumb bytes reach Photos Curator servers.
- AC-07: Face notes stay on device.
- AC-08: No face gets a real-world name or link.
- AC-09: Removing from the album does not delete library assets.
- AC-10: Reset clears app cache and keeps originals.
- AC-11: Metrics hold no pixels, thumbs, faces, GPS, names, or asset IDs.
- AC-12: Core pick runs offline once local bytes are ready.

Non-goals for MVP: cloud sync, shared editing, public share, server vision, federated learning, auto clean, lasting ID graphs, and cross-region law tools.

Guiding rule: if a leaner build can do the job, ship the leaner build.

---

## 11. Links and upkeep

- UX wording and flow: see `ux-flows.md`.
- Face and quality groups: see `selection-rules.md`.
- Engine inputs: see `selection-engine.md`.
- PhotoKit and Vision calls: see `apple-frameworks.md`.
- Resume and background: see `performance.md`.
- QA lists: see `manual-qa.md`.
- Metrics events: see `analytics.md`.

Check Apple docs before each big release: PhotoKit auth, Vision faces, privacy manifests, reason APIs, store answers, and face data terms. Platform rules can shift.
