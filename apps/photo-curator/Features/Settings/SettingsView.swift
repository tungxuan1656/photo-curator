import SwiftUI

/// S18 Settings: access state, privacy note, retention + reset, about.
///
/// Claims only what the binary proves: on-device analysis, no photo upload.
/// No ranking, cache, model, or worker-count toggles. Limited stays valid;
/// denied/restricted route to recovery without prompt loops. Dynamic Type
/// safe by construction (List + footnote secondary text, no fixed heights).
struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(ModelInstallationModel.self) private var modelInstallation
    @State private var confirmingReset = false
    @State private var confirmingModelRemoval = false

    private var accessLabel: LocalizedStringResource {
        switch appModel.authorization {
        case .authorized:
            "Full Access"
        case .limited:
            "Limited Photos Access"
        case .denied, .restricted:
            "Photos Access Needed"
        case .notDetermined:
            "Photos Access Not Set Up"
        }
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    var body: some View {
        @Bindable var appModel = appModel
        List {
            Section("Language") {
                Picker("Language", selection: $appModel.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(languageName(language))
                            .tag(language)
                    }
                }
                .accessibilityLabel("Language")
                .accessibilityValue(languageName(appModel.appLanguage))
            }
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
            Section("AI Model") {
                Text("Qwen3.5-2B (4-bit)")
                    .font(.headline)
                Text(modelInstallation.modelID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                LabeledContent("Model download size", value: byteString(modelInstallation.modelSize))
                    .font(.footnote)

                Label(modelStateTitle, systemImage: modelStateSymbol)
                    .foregroundStyle(modelStateColor)
                    .accessibilityValue(modelStateTitle)

                if let fraction = modelInstallation.progressFraction {
                    ProgressView(value: fraction)
                    if let completed = modelInstallation.completedBytes, let total = modelInstallation.totalBytes {
                        Text("\(byteString(completed)) of \(byteString(total))")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                Text(modelStateMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                switch modelInstallation.state {
                case .notInstalled:
                    Button("Download Model") { modelInstallation.download() }
                        .disabled(!modelInstallation.canStartDownload)
                case .downloading, .verifying:
                    Button("Cancel Download", role: .cancel) { modelInstallation.cancelDownload() }
                case .paused, .failed:
                    Button("Retry Download") { modelInstallation.retryDownload() }
                        .disabled(!modelInstallation.canStartDownload)
                case .installed:
                    Button("Remove Model", role: .destructive) { confirmingModelRemoval = true }
                        .disabled(modelInstallation.isBusy)
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
        .confirmationDialog(
            "Remove the AI model?",
            isPresented: $confirmingModelRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove Model", role: .destructive) { modelInstallation.remove() }
            Button("Keep Model", role: .cancel) {}
        } message: {
            Text("The model can be downloaded again later. Your photos and saved albums stay unchanged.")
        }
    }

    private var modelStateTitle: LocalizedStringResource {
        switch modelInstallation.state {
        case .notInstalled:
            "Not downloaded"
        case .downloading:
            "Downloading"
        case .verifying:
            "Verifying"
        case .paused:
            "Download paused"
        case .installed:
            "Ready for AI analysis"
        case .failed:
            "Download failed"
        }
    }

    private var modelStateMessage: LocalizedStringResource {
        switch modelInstallation.state {
        case .notInstalled:
            "Download the pinned model for local AI curation."
        case .downloading:
            "The download continues without blocking the app."
        case .verifying:
            "Verifying model files."
        case .paused:
            "The verified partial download will resume when you retry."
        case .installed:
            "Qwen is available for small-set curation."
        case let .failed(failure):
            failureMessage(failure)
        }
    }

    private var modelStateSymbol: String {
        switch modelInstallation.state {
        case .notInstalled:
            "arrow.down.circle"
        case .downloading, .verifying:
            "arrow.down.circle.fill"
        case .paused:
            "pause.circle"
        case .installed:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle"
        }
    }

    private var modelStateColor: Color {
        switch modelInstallation.state {
        case .installed:
            .green
        case .failed:
            .orange
        case .notInstalled, .downloading, .verifying, .paused:
            .secondary
        }
    }

    private func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func failureMessage(_ failure: ModelInstallationFailure) -> LocalizedStringResource {
        switch failure {
        case .cancelled:
            "The download was cancelled."
        case .diskSpace:
            "There is not enough storage to install the model."
        case .invalidResponse, .io:
            "The model could not be saved. Try again."
        case .invalidArtifact:
            "The downloaded model did not pass verification. Try again."
        case .network:
            "The model could not be downloaded. Check your connection and try again."
        }
    }

    private func languageName(_ language: AppLanguage) -> LocalizedStringResource {
        switch language {
        case .systemDefault:
            "System Default"
        case .english:
            "English"
        case .vietnamese:
            "Tiếng Việt"
        }
    }
}
