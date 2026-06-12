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
                .background(isSelected ? Color.accentPurpleFallback : Color.gatherSecondaryBackground)
                .clipShape(Capsule())
        }
    }
}
