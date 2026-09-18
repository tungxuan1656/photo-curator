import Foundation

/// Presentation copy for persisted processing stages.
///
/// `ProcessingStage` remains a stable data value in the session layer. This
/// extension keeps its localized representation at the UI boundary, where
/// SwiftUI and the active locale can resolve it.
extension ProcessingStage {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .loading:
            "Preparing photos"
        case .analysis:
            "Analyzing photos"
        case .clustering, .momentDetection:
            "Grouping similar shots"
        case .ranking:
            "Choosing the best photos"
        case .finalSelection:
            "Finishing your album"
        }
    }
}
