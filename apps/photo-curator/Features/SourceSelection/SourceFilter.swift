import Foundation

enum SourceLoadState: Equatable, Sendable {
    case idle, loading, loaded, empty, denied, failed
}

enum SourcePreset: String, CaseIterable, Sendable {
    case all, lastMonth, last3Months, lastYear, favorites
}

struct SourceFilter: Equatable, Sendable {
    var preset: SourcePreset = .all
    var hideScreenshots = false

    func apply(to assets: [PhotoAsset]) -> [PhotoAsset] {
        let now = Date()
        let cal = Calendar.current
        let start: Date? = switch preset {
        case .all: nil
        case .lastMonth: cal.date(byAdding: .month, value: -1, to: now)
        case .last3Months: cal.date(byAdding: .month, value: -3, to: now)
        case .lastYear: cal.date(byAdding: .year, value: -1, to: now)
        case .favorites: nil
        }
        return assets.filter { asset in
            if hideScreenshots, asset.mediaSubtype == .screenshot {
                return false
            }
            if preset == .favorites, !asset.isFavorite {
                return false
            }
            guard let start, let date = asset.creationDate else { return true }
            return date >= start
        }
    }
}

enum SourceSelectionMutation {
    static func selectAllFiltered(
        filteredIDs: [AssetID],
        selectedIDs: Set<AssetID>
    ) -> Set<AssetID> {
        selectedIDs.union(filteredIDs)
    }

    static func deselectAllFiltered(
        filteredIDs: [AssetID],
        selectedIDs: Set<AssetID>
    ) -> Set<AssetID> {
        selectedIDs.subtracting(filteredIDs)
    }

    static func updateDragSelection(
        filteredIDs: [AssetID],
        initialSelected: Set<AssetID>,
        startIndex: Int,
        currentIndex: Int,
        isSelecting: Bool
    ) -> Set<AssetID>? {
        guard startIndex >= 0, startIndex < filteredIDs.count,
              currentIndex >= 0, currentIndex < filteredIDs.count else { return nil }
        let range = min(startIndex, currentIndex) ... max(startIndex, currentIndex)
        let rangeIDs = Set(filteredIDs[range])
        if isSelecting {
            return initialSelected.union(rangeIDs)
        }
        return initialSelected.subtracting(rangeIDs)
    }
}

struct SelectionSummary: Equatable, Sendable {
    let selectedCount: Int
    let unavailableCount: Int
}

/// Deterministic chrono order (private feat-004 implementation detail, not a
/// cross-chain contract): creationDate first, `localIdentifier` tiebreak
/// so equal/missing dates still freeze to one stable snapshot order.
private func stableChronoSorted(_ assets: [PhotoAsset]) -> [PhotoAsset] {
    assets.sorted {
        let left = $0.creationDate ?? .distantPast
        let right = $1.creationDate ?? .distantPast
        if left != right {
            return left < right
        }
        return $0.id.rawValue < $1.id.rawValue
    }
}
