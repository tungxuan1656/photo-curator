import Foundation
import Observation

/// G1 skeleton session state. Runs on the `PhotoLibraryService` protocol (Noop in G1);
/// real permission wiring lands in feat-002INT.
@MainActor
@Observable
final class AppModel {
    private static let seenWelcomeKey = "hasSeenWelcome"

    var path: [AppRoute] = []
    var authorization: PhotoLibraryAuthorization = .notDetermined
    var hasSeenWelcome: Bool

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        hasSeenWelcome = UserDefaults.standard.bool(forKey: Self.seenWelcomeKey)
    }

    func showPermissionEducation() {
        if !path.contains(.permissionEducation) {
            path.append(.permissionEducation)
        }
    }

    func skipPermission() {
        markSeen()
        path = []
    }

    func refreshAuthorization() async {
        authorization = await container.photoLibrary.authorizationStatus()
    }

    func requestPermission() async {
        authorization = await container.photoLibrary.requestAuthorization()
        markSeen()
        path = []
    }

    private func markSeen() {
        hasSeenWelcome = true
        UserDefaults.standard.set(true, forKey: Self.seenWelcomeKey)
    }
}
