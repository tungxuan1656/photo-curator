import SwiftUI
import UIKit

/// Catalog-first home. Legacy session routes remain reachable only through their
/// matching saved-work or recovery surfaces.
struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showsAccessGuidance = false

    var body: some View {
        @Bindable var appModel = appModel
        ScrollView {
            VStack(spacing: 24) {
                HomeHeroBanner()

                libraryEntryCard(appModel: appModel)

                actionArea(appModel: appModel)

                HomeHowItWorksSection()

                HomeFeatureHighlights()
            }
        }
        .navigationTitle("Photos Curator")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape") {
                    appModel.openSettings()
                }
            }
        }
        .sheet(isPresented: $showsAccessGuidance) {
            AccessGuidanceSheet()
        }
    }

    private func actionArea(appModel: AppModel) -> some View {
        VStack(spacing: 16) {
            if !appModel.libraryActionContexts.isEmpty {
                Button {
                    appModel.openLibrarySavedWork()
                } label: {
                    Label(String(localized: "library.savedWork.title"), systemImage: "tray.full")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            if !appModel.deletionRecoveryOperations.isEmpty {
                Button {
                    if appModel.path.last != .deletionRecovery {
                        appModel.path.append(.deletionRecovery)
                    }
                } label: {
                    Label(String(localized: "home.recovery.title"), systemImage: "exclamationmark.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .accessibilityHint(String(localized: "home.recovery.hint"))
            }
            authorizationActionArea(appModel: appModel)
        }
    }

    @ViewBuilder
    private func authorizationActionArea(appModel: AppModel) -> some View {
        switch appModel.authorization {
        case .authorized, .limited:
            if appModel.authorization == .limited {
                limitedAccessBanner
            }
        case .notDetermined:
            permissionCard(
                icon: "photo.on.rectangle.angled",
                iconColor: Color.accentColor,
                title: "Photos Access Needed",
                message: "Allow photo access to choose images for curation.",
                primaryButtonTitle: "Continue"
            ) {
                appModel.showPermissionEducation()
            }
        case .denied:
            permissionCard(
                icon: "lock.shield",
                iconColor: .secondary,
                title: "Photos Access Needed",
                message: "Allow photo access to choose images for curation.",
                primaryButtonTitle: "Open Settings"
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        case .restricted:
            permissionCard(
                icon: "exclamationmark.triangle",
                iconColor: .secondary,
                title: "Photos Access Restricted",
                message: "Photos access is restricted on this device.",
                primaryButtonTitle: nil,
                primaryAction: nil
            )
        }
    }

    private func libraryEntryCard(appModel: AppModel) -> some View {
        Button {
            appModel.openLibraryDiscovery()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.title2)
                    .foregroundStyle(Color.curatorAccent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("home.library.title")
                        .font(.headline)
                    Text("home.library.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityHint(String(localized: "home.library.hint"))
    }

    private var limitedAccessBanner: some View {
        Button {
            showsAccessGuidance = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .foregroundStyle(Color.accentColor)
                Text("Limited Photos Access — Choose More Photos")
                    .font(.caption.bold())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private func permissionCard(
        icon: String,
        iconColor: Color,
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        primaryButtonTitle: LocalizedStringResource?,
        primaryAction: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let primaryButtonTitle, let primaryAction {
                Button(primaryButtonTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }

            Button("Learn More") {
                showsAccessGuidance = true
            }
            .font(.footnote)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
    }
}

private struct HomeHeroBanner: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.curatorSubtleGlow)
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 38))
                    .foregroundStyle(LinearGradient.curatorSunset)
            }
            .padding(.top, 4)

            VStack(spacing: 6) {
                Text("home.hero.title")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text(
                    "home.hero.subtitle"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
        }
    }
}

private struct HomeHowItWorksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("home.howItWorks")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                stepRow(
                    number: "1",
                    title: "home.steps.library.title",
                    subtitle: "home.steps.library.subtitle"
                )
                Divider().padding(.leading, 46)
                stepRow(
                    number: "2",
                    title: "home.steps.inspect.title",
                    subtitle: "home.steps.inspect.subtitle"
                )
                Divider().padding(.leading, 46)
                stepRow(
                    number: "3",
                    title: "home.steps.action.title",
                    subtitle: "home.steps.action.subtitle"
                )
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal)
        }
    }

    private func stepRow(
        number: String,
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.curatorSubtleGlow)
                    .frame(width: 32, height: 32)
                Text(number)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.curatorAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct HomeFeatureHighlights: View {
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            card(
                icon: "lock.shield",
                iconColor: .green,
                title: "home.feature.private.title",
                headline: "home.feature.private.headline",
                subtext: "home.feature.private.subtitle"
            )
            card(
                icon: "checkmark.shield",
                iconColor: .green,
                title: "home.feature.actions.title",
                headline: "home.feature.actions.headline",
                subtext: "home.feature.actions.subtitle"
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }

    private func card(
        icon: String,
        iconColor: Color,
        title: LocalizedStringResource,
        headline: LocalizedStringResource,
        subtext: LocalizedStringResource
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
            }
            .font(.caption.bold())
            .foregroundStyle(iconColor)
            Text(headline)
                .font(.subheadline.bold())
            Text(subtext)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
