import SwiftUI

/// S03 permission education, always before the system prompt (ux-flows invariant §1.8).
/// Copy owned by ux-flows §5.2.
struct PermissionEducationView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose photos for curation")
                .font(.headline)
            Text("Photos Curator needs access to the photos you choose so it can analyze them "
                + "and build your curated album. Photo analysis happens on this iPhone.")
            Button("Continue") {
                Task {
                    await appModel.requestPermission()
                }
            }
            .buttonStyle(.borderedProminent)
            Button("Not Now") {
                appModel.skipPermission()
            }
        }
        .padding()
        .navigationTitle("Photo Access")
    }
}
