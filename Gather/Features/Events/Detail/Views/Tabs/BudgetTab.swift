import SwiftUI
import SwiftData

/// One person's total contribution across every expense in the event.
private struct PayerTotal: Identifiable {
    let name: String
    let paid: Double
    var id: String { name }
}

/// Quick-nav slices of the Finance tab. `.all` shows everything; any other
/// case shows just that section so the page stays short on phones.
/// Three true segments instead of a 6-chip filter over one mega-scroll.
/// Overview is a compact dashboard; the deep lists live one tap away.
private enum BudgetSection: String, CaseIterable {
    case overview = "Overview"
    case expenses = "Expenses"
    case people = "People"
}

struct BudgetTab: View {
    @Bindable var event: Event
    @State private var filterFunction: EventFunction?
    /// The "General" scope chip — expenses not tied to any function. Mutually
    /// exclusive with filterFunction.
    @State private var filterGeneralOnly = false

    /// Bucket name for paid money with no recorded payer. Shown in Who Paid
    /// What (so totals reconcile with the Paid stat) but excluded from Settle Up.
    private static let unattributedPayer = "Unattributed"
    @State private var showAddCategory = false
    @State private var showAddExpense = false
    @State private var showEditBudget = false
    @State private var showAddSplit = false
    @State private var addExpenseCategory: BudgetCategory?
    @State private var editingExpense: Expense?
    @State private var expandedCategoryId: UUID?
    /// Whether the folded-away "N unused categories" group is expanded.
    @State private var showUnusedCategories = false
    @State private var showTeam = false
    @State private var selectedVendor: VendorSummary?
    @State private var recordingSplit: PaymentSplit?
    @State private var showSplitPaymentAlert = false
    @State private var splitPaymentText = ""
    @State private var visibleSection: BudgetSection = .overview
    @State private var showAllTransactions = false
    @State private var selectedPayer: PayerTotal?
    @State private var payingExpense: Expense?
    @State private var showPayConfirm = false
    @State private var openExpenseInPayment = false
    @State private var editingSplit: PaymentSplit?
    @State private var showEditSplitAlert = false
    @State private var editSplitShareText = ""
    @State private var deletingSplit: PaymentSplit?
    @State private var showDeleteSplitAlert = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager

    @Query private var eventBudgets: [Budget]

    init(event: Event) {
        self.event = event
        let eventId = event.id
        _eventBudgets = Query(
            filter: #Predicate<Budget> { $0.eventId == eventId }
        )
    }

    var body: some View {
        // Content-only: EventDetailView owns the page scroll.
        Group {
            VStack(spacing: Spacing.lg) {
                if let budget = eventBudget {
                    // PERF-004: Compute expenses once and build category lookup.
                    // The function filter is applied HERE, once, so every money
                    // section on the page (summary, breakdown, who-paid-what,
                    // settle up, upcoming, transactions) agrees with the filter.
                    let expenses = filteredExpenses(budget)
                    let categoryLookup = buildCategoryLookup(budget)

                    // Overdue / Over-budget alerts (always visible)
                    alertBanners(budget, expenses: expenses)

                    // Three-segment switcher.
                    sectionNav(budget, expenses: expenses)

                    // Function Filter — drives every money figure on the page.
                    if !event.functions.isEmpty {
                        functionFilterPicker
                    }

                    switch visibleSection {
                    case .overview:
                        // Compact dashboard: headline number, the primary
                        // action, what needs attention, and a spend preview.
                        summaryCard(budget)

                        // Primary actions (Add Expense / Manage Team).
                        quickActions(budget)

                        // Upcoming Payments — the "needs attention" list.
                        upcomingPayments(budget, expenses: expenses, categoryLookup: categoryLookup)

                        // Payment Breakdown (Paid / Owed / Overdue)
                        paymentBreakdown(budget, expenses: expenses)

                        // Spending by category uses whole-event category totals
                        // and allocations, which don't scope to a single
                        // function — so it's a whole-event ("All") view only,
                        // never shown next to a scoped "Spent under <fn>" card.
                        if !isFunctionFiltered {
                            spendingByCategory(budget)
                        }

                    case .expenses:
                        // Every expense, grouped: by category, by vendor, then flat.
                        categoriesSection(budget)

                        if !budget.vendorSummaries.isEmpty {
                            vendorSection(budget, expenses: expenses)
                        }

                        allTransactions(budget, expenses: expenses, categoryLookup: categoryLookup)

                    case .people:
                        // Who paid, who owes whom, and manual co-host splits.
                        whoPaidWhat(budget, expenses: expenses)

                        settleUp(budget, expenses: expenses)

                        if !budget.splits.isEmpty || isHost {
                            splitsSection(budget)
                        }
                    }
                } else {
                    emptyState
                }
            }
            .padding(.vertical)
            .horizontalPadding()
            .padding(.bottom, Layout.scrollBottomInsetCompact)
        }
        .sheet(isPresented: $showAddCategory) {
            if let budget = eventBudget {
                AddCategorySheet(budget: budget, functions: event.functions, filterFunction: filterFunction)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $addExpenseCategory) { category in
            // Same form as the quick-action "Add Expense", pre-seeded with the
            // tapped category, so both entry points feel like one feature.
            if let budget = eventBudget {
                QuickAddExpenseSheet(budget: budget, functions: event.functions, preselectedCategoryId: category.id)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showEditBudget) {
            if let budget = eventBudget {
                EditBudgetSheet(budget: budget)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showAddSplit) {
            if let budget = eventBudget {
                AddSplitSheet(budget: budget)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $editingExpense, onDismiss: { openExpenseInPayment = false }) { expense in
            ExpenseDetailSheet(
                expense: expense,
                functions: event.functions,
                category: owningCategory(of: expense),
                startInRecordPayment: openExpenseInPayment,
                onDelete: {
                    deleteExpense(expense)
                }
            )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedVendor) { vendor in
            if let budget = eventBudget {
                VendorDetailSheet(budget: budget, vendorName: vendor.name, functions: event.functions)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showAddExpense) {
            if let budget = eventBudget {
                QuickAddExpenseSheet(budget: budget, functions: event.functions)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showTeam) {
            EventTeamSheet(event: event)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedPayer) { payer in
            // Payment history behind a Who Paid What / Settle Up row, so an
            // "owes $X" state is explainable payment by payment.
            if let budget = eventBudget {
                PayerDetailSheet(budget: budget, payerName: payer.name)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .alert("Record Payment", isPresented: $showSplitPaymentAlert, presenting: recordingSplit) { split in
            TextField("Amount", text: $splitPaymentText)
                .keyboardType(.decimalPad)
            Button("Record") {
                recordSplitPayment(split)
            }
            Button("Cancel", role: .cancel) {}
        } message: { split in
            Text("\(split.name) still owes \(split.owedAmount.asCurrency).")
        }
        .alert("Edit Share", isPresented: $showEditSplitAlert, presenting: editingSplit) { split in
            TextField("Share amount", text: $editSplitShareText)
                .keyboardType(.decimalPad)
            Button("Save") {
                saveSplitShare(split)
            }
            Button("Cancel", role: .cancel) {}
        } message: { split in
            Text("Update \(split.name)'s share of the costs.")
        }
        .alert("Delete Split?", isPresented: $showDeleteSplitAlert, presenting: deletingSplit) { split in
            Button("Delete", role: .destructive) {
                deleteSplit(split)
            }
            Button("Cancel", role: .cancel) {}
        } message: { split in
            Text("Removes \(split.name)'s \(split.shareAmount.asCurrency) share\(split.paidAmount > 0 ? " and their recorded payments" : ""). This cannot be undone.")
        }
        .confirmationDialog("Mark as paid?", isPresented: $showPayConfirm, titleVisibility: .visible, presenting: payingExpense) { expense in
            Button("Pay \(expense.amountRemaining.asCurrency)") {
                if let budget = eventBudget {
                    markAsPaid(expense, in: budget)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { expense in
            Text("Records the remaining \(expense.amountRemaining.asCurrency) on \u{201C}\(expense.name)\u{201D} as paid.")
        }
        .task {
            // First open on a new device: pull the budget the host built elsewhere.
            await FirestoreService.shared.fetchBudget(for: event, into: modelContext)
        }
        .onDisappear {
            // Leaving the tab snapshots the whole budget tree to the cloud so
            // finance edits follow the host across devices.
            if isHost, let budget = eventBudget {
                FirestoreService.shared.pushBudget(budget, eventId: event.id)
            }
        }
    }

    private var eventBudget: Budget? {
        eventBudgets.first
    }

    private var isHost: Bool {
        authManager.currentUser?.id == event.hostId
    }

    // MARK: - Empty State

    private var emptyState: some View {
        GatherEmptyState(
            icon: "dollarsign.circle",
            title: "No budget yet",
            message: "Track expenses, manage payments, and split costs with co-hosts.",
            actionTitle: "Set a Budget",
            action: createBudget
        )
        .padding(.vertical, Spacing.xxl)
        .bouncyAppear()
    }

    // MARK: - Alert Banners

    @ViewBuilder
    private func alertBanners(_ budget: Budget, expenses: [Expense]) -> some View {
        let overBudgetCategories = filteredCategories(budget).filter { $0.isOverBudget }
        let overdueExpenses = expenses.filter { expense in
            expense.paymentState != .paid && (expense.dueDate.map { $0 < Date() } ?? false)
        }

        if !overdueExpenses.isEmpty {
            // Tapping lands on the Overview slice where Upcoming Payments lives.
            Button {
                jumpToSection(.overview)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(overdueExpenses.count) overdue \(overdueExpenses.count == 1 ? "payment" : "payments")")
                            .font(GatherFont.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Text(overdueExpenses.reduce(0) { $0 + $1.amountRemaining }.asCurrency + " needs attention")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(Spacing.sm)
                .background(Color.gatherError.gradient)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
            .buttonStyle(CardPressStyle())
            // A11Y-019: Alert banner accessibility
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(overdueExpenses.count) overdue \(overdueExpenses.count == 1 ? "payment" : "payments"). \(overdueExpenses.reduce(0) { $0 + $1.amountRemaining }.asCurrency) needs attention")
            .accessibilityHint("Double tap to view upcoming payments")
            .accessibilityAddTraits(.isButton)
        }

        // Over-budget is measured against whole-event category allocations, so
        // it's only meaningful in the unscoped ("All") view — never alongside a
        // function-scoped spend total.
        if !overBudgetCategories.isEmpty, !isFunctionFiltered {
            // Tapping opens Categories with the first offender expanded.
            // Tinted-pill styling (amber text on soft amber) keeps WCAG
            // contrast where white-on-amber failed.
            Button {
                HapticService.buttonTap()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    visibleSection = .expenses
                    expandedCategoryId = overBudgetCategories.first?.id
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.rsvpMaybeFallback)
                    Text("\(overBudgetCategories.count) \(overBudgetCategories.count == 1 ? "category" : "categories") over budget")
                        .font(GatherFont.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.rsvpMaybeFallback)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color.rsvpMaybeFallback)
                }
                .padding(Spacing.sm)
                .background(Color.rsvpMaybeFallback.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
            .buttonStyle(CardPressStyle())
            // A11Y-019: Alert banner accessibility
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(overBudgetCategories.count) \(overBudgetCategories.count == 1 ? "category" : "categories") over budget")
            .accessibilityHint("Double tap to view the over-budget categories")
            .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: - Summary Card

    /// The flagship overview: a circular progress ring paired with big,
    /// confident Total / Spent / Remaining figures. The ring and headline
    /// numbers shift green → amber → red as the budget fills up.
    private func summaryCard(_ budget: Budget) -> some View {
        let spentAmount = filteredSpent(budget)
        let percent = filteredPercentSpent(budget)
        let percentUsed = Int(percent.rounded())
        let remainingAmount = filteredRemaining(budget)
        let accent = spentColor(budget)
        let isOver = remainingAmount < 0

        return VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text("Finance")
                    .gatherEyebrow()
                    .foregroundStyle(Color.gatherTertiaryText)
                    // A11Y-007: Section header trait
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    HapticService.buttonTap()
                    showEditBudget = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Edit")
                    }
                    .font(GatherFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentPurpleFallback)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .background(Color.accentPurpleFallback.opacity(0.12))
                    .clipShape(Capsule())
                }
                .accessibilityLabel("Edit budget")
            }

            if isFunctionFiltered {
                // The whole-event budget doesn't apply to a single function, so
                // don't divide a scoped spend by it — just show what was spent
                // under this scope. "All" restores the ring + remaining.
                let scopedCount = filteredExpenses(budget).count
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Spent under \(filterScopeName)")
                        .gatherEyebrow()
                        .foregroundStyle(Color.gatherSecondaryText)
                    Text(spentAmount.asCurrency)
                        .font(.system(.largeTitle, weight: .heavy))
                        .foregroundStyle(Color.gatherPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(scopedCount) expense\(scopedCount == 1 ? "" : "s")")
                        .gatherMetaText()
                        .foregroundStyle(Color.gatherTertiaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: Spacing.lg) {
                    // Circular progress ring — the confident focal point.
                    budgetRing(percent: percent, percentUsed: percentUsed, accent: accent, isOver: isOver)
                        .frame(width: 116, height: 116)

                    VStack(alignment: .leading, spacing: Spacing.md) {
                        summaryMetric(
                            label: "Spent",
                            value: spentAmount.asCurrency,
                            color: accent,
                            emphasized: true
                        )
                        summaryMetric(
                            label: isOver ? "Over budget" : "Remaining",
                            value: abs(remainingAmount).asCurrency,
                            color: isOver ? Color.rsvpNoFallback : Color.rsvpYesFallback,
                            emphasized: false
                        )
                        summaryMetric(
                            label: "Total budget",
                            value: budget.totalBudget.asCurrency,
                            color: Color.gatherPrimaryText,
                            emphasized: false
                        )
                    }

                    Spacer(minLength: 0)
                }

                // Only surface the zero-budget nudge when no amount is set.
                if budget.totalBudget == 0 {
                    Label("Tap Edit to set your total budget", systemImage: "slider.horizontal.3")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentPurpleFallback)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(Spacing.md)
        .surfaceCard(cornerRadius: CornerRadius.featured)
        // A11Y-009: Financial data grouping for budget summary
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isFunctionFiltered
                ? "Spent under \(filterScopeName): \(spentAmount.asCurrency)."
                : "Finance overview. Total budget \(budget.totalBudget.asCurrency). Spent \(spentAmount.asCurrency). \(percentUsed) percent used. \(isOver ? "\(abs(remainingAmount).asCurrency) over budget." : "\(remainingAmount.asCurrency) remaining.")"
        )
        .bouncyAppear()
    }

    /// Circular budget ring with the percent used at its center.
    private func budgetRing(percent: Double, percentUsed: Int, accent: Color, isOver: Bool) -> some View {
        let clamped = min(percent / 100, 1)
        return ZStack {
            Circle()
                .stroke(Color.gatherElevated, lineWidth: 12)

            Circle()
                .trim(from: 0, to: max(0.001, clamped))
                .stroke(
                    AngularGradient(
                        colors: isOver
                            ? [Color.rsvpNoFallback, .orange, Color.rsvpNoFallback]
                            : [Color.accentPurpleFallback, Color.accentPinkFallback, Color.accentPurpleFallback],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: clamped)

            VStack(spacing: 0) {
                Text("\(percentUsed)%")
                    // A11Y-005: relative style so the ring center scales
                    .font(.system(.title2, weight: .heavy))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("used")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.gatherTertiaryText)
            }
        }
    }

    private func summaryMetric(label: String, value: String, color: Color, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .gatherEyebrow()
                .foregroundStyle(Color.gatherTertiaryText)
            Text(value)
                // A11Y-005: relative styles so key figures scale
                .font(emphasized ? .system(.title2, weight: .heavy) : .system(.headline, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    // MARK: - Payment Breakdown

    private func paymentBreakdown(_ budget: Budget, expenses: [Expense]) -> some View {
        let totalAmount = expenses.reduce(0) { $0 + $1.amount }
        // Installment-aware: counts partial payments toward Paid and only
        // outstanding balances toward Owed/Overdue. Derived from the
        // function-filtered expenses so these cards agree with the summary.
        let paidAmount = expenses.reduce(0) { $0 + min($1.amountPaid, $1.amount) }
        let pendingAmount = expenses.reduce(0) { $0 + $1.amountRemaining }
        let overdueAmount = expenses.filter { $0.paymentState != .paid && ($0.dueDate.map { $0 < Date() } ?? false) }.reduce(0) { $0 + $1.amountRemaining }

        return HStack(spacing: Spacing.sm) {
            paymentStatCard(
                label: "Paid",
                amount: paidAmount,
                total: totalAmount,
                icon: "checkmark.circle.fill",
                color: Color.rsvpYesFallback
            ) {
                jumpToSection(.expenses)
            }
            paymentStatCard(
                label: "Owed",
                amount: pendingAmount,
                total: totalAmount,
                icon: "clock.fill",
                color: overdueAmount > 0 ? Color.rsvpMaybeFallback : Color.accentPurpleFallback
            ) {
                jumpToSection(.overview)
            }
            if overdueAmount > 0 {
                paymentStatCard(
                    label: "Overdue",
                    amount: overdueAmount,
                    total: totalAmount,
                    icon: "exclamationmark.circle.fill",
                    color: Color.rsvpNoFallback
                ) {
                    jumpToSection(.overview)
                }
            }
        }
    }

    private func paymentStatCard(label: String, amount: Double, total: Double, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.footnote)
                        .foregroundStyle(color)
                    Text(label.uppercased())
                        .gatherEyebrow()
                        .foregroundStyle(Color.gatherTertiaryText)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .imageScale(.small)
                        .foregroundStyle(Color.gatherTertiaryText)
                }

                Text(amount.asCurrency)
                    .font(GatherFont.headline)
                    .fontWeight(.heavy)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                // Mini progress
                if total > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gatherElevated)
                            Capsule()
                                .fill(color)
                                .frame(width: max(0, min(geometry.size.width, geometry.size.width * (amount / total))))
                        }
                    }
                    .frame(height: 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .surfaceCard(cornerRadius: CornerRadius.lg)
        }
        .buttonStyle(CardPressStyle())
        // A11Y-009: Financial data grouping for payment stat cards
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label). \(amount.asCurrency)")
        .accessibilityHint("Double tap to view matching payments")
    }

    // MARK: - Spending by Category

    /// A visual breakdown of where the money is going: a stacked "donut" bar of
    /// each category's share of spend, then per-category rows with icon, color,
    /// share percent, and amount. Purely derived from existing category data.
    @ViewBuilder
    private func spendingByCategory(_ budget: Budget) -> some View {
        // Only categories that have actually been spent against.
        let spending = filteredCategories(budget)
            .filter { $0.spent > 0.005 }
            .sorted { $0.spent > $1.spent }
        let totalSpent = spending.reduce(0) { $0 + $1.spent }

        if !spending.isEmpty, totalSpent > 0 {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .foregroundStyle(Color.accentPurpleFallback)
                    Text("Spending by Category")
                        .gatherSectionHeader()
                        .foregroundStyle(Color.gatherPrimaryText)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text(totalSpent.asCurrency)
                        .gatherMetaText()
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                // Stacked share bar ("donut" unrolled) — each category's slice.
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(spending) { category in
                            categoryColor(category.color)
                                .frame(width: max(3, geometry.size.width * (category.spent / totalSpent)))
                        }
                    }
                    .frame(height: 14)
                    .clipShape(Capsule())
                }
                .frame(height: 14)
                .accessibilityHidden(true)

                VStack(spacing: Spacing.sm) {
                    // Cap the list — the stacked bar above already shows the
                    // full distribution; "Show all" jumps to Categories.
                    ForEach(spending.prefix(4)) { category in
                        categoryShareRow(category, totalSpent: totalSpent)
                    }

                    if spending.count > 4 {
                        Button {
                            jumpToSection(.expenses)
                        } label: {
                            HStack(spacing: 4) {
                                Text("Show all categories")
                                Image(systemName: "chevron.right")
                            }
                            .font(GatherFont.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentPurpleFallback)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.xs)
                        }
                        .frame(minHeight: Layout.minTouchTarget)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Show all \(spending.count) categories")
                    }
                }
            }
            .padding(Spacing.md)
            .surfaceCard()
            .bouncyAppear(delay: 0.05)
        }
    }

    private func categoryShareRow(_ category: BudgetCategory, totalSpent: Double) -> some View {
        let share = totalSpent > 0 ? (category.spent / totalSpent) * 100 : 0
        let color = categoryColor(category.color)

        // Tap lands on the Categories slice with this category expanded.
        return Button {
            HapticService.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                visibleSection = .expenses
                expandedCategoryId = category.id
            }
        } label: {
            categoryShareRowContent(category, share: share, color: color)
        }
        .buttonStyle(CardPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(category.name). \(category.spent.asCurrency), \(Int(share.rounded())) percent of spending.")
        .accessibilityHint("Double tap to open this category")
    }

    private func categoryShareRowContent(_ category: BudgetCategory, share: Double, color: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: category.icon)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.name)
                        .gatherRowTitle()
                        .foregroundStyle(Color.gatherPrimaryText)
                        .lineLimit(1)
                    Spacer()
                    Text(category.spent.asCurrency)
                        .gatherRowTitle()
                        .foregroundStyle(Color.gatherPrimaryText)
                }

                // Per-category share track.
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gatherElevated)
                        Capsule()
                            .fill(color)
                            .frame(width: max(3, geometry.size.width * share / 100))
                    }
                }
                .frame(height: 5)
            }

            Text("\(Int(share.rounded()))%")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(Color.gatherSecondaryText)
                .frame(width: 34, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .imageScale(.small)
                .foregroundStyle(Color.gatherTertiaryText)
        }
    }

    // MARK: - Payer Aggregation

    /// Per-person total actually paid across every expense in the event.
    ///
    /// Walks each expense's individual payments and attributes each to its
    /// `paidByName`. When an expense has recorded payments but a payment carries
    /// no payer, that money falls back to the expense-level `paidByName`
    /// (legacy single-payer). Expenses with no recorded payments but a legacy
    /// `isPaid`/`paidByName` are attributed as a full payment to that person.
    private func payerTotals(_ expenses: [Expense]) -> [PayerTotal] {
        var totals: [String: Double] = [:]

        for expense in expenses {
            let payments = expense.recordedPayments
            if payments.isEmpty {
                // Legacy expense paid without a per-payment ledger — attribute
                // the paid amount so this money isn't silently dropped.
                let paid = min(expense.amountPaid, expense.amount)
                if paid > 0 {
                    let name = (expense.paidByName?.isEmpty == false ? expense.paidByName! : Self.unattributedPayer)
                    totals[name, default: 0] += paid
                }
                continue
            }

            // Cap the money attributed to this expense at its amount, so if the
            // amount was later edited below its recorded payments the People
            // totals don't exceed the Paid stat (which caps at min(paid, amount)).
            let rawSum = payments.reduce(0.0) { $0 + $1.amount }
            let scale = rawSum > expense.amount && rawSum > 0 ? expense.amount / rawSum : 1

            for payment in payments {
                let payer = (payment.paidByName?.isEmpty == false ? payment.paidByName : nil)
                    ?? (expense.paidByName?.isEmpty == false ? expense.paidByName : nil)
                // Payments with no payer used to be dropped, so the People
                // total silently disagreed with the Paid stat. Bucket them under
                // "Unattributed" instead — settleUp filters this sentinel out.
                totals[payer ?? Self.unattributedPayer, default: 0] += payment.amount * scale
            }
        }

        return totals
            .map { PayerTotal(name: $0.key, paid: $0.value) }
            .sorted { $0.paid > $1.paid }
    }

    // MARK: - Who Paid What

    @ViewBuilder
    private func whoPaidWhat(_ budget: Budget, expenses: [Expense]) -> some View {
        let payers = payerTotals(expenses)
        let totalPaid = payers.reduce(0) { $0 + $1.paid }

        if !payers.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: "person.2.circle.fill")
                        .foregroundStyle(Color.accentPurpleFallback)
                    Text("Who Paid What")
                        .gatherSectionHeader()
                        .foregroundStyle(Color.gatherPrimaryText)
                        // A11Y-007: Section header trait
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text(totalPaid.asCurrency)
                        .gatherMetaText()
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                VStack(spacing: Spacing.sm) {
                    ForEach(payers) { payer in
                        whoPaidRow(payer, totalPaid: totalPaid)
                    }
                }
            }
            .padding(Spacing.md)
            .surfaceCard()
            .bouncyAppear(delay: 0.08)
        }
    }

    private func whoPaidRow(_ payer: PayerTotal, totalPaid: Double) -> some View {
        let share = totalPaid > 0 ? (payer.paid / totalPaid) * 100 : 0
        let name = payer.name.isEmpty ? "Unknown" : payer.name

        // Tap opens the payer's payment history sheet.
        return Button {
            HapticService.buttonTap()
            selectedPayer = payer
        } label: {
            whoPaidRowContent(payer, share: share)
        }
        .buttonStyle(CardPressStyle())
        // A11Y: Who-paid-what row grouping
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) paid \(payer.paid.asCurrency), \(Int(share.rounded())) percent of the total.")
        .accessibilityHint("Double tap to see this person's payments")
    }

    private func whoPaidRowContent(_ payer: PayerTotal, share: Double) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(avatarColor(for: payer.name))
                .frame(width: 38, height: 38)
                .overlay {
                    Text(payer.name.isEmpty ? "?" : payer.name.prefix(1).uppercased())
                        .font(GatherFont.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(payer.name.isEmpty ? "Unknown" : payer.name)
                        .gatherRowTitle()
                        .foregroundStyle(Color.gatherPrimaryText)
                        .lineLimit(1)
                    Spacer()
                    Text(payer.paid.asCurrency)
                        .gatherRowTitle()
                        .foregroundStyle(Color.gatherPrimaryText)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gatherElevated)
                        Capsule()
                            .fill(avatarColor(for: payer.name))
                            .frame(width: max(3, geometry.size.width * share / 100))
                    }
                }
                .frame(height: 5)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .imageScale(.small)
                .foregroundStyle(Color.gatherTertiaryText)
        }
    }

    // MARK: - Settle Up

    @ViewBuilder
    private func settleUp(_ budget: Budget, expenses: [Expense]) -> some View {
        // "Unattributed" money can't be split between people, so it's excluded
        // from the even-split maths (it still shows in Who Paid What).
        let payers = payerTotals(expenses).filter { $0.name != Self.unattributedPayer }

        // Only meaningful with 2+ distinct payers to split between.
        if payers.count >= 2 {
            let totalPaid = payers.reduce(0) { $0 + $1.paid }
            let fairShare = totalPaid / Double(payers.count)
            let sortedByBalance = payers
                .map { (name: $0.name, balance: $0.paid - fairShare) }
                .sorted { $0.balance > $1.balance }

            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .foregroundStyle(Color.accentPurpleFallback)
                    Text("Settle Up")
                        .gatherSectionHeader()
                        .foregroundStyle(Color.gatherPrimaryText)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                }

                // Even-split summary on a nested elevated tile.
                HStack(alignment: .center, spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TOTAL PAID")
                            .gatherEyebrow()
                            .foregroundStyle(Color.gatherTertiaryText)
                        Text(totalPaid.asCurrency)
                            .gatherCardTitle()
                            .foregroundStyle(Color.gatherPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(Color.gatherTertiaryText)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("EVEN SPLIT \u{00B7} \(payers.count)")
                            .gatherEyebrow()
                            .foregroundStyle(Color.gatherTertiaryText)
                        Text(fairShare.asCurrency)
                            .gatherCardTitle()
                            .foregroundStyle(Color.gatherPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .padding(Spacing.sm)
                .background(Color.gatherElevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Total paid \(totalPaid.asCurrency). Even split \(fairShare.asCurrency) each across \(payers.count) people.")

                VStack(spacing: Spacing.sm) {
                    ForEach(sortedByBalance, id: \.name) { entry in
                        settleUpRow(name: entry.name, balance: entry.balance)
                    }
                }
            }
            .padding(Spacing.md)
            .surfaceCard()
            .bouncyAppear(delay: 0.1)
        }
    }

    private func settleUpRow(name: String, balance: Double) -> some View {
        // Round to the cent so tiny Double residue doesn't read as "owes $0".
        let cents = (balance * 100).rounded() / 100
        let displayName = name.isEmpty ? "Unknown" : name

        let statusText: String
        let statusValue: String
        let statusColor: Color
        let statusIcon: String
        if cents > 0.005 {
            statusText = "is owed"
            statusValue = cents.asCurrency
            statusColor = Color.rsvpYesFallback
            statusIcon = "arrow.down.left"
        } else if cents < -0.005 {
            statusText = "owes"
            statusValue = abs(cents).asCurrency
            statusColor = Color.rsvpNoFallback
            statusIcon = "arrow.up.right"
        } else {
            statusText = "settled up"
            statusValue = ""
            statusColor = Color.rsvpYesFallback
            statusIcon = "checkmark"
        }

        // Tap opens the payer's payment history so an "owes" state is
        // explainable — the user can see exactly what made up the balance.
        return Button {
            HapticService.buttonTap()
            selectedPayer = PayerTotal(name: name, paid: max(0, balance))
        } label: {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(avatarColor(for: name))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Text(name.isEmpty ? "?" : name.prefix(1).uppercased())
                            .font(GatherFont.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text(displayName)
                        .gatherRowTitle()
                        .foregroundStyle(Color.gatherPrimaryText)
                        .lineLimit(1)
                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(Color.gatherTertiaryText)
                }

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: statusIcon)
                        .font(.caption2)
                        .fontWeight(.bold)
                    if !statusValue.isEmpty {
                        Text(statusValue)
                            .font(GatherFont.caption)
                            .fontWeight(.bold)
                    }
                }
                .foregroundStyle(statusColor)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .buttonStyle(CardPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(displayName) \(statusText) \(statusValue)")
        .accessibilityHint("Double tap to see this person's payments")
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
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
                }
                // A11Y-023: Add Expense button touch target
                .frame(minHeight: 44)

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
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(Capsule())
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
            // A11Y-023: Add Category button touch target
            .frame(minHeight: 44)
        }
    }

    // MARK: - Segment Switcher

    /// Equal-width 3-segment capsule control (Overview / Expenses / People).
    /// Fits one row at every Dynamic Type size — no horizontal scroll.
    @ViewBuilder
    private func sectionNav(_ budget: Budget, expenses: [Expense]) -> some View {
        HStack(spacing: 0) {
            ForEach(BudgetSection.allCases, id: \.self) { section in
                let isSelected = visibleSection == section
                Button {
                    HapticService.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        visibleSection = section
                    }
                } label: {
                    Text(section.rawValue)
                        .font(GatherFont.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? Color.accentPurpleFallback : Color.gatherSecondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: Layout.minTouchTarget)
                        .background(
                            isSelected
                                ? AnyShapeStyle(Color.accentPurpleFallback.opacity(0.14))
                                : AnyShapeStyle(Color.clear)
                        )
                        .clipShape(Capsule())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.rawValue)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Color.gatherSurface)
        .clipShape(Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Finance sections")
    }

    // MARK: - Function Filter

    private var functionFilterPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Filter by Function")
                .textCase(.uppercase)
                .gatherEyebrow()
                .foregroundStyle(Color.gatherTertiaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    BudgetFilterChip(title: "All", isSelected: !isFunctionFiltered) {
                        HapticService.selection()
                        filterFunction = nil
                        filterGeneralOnly = false
                    }
                    // Reaches expenses not tied to any function — no longer
                    // silently folded into every function's totals.
                    BudgetFilterChip(title: "General", isSelected: filterGeneralOnly) {
                        HapticService.selection()
                        filterFunction = nil
                        filterGeneralOnly = true
                    }
                    ForEach(event.functions.sorted { $0.date < $1.date }) { function in
                        BudgetFilterChip(title: function.name, isSelected: filterFunction?.id == function.id) {
                            HapticService.selection()
                            filterGeneralOnly = false
                            filterFunction = function
                        }
                    }
                }
            }
        }
    }

    // MARK: - Upcoming Payments

    @ViewBuilder
    private func upcomingPayments(_ budget: Budget, expenses: [Expense], categoryLookup: [UUID: String]) -> some View {
        let upcoming = expenses
            .filter { $0.paymentState != .paid && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(Color.rsvpMaybeFallback)
                    Text("Upcoming Payments")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)
                        // A11Y-007: Section header trait
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    // Tinted-pill styling (amber on soft amber) keeps WCAG
                    // contrast where white-on-amber failed.
                    Text("\(upcoming.count)")
                        .font(GatherFont.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.rsvpMaybeFallback)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.rsvpMaybeFallback.opacity(0.15))
                        .clipShape(Capsule())
                }

                ForEach(upcoming.prefix(5)) { expense in
                    Button {
                        editingExpense = expense
                    } label: {
                        upcomingPaymentRow(expense, budget: budget, categoryLookup: categoryLookup)
                    }
                }
            }
            .padding()
            .surfaceCard()
            .bouncyAppear(delay: 0.05)
        }
    }

    private func upcomingPaymentRow(_ expense: Expense, budget: Budget, categoryLookup: [UUID: String]) -> some View {
        let isOverdue = expense.dueDate.map { $0 < Date() } ?? false
        let categoryName = categoryLookup[expense.id]

        return HStack(spacing: Spacing.sm) {
            // Due date indicator
            VStack(spacing: 2) {
                if let dueDate = expense.dueDate {
                    Text(dueDate.formatted(.dateTime.month(.abbreviated)))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(isOverdue ? Color.rsvpNoFallback : Color.gatherSecondaryText)
                    Text(dueDate.formatted(.dateTime.day()))
                        // A11Y-005: Dynamic Type-compatible font
                        .font(GatherFont.title3)
                        .fontWeight(.bold)
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
                            .font(.caption2)
                            .fontWeight(.bold)
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
                            Text("\u{00B7}")
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
                Text(expense.amountRemaining.asCurrency)
                    .font(GatherFont.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(isOverdue ? Color.rsvpNoFallback : Color.gatherPrimaryText)

                if expense.paymentState == .partial {
                    Text("of \(expense.amount.asCurrency)")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                HStack(spacing: 6) {
                    Button {
                        // Lands directly in the record-payment form — the
                        // flow the "Partial" label promises.
                        openExpenseInPayment = true
                        editingExpense = expense
                    } label: {
                        Text("Partial")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.accentPurpleFallback)
                            .padding(.horizontal, 10)
                            .padding(.vertical, Spacing.xs)
                            .frame(minWidth: 60)
                            .background(Color.gatherTertiaryBackground)
                            .clipShape(Capsule())
                    }
                    // A11Y: Partial payment button
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Record a partial payment for \(expense.name)")

                    Button {
                        // Confirm before recording the full remaining balance.
                        payingExpense = expense
                        showPayConfirm = true
                    } label: {
                        Text("Pay")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, Spacing.xs)
                            .frame(minWidth: 60)
                            .background(Color.rsvpYesFallback)
                            .clipShape(Capsule())
                    }
                    // A11Y-008: Pay button touch target
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Pay remaining \(expense.amountRemaining.asCurrency) for \(expense.name)")
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    // MARK: - Categories Section

    private func categoriesSection(_ budget: Budget) -> some View {
        let categories = filteredCategories(budget).sorted { $0.sortOrder < $1.sortOrder }

        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.accentPurpleFallback)
                Text("Categories")
                    .gatherSectionHeader()
                    .foregroundStyle(Color.gatherPrimaryText)
                    // A11Y-007: Section header trait
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    HapticService.buttonTap()
                    showAddCategory = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(GatherFont.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentPurpleFallback)
                }
                .accessibilityLabel("Add category")
            }

            if categories.isEmpty {
                GatherEmptyState(
                    icon: "folder.badge.plus",
                    title: "No categories yet",
                    message: "Break your budget into categories like venue, food, and decor to track spending.",
                    actionTitle: "Add Category"
                ) {
                    showAddCategory = true
                }
            } else {
                // A fresh wedding budget seeds ~10 categories with allocations
                // but no spend; showing them all floods the tab. Keep the ones
                // in use up top and fold the untouched ones behind one row.
                let used = categories.filter { $0.spent > 0 || !$0.expenses.isEmpty }
                let unused = categories.filter { $0.spent == 0 && $0.expenses.isEmpty }

                ForEach(used) { category in
                    categoryCard(category, budget: budget)
                }

                if !unused.isEmpty {
                    unusedCategoriesRow(unused, budget: budget)
                }
            }
        }
        .bouncyAppear(delay: 0.1)
    }

    /// Collapsed aggregate for categories that have no expenses yet — expands
    /// to the full cards on tap so nothing is lost, just tidied away.
    @ViewBuilder
    private func unusedCategoriesRow(_ unused: [BudgetCategory], budget: Budget) -> some View {
        VStack(spacing: Spacing.sm) {
            Button {
                HapticService.selection()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showUnusedCategories.toggle()
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "folder")
                        .foregroundStyle(Color.gatherSecondaryText)
                    Text("\(unused.count) unused \(unused.count == 1 ? "category" : "categories")")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherSecondaryText)
                    Spacer()
                    Image(systemName: showUnusedCategories ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.gatherTertiaryText)
                }
                .frame(minHeight: Layout.minTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(unused.count) unused categories")
            .accessibilityHint(showUnusedCategories ? "Double tap to collapse" : "Double tap to show them")

            if showUnusedCategories {
                ForEach(unused.sorted { $0.sortOrder < $1.sortOrder }) { category in
                    categoryCard(category, budget: budget)
                }
            }
        }
    }

    private func categoryCard(_ category: BudgetCategory, budget: Budget) -> some View {
        let isExpanded = expandedCategoryId == category.id

        return VStack(spacing: Spacing.sm) {
            // Main row - tap to expand
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    expandedCategoryId = isExpanded ? nil : category.id
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

                    // Paid / Owed mini indicator (installment-aware)
                    let catPaid = category.totalPaidAmount
                    let catOwed = category.expenses.reduce(0) { $0 + $1.amountRemaining }

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
                                .font(.caption2)
                                .foregroundStyle(Color.rsvpMaybeFallback)
                        } else if catPaid > 0 {
                            Text("All paid")
                                .font(.caption2)
                                .foregroundStyle(Color.rsvpYesFallback)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherTertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            // A11Y-009: Category expand/collapse hint
            .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")

            // Progress bar
            if category.allocated > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gatherElevated)

                        Capsule()
                            .fill(category.isOverBudget ? Color.rsvpNoFallback : categoryColor(category.color))
                            .frame(width: max(4, min(geometry.size.width, geometry.size.width * category.percentSpent / 100)))
                    }
                }
                .frame(height: 6)
            }

            // Expanded expenses
            if isExpanded {
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
                            .buttonStyle(CardPressStyle())
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
                    // A11Y-023: Add Expense button touch target
                    .frame(minHeight: 44)
                }
                .padding(.leading, Spacing.xl)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.sm)
        .surfaceCard()
    }

    /// Payment-aware presentation (icon, tint, a11y text) for an expense row.
    private func expenseRowStatus(_ expense: Expense, isOverdue: Bool) -> (icon: String, color: Color, text: String) {
        switch expense.paymentState {
        case .paid:
            return ("checkmark.circle.fill", Color.rsvpYesFallback, "Paid")
        case .partial:
            return ("circle.bottomhalf.filled", Color.rsvpMaybeFallback, "Partially paid, \(expense.amountRemaining.asCurrency) left")
        case .unpaid:
            if isOverdue {
                return ("exclamationmark.circle.fill", Color.rsvpNoFallback, "Overdue")
            }
            return ("circle", Color.gatherTertiaryText, "Unpaid")
        }
    }

    private func expenseRow(_ expense: Expense) -> some View {
        let state = expense.paymentState
        let isOverdue = state != .paid && (expense.dueDate.map { $0 < Date() } ?? false)
        let status = expenseRowStatus(expense, isOverdue: isOverdue)
        let statusText = status.text
        let iconName = status.icon
        let iconColor = status.color

        return HStack(spacing: Spacing.sm) {
            // Status icon
            Image(systemName: iconName)
                .font(.callout)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(expense.name)
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherPrimaryText)

                HStack(spacing: 4) {
                    if let paidBy = expense.paidByName, !paidBy.isEmpty {
                        Text(paidBy)
                        Text("\u{00B7}")
                    }
                    if let vendor = expense.vendorName {
                        Text(vendor)
                    }
                    if state == .paid, let paidDate = expense.paidDate {
                        if expense.vendorName != nil || expense.paidByName != nil { Text("\u{00B7}") }
                        Text("Paid \(paidDate.formatted(date: .abbreviated, time: .omitted))")
                    } else if let dueDate = expense.dueDate {
                        if expense.vendorName != nil || expense.paidByName != nil { Text("\u{00B7}") }
                        Text("Due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .font(.caption2)
                .foregroundStyle(isOverdue ? Color.rsvpNoFallback : Color.gatherTertiaryText)

                // Partial payment progress
                if state == .partial {
                    HStack(spacing: 6) {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gatherTertiaryBackground)
                            Capsule()
                                .fill(Color.rsvpMaybeFallback)
                                .frame(width: max(2, 56 * expense.percentPaid / 100))
                        }
                        .frame(width: 56, height: 3)

                        Text("\(expense.amountRemaining.asCurrency) left")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.rsvpMaybeFallback)
                    }
                    .padding(.top, 1)
                }
            }

            Spacer()

            Text(expense.amount.asCurrency)
                .font(GatherFont.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.gatherPrimaryText)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .imageScale(.small)
                .foregroundStyle(Color.gatherTertiaryText)
        }
        .padding(.vertical, 6)
        // A11Y-022: Expense row accessibility grouping
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(expense.name). \(expense.amount.asCurrency). \(statusText)")
    }

    // MARK: - Vendor Section

    @ViewBuilder
    private func vendorSection(_ budget: Budget, expenses: [Expense]) -> some View {
        let vendors = budget.vendorSummaries

        if !vendors.isEmpty {
            let vendorRemaining = vendors.reduce(0) { $0 + $1.remaining }
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: "bag.fill")
                        .foregroundStyle(Color.accentPurpleFallback)
                    Text("Vendors")
                        .gatherSectionHeader()
                        .foregroundStyle(Color.gatherPrimaryText)
                        // A11Y-007: Section header trait
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if vendorRemaining > 0.009 {
                        Text("\(vendorRemaining.asCurrency) to pay")
                            .gatherMetaText()
                            .foregroundStyle(Color.rsvpMaybeFallback)
                    } else {
                        Label("All settled", systemImage: "checkmark.circle.fill")
                            .font(GatherFont.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.rsvpYesFallback)
                    }
                }

                ForEach(vendors) { vendor in
                    Button {
                        HapticService.buttonTap()
                        selectedVendor = vendor
                    } label: {
                        vendorCard(vendor)
                    }
                    .buttonStyle(CardPressStyle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(vendor.name). \(vendor.expenseCount) \(vendor.expenseCount == 1 ? "expense" : "expenses"). \(vendor.paid.asCurrency) paid of \(vendor.total.asCurrency). \(vendor.isSettled ? "Settled" : "\(vendor.remaining.asCurrency) remaining")")
                    .accessibilityHint("Double tap to view vendor details")
                }
            }
            .bouncyAppear(delay: 0.2)
        }
    }

    private func vendorCard(_ vendor: VendorSummary) -> some View {
        HStack(spacing: Spacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(avatarColor(for: vendor.name))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(vendor.name.prefix(1).uppercased())
                            .font(GatherFont.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }

                if vendor.isSettled {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.rsvpYesFallback)
                        .background(Circle().fill(Color.gatherSecondaryBackground))
                        .offset(x: 3, y: 3)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(vendor.name)
                    .font(GatherFont.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.gatherPrimaryText)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gatherElevated)
                        Capsule()
                            .fill(Color.rsvpYesFallback)
                            .frame(width: max(0, min(geometry.size.width, geometry.size.width * vendor.percentPaid / 100)))
                    }
                }
                .frame(height: 4)

                Text("\(vendor.expenseCount) expense\(vendor.expenseCount == 1 ? "" : "s") \u{00B7} \(vendor.paid.asCurrency) paid of \(vendor.total.asCurrency)")
                    .font(.caption2)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if vendor.isSettled {
                    Label("Settled", systemImage: "checkmark.circle.fill")
                        .font(GatherFont.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.rsvpYesFallback)
                    Text(vendor.total.asCurrency)
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                } else {
                    Text(vendor.remaining.asCurrency)
                        .font(GatherFont.callout)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.rsvpMaybeFallback)
                    Text("left to pay")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Color.gatherTertiaryText)
        }
        .padding(Spacing.sm)
        .surfaceCard()
    }

    // MARK: - Splits Section

    private func splitsSection(_ budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Co-Host Splits")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)
                    // A11Y-007: Section header trait
                    .accessibilityAddTraits(.isHeader)
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
                    splitRow(split)
                }
            }
        }
        .bouncyAppear(delay: 0.25)
    }

    private func splitRow(_ split: PaymentSplit) -> some View {
        // Cap displayed progress/amounts at the share, even if overpaid.
        let paidDisplay = min(split.paidAmount, split.shareAmount)

        return HStack {
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
                            .frame(width: split.shareAmount > 0 ? min(geometry.size.width, geometry.size.width * (paidDisplay / split.shareAmount)) : 0)
                    }
                }
                .frame(height: 4)

                if !split.isPaidUp, split.paidAmount > 0 {
                    Text("\(paidDisplay.asCurrency) paid so far")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
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

                    Button {
                        HapticService.buttonTap()
                        splitPaymentText = String(format: "%.2f", split.owedAmount)
                        recordingSplit = split
                        showSplitPaymentAlert = true
                    } label: {
                        Text("Record payment")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.accentPurpleFallback)
                            .padding(.horizontal, 10)
                            .padding(.vertical, Spacing.xxs)
                            .background(Color.gatherTertiaryBackground)
                            .clipShape(Capsule())
                    }
                    // A11Y: Record split payment touch target
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Record a payment from \(split.name), \(split.owedAmount.asCurrency) remaining")
                }
            }

            // Visible overflow so edit/delete aren't trapped behind long-press.
            Menu {
                splitMenuItems(split)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(split.name)'s split")
        }
        .padding(Spacing.sm)
        .surfaceCard()
        .contextMenu {
            splitMenuItems(split)
        }
    }

    /// Edit / clear / delete actions for a co-host split — shared by the
    /// row's visible ellipsis Menu and its long-press context menu.
    @ViewBuilder
    private func splitMenuItems(_ split: PaymentSplit) -> some View {
        Button {
            HapticService.buttonTap()
            editSplitShareText = String(format: "%.2f", split.shareAmount)
            editingSplit = split
            showEditSplitAlert = true
        } label: {
            Label("Edit Share", systemImage: "slider.horizontal.3")
        }

        if split.paidAmount > 0 {
            Button {
                HapticService.buttonTap()
                split.paidAmount = 0
                modelContext.safeSave()
            } label: {
                Label("Clear Recorded Payments", systemImage: "arrow.uturn.backward")
            }
        }

        Button(role: .destructive) {
            deletingSplit = split
            showDeleteSplitAlert = true
        } label: {
            Label("Delete Split", systemImage: "trash")
        }
    }

    private func saveSplitShare(_ split: PaymentSplit) {
        guard let value = parseSplitPaymentAmount(editSplitShareText), value > 0 else {
            // Invalid entry: give feedback and re-present the alert.
            HapticService.warning()
            DispatchQueue.main.async {
                editingSplit = split
                showEditSplitAlert = true
            }
            return
        }
        split.shareAmount = value
        // Never leave more recorded than the new share allows.
        split.paidAmount = min(split.paidAmount, value)
        modelContext.safeSave()
        HapticService.success()
    }

    private func deleteSplit(_ split: PaymentSplit) {
        guard let budget = eventBudget else { return }
        budget.splits.removeAll { $0.id == split.id }
        modelContext.safeSave()
        HapticService.success()
    }

    private func recordSplitPayment(_ split: PaymentSplit) {
        guard let value = parseSplitPaymentAmount(splitPaymentText), value > 0 else {
            // Invalid entry: give feedback and re-present the alert.
            HapticService.warning()
            DispatchQueue.main.async {
                recordingSplit = split
                showSplitPaymentAlert = true
            }
            return
        }
        // Never record more than what's still owed.
        split.paidAmount += min(value, split.owedAmount)
        modelContext.safeSave()
        HapticService.success()
    }

    /// Locale-aware amount parsing (handles "1,234.56" and "1.234,56"),
    /// falling back to a digits-and-single-dot cleanup.
    private func parseSplitPaymentAmount(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: trimmed) {
            return number.doubleValue
        }

        var cleaned = trimmed.filter { "0123456789.".contains($0) }
        if let firstDot = cleaned.firstIndex(of: ".") {
            let afterDot = cleaned.index(after: firstDot)
            cleaned = String(cleaned[..<afterDot]) + cleaned[afterDot...].replacingOccurrences(of: ".", with: "")
        }
        return Double(cleaned)
    }

    // MARK: - All Transactions

    @ViewBuilder
    private func allTransactions(_ budget: Budget, expenses: [Expense], categoryLookup: [UUID: String]) -> some View {
        if !expenses.isEmpty {
            // Latest 5 by default; the expander reveals the full history so
            // the page stays short on phones.
            let visibleExpenses = showAllTransactions ? expenses : Array(expenses.prefix(5))

            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("All Transactions")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)
                        // A11Y-007: Section header trait
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("\(expenses.count)")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                ForEach(visibleExpenses) { expense in
                    Button {
                        editingExpense = expense
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: expense.paymentState == .paid ? "checkmark.circle.fill" : (expense.paymentState == .partial ? "circle.bottomhalf.filled" : "circle"))
                                .font(.callout)
                                .foregroundStyle(expense.paymentState == .paid ? Color.rsvpYesFallback : (expense.paymentState == .partial ? Color.rsvpMaybeFallback : Color.gatherTertiaryText))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(expense.name)
                                    .font(GatherFont.callout)
                                    .foregroundStyle(Color.gatherPrimaryText)
                                HStack(spacing: 4) {
                                    if let vendor = expense.vendorName {
                                        Text(vendor)
                                    }
                                    if let cat = categoryLookup[expense.id] {
                                        if expense.vendorName != nil { Text("\u{00B7}") }
                                        Text(cat)
                                    }
                                    Text("\u{00B7}")
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
                                Text(expense.paymentState == .paid ? "Paid" : (expense.paymentState == .partial ? "\(expense.amountRemaining.asCurrency) left" : "Pending"))
                                    .font(.caption2)
                                    .foregroundStyle(expense.paymentState == .paid ? Color.rsvpYesFallback : Color.rsvpMaybeFallback)
                            }
                        }
                        .padding(.vertical, Spacing.xxs)
                    }
                    .buttonStyle(CardPressStyle())
                }

                if expenses.count > 5 {
                    Button {
                        HapticService.buttonTap()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showAllTransactions.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showAllTransactions ? "Show less" : "Show all (\(expenses.count))")
                            Image(systemName: showAllTransactions ? "chevron.up" : "chevron.down")
                        }
                        .font(GatherFont.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentPurpleFallback)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xs)
                    }
                    // A11Y: expander touch target
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel(showAllTransactions ? "Show fewer transactions" : "Show all \(expenses.count) transactions")
                }
            }
            .padding()
            .surfaceCard()
            .bouncyAppear(delay: 0.3)
        }
    }

    // MARK: - Helpers

    private func createBudget() {
        // Seed at 0 and immediately ask for the real amount — never show a
        // fabricated "$10,000 total budget" the user didn't enter.
        let newBudget = Budget(eventId: event.id, totalBudget: 0)
        let defaultCategories = BudgetCategory.createDefaultCategories(for: event.category)
        for category in defaultCategories {
            newBudget.categories.append(category)
        }
        modelContext.insert(newBudget)
        modelContext.safeSave()
        FirestoreService.shared.pushBudget(newBudget, eventId: event.id)

        HapticService.success()
        showEditBudget = true
    }

    private func allExpenses(_ budget: Budget) -> [Expense] {
        budget.categories.flatMap { $0.expenses }.sorted { $0.createdAt > $1.createdAt }
    }

    /// Every expense, narrowed to the selected function (general expenses
    /// with no function always stay visible). Computed once per render and
    /// fed to every money section so the whole page agrees with the filter.
    /// True when the page is scoped to one function (or the General bucket)
    /// rather than the whole event.
    private var isFunctionFiltered: Bool {
        filterFunction != nil || filterGeneralOnly
    }

    /// Human label for the active scope, for the summary card.
    private var filterScopeName: String {
        filterGeneralOnly ? "General" : (filterFunction?.name ?? "")
    }

    /// The one function-scope predicate. Under a specific function, general
    /// (nil-function) expenses are EXCLUDED — they were previously counted in
    /// every function, inflating each one. They're reachable via the General chip.
    private func matchesFunctionFilter(_ functionId: UUID?) -> Bool {
        if filterGeneralOnly { return functionId == nil }
        if let function = filterFunction { return functionId == function.id }
        return true
    }

    private func filteredExpenses(_ budget: Budget) -> [Expense] {
        allExpenses(budget).filter { matchesFunctionFilter($0.functionId) }
    }

    /// Animated jump between quick-nav slices, used by tappable summary
    /// cards and banners so they land on the section they describe.
    private func jumpToSection(_ section: BudgetSection) {
        HapticService.buttonTap()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            visibleSection = section
        }
    }

    // PERF-004: O(1) category name lookup replacing O(n*m) findCategoryName
    private func buildCategoryLookup(_ budget: Budget) -> [UUID: String] {
        var lookup: [UUID: String] = [:]
        for category in budget.categories {
            for expense in category.expenses {
                lookup[expense.id] = category.name
            }
        }
        return lookup
    }

    private func filteredCategories(_ budget: Budget) -> [BudgetCategory] {
        guard isFunctionFiltered else { return budget.categories }
        return budget.categories.filter { matchesFunctionFilter($0.functionId) }
    }

    private func filteredSpent(_ budget: Budget) -> Double {
        guard isFunctionFiltered else { return budget.totalSpent }
        return filteredExpenses(budget).reduce(0) { $0 + $1.amount }
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
        let index = name.stableHash % colors.count
        return colors[index]
    }

    private func owningCategory(of expense: Expense) -> BudgetCategory? {
        eventBudget?.categories.first { category in
            category.expenses.contains { $0.id == expense.id }
        }
    }

    private func markAsPaid(_ expense: Expense, in budget: Budget) {
        // Settles the outstanding balance as an installment, keeping the
        // legacy isPaid/paidDate flags in sync.
        expense.markFullyPaid()
        owningCategory(of: expense)?.reconcileSpent()
        modelContext.safeSave()
        HapticService.success()
    }

    private func deleteExpense(_ expense: Expense) {
        guard let budget = eventBudget else { return }
        for category in budget.categories {
            if let index = category.expenses.firstIndex(where: { $0.id == expense.id }) {
                category.expenses.remove(at: index)
                category.reconcileSpent()
                break
            }
        }
        modelContext.safeSave()
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

// MARK: - Vendor Detail Sheet

struct VendorDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var budget: Budget
    let vendorName: String
    let functions: [EventFunction]

    @State private var editingExpense: Expense?

    private var vendorExpenses: [Expense] {
        budget.categories.flatMap { $0.expenses }
            .filter { $0.vendorName == vendorName }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var totalAmount: Double {
        vendorExpenses.reduce(0) { $0 + $1.amount }
    }

    private var totalPaid: Double {
        vendorExpenses.reduce(0) { $0 + min($1.amountPaid, $1.amount) }
    }

    private var totalRemaining: Double {
        max(0, totalAmount - totalPaid)
    }

    private var isSettled: Bool {
        totalRemaining <= 0.009 && totalAmount > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    vendorHeader

                    if vendorExpenses.isEmpty {
                        GatherEmptyState(
                            icon: "tray",
                            title: "No expenses",
                            message: "Expenses for this vendor will show up here."
                        )
                        .padding(.vertical, Spacing.xxl)
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Expenses")
                                .font(GatherFont.headline)
                                .foregroundStyle(Color.gatherPrimaryText)
                                .accessibilityAddTraits(.isHeader)

                            ForEach(vendorExpenses) { expense in
                                Button {
                                    HapticService.buttonTap()
                                    editingExpense = expense
                                } label: {
                                    vendorExpenseRow(expense)
                                }
                                .buttonStyle(CardPressStyle())
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(expense.name). \(min(expense.amountPaid, expense.amount).asCurrency) paid of \(expense.amount.asCurrency). \(expense.paymentState.displayName)")
                                .accessibilityHint("Double tap to edit and record payments")
                            }
                        }
                    }
                }
                .padding(.vertical)
                .horizontalPadding()
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.gatherBackground)
            .navigationTitle(vendorName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close vendor details")
                }
            }
            .sheet(item: $editingExpense) { expense in
                ExpenseDetailSheet(expense: expense, functions: functions, category: owningCategory(of: expense), onDelete: {
                    delete(expense)
                })
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var vendorHeader: some View {
        VStack(spacing: Spacing.sm) {
            ExpensePaymentStatusPill(state: isSettled ? .paid : (totalPaid > 0 ? .partial : .unpaid))

            if isSettled {
                Text(totalAmount.asCurrency)
                    .font(GatherFont.largeTitle)
                    .foregroundStyle(Color.gatherPrimaryText)
                Text("Settled up")
                    .font(GatherFont.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.rsvpYesFallback)
            } else {
                Text(totalRemaining.asCurrency)
                    .font(GatherFont.largeTitle)
                    .foregroundStyle(Color.gatherPrimaryText)
                Text("left to pay")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gatherTertiaryBackground)
                    Capsule()
                        .fill(Color.rsvpYesFallback)
                        .frame(width: totalAmount > 0 ? max(0, min(geometry.size.width, geometry.size.width * (totalPaid / totalAmount))) : 0)
                }
            }
            .frame(height: 8)

            Text("\(totalPaid.asCurrency) paid of \(totalAmount.asCurrency) \u{00B7} \(vendorExpenses.count) expense\(vendorExpenses.count == 1 ? "" : "s")")
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .surfaceCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(vendorName). \(totalPaid.asCurrency) paid of \(totalAmount.asCurrency). \(isSettled ? "Settled up" : "\(totalRemaining.asCurrency) left to pay")")
        .bouncyAppear()
    }

    private func vendorExpenseRow(_ expense: Expense) -> some View {
        let state = expense.paymentState

        return HStack(spacing: Spacing.sm) {
            Image(systemName: state == .paid ? "checkmark.circle.fill" : (state == .partial ? "circle.bottomhalf.filled" : "circle"))
                .font(.callout)
                .foregroundStyle(state == .paid ? Color.rsvpYesFallback : (state == .partial ? Color.rsvpMaybeFallback : Color.gatherTertiaryText))

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.name)
                    .font(GatherFont.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text("\(min(expense.amountPaid, expense.amount).asCurrency) paid of \(expense.amount.asCurrency)")
                    .font(.caption2)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if state == .paid {
                    Label("Paid", systemImage: "checkmark.circle.fill")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.rsvpYesFallback)
                } else {
                    Text(expense.amountRemaining.asCurrency)
                        .font(GatherFont.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.rsvpMaybeFallback)
                    Text("left")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Color.gatherTertiaryText)
        }
        .padding(Spacing.sm)
        .surfaceCard()
    }

    private func owningCategory(of expense: Expense) -> BudgetCategory? {
        budget.categories.first { category in
            category.expenses.contains { $0.id == expense.id }
        }
    }

    private func delete(_ expense: Expense) {
        for category in budget.categories {
            if let index = category.expenses.firstIndex(where: { $0.id == expense.id }) {
                category.expenses.remove(at: index)
                category.reconcileSpent()
                break
            }
        }
        modelContext.safeSave()
    }
}

// MARK: - Payer Detail Sheet

/// One person's payment history across the whole budget — the receipts
/// behind a Who Paid What total or a Settle Up balance.
private struct PayerDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var budget: Budget
    let payerName: String

    /// A single recorded payment attributed to this payer, joined with the
    /// expense it was made against.
    private struct PayerPaymentEntry: Identifiable {
        let id: UUID
        let expenseName: String
        let amount: Double
        let date: Date
        let method: String?
        let note: String?
    }

    /// Payments attributed to this payer, newest first. Mirrors the
    /// attribution rules of BudgetTab.payerTotals: a payment's own payer wins,
    /// otherwise it falls back to the expense-level legacy `paidByName`.
    private var entries: [PayerPaymentEntry] {
        var result: [PayerPaymentEntry] = []
        for category in budget.categories {
            for expense in category.expenses {
                for payment in expense.recordedPayments {
                    let payer = (payment.paidByName?.isEmpty == false ? payment.paidByName : nil)
                        ?? (expense.paidByName?.isEmpty == false ? expense.paidByName : nil)
                    guard payer == payerName else { continue }
                    result.append(PayerPaymentEntry(
                        id: payment.id,
                        expenseName: expense.name,
                        amount: payment.amount,
                        date: payment.date,
                        method: payment.method,
                        note: payment.note
                    ))
                }
            }
        }
        return result.sorted { $0.date > $1.date }
    }

    private var totalPaid: Double {
        entries.reduce(0) { $0 + $1.amount }
    }

    private var displayName: String {
        payerName.isEmpty ? "Unknown" : payerName
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    payerHeader

                    if entries.isEmpty {
                        GatherEmptyState(
                            icon: "tray",
                            title: "No payments",
                            message: "Payments recorded for \(displayName) will show up here."
                        )
                        .padding(.vertical, Spacing.xxl)
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Payments")
                                .font(GatherFont.headline)
                                .foregroundStyle(Color.gatherPrimaryText)
                                .accessibilityAddTraits(.isHeader)

                            ForEach(entries) { entry in
                                paymentRow(entry)
                            }
                        }
                    }
                }
                .padding(.vertical)
                .horizontalPadding()
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.gatherBackground)
            .navigationTitle(displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close payment history")
                }
            }
        }
    }

    private var payerHeader: some View {
        VStack(spacing: Spacing.sm) {
            Circle()
                .fill(payerAvatarColor)
                .frame(width: 52, height: 52)
                .overlay {
                    Text(displayName.prefix(1).uppercased())
                        .font(GatherFont.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

            Text(totalPaid.asCurrency)
                .font(GatherFont.largeTitle)
                .foregroundStyle(Color.gatherPrimaryText)

            Text("paid across \(entries.count) payment\(entries.count == 1 ? "" : "s")")
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .surfaceCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(displayName) paid \(totalPaid.asCurrency) across \(entries.count) payment\(entries.count == 1 ? "" : "s")")
        .bouncyAppear()
    }

    private func paymentRow(_ entry: PayerPaymentEntry) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(Color.rsvpYesFallback)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.expenseName)
                    .font(GatherFont.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.gatherPrimaryText)

                HStack(spacing: 4) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    if let method = entry.method, !method.isEmpty {
                        Text("\u{00B7}")
                        Text(method)
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)

                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(Color.gatherTertiaryText)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(entry.amount.asCurrency)
                .font(GatherFont.callout)
                .fontWeight(.semibold)
                .foregroundStyle(Color.gatherPrimaryText)
        }
        .padding(Spacing.sm)
        .surfaceCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.amount.asCurrency) toward \(entry.expenseName) on \(entry.date.formatted(date: .abbreviated, time: .omitted))\(entry.method.map { ", via \($0)" } ?? "")")
    }

    /// Same stable avatar tint the Finance tab rows use for this person.
    private var payerAvatarColor: Color {
        let colors: [Color] = [.purple, .blue, .green, .orange, .pink, .teal]
        let index = payerName.stableHash % colors.count
        return colors[index]
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
