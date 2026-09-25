# Photos Curator

An on-device companion to Apple Photos for finding similar shots and organizing photos with useful labels.

## Product direction

```text
Authorized Photos access → catalog faceted discovery → incremental analysis
  → similar groups + labels → combined filters → inspect / compare
  → select photos → label / add to album / stage deletion
  → Saved Work recovery
```

Similar-photo grouping is the first priority. Labels help users find and narrow the photos they want to handle.
Albums and cleanup are downstream actions, not required entry intents.
The app references originals in Apple Photos instead of copying the library.
It does not edit photos or replace everyday Photos viewing.

## Implementation status

The current code has catalog discovery, native analysis, revision-aware caches, durable action contexts,
Saved Work recovery, and separate album/deletion operations. Legacy session flows are retained as
recovery-only compatibility paths; they are not new entry routes.
See the [roadmap](docs/exec-plans/roadmap.md) and [feature tracker](feature_index.json) for delivery state.
No model or image-accuracy claim is implied by the new direction.

## Core constraints

- Local photo processing, no account or app photo backend.
- Limited Photos access remains useful; the app works only with accessible assets.
- User labels and corrections survive re-analysis.
- Original deletion requires exact-set confirmation and full read-write access under the product policy.
- Analysis can pause and resume; completion after app suspension is not promised.
- English/Vietnamese UI; iPhone 14+ / iOS 26+ planning baseline.

## Development

Swift 5, SwiftUI + Observation, PhotoKit, Vision, SwiftData, and local runtime seams.
The project uses SwiftLint, SwiftFormat, and one Xcode app target.
Qwen-related source/packages remain legacy material; Qwen is not an admitted live analysis provider.

From the repository root:

```bash
./init.sh
open apps/photo-curator.xcodeproj
```

Use Xcode compatible with the project's current SDK/deployment settings.
The scheme is `photo-curator`.
`./init.sh` runs formatting, strict lint, and a generic iOS Simulator build.
Tests report `SKIP [test]` under DEC-040. Do not add test targets or standalone proof harnesses.
Build success does not establish image accuracy or iPhone performance.

## Repository map

| Path | Responsibility |
|---|---|
| `apps/photo-curator/App/` | Composition, app state, routes |
| `apps/photo-curator/Features/` | UI and presentation models |
| `apps/photo-curator/Domain/` | Value models and image-selection/grouping logic |
| `apps/photo-curator/Services/` | Photos, analysis, lifecycle, album/deletion boundaries |
| `apps/photo-curator/Infrastructure/` | SwiftData stores, files, migration, checkpoints |
| `docs/` | Canonical product and technical contracts |
| `features/` | Feature scope, acceptance, evidence, handoff |

## Read next

- [Documentation index](docs/index.md): task routes and ownership.
- [Product](docs/product-specs/product.md): accepted direction and scope.
- [Organization rules](docs/product-specs/organization-rules.md): labels, groups, filters.
- [Architecture](docs/design-docs/ios-architecture.md): observed code and intended boundaries.
- [Roadmap](docs/exec-plans/roadmap.md): transition features and dependencies.
- [Privacy](docs/ship-gates/privacy.md): local data and retention.
- [AGENTS.md](AGENTS.md): repository workflow and verification.

## Contribution flow

Obtain approval before activating a `todo` feature. Complete its dependencies first.
Keep changes within its scope, run `./init.sh`, and record actual evidence and limitations.
Preserve historical feature results; current owner documents define current intended behavior.

## License

MIT — see [LICENSE](LICENSE). Model artifacts require their own license review.
