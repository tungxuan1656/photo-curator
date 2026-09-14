import Foundation

/// Terminal save outcome for one session. S15 maps each case to copy;
/// `.saved` and usable `.partial` both carry the persisted album identity.
enum SaveOutcome: Sendable {
    case saved(state: SaveState)
    case partial(state: SaveState)
    case permissionLost
    case failed(ExportError)

    var saveState: SaveState? {
        switch self {
        case let .saved(state), let .partial(state):
            state
        case .permissionLost, .failed:
            nil
        }
    }
}
