import SwiftUI
import SwiftData

struct BudgetView: View {
    @Bindable var event: Event
    @Environment(\.modelContext) private var modelContext
    @Query private var eventBudgets: [Budget]

    @State private var showAddCategory = false
    @State private var showAddExpense = false
    @State private var selectedCategory: BudgetCategory?
    @State private var showEditBudget = false

    init(event: Event) {
        self.event = event
        let eventId = event.id
        _eventBudgets = Query(
            filter: #Predicate<Budget> { $0.eventId == eventId }
        )
    }

    private var budget: Budget? {
        eventBudgets.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    if let budget = budget {
                        // Budget Overview Card
                        budgetOverviewCard(budget)

                        // Categories
                        categoriesSection(budget)

                        // Recent Expenses
                        recentExpensesSection(budget)
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if budget != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showEditBudget = true
                            } label: {
                                Label("Edit Total Budget", systemImage: "pencil")
                            }

                            Button {
                                showAddCategory = true
                            } label: {
                                Label("Add Category", systemImage: "plus.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                if let budget = budget {
                    AddCategorySheet(budget: budget, functions: event.functions)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showAddExpense) {
                if let category = selectedCategory {
                    AddExpenseSheet(category: category, functions: event.functions)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showEditBudget) {
                if let budget = budget {
                    EditBudgetSheet(budget: budget)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentPurpleFallback)

            Text("No Budget Set")
                .font(GatherFont.title2)

            Text("Create a budget to track your event expenses")
                .font(GatherFont.body)
                .foregroundStyle(Color.gatherSecondaryText)
                .multilineTextAlignment(.center)

            Button {
                createBudget()
            } label: {
                Text("Create Budget")
                    .font(GatherFont.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Budget Overview Card

    private func budgetOverviewCard(_ budget: Budget) -> some View {
        VStack(spacing: Spacing.md) {
            // Total budget
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Budget")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                    Text(budget.totalBudget.asCurrency)
                        .font(GatherFont.largeTitle)
                        .fontWeight(.bold)
                }

                Spacer()

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.gatherSecondaryBackground, lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: min(budget.percentSpent / 100, 1.0))
                        .stroke(
                            budget.percentSpent > 100 ? Color.gatherError : Color.accentPurpleFallback,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(budget.percentSpent))%")
                        .font(GatherFont.caption)
                        .fontWeight(.bold)
                }
            }

            Divider()

            // Stats row
            HStack {
                BudgetStatItem(
                    title: "Spent",
                    value: budget.totalSpent.asCurrency,
                    color: .gatherSecondaryText
                )

                Spacer()

                BudgetStatItem(
                    title: "Remaining",
                    value: budget.remaining.asCurrency,
                    color: budget.remaining < 0 ? .gatherError : .gatherSuccess
                )

                Spacer()

                BudgetStatItem(
                    title: "Allocated",
                    value: budget.totalAllocated.asCurrency,
                    color: .gatherSecondaryText
                )
            }
        }
        .padding()
        .background(Color.gatherSecondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    // MARK: - Categories Section

    private func categoriesSection(_ budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Categories")
                    .font(GatherFont.headline)

                Spacer()

                Button {
                    showAddCategory = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.accentPurpleFallback)
                }
            }

            if budget.categories.isEmpty {
                Text("No categories yet. Add one to start tracking.")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .padding()
            } else {
                ForEach(budget.categories.sorted { $0.sortOrder < $1.sortOrder }) { category in
                    CategoryRow(category: category) {
                        selectedCategory = category
                        showAddExpense = true
                    }
                }
            }
        }
    }

    // MARK: - Recent Expenses Section

    private func recentExpensesSection(_ budget: Budget) -> some View {
        let allExpenses = budget.categories.flatMap { $0.expenses }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)

        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Recent Expenses")
                .font(GatherFont.headline)

            if allExpenses.isEmpty {
                Text("No expenses recorded yet.")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .padding()
            } else {
                ForEach(Array(allExpenses)) { expense in
                    ExpenseRow(expense: expense)
                }
            }
        }
    }

    // MARK: - Actions

    private func createBudget() {
        let newBudget = Budget(eventId: event.id, totalBudget: 10000)

        // Add default wedding categories
        let defaultCategories = BudgetCategory.createDefaultCategories()
        for category in defaultCategories {
            newBudget.categories.append(category)
        }

        modelContext.insert(newBudget)

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Supporting Views

struct BudgetStatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .center, spacing: Spacing.xxs) {
            Text(title)
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)
            Text(value)
                .font(GatherFont.headline)
                .foregroundStyle(color)
        }
    }
}

struct CategoryRow: View {
    let category: BudgetCategory
    let onAddExpense: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(Color.accentPurpleFallback)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(GatherFont.body)
                    Text("\(category.spent.asCurrency) of \(category.allocated.asCurrency)")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                Button {
                    onAddExpense()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentPurpleFallback)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gatherSecondaryBackground)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(category.isOverBudget ? Color.gatherError : Color.accentPurpleFallback)
                        .frame(width: geometry.size.width * min(category.percentSpent / 100, 1.0), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding()
        .background(Color.gatherSecondaryBackground.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.name)
                    .font(GatherFont.body)
                if let vendor = expense.vendorName {
                    Text(vendor)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.amount.asCurrency)
                    .font(GatherFont.headline)

                if expense.isPaid {
                    Label("Paid", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSuccess)
                }
            }
        }
        .padding()
        .background(Color.gatherSecondaryBackground.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

#Preview {
    BudgetView(event: Event(title: "Sample Wedding"))
}
