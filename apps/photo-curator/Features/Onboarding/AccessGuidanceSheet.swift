import SwiftUI
import UIKit

/// S19 access management sheet, not a full flow. Copy owned by ux-flows §11.
struct AccessGuidanceSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Photos access", systemImage: "photo.on.rectangle")
                .font(.title2.bold())
            switch appModel.authorization {
            case .limited:
                Text(
                    "Full Photos access is needed before originals can be deleted. "
                        + "You can still review and stage photos with limited access."
                )
                Button("Choose More Photos") {
                    appModel.presentPicker()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
                Button("Dismiss") { dismiss() }
                    .frame(minHeight: 44)
            case .denied:
                Text("Photo access is turned off. Enable Full Access in Settings before starting deletion.")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
                Button("Dismiss") { dismiss() }
                    .frame(minHeight: 44)
            case .restricted:
                Text(
                    "Photos access is restricted on this device. "
                        + "Deletion is unavailable until the restriction is removed."
                )
                Button("Done") {
                    dismiss()
                }
                .frame(minHeight: 44)
            case .notDetermined, .authorized:
                Text("Photo analysis is performed on this device.")
                Button("Done") {
                    dismiss()
                }
                .frame(minHeight: 44)
            }
        }
        .padding()
    }
}
