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
