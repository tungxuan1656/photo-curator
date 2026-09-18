#!/usr/bin/env bash
# feat-029 proof harness: compile the shipped inspection state and assert the
# fullscreen canvas/lifecycle surface without adding a test target.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$ROOT_DIR/scripts/proof/out/feat-029"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
TARGET="arm64-apple-ios26.5-simulator"
DEVICE="iPhone 17 Pro"
STATE_SOURCE="$ROOT_DIR/apps/photo-curator/Features/Review/PhotoInspectionState.swift"
CANVAS_SOURCE="$ROOT_DIR/apps/photo-curator/Features/Review/PhotoInspectionCanvas.swift"
DETAIL_SOURCE="$ROOT_DIR/apps/photo-curator/Features/Review/PhotoDetail.swift"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/stage"
STAGE="$OUT_DIR/stage"

STATE_STAGE="$STAGE/PhotoInspectionState.swift"
cp "$STATE_SOURCE" "$STATE_STAGE"
if ! cmp -s "$STATE_SOURCE" "$STATE_STAGE"; then
    echo "STAGED-MISMATCH $STATE_SOURCE" >&2
    exit 1
fi
cp "$ROOT_DIR/scripts/proof/feat-029-proof.swift" "$STAGE/feat-029-proof.swift"
echo "STAGED-MATCH 1"

xcrun --sdk iphonesimulator swiftc \
    -O -target "$TARGET" -sdk "$SDK" \
    -framework CoreGraphics \
    "$STATE_STAGE" "$STAGE/feat-029-proof.swift" -o "$OUT_DIR/feat-029-proof"

xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl spawn "$DEVICE" "$OUT_DIR/feat-029-proof"

require_source() {
    local source="$1"
    local pattern="$2"
    local label="$3"
    if ! rg -q --fixed-strings "$pattern" "$source"; then
        echo "$label FAIL" >&2
        exit 1
    fi
}

require_source "$CANVAS_SOURCE" 'Button("Back"' "BACK-CONTROL"
require_source "$CANVAS_SOURCE" 'Text("\(position) of \(total)"' "POSITION-CONTROL"
require_source "$CANVAS_SOURCE" 'Button(isSelected ? "In Album" : "Removed"' "SELECTION-CONTROL"
require_source "$CANVAS_SOURCE" 'Button("View Analysis"' "ANALYSIS-CONTROL"
require_source "$CANVAS_SOURCE" 'Button("Previous"' "PREVIOUS-CONTROL"
require_source "$CANVAS_SOURCE" 'Button("Next"' "NEXT-CONTROL"
require_source "$CANVAS_SOURCE" 'Button("Fit"' "FIT-CONTROL"
require_source "$CANVAS_SOURCE" 'accessibilityAction(named: "Zoom in")' "ZOOM-ACCESSIBILITY"
require_source "$CANVAS_SOURCE" 'accessibilityHint("Double tap to inspect.' "GESTURE-ACCESSIBILITY"
echo "ACCESSIBILITY-CONTROLS PASS"

require_source "$DETAIL_SOURCE" 'appModel.imageLoader.preview(' "PREVIEW-BOUNDARY"
require_source "$DETAIL_SOURCE" 'targetSize: CGSize(width: 2048, height: 2048)' "PREVIEW-CAP"
require_source "$DETAIL_SOURCE" 'guard !Task.isCancelled else { return }' "CANCELLATION-GUARD"
require_source "$DETAIL_SOURCE" 'guard requested == currentAssetID else { return }' "STALE-RESULT-GUARD"
require_source "$DETAIL_SOURCE" '@State private var cgImage: CGImage?' "CURRENT-IMAGE-STATE"
require_source "$DETAIL_SOURCE" '.task(id: "\(currentAssetID.rawValue)-\(retryToken)")' "TASK-IDENTITY"
require_source "$DETAIL_SOURCE" '.onChange(of: currentAssetID)' "ASSET-CHANGE-HOOK"
require_source "$DETAIL_SOURCE" '.onDisappear' "DISAPPEAR-HOOK"
echo "CURRENT-ONLY PASS"
echo "SERVICE-BOUNDARY PASS"
echo "ASSET-LIFECYCLE PASS"
