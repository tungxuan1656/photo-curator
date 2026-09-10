import SwiftUI
import UIKit

/// S19 access management sheet, not a full flow. Copy owned by ux-flows §11.
struct AccessGuidanceSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            switch appModel.authorization {
            case .limited:
                Text("Photos Curator can only use the photos currently shared with the app.")
                Button("Choose More Photos") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            case .denied:
                Text("Photo access is turned off. Enable it in Settings to curate photos.")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            case .restricted:
                Text("Photos access is restricted on this device.")
                Button("Done") {
                    dismiss()
                }
            default:
                Text("Photo analysis is performed on this device.")
                Button("Done") {
                    dismiss()
                }
            }
        }
        .padding()
    }
}
