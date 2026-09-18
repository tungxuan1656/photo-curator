import SwiftUI

/// S03 permission education, always before the system prompt (ux-flows invariant §1.8).
/// Copy owned by ux-flows §5.2.
struct PermissionEducationView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.curatorSubtleGlow)
                    .frame(width: 88, height: 88)

                Image(systemName: "photo.stack")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient.curatorSunset)
            }

            VStack(spacing: 8) {
                Text("Choose photos for curation")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                Text("Photos Curator needs access to the photos you choose so it can analyze them "
                    + "and build your curated album. Photo analysis happens on this iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 14) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Full Access (Recommended)").font(.subheadline.bold())
                        Text("Easily select from your entire library, albums, and trips.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                        .foregroundStyle(Color.curatorAccent)
                        .frame(width: 28)
                }

                Divider()

                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Limited Access").font(.subheadline.bold())
                        Text("Choose specific photos to share with the app. You can add more anytime.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "hand.raised")
                        .font(.title3)
                        .foregroundStyle(Color.curatorSunsetCoral)
                        .frame(width: 28)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            Spacer()

            VStack(spacing: 10) {
                Button("Continue") {
                    Task {
                        await appModel.requestPermission()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Not Now") {
                    appModel.skipPermission()
                }
                .font(.subheadline)
            }
        }
        .padding()
        .navigationTitle("Photo Access")
    }
}
