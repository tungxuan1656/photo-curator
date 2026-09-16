import SwiftUI

/// Shared selection toggle for S10/S12: 44pt checkmark icon with border and
/// text state. Never color-only (ux-flows §13).
struct SelectionToggle: View {
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : .white)
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityLabel(isSelected ? "Remove photo from album" : "Add photo to album")
    }
}
