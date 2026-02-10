import SwiftUI

// MARK: - Supporting Views

struct BudgetFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(GatherFont.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(isSelected ? AnyShapeStyle(Color.accentPurpleFallback) : AnyShapeStyle(.ultraThinMaterial))
                .clipShape(Capsule())
                .overlay(
                    isSelected ? nil : Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.glassBorderTop, Color.glassBorderBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
        }
    }
}
