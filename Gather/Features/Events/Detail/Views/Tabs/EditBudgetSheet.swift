import SwiftUI
import SwiftData

// MARK: - Edit Budget Sheet

struct EditBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var budget: Budget
    @State private var totalBudget: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Total Budget")
                            .font(GatherFont.callout)
                            .foregroundStyle(Color.gatherSecondaryText)

                        TextField("Budget amount", value: $totalBudget, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .submitLabel(.done)
                    }
                    .padding(.vertical, Spacing.sm)
                }

                Section("Current Spending") {
                    HStack {
                        Text("Total Spent")
                        Spacer()
                        Text(budget.totalSpent.asCurrency)
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text("Remaining")
                        Spacer()
                        let remaining = totalBudget - budget.totalSpent
                        Text(remaining.asCurrency)
                            .fontWeight(.semibold)
                            .foregroundStyle(remaining >= 0 ? Color.rsvpYesFallback : Color.rsvpNoFallback)
                    }
                    HStack {
                        Text("Categories")
                        Spacer()
                        Text("\(budget.categories.count)")
                    }
                }
            }
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        budget.totalBudget = totalBudget
                        budget.updatedAt = Date()
                        dismiss()
                    }
                }
            }
            .onAppear {
                totalBudget = budget.totalBudget
            }
        }
    }
}
