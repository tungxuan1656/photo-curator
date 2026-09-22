import SwiftUI
import UIKit

/// S04 Home skeleton. Copy owned by ux-flows §6.1. Denied/restricted replace the CTA
/// with the access-required card (never a dead Curate Photos button).
struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showsAccessGuidance = false

    var body: some View {
        @Bindable var appModel = appModel
        ScrollView {
            VStack(spacing: 24) {
                HomeHeroBanner()

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
        .confirmationDialog(
            "Discard this curation?",
            isPresented: $appModel.confirmingNewSession,
            titleVisibility: .visible
        ) {
            Button("Discard Curation", role: .destructive) { appModel.startNewSession(confirmed: true) }
            Button("Keep Curation", role: .cancel) { appModel.startNewSession(confirmed: false) }
        } message: {
            Text("Your original photos will stay unchanged. The current analysis and selection will be removed.")
        }
        .sheet(isPresented: $showsAccessGuidance) {
            AccessGuidanceSheet()
        }
    }

    @ViewBuilder
    private func actionArea(appModel: AppModel) -> some View {
        switch appModel.authorization {
        case .authorized, .limited:
            if let snapshot = appModel.resumeSnapshot {
                resumeCard(snapshot: snapshot, appModel: appModel)
            } else {
                startCurationCard(appModel: appModel)
            }

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

    private func resumeCard(snapshot: ResumeSnapshot, appModel: AppModel) -> some View {
        let stage = snapshot.processingStage?.localizedTitle ?? "In progress"
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Unfinished Curation", systemImage: "clock.arrow.circlepath")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text(snapshot.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("Continue Curation")
                .font(.headline)

            Text(
                "\(snapshot.sourceCount) photos · \(stage) · \(snapshot.updatedAt, style: .relative)"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Continue") { appModel.continueResumedSession() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                Button("Start New") { appModel.requestNewSession() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Continue curation, \(snapshot.sourceCount) photos, \(stage)"
        )
    }

    private func startCurationCard(appModel: AppModel) -> some View {
        VStack(spacing: 10) {
            Button {
                appModel.startCleanupReview()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text("Clean Up Photos")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                appModel.startAlbumReview()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Build an Album")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Text("Select photos to begin · Originals remain unchanged")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
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
                Text("Turn photo clutter into curated stories")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text(
                    // swiftlint:disable:next line_length
                    "Pick a trip, event, or batch of photos. Photos Curator will find the strongest set for you to review."
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
            Text("How It Works")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                stepRow(
                    number: "1",
                    title: "Select Source Photos",
                    subtitle: "Recommended: 50–500 photos from a trip, event, or album."
                )
                Divider().padding(.leading, 46)
                stepRow(
                    number: "2",
                    title: "On-Device AI Curation",
                    subtitle: "Evaluates sharpness, expressions, and groups similar angles."
                )
                Divider().padding(.leading, 46)
                stepRow(
                    number: "3",
                    title: "Review & Save Album",
                    subtitle: "Inspect the proposed album and export back to Apple Photos."
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
                icon: "sparkles",
                iconColor: Color.curatorSunsetCoral,
                title: "Quality First",
                headline: "Best Smiles & Focus",
                subtext: "Filters blurs, closed eyes, and bad lighting."
            )
            card(
                icon: "square.2.layers.3d",
                iconColor: Color.curatorAccent,
                title: "Clustering",
                headline: "Prunes Duplicates",
                subtext: "Recommends the single top shot per moment."
            )
            card(
                icon: "lock.shield",
                iconColor: .green,
                title: "Private",
                headline: "100% On-Device",
                subtext: "Photos never leave your iPhone."
            )
            card(
                icon: "arrow.triangle.2.circlepath",
                iconColor: .green,
                title: "Safe",
                headline: "Never Deletes",
                subtext: "Original library stays completely intact."
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
