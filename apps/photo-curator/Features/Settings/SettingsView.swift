import SwiftUI

/// S18 Settings: access state, privacy note, retention + reset, about.
///
/// Claims only what the binary proves: on-device analysis, no photo upload.
/// No ranking, cache, model, or worker-count toggles. Limited stays valid;
/// denied/restricted route to recovery without prompt loops. Dynamic Type
/// safe by construction (List + footnote secondary text, no fixed heights).
struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var confirmingReset = false

    private var accessLabel: String {
        switch appModel.authorization {
        case .authorized: return "Full Access"
        case .limited: return "Limited Photos Access"
        case .denied, .restricted: return "Photos Access Needed"
        case .notDetermined: return "Photos Access Not Set Up"
        }
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    var body: some View {
        List {
            Section("Photos Access") {
                Text(accessLabel)
                    .accessibilityLabel("Photos access: \(accessLabel)")
                if appModel.authorization == .notDetermined {
                    Text("Photo access is not set up yet.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Continue") {
                        Task { await appModel.requestPermission() }
                    }
                    .accessibilityLabel("Continue to photo access setup")
                } else if appModel.authorization == .denied || appModel.authorization == .restricted {
                    Text("Allow photo access to choose images for curation.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Open Settings") { appModel.openSettingsURL() }
                        .accessibilityLabel("Open Settings to allow photo access")
                } else if appModel.authorization == .limited {
                    Text("Only shared photos appear.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Choose More Photos") { appModel.presentPicker() }
                        .accessibilityLabel("Choose more photos to share")
                } else {
                    Text("All photos are available for curation.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Privacy") {
                Text("Photo analysis happens on this iPhone. Your photos are not uploaded.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityLabel("Privacy: photo analysis happens on this iPhone. Photos are not uploaded.")
            }
            Section("Storage") {
                Text(
                    "Analysis results stay on this iPhone until you reset them. Your original photos are never changed."
                )
                .font(.footnote).foregroundStyle(.secondary)
                Button("Reset Analysis", role: .destructive) { confirmingReset = true }
                    .accessibilityLabel("Reset analysis results")
                    .accessibilityHint("Clears saved analysis. Original photos stay unchanged.")
            }
            Section("About") {
                Text("Photos Curator \(appVersion)")
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Reset analysis results?",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset Analysis", role: .destructive) { appModel.resetAnalysis() }
            Button("Keep Results", role: .cancel) {}
        } message: {
            Text("Saved analysis is removed. Your original photos stay unchanged.")
        }
    }
}
