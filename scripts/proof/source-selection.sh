#!/usr/bin/env bash
# Source-selection proof harness. It compiles the shipped selection mutation
# seam verbatim for the iOS Simulator and exercises bulk selection, inclusive
# range dragging, invalid drag bounds, and filter boundaries. This is proof
# evidence, not a test target or test framework.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$ROOT_DIR/scripts/proof/out/source-selection"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
TARGET="arm64-apple-ios26.5-simulator"
DEVICE="iPhone 17 Pro"
STAGE="$OUT_DIR/stage"

rm -rf "$OUT_DIR"
mkdir -p "$STAGE"

SOURCES=(
  "$ROOT_DIR/apps/photo-curator/Domain/Models/AssetIDs.swift"
  "$ROOT_DIR/apps/photo-curator/Domain/Models/PhotoAsset.swift"
  "$ROOT_DIR/apps/photo-curator/Features/SourceSelection/SourceFilter.swift"
)
STAGED_SOURCES=()
for source in "${SOURCES[@]}"; do
  rel="${source#"$ROOT_DIR/"}"
  staged="$STAGE/$rel"
  mkdir -p "$(dirname "$staged")"
  cp "$source" "$staged"
  cmp -s "$source" "$staged"
  STAGED_SOURCES+=("$staged")
done

HARNESS="$ROOT_DIR/scripts/proof/source-selection-proof.swift"
cp "$HARNESS" "$STAGE/source-selection-proof.swift"

APP_MODEL="$ROOT_DIR/apps/photo-curator/App/AppModel.swift"
for symbol in selectAllFiltered deselectAllFiltered updateDragSelection; do
  rg -q "SourceSelectionMutation\.$symbol" "$APP_MODEL"
done

echo "STAGED-MATCH ${#SOURCES[@]}"
xcrun --sdk iphonesimulator swiftc \
  -O -target "$TARGET" -sdk "$SDK" \
  "${STAGED_SOURCES[@]}" "$STAGE/source-selection-proof.swift" \
  -o "$OUT_DIR/source-selection-proof"

xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl spawn "$DEVICE" "$OUT_DIR/source-selection-proof"
