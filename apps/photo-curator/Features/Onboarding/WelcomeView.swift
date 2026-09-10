import SwiftUI

/// S02 Welcome, first run only. Copy owned by ux-flows §5.1.
struct WelcomeView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Turn hundreds of photos into a small, polished album.")
                .font(.headline)
            Text("Finds the best shots. Trims similar photos. You stay in control of the final album.")
            Button("Get Started") {
                appModel.showPermissionEducation()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Welcome")
    }
}
