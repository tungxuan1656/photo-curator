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

// TEMP(feat-006-task-2): minimal destinations so the additive routes compile before
// Task 3 delivers the real views. Task 3 deletes these stubs when adding the real
// ProcessingView/SettingsView/ReviewReadyView files (same type names).

/// Minimal processing destination. Reads the live run from the environment model;
/// the full progress/cancel/retry/error-gate UI arrives in Task 3.
struct ProcessingView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 16) {
            if appModel.activeSessionID != nil {
                Text("Curating your photos…")
                    .font(.title2)
                Text("Analysis happens on this iPhone. You can leave the app; progress is saved.")
                    .font(.body)
                Button("Cancel") {
                    appModel.cancelProcessing()
                }
            } else {
                Text("No active curation session.")
                    .font(.body)
                Button("Back to Home") {
                    appModel.goHome()
                }
            }
        }
        .padding()
        .navigationTitle("Processing")
    }
}

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

/// Minimal review-ready destination. Loads the persisted result for its session;
/// the full review UI arrives in Task 3 and reuses this route without renaming.
struct ReviewReadyView: View {
    @Environment(AppModel.self) private var appModel

    let sessionID: SessionID

    @State private var result: SelectionResult?

    var body: some View {
        VStack(spacing: 16) {
            Text("Your album is ready")
                .font(.title2)
            if let result {
                Text("\(result.selectedAssetIDs.count) photos selected.")
                    .font(.body)
            } else {
                Text("Loading your selection…")
                    .font(.body)
            }
            Button("Back to Home") {
                appModel.goHome()
            }
        }
        .padding()
        .navigationTitle("Review")
        .task {
            result = await appModel.loadResult(for: sessionID)
        }
    }
}
