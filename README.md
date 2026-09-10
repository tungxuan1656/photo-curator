# Photos Curator

On-device-first iPhone app that turns hundreds or thousands of personal photos into a smaller, diverse, high-quality album the user reviews and approves.

![iOS 26](https://img.shields.io/badge/iOS-26-black) ![Swift 5](https://img.shields.io/badge/Swift-5-orange) ![SwiftUI](https://img.shields.io/badge/SwiftUI-Observation-blue) ![License: MIT](https://img.shields.io/badge/License-MIT-green)

> How much manual photo-review work can Photos Curator remove without making users feel that important memories were lost?

## How it works

```text
SOURCE PHOTOS → ANALYZE → GROUP INTO MOMENTS / SIMILAR SETS → RANK
  → BUILD DIVERSE ALBUM → USER REVIEW + CORRECTIONS → SAVE CURATED ALBUM
```

```text
Home → Choose Photos → Configure Curation → Processing
  → Curated Result → Review / Alternatives → Save Album → Completed
```

Product guarantees:

* Never deletes or modifies originals. Reject means "not in this album".
* Core curation runs on-device. No photo pixels leave the device for normal curation.
* No account, no login, no custom backend for the core flow.
* The user approves the final album. Manual edits are never silently overwritten.

## Tech stack

Swift 5 / SwiftUI + Observation, PhotoKit, Vision, Core ML. Single Xcode target, zero third-party runtime dependencies. File-based Codable persistence, no database for MVP. SwiftLint + SwiftFormat.

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

`./init.sh` runs format, strict lint, and a simulator build. Tests report `SKIP [test]` by policy: this repo has no test targets and validation is manual (see `docs/ship-gates/manual-qa.md`).

## Project structure

```text
apps/photo-curator/      Xcode project (scheme: photo-curator)
├── App/                 PhotoCuratorApp, AppContainer, AppModel, AppRoute
├── Features/            Onboarding, SourceSelection, Processing, Results, Review, Settings
├── Domain/              Models, Selection engine facade + stages, Scoring
├── Services/            Photos, Analysis, Cache, Export, Analytics
├── Infrastructure/      FileStore, SessionCheckpointStore, MemoryPressureObserver, Logging
├── SharedUI/            Thumbnails, empty/error states, components
├── Resources/           Assets, Localizable
└── Configuration/       AppConfiguration
docs/                    Product specs, design docs, ship gates, exec plans (start at docs/index.md)
features/                Per-feat scope + acceptance + handoff (index: feature_index.json)
```

Architecture rules: views render state only; a session coordinator sequences work; services own Apple-framework contact; the engine is a UI-free facade. Detail: `docs/design-docs/ios-architecture.md`.

## Docs

Start at [`docs/index.md`](docs/index.md) → `AGENTS.md` → one owner doc per task. Do not copy text between docs.

| Need | Read |
|---|---|
| Product scope and launch gates | `docs/product-specs/product.md` |
| Screens, copy, review behavior | `docs/product-specs/ux-flows.md` |
| Pick rules and sizing | `docs/product-specs/selection-rules.md` |
| Pipeline stages | `docs/design-docs/selection-engine.md` |
| Build order P0–P8 | `docs/exec-plans/roadmap.md` |
| Team execution (lanes, INT, git) | `docs/exec-plans/team-build-plan.md` |
| Privacy and retention | `docs/ship-gates/privacy.md` |
| Manual QA | `docs/ship-gates/manual-qa.md` |

## Build status and plan

* Current state: foundation stage (G0). See `feature_index.json` for the 18-feat plan across G0–G6 and `progress.md` for the latest result.
* Execution: two parallel lanes (A = Engine/Data, B = App/UI) inside each sequential stage, merged by a leader-owned `*INT` feat. Branch flow is `lane-*/feat-xxx` → `int/<stage>` → `main`. Detail: `docs/exec-plans/team-build-plan.md`.
* Success looks like: 1,000 messy photos become a shortlist the user keeps with only small fixes; duplicates suppressed; moments covered; originals untouched.

## Privacy

On-device analysis. No photo pixels, face data, embeddings, GPS, or asset IDs are uploaded to Photos Curator servers. Limited Photos access is a valid state, not an error. Full policy: `docs/ship-gates/privacy.md`.

## Contributing

1. Pick a `todo` feat whose `depends_on` feats are `done`; mark it `active`.
2. Branch `lane-A/feat-xxx` or `lane-B/feat-xxx`; touch only your `owns` files.
3. Run `./init.sh` before opening a PR into `int/<stage>`.
4. Keep scope inside the active feat; record evidence and handoff in `features/feat-<id>.md`.
5. Never add test targets, `*Test*.swift` files, or test-only architecture.

## License

MIT — see [LICENSE](LICENSE).
