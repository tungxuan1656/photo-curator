import SwiftUI

/// S02 Welcome, first run only. Copy owned by ux-flows §5.1.
struct WelcomeView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.curatorSubtleGlow)
                    .frame(width: 96, height: 96)

                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 46))
                    .foregroundStyle(LinearGradient.curatorSunset)
            }
            .padding(.bottom, 8)

            VStack(spacing: 8) {
                Text("Turn hundreds of photos into a small, polished album.")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                Text("Finds the best shots. Trims similar photos. You stay in control of the final album.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button("Get Started") {
                appModel.showPermissionEducation()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .navigationTitle("Welcome")
    }
}
