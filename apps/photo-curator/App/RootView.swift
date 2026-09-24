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
                case let .reviewWorkspace(id):
                    if appModel.reviewModel?.sessionID == id {
                        ReviewWorkspaceView(sessionID: id)
                    } else {
                        ReviewLoadFailedView(sessionID: id)
                    }
                case let .cleanupReview(id):
                    CleanupReviewView(sessionID: id)
                case .deletionRecovery:
                    DeletionRecoveryView()
                case let .reviewOverview(id):
                    if appModel.reviewModel?.sessionID == id {
                        ReviewOverview(sessionID: id)
                    } else {
                        ReviewLoadFailedView(sessionID: id)
                    }
                case let .curatedGrid(id):
                    if appModel.reviewModel?.sessionID == id {
                        CuratedGrid(sessionID: id)
                    } else {
                        ReviewLoadFailedView(sessionID: id)
                    }
                case let .similarGroups(id):
                    if appModel.reviewModel?.sessionID == id {
                        SimilarGroups(sessionID: id)
                    } else {
                        ReviewLoadFailedView(sessionID: id)
                    }
                case let .removedPhotos(id):
                    if appModel.reviewModel?.sessionID == id {
                        RemovedPhotos(sessionID: id)
                    } else {
                        ReviewLoadFailedView(sessionID: id)
                    }
                case let .needsReview(id):
                    if appModel.reviewModel?.sessionID == id {
                        NeedsReview(sessionID: id)
                    } else {
                        ReviewLoadFailedView(sessionID: id)
                    }
                case let .finalReview(id):
                    if appModel.reviewModel?.sessionID == id {
                        FinalReview(sessionID: id)
                    } else {
                        ReviewLoadFailedView(sessionID: id)
                    }
                case let .saving(id):
                    Saving(sessionID: id)
                case let .completion(id):
                    Completion(sessionID: id)
                }
            }
        }
        .task {
            await appModel.startup()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                Task { await appModel.applicationDidEnterBackground() }
            }
            if newPhase == .active {
                Task { await appModel.applicationDidBecomeActive() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoLibraryDidChange)) { _ in
            appModel.reconcileCatalog()
        }
        .safeAreaInset(edge: .top) {
            if appModel.path.isEmpty, !appModel.deletionRecoveryOperations.isEmpty {
                Button {
                    appModel.path.append(.deletionRecovery)
                } label: {
                    Label(
                        "Deletion needs your attention",
                        systemImage: "exclamationmark.arrow.circlepath"
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.horizontal)
                .accessibilityHint("Review saved deletion outcomes; no deletion will restart automatically")
            }
        }
    }
}
