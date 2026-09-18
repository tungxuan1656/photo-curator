#!/usr/bin/env bash
# feat-028 proof harness: compile the shipped deterministic ranker boundary
# verbatim and evaluate fixed synthetic labels on disjoint smoke, Golden-shaped,
# trip-shaped, and 1k-scale fixtures. No test target or framework.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$ROOT_DIR/scripts/proof/out/feat-028"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
TARGET="arm64-apple-ios26.5-simulator"
DEVICE="iPhone 17 Pro"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/stage"
STAGE="$OUT_DIR/stage"

SOURCES=(
  "$ROOT_DIR/apps/photo-curator/Configuration/AppConfiguration.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Models/AssetIDs.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Models/PhotoAnalysis.swift"
  "$ROOT_DIR/apps/photo-curator/Services/Analysis/ImageSimilarityArtifact.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Models/PhotoAsset.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Models/SelectionGrouping.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Models/SelectionResult.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Scoring/QualityScorer.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Selection/DiversitySelector.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Selection/DuplicateResolver.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Selection/FinalAlbumBuilder.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Selection/GlobalDiversityGraph.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Selection/MomentBuilder.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Selection/SelectionEngine.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Selection/VisualEmbeddingProvider.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Selection/SemanticJury.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Selection/UncertaintyReview.swift"
)
for source in "${SOURCES[@]}"; do
  rel="${source#"$ROOT_DIR/"}"
  staged="$STAGE/$rel"
  mkdir -p "$(dirname "$staged")"
  cp "$source" "$staged"
  if ! cmp -s "$source" "$staged"; then
    echo "STAGED-MISMATCH $source" >&2
    exit 1
  fi
  STAGED_SOURCES+=("$staged")
done

HARNESS="$ROOT_DIR/scripts/proof/feat-028-proof.swift"
cp "$HARNESS" "$STAGE/feat-028-proof.swift"
STAGED_N=${#SOURCES[@]}
echo "STAGED-MATCH $STAGED_N"

xcrun --sdk iphonesimulator swiftc \
  -O -target "$TARGET" -sdk "$SDK" \
  -framework Foundation -framework CoreGraphics -framework CryptoKit -framework Vision \
  "${STAGED_SOURCES[@]}" "$STAGE/feat-028-proof.swift" -o "$OUT_DIR/feat-028-proof"
xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl spawn "$DEVICE" "$OUT_DIR/feat-028-proof"
