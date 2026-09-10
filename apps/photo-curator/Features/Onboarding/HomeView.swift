import SwiftUI
import UIKit

/// S04 Home skeleton. Copy owned by ux-flows §6.1. Denied/restricted replace the CTA
/// with the access-required card (never a dead Curate Photos button).
struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showsAccessGuidance = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Pick a trip, event, or batch of photos. "
                + "Photos Curator will find the strongest set for you to review.")
            switch appModel.authorization {
            case .authorized, .limited:
                Button("Curate Photos") {}
                    .buttonStyle(.borderedProminent)
                if appModel.authorization == .limited {
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
        .sheet(isPresented: $showsAccessGuidance) {
            AccessGuidanceSheet()
        }
        .task {
            await appModel.refreshAuthorization()
        }
    }
}
