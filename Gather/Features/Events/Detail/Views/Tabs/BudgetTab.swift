import SwiftUI
import SwiftData

struct BudgetTab: View {
    @Bindable var event: Event
    @State private var filterFunction: EventFunction?
    @State private var showAddCategory = false
    @State private var showAddExpense = false
    @State private var showEditBudget = false
    @State private var showAddSplit = false
    @State private var addExpenseCategory: BudgetCategory?
    @State private var editingExpense: Expense?
    @State private var expandedCategoryId: UUID?
    @State private var showTeam = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager

    @Query private var allBudgets: [Budget]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                if let budget = eventBudget {
                    // Overdue / Over-budget alerts
                    alertBanners(budget)

                    // Budget Summary
                    summaryCard(budget)

                    // Payment Breakdown (Paid / Owed / Overdue)
                    paymentBreakdown(budget)

                    // Who Paid What
                    whoPaidWhat(budget)

                    // Quick Actions
                    quickActions(budget)

                    // Function Filter
                    if !event.functions.isEmpty {
                        functionFilterPicker
                    }

                    // Upcoming Payments
                    upcomingPayments(budget)

                    // Categories
                    categoriesSection(budget)

                    // Vendors
                    vendorSection(budget)

                    // Co-Host Splits
                    if !budget.splits.isEmpty || isHost {
                        splitsSection(budget)
                    }

                    // All Transactions
                    allTransactions(budget)
                } else {
                    emptyState
                }
            }
            .padding()
            .padding(.bottom, 80)
        }
        .sheet(isPresented: $showAddCategory) {
            if let budget = eventBudget {
                AddCategorySheet(budget: budget, functions: event.functions, filterFunction: filterFunction)
            }
        }
        .sheet(item: $addExpenseCategory) { category in
            AddExpenseSheet(category: category, functions: event.functions)
        }
        .sheet(isPresented: $showEditBudget) {
            if let budget = eventBudget {
                EditBudgetSheet(budget: budget)
            }
        }
        .sheet(isPresented: $showAddSplit) {
            if let budget = eventBudget {
                AddSplitSheet(budget: budget)
            }
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseDetailSheet(expense: expense, functions: event.functions, onDelete: {
                deleteExpense(expense)
            })
        }
        .sheet(isPresented: $showAddExpense) {
            if let budget = eventBudget {
                QuickAddExpenseSheet(budget: budget, functions: event.functions)
            }
        }
        .sheet(isPresented: $showTeam) {
            EventTeamSheet(event: event)
        }
    }

    private var eventBudget: Budget? {
        allBudgets.first { $0.eventId == event.id }
    }

    private var isHost: Bool {
        authManager.currentUser?.id == event.hostId
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient.gatherAccentGradient)

            VStack(spacing: Spacing.sm) {
                Text("No Budget Set")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text("Track expenses, manage payments, and split costs with co-hosts")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
            }

            Button {
                createBudget()
            } label: {
                Label("Create Budget", systemImage: "plus.circle.fill")
                    .font(GatherFont.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.sm)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, Spacing.xxxl)
        .bouncyAppear()
    }

    // MARK: - Alert Banners

    @ViewBuilder
    private func alertBanners(_ budget: Budget) -> some View {
        let overBudgetCategories = filteredCategories(budget).filter { $0.isOverBudget }
        let overdueExpenses = allExpenses(budget).filter { expense in
            !expense.isPaid && (expense.dueDate.map { $0 < Date() } ?? false)
        }

        if !overdueExpenses.isEmpty {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(overdueExpenses.count) overdue \(overdueExpenses.count == 1 ? "payment" : "payments")")
                        .font(GatherFont.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(overdueExpenses.reduce(0) { $0 + $1.amount }.asCurrency + " needs attention")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
            .padding(Spacing.sm)
            .background(Color.red.gradient)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }

        if !overBudgetCategories.isEmpty {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                Text("\(overBudgetCategories.count) \(overBudgetCategories.count == 1 ? "category" : "categories") over budget")
                    .font(GatherFont.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(Spacing.sm)
            .background(Color.rsvpMaybeFallback.gradient)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }
    }

    // MARK: - Summary Card

    private func summaryCard(_ budget: Budget) -> some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("Budget Overview")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)
                Spacer()
                Button {
                    showEditBudget = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.accentPurpleFallback)
                }
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Budget")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                    Text(budget.totalBudget.asCurrency)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.gatherPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Spent")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                    Text(filteredSpent(budget).asCurrency)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(spentColor(budget))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }

            // Progress bar
            VStack(spacing: Spacing.xs) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gatherTertiaryBackground)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(progressGradient(budget))
                            .frame(width: max(0, min(geometry.size.width, geometry.size.width * filteredPercentSpent(budget) / 100)))
                    }
                }
                .frame(height: 12)

                HStack {
                    Text("\(Int(filteredPercentSpent(budget)))% used")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(spentColor(budget))

                    Spacer()

                    Text("\(filteredRemaining(budget).asCurrency) left")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(filteredRemaining(budget) >= 0 ? Color.rsvpYesFallback : Color.rsvpNoFallback)
                }
            }
        }
        .padding()
        .glassCard()
        .bouncyAppear()
    }

    // MARK: - Payment Breakdown

    private func paymentBreakdown(_ budget: Budget) -> some View {
        let expenses = allExpenses(budget)
        let totalAmount = expenses.reduce(0) { $0 + $1.amount }
        let paidAmount = expenses.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
        let pendingAmount = expenses.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
        let overdueAmount = expenses.filter { !$0.isPaid && ($0.dueDate.map { $0 < Date() } ?? false) }.reduce(0) { $0 + $1.amount }

        return HStack(spacing: Spacing.sm) {
            paymentStatCard(
                label: "Paid",
                amount: paidAmount,
                total: totalAmount,
                icon: "checkmark.circle.fill",
                color: Color.rsvpYesFallback
            )
            paymentStatCard(
                label: "Owed",
                amount: pendingAmount,
                total: totalAmount,
                icon: "clock.fill",
                color: overdueAmount > 0 ? Color.rsvpMaybeFallback : Color.accentPurpleFallback
            )
            if overdueAmount > 0 {
                paymentStatCard(
                    label: "Overdue",
                    amount: overdueAmount,
                    total: totalAmount,
                    icon: "exclamationmark.circle.fill",
                    color: Color.rsvpNoFallback
                )
            }
        }
    }

    private func paymentStatCard(label: String, amount: Double, total: Double, icon: String, color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(amount.asCurrency)
                .font(GatherFont.callout)
                .fontWeight(.bold)
                .foregroundStyle(Color.gatherPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)

            // Mini progress
            if total > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gatherTertiaryBackground)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: max(0, geometry.size.width * (amount / total)))
                    }
                }
                .frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.xs)
        .glassCard()
    }

    // MARK: - Who Paid What

    @ViewBuilder
    private func whoPaidWhat(_ budget: Budget) -> some View {
        let expenses = allExpenses(budget)
        let paidExpenses = expenses.filter { $0.paidByName != nil && !$0.paidByName!.isEmpty }
        let grouped = Dictionary(grouping: paidExpenses) { $0.paidByName! }

        if !grouped.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: "person.2.circle.fill")
                        .foregroundStyle(Color.accentPurpleFallback)
                    Text("Who Paid What")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Spacer()
                }

                ForEach(grouped.keys.sorted(), id: \.self) { person in
                    let personExpenses = grouped[person] ?? []
                    let totalPaid = personExpenses.reduce(0) { $0 + $1.amount }
                    let paidCount = personExpenses.filter { $0.isPaid }.count
                    let allPaid = paidCount == personExpenses.count

                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(avatarColor(for: person))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text(person.prefix(1).uppercased())
                                    .font(GatherFont.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(person)
                                .font(GatherFont.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.gatherPrimaryText)

                            Text("\(personExpenses.count) expense\(personExpenses.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(totalPaid.asCurrency)
                                .font(GatherFont.callout)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.gatherPrimaryText)

                            if allPaid {
                                Label("All paid", systemImage: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.rsvpYesFallback)
                            } else {
                                Text("\(paidCount)/\(personExpenses.count) paid")
                                    .font(.caption2)
                                    .foregroundStyle(Color.rsvpMaybeFallback)
                            }
                        }
                    }
                    .padding(Spacing.sm)
                    .glassCard()
                }
            }
            .bouncyAppear(delay: 0.08)
        }
    }

    // MARK: - Quick Actions

    private func quickActions(_ budget: Budget) -> some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Button {
                    showAddExpense = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Expense")
                    }
                    .font(GatherFont.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }

                Button {
                    showTeam = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                        Text("Manage Team")
                    }
                    .font(GatherFont.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentPurpleFallback)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.accentPurpleFallback.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
            }

            Button {
                showAddCategory = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus")
                    Text("Add Category")
                }
                .font(GatherFont.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.gatherSecondaryText)
            }
        }
    }

    // MARK: - Function Filter

    private var functionFilterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                BudgetFilterChip(title: "All", isSelected: filterFunction == nil) {
                    filterFunction = nil
                }
                ForEach(event.functions.sorted { $0.date < $1.date }) { function in
                    BudgetFilterChip(title: function.name, isSelected: filterFunction?.id == function.id) {
                        filterFunction = function
                    }
                }
            }
        }
    }

    // MARK: - Upcoming Payments

    @ViewBuilder
    private func upcomingPayments(_ budget: Budget) -> some View {
        let upcoming = allExpenses(budget)
            .filter { !$0.isPaid && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(Color.rsvpMaybeFallback)
                    Text("Upcoming Payments")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Spacer()
                    Text("\(upcoming.count)")
                        .font(GatherFont.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.rsvpMaybeFallback)
                        .clipShape(Capsule())
                }

                ForEach(upcoming.prefix(5)) { expense in
                    Button {
                        editingExpense = expense
                    } label: {
                        upcomingPaymentRow(expense, budget: budget)
                    }
                }
            }
            .padding()
            .glassCard()
            .bouncyAppear(delay: 0.05)
        }
    }

    private func upcomingPaymentRow(_ expense: Expense, budget: Budget) -> some View {
        let isOverdue = expense.dueDate.map { $0 < Date() } ?? false
        let categoryName = findCategoryName(for: expense, in: budget)

        return HStack(spacing: Spacing.sm) {
            // Due date indicator
            VStack(spacing: 2) {
                if let dueDate = expense.dueDate {
                    Text(dueDate.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isOverdue ? Color.rsvpNoFallback : Color.gatherSecondaryText)
                    Text(dueDate.formatted(.dateTime.day()))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(isOverdue ? Color.rsvpNoFallback : Color.gatherPrimaryText)
                }
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(expense.name)
                        .font(GatherFont.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.gatherPrimaryText)

                    if isOverdue {
                        Text("OVERDUE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.rsvpNoFallback)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: Spacing.xs) {
                    if let vendor = expense.vendorName {
                        Text(vendor)
                    }
                    if let cat = categoryName {
                        if expense.vendorName != nil {
                            Text("·")
                        }
                        Text(cat)
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)

                if let dueDate = expense.dueDate {
                    Text(dueDateLabel(dueDate))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(isOverdue ? Color.rsvpNoFallback : Color.rsvpMaybeFallback)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.amount.asCurrency)
                    .font(GatherFont.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(isOverdue ? Color.rsvpNoFallback : Color.gatherPrimaryText)

                Button {
                    markAsPaid(expense, in: budget)
                } label: {
                    Text("Pay")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.rsvpYesFallback)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Categories Section

    private func categoriesSection(_ budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Categories")
                .font(GatherFont.headline)
                .foregroundStyle(Color.gatherPrimaryText)

            let categories = filteredCategories(budget).sorted { $0.sortOrder < $1.sortOrder }

            if categories.isEmpty {
                Text("No categories yet. Tap \"Add Category\" above.")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Spacing.md)
            } else {
                ForEach(categories) { category in
                    categoryCard(category, budget: budget)
                }
            }
        }
        .bouncyAppear(delay: 0.1)
    }

    private func categoryCard(_ category: BudgetCategory, budget: Budget) -> some View {
        VStack(spacing: Spacing.sm) {
            // Main row - tap to expand
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    expandedCategoryId = expandedCategoryId == category.id ? nil : category.id
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: category.icon)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(categoryColor(category.color))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(category.name)
                            .font(GatherFont.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.gatherPrimaryText)

                        if category.allocated > 0 {
                            Text("\(category.spent.asCurrency) of \(category.allocated.asCurrency)")
                                .font(.caption2)
                                .foregroundStyle(Color.gatherSecondaryText)
                        } else {
                            Text("\(category.expenses.count) expense\(category.expenses.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                    }

                    Spacer()

                    // Paid / Owed mini indicator
                    let catPaid = category.expenses.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
                    let catOwed = category.expenses.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }

                    VStack(alignment: .trailing, spacing: 1) {
                        if category.isOverBudget {
                            Text("Over")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.rsvpNoFallback)
                                .clipShape(Capsule())
                        } else if category.allocated > 0 {
                            Text("\(Int(category.percentSpent))%")
                                .font(GatherFont.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }

                        if catOwed > 0 {
                            Text("\(catOwed.asCurrency) owed")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.rsvpMaybeFallback)
                        } else if catPaid > 0 {
                            Text("All paid")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.rsvpYesFallback)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherTertiaryText)
                        .rotationEffect(.degrees(expandedCategoryId == category.id ? 90 : 0))
                }
            }

            // Progress bar
            if category.allocated > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gatherTertiaryBackground)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(category.isOverBudget ? Color.rsvpNoFallback : categoryColor(category.color))
                            .frame(width: max(4, min(geometry.size.width, geometry.size.width * category.percentSpent / 100)))
                    }
                }
                .frame(height: 6)
            }

            // Expanded expenses
            if expandedCategoryId == category.id {
                VStack(spacing: 0) {
                    if category.expenses.isEmpty {
                        Text("No expenses yet")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .padding(.vertical, Spacing.sm)
                    } else {
                        ForEach(category.expenses.sorted { $0.createdAt > $1.createdAt }) { expense in
                            Button {
                                editingExpense = expense
                            } label: {
                                expenseRow(expense)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Add expense button for this category
                    Button {
                        addExpenseCategory = category
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text("Add Expense")
                        }
                        .font(GatherFont.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.accentPurpleFallback)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xs)
                    }
                }
                .padding(.leading, Spacing.xl)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.sm)
        .glassCard()
    }

    private func expenseRow(_ expense: Expense) -> some View {
        let isOverdue = !expense.isPaid && (expense.dueDate.map { $0 < Date() } ?? false)

        return HStack(spacing: Spacing.sm) {
            // Status icon
            Image(systemName: expense.isPaid ? "checkmark.circle.fill" : (isOverdue ? "exclamationmark.circle.fill" : "circle"))
                .font(.callout)
                .foregroundStyle(expense.isPaid ? Color.rsvpYesFallback : (isOverdue ? Color.rsvpNoFallback : Color.gatherTertiaryText))

            VStack(alignment: .leading, spacing: 1) {
                Text(expense.name)
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherPrimaryText)

                HStack(spacing: 4) {
                    if let paidBy = expense.paidByName, !paidBy.isEmpty {
                        Text(paidBy)
                        Text("·")
                    }
                    if let vendor = expense.vendorName {
                        Text(vendor)
                    }
                    if expense.isPaid, let paidDate = expense.paidDate {
                        if expense.vendorName != nil || expense.paidByName != nil { Text("·") }
                        Text("Paid \(paidDate.formatted(date: .abbreviated, time: .omitted))")
                    } else if let dueDate = expense.dueDate {
                        if expense.vendorName != nil || expense.paidByName != nil { Text("·") }
                        Text("Due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .font(.caption2)
                .foregroundStyle(isOverdue ? Color.rsvpNoFallback : Color.gatherTertiaryText)
            }

            Spacer()

            Text(expense.amount.asCurrency)
                .font(GatherFont.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.gatherPrimaryText)

            Image(systemName: "chevron.right")
                .font(.system(size: 9))
                .foregroundStyle(Color.gatherTertiaryText)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Vendor Section

    @ViewBuilder
    private func vendorSection(_ budget: Budget) -> some View {
        let expenses = allExpenses(budget)
        let vendorExpenses = Dictionary(grouping: expenses.filter { $0.vendorName != nil }) { $0.vendorName! }

        if !vendorExpenses.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Vendors")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)

                ForEach(vendorExpenses.keys.sorted(), id: \.self) { vendor in
                    let vExpenses = vendorExpenses[vendor] ?? []
                    let totalOwed = vExpenses.reduce(0) { $0 + $1.amount }
                    let totalPaid = vExpenses.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
                    let unpaidCount = vExpenses.filter { !$0.isPaid }.count

                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(avatarColor(for: vendor))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text(vendor.prefix(1).uppercased())
                                    .font(GatherFont.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(vendor)
                                .font(GatherFont.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.gatherPrimaryText)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.gatherTertiaryBackground)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.rsvpYesFallback)
                                        .frame(width: totalOwed > 0 ? geometry.size.width * (totalPaid / totalOwed) : 0)
                                }
                            }
                            .frame(height: 4)

                            Text("\(vExpenses.count) expense\(vExpenses.count == 1 ? "" : "s")\(unpaidCount > 0 ? " · \(unpaidCount) unpaid" : "")")
                                .font(.caption2)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(totalOwed.asCurrency)
                                .font(GatherFont.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.gatherPrimaryText)

                            if totalPaid >= totalOwed {
                                Label("Paid", systemImage: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.rsvpYesFallback)
                            } else {
                                Text("\((totalOwed - totalPaid).asCurrency) owed")
                                    .font(.caption2)
                                    .foregroundStyle(Color.rsvpMaybeFallback)
                            }
                        }
                    }
                    .padding(Spacing.sm)
                    .glassCard()
                }
            }
            .bouncyAppear(delay: 0.2)
        }
    }

    // MARK: - Splits Section

    private func splitsSection(_ budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Co-Host Splits")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)
                Spacer()
                Button {
                    showAddSplit = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(GatherFont.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentPurpleFallback)
                }
            }

            if budget.splits.isEmpty {
                Text("Split costs with co-hosts")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .padding(.vertical, Spacing.sm)
            } else {
                ForEach(budget.splits) { split in
                    HStack {
                        Circle()
                            .fill(avatarColor(for: split.name))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text(split.name.prefix(1).uppercased())
                                    .font(GatherFont.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(split.name)
                                .font(GatherFont.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.gatherPrimaryText)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.gatherTertiaryBackground)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(split.isPaidUp ? Color.rsvpYesFallback : Color.accentPurpleFallback)
                                        .frame(width: split.shareAmount > 0 ? geometry.size.width * (split.paidAmount / split.shareAmount) : 0)
                                }
                            }
                            .frame(height: 4)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if split.isPaidUp {
                                Label("Paid", systemImage: "checkmark.circle.fill")
                                    .font(GatherFont.caption)
                                    .foregroundStyle(Color.rsvpYesFallback)
                            } else {
                                Text(split.owedAmount.asCurrency)
                                    .font(GatherFont.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.rsvpMaybeFallback)
                                Text("of \(split.shareAmount.asCurrency)")
                                    .font(.caption2)
                                    .foregroundStyle(Color.gatherSecondaryText)
                            }
                        }
                    }
                    .padding(Spacing.sm)
                    .glassCard()
                }
            }
        }
        .bouncyAppear(delay: 0.25)
    }

    // MARK: - All Transactions

    @ViewBuilder
    private func allTransactions(_ budget: Budget) -> some View {
        let expenses = allExpenses(budget)

        if !expenses.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("All Transactions")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Spacer()
                    Text("\(expenses.count)")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                ForEach(expenses.prefix(10)) { expense in
                    Button {
                        editingExpense = expense
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: expense.isPaid ? "checkmark.circle.fill" : "circle")
                                .font(.callout)
                                .foregroundStyle(expense.isPaid ? Color.rsvpYesFallback : Color.gatherTertiaryText)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(expense.name)
                                    .font(GatherFont.callout)
                                    .foregroundStyle(Color.gatherPrimaryText)
                                HStack(spacing: 4) {
                                    if let vendor = expense.vendorName {
                                        Text(vendor)
                                    }
                                    if let cat = findCategoryName(for: expense, in: budget) {
                                        if expense.vendorName != nil { Text("·") }
                                        Text(cat)
                                    }
                                    Text("·")
                                    Text(expense.createdAt.formatted(date: .abbreviated, time: .omitted))
                                }
                                .font(.caption2)
                                .foregroundStyle(Color.gatherSecondaryText)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 1) {
                                Text(expense.amount.asCurrency)
                                    .font(GatherFont.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.gatherPrimaryText)
                                Text(expense.isPaid ? "Paid" : "Pending")
                                    .font(.caption2)
                                    .foregroundStyle(expense.isPaid ? Color.rsvpYesFallback : Color.rsvpMaybeFallback)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .glassCard()
            .bouncyAppear(delay: 0.3)
        }
    }

    // MARK: - Helpers

    private func createBudget() {
        let newBudget = Budget(eventId: event.id, totalBudget: 10000)
        let defaultCategories = BudgetCategory.createDefaultCategories(for: event.category)
        for category in defaultCategories {
            newBudget.categories.append(category)
        }
        modelContext.insert(newBudget)
        try? modelContext.save()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func allExpenses(_ budget: Budget) -> [Expense] {
        budget.categories.flatMap { $0.expenses }.sorted { $0.createdAt > $1.createdAt }
    }

    private func filteredCategories(_ budget: Budget) -> [BudgetCategory] {
        if let function = filterFunction {
            return budget.categories.filter { $0.functionId == function.id || $0.functionId == nil }
        }
        return budget.categories
    }

    private func filteredSpent(_ budget: Budget) -> Double {
        if let function = filterFunction {
            return budget.categories.reduce(0) { total, category in
                total + category.expenses
                    .filter { $0.functionId == function.id || $0.functionId == nil }
                    .reduce(0) { $0 + $1.amount }
            }
        }
        return budget.totalSpent
    }

    private func filteredRemaining(_ budget: Budget) -> Double {
        budget.totalBudget - filteredSpent(budget)
    }

    private func filteredPercentSpent(_ budget: Budget) -> Double {
        guard budget.totalBudget > 0 else { return 0 }
        return (filteredSpent(budget) / budget.totalBudget) * 100
    }

    private func spentColor(_ budget: Budget) -> Color {
        let percent = filteredPercentSpent(budget)
        if percent > 100 { return Color.rsvpNoFallback }
        if percent > 80 { return Color.rsvpMaybeFallback }
        return Color.gatherPrimaryText
    }

    private func progressGradient(_ budget: Budget) -> LinearGradient {
        let percent = filteredPercentSpent(budget)
        if percent > 100 {
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        }
        if percent > 80 {
            return LinearGradient(colors: [Color.rsvpMaybeFallback, .orange], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [Color.accentPurpleFallback, Color.accentPinkFallback], startPoint: .leading, endPoint: .trailing)
    }

    private func categoryColor(_ colorName: String) -> Color {
        switch colorName {
        case "purple": return .purple
        case "pink": return .pink
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "yellow": return .yellow
        case "red": return .red
        case "indigo": return .indigo
        case "teal": return .teal
        case "gray", "secondary": return .gray
        default: return .purple
        }
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.purple, .blue, .green, .orange, .pink, .teal]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }

    private func findCategoryName(for expense: Expense, in budget: Budget) -> String? {
        budget.categories.first { category in
            category.expenses.contains { $0.id == expense.id }
        }?.name
    }

    private func markAsPaid(_ expense: Expense, in budget: Budget) {
        expense.isPaid = true
        expense.paidDate = Date()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func deleteExpense(_ expense: Expense) {
        guard let budget = eventBudget else { return }
        for category in budget.categories {
            if let index = category.expenses.firstIndex(where: { $0.id == expense.id }) {
                category.spent -= expense.amount
                category.expenses.remove(at: index)
                break
            }
        }
    }

    private func dueDateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if date < now {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if days == 0 { return "Due today" }
            if days == 1 { return "1 day overdue" }
            return "\(days) days overdue"
        } else {
            let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0
            if days == 0 { return "Due today" }
            if days == 1 { return "Due tomorrow" }
            if days <= 7 { return "Due in \(days) days" }
            return "Due \(date.formatted(date: .abbreviated, time: .omitted))"
        }
    }
}

// MARK: - Quick Add Expense Sheet (picks category inside form)

struct QuickAddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var budget: Budget
    let functions: [EventFunction]

    @State private var name = ""
    @State private var amount: Double = 0
    @State private var vendorName = ""
    @State private var paidByName = ""
    @State private var isPaid = false
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var notes = ""
    @State private var selectedCategoryId: UUID?
    @State private var selectedFunctionId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you spend on?") {
                    TextField("e.g. Venue deposit, DJ booking", text: $name)
                    TextField("Amount", value: $amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .keyboardType(.decimalPad)
                }

                Section("Category") {
                    if budget.categories.isEmpty {
                        Text("No categories yet")
                            .foregroundStyle(Color.gatherSecondaryText)
                    } else {
                        Picker("Category", selection: $selectedCategoryId) {
                            Text("Select category").tag(UUID?.none)
                            ForEach(budget.categories.sorted { $0.sortOrder < $1.sortOrder }) { category in
                                HStack {
                                    Image(systemName: category.icon)
                                    Text(category.name)
                                }
                                .tag(Optional(category.id))
                            }
                        }
                    }
                }

                Section("Vendor (Optional)") {
                    TextField("e.g. Grand Hyatt, DJ Mike", text: $vendorName)
                }

                Section("Who Paid?") {
                    TextField("e.g. You, Aisha, Jordan", text: $paidByName)
                }

                Section("Payment Status") {
                    Toggle("Already Paid", isOn: $isPaid)

                    if isPaid {
                        // No due date needed
                    } else {
                        Toggle("Has Due Date", isOn: $hasDueDate)
                        if hasDueDate {
                            DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        }
                    }
                }

                if !functions.isEmpty {
                    Section("Link to Function") {
                        Picker("Function", selection: $selectedFunctionId) {
                            Text("General").tag(UUID?.none)
                            ForEach(functions.sorted { $0.date < $1.date }) { function in
                                Text(function.name).tag(Optional(function.id))
                            }
                        }
                    }
                }

                if !isPaid {
                    Section("Notes (Optional)") {
                        TextField("e.g. 50% deposit, balance due on event day", text: $notes, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let categoryId = selectedCategoryId,
                              let category = budget.categories.first(where: { $0.id == categoryId }) else { return }

                        let expense = Expense(
                            name: name,
                            amount: amount,
                            isPaid: isPaid,
                            paidDate: isPaid ? Date() : nil,
                            dueDate: hasDueDate ? dueDate : nil,
                            notes: notes.isEmpty ? nil : notes,
                            vendorName: vendorName.isEmpty ? nil : vendorName,
                            paidByName: paidByName.isEmpty ? nil : paidByName,
                            functionId: selectedFunctionId
                        )
                        category.expenses.append(expense)
                        category.spent += amount
                        dismiss()
                    }
                    .disabled(name.isEmpty || amount <= 0 || selectedCategoryId == nil)
                }
            }
        }
    }
}

// MARK: - Expense Detail Sheet

struct ExpenseDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var expense: Expense
    let functions: [EventFunction]
    var onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                // Amount header
                Section {
                    VStack(spacing: Spacing.sm) {
                        Text(expense.amount.asCurrency)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.gatherPrimaryText)

                        HStack(spacing: Spacing.xs) {
                            Image(systemName: expense.isPaid ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(expense.isPaid ? Color.rsvpYesFallback : Color.gatherTertiaryText)
                            Text(expense.isPaid ? "Paid" : "Unpaid")
                                .fontWeight(.medium)
                                .foregroundStyle(expense.isPaid ? Color.rsvpYesFallback : Color.gatherSecondaryText)
                        }
                        .font(GatherFont.callout)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .listRowBackground(Color.clear)
                }

                // Details
                Section("Details") {
                    LabeledContent("Name", value: expense.name)

                    if let vendor = expense.vendorName, !vendor.isEmpty {
                        LabeledContent("Vendor", value: vendor)
                    }

                    if let paidBy = expense.paidByName, !paidBy.isEmpty {
                        LabeledContent("Paid by", value: paidBy)
                    }

                    LabeledContent("Added", value: expense.createdAt.formatted(date: .abbreviated, time: .shortened))

                    if let notes = expense.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(GatherFont.caption)
                                .foregroundStyle(Color.gatherSecondaryText)
                            Text(notes)
                                .font(GatherFont.callout)
                        }
                    }
                }

                // Payment status
                Section("Payment") {
                    Toggle("Paid", isOn: Binding(
                        get: { expense.isPaid },
                        set: { newValue in
                            expense.isPaid = newValue
                            if newValue {
                                expense.paidDate = Date()
                            } else {
                                expense.paidDate = nil
                            }
                        }
                    ))

                    if expense.isPaid, let paidDate = expense.paidDate {
                        LabeledContent("Paid on", value: paidDate.formatted(date: .abbreviated, time: .omitted))
                    }

                    if !expense.isPaid {
                        if let dueDate = expense.dueDate {
                            LabeledContent("Due date", value: dueDate.formatted(date: .abbreviated, time: .omitted))

                            if dueDate < Date() {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(Color.rsvpNoFallback)
                                    Text("This payment is overdue")
                                        .font(GatherFont.caption)
                                        .foregroundStyle(Color.rsvpNoFallback)
                                }
                            }
                        }
                    }
                }

                // Function link
                if !functions.isEmpty {
                    Section("Function") {
                        if let funcId = expense.functionId,
                           let function = functions.first(where: { $0.id == funcId }) {
                            LabeledContent("Linked to", value: function.name)
                        } else {
                            Text("General (not linked)")
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                    }
                }

                // Delete
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Expense", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete Expense", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(expense.name)\"? This cannot be undone.")
            }
        }
    }
}

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var budget: Budget
    let functions: [EventFunction]
    var filterFunction: EventFunction?

    @State private var name = ""
    @State private var icon = "dollarsign.circle"
    @State private var allocated: Double = 0
    @State private var color = "purple"
    @State private var selectedFunctionId: UUID?

    private let iconOptions = [
        "dollarsign.circle", "building.2", "fork.knife", "camera",
        "music.note", "sparkles", "gift", "car",
        "tshirt", "envelope", "leaf", "cup.and.saucer",
        "bag", "paintbrush", "film", "mic"
    ]

    private let colorOptions = ["purple", "pink", "blue", "green", "orange", "teal", "indigo", "red"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Category Name") {
                    TextField("e.g. Venue, Catering", text: $name)
                }

                Section("Budget Amount") {
                    TextField("Allocated budget", value: $allocated, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .keyboardType(.decimalPad)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { opt in
                            Button {
                                icon = opt
                            } label: {
                                Image(systemName: opt)
                                    .font(.title3)
                                    .foregroundStyle(icon == opt ? .white : Color.gatherPrimaryText)
                                    .frame(width: 36, height: 36)
                                    .background(icon == opt ? Color.accentPurpleFallback : Color.gatherTertiaryBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }

                Section("Color") {
                    HStack(spacing: 12) {
                        ForEach(colorOptions, id: \.self) { opt in
                            Circle()
                                .fill(colorForName(opt))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white, lineWidth: color == opt ? 3 : 0)
                                )
                                .shadow(color: color == opt ? colorForName(opt).opacity(0.5) : .clear, radius: 4)
                                .onTapGesture { color = opt }
                        }
                    }
                }

                if !functions.isEmpty {
                    Section("Link to Function (Optional)") {
                        Picker("Function", selection: $selectedFunctionId) {
                            Text("None").tag(UUID?.none)
                            ForEach(functions.sorted { $0.date < $1.date }) { function in
                                Text(function.name).tag(Optional(function.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let category = BudgetCategory(
                            name: name,
                            icon: icon,
                            allocated: allocated,
                            color: color,
                            sortOrder: budget.categories.count,
                            functionId: selectedFunctionId ?? filterFunction?.id
                        )
                        budget.categories.append(category)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "purple": return .purple
        case "pink": return .pink
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "teal": return .teal
        case "indigo": return .indigo
        case "red": return .red
        default: return .purple
        }
    }
}

// MARK: - Add Expense Sheet (for specific category)

struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var category: BudgetCategory
    let functions: [EventFunction]

    @State private var name = ""
    @State private var amount: Double = 0
    @State private var vendorName = ""
    @State private var paidByName = ""
    @State private var isPaid = false
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var notes = ""
    @State private var selectedFunctionId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    TextField("Name", text: $name)
                    TextField("Amount", value: $amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .keyboardType(.decimalPad)
                }

                Section("Vendor (Optional)") {
                    TextField("Vendor name", text: $vendorName)
                }

                Section("Who Paid?") {
                    TextField("e.g. You, Aisha, Jordan", text: $paidByName)
                }

                Section("Payment") {
                    Toggle("Already Paid", isOn: $isPaid)

                    if !isPaid {
                        Toggle("Set Due Date", isOn: $hasDueDate)
                        if hasDueDate {
                            DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        }
                    }
                }

                if !functions.isEmpty {
                    Section("Link to Function") {
                        Picker("Function", selection: $selectedFunctionId) {
                            Text("General").tag(UUID?.none)
                            ForEach(functions.sorted { $0.date < $1.date }) { function in
                                Text(function.name).tag(Optional(function.id))
                            }
                        }
                    }
                }

                Section("Notes (Optional)") {
                    TextField("e.g. 50% deposit, balance on event day", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Add to \(category.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let expense = Expense(
                            name: name,
                            amount: amount,
                            isPaid: isPaid,
                            paidDate: isPaid ? Date() : nil,
                            dueDate: hasDueDate ? dueDate : nil,
                            notes: notes.isEmpty ? nil : notes,
                            vendorName: vendorName.isEmpty ? nil : vendorName,
                            paidByName: paidByName.isEmpty ? nil : paidByName,
                            functionId: selectedFunctionId
                        )
                        category.expenses.append(expense)
                        category.spent += amount
                        dismiss()
                    }
                    .disabled(name.isEmpty || amount <= 0)
                }
            }
        }
    }
}

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
                            .foregroundStyle(remaining >= 0 ? .green : .red)
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

// MARK: - Add Split Sheet

struct AddSplitSheet: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var budget: Budget

    @State private var name = ""
    @State private var email = ""
    @State private var shareAmount: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Co-Host Info") {
                    TextField("Name", text: $name)
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                Section("Share Amount") {
                    TextField("Amount", value: $shareAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let split = PaymentSplit(
                            name: name,
                            email: email.isEmpty ? nil : email,
                            shareAmount: shareAmount
                        )
                        budget.splits.append(split)
                        dismiss()
                    }
                    .disabled(name.isEmpty || shareAmount <= 0)
                }
            }
        }
    }
}

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

// MARK: - Preview

#Preview {
    @Previewable @State var previewEvent = Event(
        title: "Birthday Party",
        startDate: Date(),
        category: .party,
        enabledFeatures: [.budget, .guestManagement]
    )
    BudgetTab(event: previewEvent)
        .modelContainer(for: [Budget.self, BudgetCategory.self, Expense.self, PaymentSplit.self])
}
