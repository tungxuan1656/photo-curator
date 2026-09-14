import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
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
                if appModel.authorization == .denied || appModel.authorization == .restricted {
                    Text("Allow photo access to choose images for curation.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Open Settings") { appModel.openSettingsURL() }
                } else if appModel.authorization == .limited {
                    Text("Only shared photos appear.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Choose More Photos") { appModel.presentPicker() }
                } else {
                    Button("Manage Photos Access") { appModel.presentPicker() }
                }
            }
            Section("Processing & Privacy") {
                Text("Photo analysis is performed on this device.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("About") {
                Text("Photos Curator \(appVersion)")
            }
        }.navigationTitle("Settings")
    }
}
