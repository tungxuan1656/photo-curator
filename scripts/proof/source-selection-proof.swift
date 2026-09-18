import Foundation

var passes = 0
var failures = 0

func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() {
        passes += 1
        print("PASS \(name)")
    } else {
        failures += 1
        print("FAIL \(name)")
    }
}

func assetIDs(_ values: [Int]) -> Set<AssetID> {
    Set(values.map { AssetID(rawValue: "asset-\($0)") })
}

func sourceAssets() -> [PhotoAsset] {
    (0 ..< 6).map { index in
        PhotoAsset(
            id: AssetID(rawValue: "asset-\(index)"),
            creationDate: nil,
            pixelWidth: 1000,
            pixelHeight: 1000,
            mediaSubtype: index == 5 ? .screenshot : .standard,
            isFavorite: index == 1 || index == 3,
            isEdited: false,
            source: .local
        )
    }
}

func runProof() {
    let allAssets = sourceAssets()
    let allIDs = allAssets.map(\.id)
    let filteredIDs = SourceFilter(preset: .all, hideScreenshots: true)
        .apply(to: allAssets)
        .map(\.id)

    let outsideSelection = assetIDs([5])
    let selectedAll = SourceSelectionMutation.selectAllFiltered(
        filteredIDs: filteredIDs,
        selectedIDs: outsideSelection
    )
    check(selectedAll == assetIDs([0, 1, 2, 3, 4, 5]), "select-all preserves outside selection")

    let deselectedAll = SourceSelectionMutation.deselectAllFiltered(
        filteredIDs: filteredIDs,
        selectedIDs: selectedAll
    )
    check(deselectedAll == outsideSelection, "deselect-all affects only filtered assets")

    let rangeSelected = SourceSelectionMutation.updateDragSelection(
        filteredIDs: filteredIDs,
        initialSelected: outsideSelection,
        startIndex: 1,
        currentIndex: 3,
        isSelecting: true
    )
    check(rangeSelected == assetIDs([1, 2, 3, 5]), "drag select is inclusive and preserves baseline")

    let rangeDeselected = SourceSelectionMutation.updateDragSelection(
        filteredIDs: allIDs,
        initialSelected: assetIDs([0, 1, 2, 3, 4, 5]),
        startIndex: 4,
        currentIndex: 2,
        isSelecting: false
    )
    check(rangeDeselected == assetIDs([0, 1, 5]), "reverse drag deselects the inclusive range")

    let invalidDrag = SourceSelectionMutation.updateDragSelection(
        filteredIDs: filteredIDs,
        initialSelected: outsideSelection,
        startIndex: -1,
        currentIndex: 2,
        isSelecting: true
    )
    check(invalidDrag == nil, "out-of-bounds drag is ignored")

    let favorites = SourceFilter(preset: .favorites, hideScreenshots: false)
        .apply(to: allAssets)
        .map(\.id)
    let boundarySelection = SourceSelectionMutation.selectAllFiltered(
        filteredIDs: favorites,
        selectedIDs: assetIDs([0])
    )
    check(boundarySelection == assetIDs([0, 1, 3]), "filter boundary excludes non-matching assets")
}

@main
struct SourceSelectionProof {
    static func main() {
        runProof()
        print("\(passes) PASS / \(failures) FAIL")
        if failures > 0 {
            print("RESULT FAIL")
            exit(1)
        }
        print("RESULT PASS")
    }
}
