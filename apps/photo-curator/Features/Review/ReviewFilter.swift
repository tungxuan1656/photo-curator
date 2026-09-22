import SwiftUI

/// Typed filter state for the shared workspace shell. Titles reuse owner
/// copy only (`ui-copy.md`); no untranslated fallback strings.
enum ReviewWorkspaceFilter: String, CaseIterable, Hashable, Sendable {
    case all
    case needsReview
    case albumDraft
    case staged

    var title: LocalizedStringResource {
        switch self {
        case .all: "Review Photos"
        case .needsReview: "Needs Review"
        case .albumDraft: "Album Draft"
        case .staged: "Review Staged Photos"
        }
    }
}
