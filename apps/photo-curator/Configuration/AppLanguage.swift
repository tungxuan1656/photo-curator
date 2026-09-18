import Foundation

/// The only language choices exposed by the product. The system case keeps a
/// live locale reference so it never stores a snapshot of the system language.
enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case systemDefault
    case english = "en"
    case vietnamese = "vi"

    var id: Self {
        self
    }

    var locale: Locale {
        switch self {
        case .systemDefault:
            .autoupdatingCurrent
        case .english:
            Locale(identifier: "en")
        case .vietnamese:
            Locale(identifier: "vi")
        }
    }
}
