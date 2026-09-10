import SwiftUI

/// G1 skeleton root. One `NavigationStack` with typed routes; permission rechecked
/// on appear and on return from Settings.
struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var appModel = appModel
        NavigationStack(path: $appModel.path) {
            Group {
                if appModel.hasSeenWelcome {
                    HomeView()
                } else {
                    WelcomeView()
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .welcome:
                    WelcomeView()
                case .permissionEducation:
                    PermissionEducationView()
                case .home:
                    HomeView()
                }
            }
        }
        .task {
            await appModel.refreshAuthorization()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await appModel.refreshAuthorization()
                }
            }
        }
    }
}
