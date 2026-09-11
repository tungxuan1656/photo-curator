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
                case .sourceSelection:
                    SourceSelectionView()
                case .summary:
                    SelectionSummaryView()
                case .processing:
                    ProcessingView()
                case .settings:
                    SettingsView()
                case let .reviewReady(id):
                    ReviewReadyView(sessionID: id)
                }
            }
        }
        .task {
            await appModel.refreshAuthorization()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                Task { await appModel.checkpointForBackground() }
            }
            if newPhase == .active {
                Task {
                    await appModel.refreshAuthorization()
                    await appModel.resumeIfPaused()
                }
            }
        }
    }
}

// TEMP(feat-006-task-2, kept for Task 4): minimal settings destination so the
// additive `.settings` route compiles before Task 4 delivers the real
// SettingsView. Task 3 deleted the ProcessingView/ReviewReadyView stubs here
// when adding the real same-named views in Features/Processing.

/// Minimal settings destination. Full copy/controls arrive in Task 4.
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Settings")
                .font(.title2)
            Text("Curation settings will live here.")
                .font(.body)
        }
        .padding()
        .navigationTitle("Settings")
    }
}
