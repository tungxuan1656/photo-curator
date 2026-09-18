import Foundation
import SwiftUI

/// One reusable S20 recoverable-error view: plain title, one line on what
/// happened and whether progress is safe, primary recovery action, safe-exit
/// secondary. Never shows raw errors, IDs, filenames, GPS, or face detail.
struct ErrorStateView: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let primaryTitle: LocalizedStringResource
    let primary: () -> Void
    let secondaryTitle: LocalizedStringResource?
    let secondary: (() -> Void)?

    init(
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        primaryTitle: LocalizedStringResource,
        primary: @escaping () -> Void,
        secondaryTitle: LocalizedStringResource? = nil,
        secondary: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryTitle = primaryTitle
        self.primary = primary
        self.secondaryTitle = secondaryTitle
        self.secondary = secondary
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.title2.bold())
            Text(message).font(.body).multilineTextAlignment(.center)
            Button(primaryTitle, action: primary)
                .buttonStyle(.borderedProminent)
            if let secondaryTitle, let secondary {
                Button(secondaryTitle, action: secondary)
            }
        }
        .padding()
    }
}
