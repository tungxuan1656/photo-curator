import SwiftUI
import UIKit

/// S04 Home skeleton. Copy owned by ux-flows §6.1. Denied/restricted replace the CTA
/// with the access-required card (never a dead Curate Photos button).
struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showsAccessGuidance = false

    var body: some View {
        @Bindable var appModel = appModel
        VStack(spacing: 16) {
            Text("Pick a trip, event, or batch of photos. "
                + "Photos Curator will find the strongest set for you to review.")
            switch appModel.authorization {
            case .authorized, .limited:
                if let snapshot = appModel.resumeSnapshot {
                    VStack(spacing: 8) {
                        Text("Continue Curation").font(.headline)
                        Text(
                            "\(snapshot.sourceCount) photos · \(snapshot.stageDescription) · \(snapshot.updatedAt, style: .relative)"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        Button("Continue") { appModel.continueResumedSession() }
                            .buttonStyle(.borderedProminent)
                        Button("Start New") { appModel.requestNewSession() }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(
                        "Continue curation, \(snapshot.sourceCount) photos, \(snapshot.stageDescription)"
                    )
                } else {
                    Button("Curate Photos") {
                        appModel.showSourceSelection()
                    }
                    .buttonStyle(.borderedProminent)
                }
                if appModel.authorization == .limited {
                    // Picker lives in the guidance sheet (wired in feat-002);
                    // this entry only opens the sheet.
                    Button("Limited Photos Access — Choose More Photos") {
                        showsAccessGuidance = true
                    }
                }
            case .notDetermined:
                Text("Photos Access Needed")
                    .font(.headline)
                Text("Allow photo access to choose images for curation.")
                Button("Continue") {
                    appModel.showPermissionEducation()
                }
                .buttonStyle(.borderedProminent)
                Button("Learn More") {
                    showsAccessGuidance = true
                }
            case .denied:
                Text("Photos Access Needed")
                    .font(.headline)
                Text("Allow photo access to choose images for curation.")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("Learn More") {
                    showsAccessGuidance = true
                }
            case .restricted:
                Text("Photos Access Restricted")
                    .font(.headline)
                Text("Photos access is restricted on this device.")
                Button("Learn More") {
                    showsAccessGuidance = true
                }
            }
        }
        .padding()
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
}
