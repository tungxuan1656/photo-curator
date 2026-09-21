# Photos Curator

On-device iPhone app for assisted photo review. Clean Up Photos and Build an Album share one workspace; the user controls every choice.

![iOS 26](https://img.shields.io/badge/iOS-26-black) ![Swift 5](https://img.shields.io/badge/Swift-5-orange) ![SwiftUI](https://img.shields.io/badge/SwiftUI-Observation-blue) ![License: MIT](https://img.shields.io/badge/License-MIT-green)

> How much manual photo-review work can Photos Curator remove without making users feel that important memories were lost?

## How it works

```text
SOURCE PHOTOS → ANALYZE → GROUP / SUGGEST → USER REVIEW
  → SAVE ALBUM or REVIEW STAGED PHOTOS → CONFIRM ORIGINAL DELETION
```

```text
Home → Clean Up Photos / Build an Album → Choose Photos → Analyze / Resume
  → Shared Review Workspace → Independent Album Save / Confirmed Cleanup
```

Product guarantees:

* Never deletes originals automatically. Deletion requires full Photos read-write access and exact-set user confirmation.
* Core curation runs on-device. No photo pixels leave the device for normal curation.
* No account, no login, no custom backend for the core flow.
* The user approves the final album. Manual edits are never silently overwritten.

## Tech stack

Swift 5 / SwiftUI + Observation, PhotoKit, Vision, Core ML, and SwiftData. One app target with Swift Package dependencies. Durable workspace choices use SwiftData; analyses, checkpoints, caches, and model artifacts remain file/cache-backed. SwiftLint + SwiftFormat.

The flows above describe the target product. Workspace persistence and legacy import are implemented; shared review, resilient album save, and confirmed deletion follow the [feature tracker](feature_index.json). Qwen remains unadmitted; dependencies alone do not establish model admission.

## Requirements

* Xcode with iOS 26 SDK, iPhone running iOS 26 (see `docs/design-docs/apple-frameworks.md`).
* No backend, no API keys, no accounts.

## Quickstart

```bash
git clone <repo-url> photo-curator
cd photo-curator
./init.sh
open apps/photo-curator.xcodeproj
```

`./init.sh` runs format, strict lint, and a simulator build. Tests report `SKIP [test]` by policy: this repo has no test targets. A passing `./init.sh` is the automated verification evidence for behavior-changing features; do not add standalone proof files or harnesses. Manual QA (see `docs/ship-gates/manual-qa.md`) is optional non-blocking guidance per DEC-032.

## Project structure

```text
apps/photo-curator.xcodeproj/  Xcode project (scheme: photo-curator)
apps/photo-curator/            App source and resources
├── PhotoCuratorApp.swift      App entry
├── App/                      Composition, app model, routes
├── Features/                 Onboarding, source selection, processing, review, settings
├── Domain/                   Models and selection logic
├── Services/                 PhotoKit, analysis, session coordination, export, intelligence
├── Infrastructure/           WorkspaceStore, legacy importer, files and checkpoints
└── SharedUI/                 Shared view components
docs/                    Product specs, design docs, ship gates, exec plans (start at docs/index.md)
features/                Per-feat scope + acceptance + handoff (index: feature_index.json)
```

Architecture rules: views render state only; a session coordinator sequences work; services own Apple-framework contact; the engine is a UI-free facade. Detail: `docs/design-docs/ios-architecture.md`.

## Docs

Start at [`AGENTS.md`](AGENTS.md) → [`docs/index.md`](docs/index.md) → one owner doc per task.

| Need | Read |
|---|---|
| Product scope and launch gates | `docs/product-specs/product.md` |
| Screens, copy, review behavior | `docs/product-specs/ux-flows.md` |
| Review choices and deletion safety | `docs/product-specs/review-rules.md` |
| Facts and advisory suggestions | `docs/design-docs/photo-intelligence.md` |
| Build order | `docs/exec-plans/roadmap.md` |
| Execution (sequential feats, git) | `feature_index.json` + `features/feat-template.md` |
| Privacy and retention | `docs/ship-gates/privacy.md` |
| Manual QA | `docs/ship-gates/manual-qa.md` |

## Build status and plan

* Current status and dependencies: `feature_index.json`; evidence and handoff: the selected feature and latest relevant `progress.md` entry.
* Execution: at most one active feature; dependencies must be complete before activation.
* Success means less review work while preserving user choices across analysis, resume, album save, and cleanup.

## Privacy

On-device analysis. No photo pixels, face data, embeddings, GPS, or asset IDs are uploaded to Photos Curator servers. Limited Photos access is a valid state, not an error. Full policy: `docs/ship-gates/privacy.md`.

## Contributing

1. Obtain user approval for a `todo` feature whose dependencies are `done`, then activate it.
2. Follow its ownership and linked plan; preserve unrelated working-tree changes.
3. Run `./init.sh` before opening a PR into `main`.
4. Keep scope inside the active feat; record evidence and handoff in `features/feat-<id>.md`.
5. Never add test targets, `*Test*.swift` files, or test-only architecture.

## License

MIT — see [LICENSE](LICENSE).
