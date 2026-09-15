import SwiftUI

/// Shared selection toggle for S10/S12: 44pt checkmark icon with border and
/// text state. Never color-only (ux-flows §13).
struct SelectionToggle: View {
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                Text(isSelected ? "Selected" : "Removed")
                    .font(.caption)
            }
            .padding(12)
            .contentShape(Rectangle())
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.secondary, lineWidth: 1)
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityLabel(isSelected ? "Remove photo from album" : "Add photo to album")
    }
}
