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
                case .libraryDiscovery:
                    LibraryDiscoveryView(
                        snapshot: appModel.libraryComparisonSnapshot,
                        observations: appModel.libraryObservations,
                        catalogState: appModel.libraryCatalogState,
                        loadFailed: appModel.librarySnapshotLoadFailed,
                        onRefresh: { await appModel.loadLibrarySnapshot() },
                        onOpenGroup: { appModel.openLibraryGroup($0) },
                        onOpenPhoto: { appModel.openLibraryPhoto(assetID: $0, pagerIDs: $1) }
                    )
                    .task { await appModel.loadLibrarySnapshot() }
                case .libraryFacetedBrowsing:
                    Group {
                        if let result = appModel.libraryQueryResult {
                            LibraryFacetedBrowsingView(
                                result: result,
                                observations: appModel.libraryObservations,
                                personalLabels: appModel.libraryPersonalLabels,
                                onQueryChanged: { appModel.applyLibraryQuery($0) },
                                onOpenPhoto: { appModel.openLibraryPhoto(assetID: $0, pagerIDs: $1) },
                                onOpenGroup: { appModel.openLibraryQueryGroup($0) },
                                onEditLabels: { appModel.openLibraryLabelEditor(assetID: $0) },
                                onManagePersonalLabels: {
                                    Task { await appModel.refreshLibraryPersonalLabels() }
                                },
                                onSelectionChanged: { appModel.updateLibrarySelection($0) }
                            )
                        } else {
                            LibraryDiscoveryView(
                                snapshot: appModel.libraryComparisonSnapshot,
                                observations: appModel.libraryObservations,
                                catalogState: appModel.libraryCatalogState,
                                loadFailed: appModel.librarySnapshotLoadFailed || appModel.libraryQueryLoadFailed,
                                onRefresh: { await appModel.loadLibraryFacetedBrowsing() },
                                onOpenGroup: { appModel.openLibraryGroup($0) },
                                onOpenPhoto: { appModel.openLibraryPhoto(assetID: $0, pagerIDs: $1) }
                            )
                            .overlay {
                                if !appModel.libraryQueryLoadFailed {
                                    ProgressView("Preparing label filters")
                                        .padding()
                                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }
                    }
                    .task { await appModel.loadLibraryFacetedBrowsing() }
                case let .libraryGroup(groupID):
                    if let context = appModel.libraryGroupContext(for: groupID) {
                        LibraryGroupDetailView(
                            group: context.group,
                            coverage: context.coverage,
                            onOpenPhoto: { appModel.openLibraryPhoto(assetID: $0, pagerIDs: $1) }
                        )
                    } else {
                        ContentUnavailableView(
                            "Group unavailable",
                            systemImage: "square.stack.3d.up.slash",
                            description: Text("This group changed during a library refresh.")
                        )
                    }
                case let .libraryPhoto(assetID, pagerIDs):
                    LibraryPhotoInspector(
                        assetID: assetID,
                        pagerIDs: pagerIDs,
                        imageLoader: appModel.container.visibleImageLoader,
                        onDismiss: { appModel.dismissLibraryPhoto() }
                    )
                    .toolbar(.hidden, for: .navigationBar)
                case let .libraryLabelEditor(assetID):
                    Group {
                        if let editor = appModel.libraryLabelEditor, editor.assetID == assetID {
                            PhotoLabelEditor(
                                assetID: editor.assetID,
                                automaticLabels: editor.automaticLabels,
                                effectiveLabels: editor.effectiveLabels,
                                overrides: editor.overrides,
                                personalLabels: editor.personalLabels,
                                analysisState: editor.analysisState,
                                onOverride: { labelID, intent in
                                    try await appModel.setLibraryLabelOverride(
                                        assetID: assetID, labelID: labelID, intent: intent
                                    )
                                },
                                onRestore: { labelID in
                                    try await appModel.restoreLibraryAutomaticLabel(
                                        assetID: assetID, labelID: labelID
                                    )
                                },
                                onAssignPersonal: { labelID in
                                    try await appModel.assignLibraryPersonalLabel(labelID, to: assetID)
                                },
                                onRemovePersonal: { labelID in
                                    try await appModel.removeLibraryPersonalLabel(labelID, from: assetID)
                                },
                                onCreatePersonal: { name in
                                    try await appModel.createLibraryPersonalLabel(name, for: assetID)
                                }
                            )
                        } else if appModel.libraryLabelEditorLoadFailed {
                            ContentUnavailableView(
                                "Labels unavailable",
                                systemImage: "tag.slash",
                                description: Text("This photo's label state could not be loaded.")
                            )
                        } else {
                            ProgressView("Loading labels")
                        }
                    }
                    .task {
                        if appModel.libraryLabelEditor?.assetID != assetID {
                            await appModel.loadLibraryLabelEditor(assetID: assetID)
                        }
                    }
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
