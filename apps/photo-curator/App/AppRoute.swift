import Foundation

/// Typed navigation routes for the app. Legacy selection/review routes remain
/// session-scoped; library routes are independent of a curation session.
enum AppRoute: Hashable, Sendable {
    /// Reserved: first-run entry, shown as root (never pushed) in G1.
    case welcome
    /// Pushed from Welcome/Get Started and Home/Continue in G1.
    case permissionEducation
    /// Reserved: Home is the root (never pushed) in G1; later stages push it.
    case home
    case libraryDiscovery
    case libraryFacetedBrowsing
    case libraryActionPreview
    case librarySavedWork
    case libraryGroup(groupID: UUID)
    case libraryPhoto(assetID: AssetID, pagerIDs: [AssetID])
    case libraryLabelEditor(assetID: AssetID)
    case sourceSelection
    case summary
    case processing(sessionID: SessionID)
    case settings
    case reviewWorkspace(sessionID: SessionID)
    case cleanupReview(sessionID: SessionID)
    case deletionRecovery
    case reviewOverview(sessionID: SessionID)
    case curatedGrid(sessionID: SessionID)
    case similarGroups(sessionID: SessionID)
    case removedPhotos(sessionID: SessionID)
    case needsReview(sessionID: SessionID)
    case finalReview(sessionID: SessionID)
    case saving(sessionID: SessionID)
    case completion(sessionID: SessionID)
}
