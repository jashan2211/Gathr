import SwiftUI
import SwiftData

// MARK: - Expense Detail Sheet (editor + payment ledger)

struct ExpenseDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var expense: Expense
    let functions: [EventFunction]
    var category: BudgetCategory?
    /// When true the sheet opens straight into the record-payment form,
    /// so a "Partial" entry point lands on the flow it promises.
    var startInRecordPayment: Bool
    var onDelete: () -> Void

    @State private var showDeleteConfirm = false
    @State private var showRecordPayment = false
    @State private var paymentAmount: Double = 0
    @State private var paymentDate = Date()
    @State private var paymentMethod: PaymentMethodOption?
    @State private var paymentNote = ""
    @State private var paymentPaidBy = ""

    private enum PaymentMethodOption: String, CaseIterable, Identifiable {
        case cash = "Cash"
        case card = "Card"
        case transfer = "Transfer"
        case other = "Other"

        var id: String { rawValue }
    }

    init(
        expense: Expense,
        functions: [EventFunction],
        category: BudgetCategory? = nil,
        startInRecordPayment: Bool = false,
        onDelete: @escaping () -> Void
    ) {
        self.expense = expense
        self.functions = functions
        self.category = category
        self.startInRecordPayment = startInRecordPayment
        self.onDelete = onDelete
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    private var isOverdue: Bool {
        expense.paymentState != .paid && (expense.dueDate.map { $0 < Date() } ?? false)
    }

    /// Never record more than the outstanding balance.
    private var clampedPaymentAmount: Double {
        min(paymentAmount, expense.amountRemaining)
    }

    var body: some View {
        NavigationStack {
            List {
                // Payment progress header
                Section {
                    progressHeader
                        .listRowBackground(Color.clear)
                }

                // Record payment / mark fully paid
                if expense.amountRemaining > 0 {
                    Section {
                        if showRecordPayment {
                            recordPaymentForm
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        } else {
                            paymentActions
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }
                }

                // Payment history
                Section("Payment History") {
                    if expense.recordedPayments.isEmpty {
                        Text("No payments yet")
                            .font(GatherFont.callout)
                            .foregroundStyle(Color.gatherSecondaryText)
                    } else {
                        ForEach(expense.recordedPayments) { payment in
                            ExpensePaymentHistoryRow(payment: payment)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deletePayment(payment)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deletePayment(payment)
                                    } label: {
                                        Label("Delete Payment", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .listRowBackground(Color.gatherSecondaryBackground)

                // Contributions (multi-payer summary). Rows reconcile to the
                // full amount: named payers + any unattributed paid + unpaid.
                if !expense.contributionsByPayer.isEmpty {
                    Section("Contributions") {
                        ForEach(expense.contributionsByPayer, id: \.name) { contribution in
                            ExpenseContributionRow(name: contribution.name, amount: contribution.amount)
                        }

                        // Money that's been paid but not attributed to a person.
                        let namedPaid = expense.contributionsByPayer.reduce(0) { $0 + $1.amount }
                        let unattributed = expense.amountPaid - namedPaid
                        if unattributed >= 0.005 {
                            ExpenseContributionRow(name: "Unattributed", amount: unattributed)
                        }

                        if expense.amountRemaining > 0 {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "circle.dashed")
                                    .font(.callout)
                                    .foregroundStyle(Color.gatherTertiaryText)
                                Text("Unpaid")
                                    .gatherRowTitle()
                                    .foregroundStyle(Color.gatherSecondaryText)
                                Spacer()
                                Text(expense.amountRemaining.asCurrency)
                                    .gatherRowTitle()
                                    .foregroundStyle(Color.rsvpMaybeFallback)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Unpaid, \(expense.amountRemaining.asCurrency) remaining")
                        }
                    }
                    .listRowBackground(Color.gatherSecondaryBackground)
                }

                // Editable details
                Section("Details") {
                    HStack {
                        Text("Name")
                            .foregroundStyle(Color.gatherSecondaryText)
                        TextField("Expense name", text: $expense.name)
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                            .accessibilityLabel("Expense name")
                    }

                    HStack {
                        Text("Amount")
                            .foregroundStyle(Color.gatherSecondaryText)
                        TextField("Amount", value: $expense.amount, format: .currency(code: currencyCode))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Expense amount")
                    }

                    HStack {
                        Text("Vendor")
                            .foregroundStyle(Color.gatherSecondaryText)
                        TextField("Vendor name", text: optionalTextBinding(\.vendorName))
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                            .accessibilityLabel("Vendor name")
                    }

                    HStack {
                        Text("Paid by")
                            .foregroundStyle(Color.gatherSecondaryText)
                        TextField("e.g. You, Aisha", text: optionalTextBinding(\.paidByName))
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                            .accessibilityLabel("Paid by")
                    }

                    Toggle("Due date", isOn: hasDueDateBinding)
                        .accessibilityLabel("Has due date")

                    if expense.dueDate != nil {
                        DatePicker("Due", selection: dueDateBinding, displayedComponents: .date)
                            .accessibilityLabel("Due date")

                        if isOverdue {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.rsvpNoFallback)
                                Text("This payment is overdue")
                                    .font(GatherFont.caption)
                                    .foregroundStyle(Color.rsvpNoFallback)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                        TextField("e.g. 50% deposit, balance on event day", text: optionalTextBinding(\.notes), axis: .vertical)
                            .lineLimit(3, reservesSpace: false)
                            .accessibilityLabel("Notes")
                    }

                    LabeledContent("Added", value: expense.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
                .listRowBackground(Color.gatherSecondaryBackground)

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
                    .listRowBackground(Color.gatherSecondaryBackground)
                }

                // Delete
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Expense", systemImage: "trash")
                            .foregroundStyle(Color.gatherError)
                    }
                    .accessibilityLabel("Delete expense")
                }
                .listRowBackground(Color.gatherSecondaryBackground)
            }
            .scrollContentBackground(.hidden)
            .background(Color.gatherBackground)
            .onAppear {
                if startInRecordPayment, expense.amountRemaining > 0 {
                    startRecordPayment()
                }
            }
            .onChange(of: expense.amount) { _, _ in
                // Keep legacy isPaid/paidDate flags consistent when the amount
                // is edited (e.g. lowered below what's already been paid).
                expense.resyncPaidFlags()
                category?.reconcileSpent()
                modelContext.safeSave()
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    category?.reconcileSpent()
                    modelContext.safeSave()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(GatherFont.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: Layout.buttonHeight)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                }
                .accessibilityLabel("Done, save and close")
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.vertical, Spacing.sm)
                .background(
                    LinearGradient(
                        colors: [Color.gatherBackground.opacity(0), Color.gatherBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .navigationTitle("Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if expense.amountPaid > 0 {
                            Button(role: .destructive) {
                                markUnpaid()
                            } label: {
                                Label("Mark Unpaid", systemImage: "arrow.uturn.backward")
                            }
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Expense", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More actions")
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

    // MARK: - Progress Header

    private var progressHeader: some View {
        let paidDisplay = min(expense.amountPaid, expense.amount)

        return VStack(spacing: Spacing.sm) {
            ExpensePaymentStatusPill(state: expense.paymentState)

            if expense.paymentState == .paid {
                Text(expense.amount.asCurrency)
                    .font(GatherFont.largeTitle)
                    .foregroundStyle(Color.gatherPrimaryText)
                Text("Paid in full")
                    .font(GatherFont.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.rsvpYesFallback)
            } else {
                Text(expense.amountRemaining.asCurrency)
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
                        .frame(width: max(0, min(geometry.size.width, geometry.size.width * expense.percentPaid / 100)))
                }
            }
            .frame(height: 8)

            Text("\(paidDisplay.asCurrency) of \(expense.amount.asCurrency) paid")
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: expense.amountPaid)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(expense.paymentState.displayName). \(paidDisplay.asCurrency) of \(expense.amount.asCurrency) paid. \(expense.amountRemaining.asCurrency) remaining.")
    }

    // MARK: - Payment Actions

    private var paymentActions: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                startRecordPayment()
            } label: {
                Label("Record Payment", systemImage: "plus.circle.fill")
                    .font(GatherFont.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.buttonHeight)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Record a payment")
            .accessibilityHint("Opens a form to log a partial or full payment")

            Button {
                settleRemaining()
            } label: {
                Text("Mark Fully Paid \u{00B7} \(expense.amountRemaining.asCurrency)")
                    .font(GatherFont.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Mark fully paid, records the remaining \(expense.amountRemaining.asCurrency)")
        }
        .padding(.vertical, Spacing.xxs)
    }

    // MARK: - Record Payment Form

    private var recordPaymentForm: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            fieldLabel("Amount")
            TextField("Amount", value: $paymentAmount, format: .currency(code: currencyCode))
                .keyboardType(.decimalPad)
                .font(GatherFont.title3)
                .fontWeight(.semibold)
                .padding(Spacing.sm)
                .background(Color.gatherTertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                .accessibilityLabel("Payment amount")

            if paymentAmount > expense.amountRemaining {
                Text("Remaining balance is \(expense.amountRemaining.asCurrency)")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.rsvpMaybeFallback)
                    .accessibilityLabel("Amount exceeds remaining balance of \(expense.amountRemaining.asCurrency). The recorded payment will be capped.")
            }

            fieldLabel("Date")
            DatePicker("Payment date", selection: $paymentDate, displayedComponents: .date)
                .labelsHidden()
                .accessibilityLabel("Payment date")

            fieldLabel("Method (Optional)")
            HStack(spacing: Spacing.xs) {
                ForEach(PaymentMethodOption.allCases) { option in
                    methodChip(option)
                }
            }

            fieldLabel("Paid By (Optional)")
            TextField("e.g. Simar, You", text: $paymentPaidBy)
                .padding(Spacing.sm)
                .background(Color.gatherElevated)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .submitLabel(.done)
                .accessibilityLabel("Paid by")

            fieldLabel("Note (Optional)")
            TextField("e.g. Deposit", text: $paymentNote)
                .padding(Spacing.sm)
                .background(Color.gatherTertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                .submitLabel(.done)
                .accessibilityLabel("Payment note")

            HStack(spacing: Spacing.sm) {
                Button {
                    HapticService.buttonTap()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showRecordPayment = false
                    }
                } label: {
                    Text("Cancel")
                        .font(GatherFont.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Cancel recording payment")

                Button {
                    confirmRecordPayment()
                } label: {
                    Text("Record \(clampedPaymentAmount.asCurrency)")
                        .font(GatherFont.callout)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                        .opacity(clampedPaymentAmount <= 0 ? 0.5 : 1)
                }
                .buttonStyle(.borderless)
                .disabled(clampedPaymentAmount <= 0)
                .accessibilityLabel("Confirm payment of \(clampedPaymentAmount.asCurrency)")
            }
        }
        .padding()
        .surfaceCard()
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .tracking(0.5)
            .foregroundStyle(Color.gatherSecondaryText)
    }

    private func methodChip(_ option: PaymentMethodOption) -> some View {
        let isSelected = paymentMethod == option

        return Button {
            HapticService.buttonTap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                paymentMethod = isSelected ? nil : option
            }
        } label: {
            Text(option.rawValue)
                .font(GatherFont.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentPurpleFallback : Color.gatherTertiaryBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(option.rawValue) payment method")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Bindings

    private func optionalTextBinding(_ keyPath: ReferenceWritableKeyPath<Expense, String?>) -> Binding<String> {
        Binding(
            get: { expense[keyPath: keyPath] ?? "" },
            set: { expense[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private var hasDueDateBinding: Binding<Bool> {
        Binding(
            get: { expense.dueDate != nil },
            set: { hasDue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    expense.dueDate = hasDue ? (expense.dueDate ?? Date()) : nil
                }
            }
        )
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { expense.dueDate ?? Date() },
            set: { expense.dueDate = $0 }
        )
    }

    // MARK: - Actions

    private func startRecordPayment() {
        paymentAmount = expense.amountRemaining
        paymentDate = Date()
        paymentMethod = nil
        paymentNote = ""
        paymentPaidBy = expense.paidByName ?? ""
        HapticService.buttonTap()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            showRecordPayment = true
        }
    }

    private func confirmRecordPayment() {
        // Clamp so an entry larger than the outstanding balance can't overpay.
        let amount = clampedPaymentAmount
        guard amount > 0 else { return }
        let trimmedPaidBy = paymentPaidBy.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.recordPayment(
            amount: amount,
            date: paymentDate,
            method: paymentMethod?.rawValue,
            note: paymentNote.isEmpty ? nil : paymentNote,
            paidByName: trimmedPaidBy.isEmpty ? nil : trimmedPaidBy
        )
        category?.reconcileSpent()
        modelContext.safeSave()
        HapticService.success()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            showRecordPayment = false
        }
    }

    private func settleRemaining() {
        expense.markFullyPaid()
        category?.reconcileSpent()
        modelContext.safeSave()
        HapticService.success()
    }

    private func markUnpaid() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            expense.markUnpaid()
        }
        category?.reconcileSpent()
        modelContext.safeSave()
        HapticService.buttonTap()
    }

    private func deletePayment(_ payment: ExpensePayment) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            if expense.payments?.isEmpty != false {
                // Legacy expense: the only "payment" is synthesized from isPaid.
                expense.markUnpaid()
            } else {
                expense.removePayment(id: payment.id)
            }
        }
        category?.reconcileSpent()
        modelContext.safeSave()
        HapticService.buttonTap()
    }
}

// MARK: - Payment Status Pill

struct ExpensePaymentStatusPill: View {
    let state: ExpensePaymentState

    private var color: Color {
        switch state {
        case .unpaid: return Color.gatherSecondaryText
        case .partial: return Color.rsvpMaybeFallback
        case .paid: return Color.rsvpYesFallback
        }
    }

    var body: some View {
        Text(state.displayName)
            .font(GatherFont.caption)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel("Status: \(state.displayName)")
    }
}

// MARK: - Payment History Row

struct ExpensePaymentHistoryRow: View {
    let payment: ExpensePayment

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(Color.rsvpYesFallback)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(payment.amount.asCurrency)
                        .font(GatherFont.callout)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.gatherPrimaryText)

                    if let payer = payment.paidByName, !payer.isEmpty {
                        Text(payer)
                            .gatherEyebrow()
                            .textCase(nil)
                            .foregroundStyle(Color.accentPurpleFallback)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentPurpleFallback.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 4) {
                    Text(payment.date.formatted(date: .abbreviated, time: .omitted))
                    if let method = payment.method, !method.isEmpty {
                        Text("\u{00B7}")
                        Text(method)
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)

                if let note = payment.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(Color.gatherTertiaryText)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Payment of \(payment.amount.asCurrency)\(payment.paidByName.map { $0.isEmpty ? "" : " by \($0)" } ?? "") on \(payment.date.formatted(date: .abbreviated, time: .omitted))\(payment.method.map { ", via \($0)" } ?? "")\(payment.note.map { ". \($0)" } ?? "")")
        .accessibilityHint("Swipe up or down for delete action")
    }
}

// MARK: - Contribution Row (multi-payer summary)

struct ExpenseContributionRow: View {
    let name: String
    let amount: Double

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(Color.accentPurpleFallback.opacity(0.9))
                .frame(width: 30, height: 30)
                .overlay {
                    Text(name.isEmpty ? "?" : name.prefix(1).uppercased())
                        .font(GatherFont.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

            Text(name.isEmpty ? "Unknown" : name)
                .gatherRowTitle()
                .foregroundStyle(Color.gatherPrimaryText)

            Spacer()

            Text(amount.asCurrency)
                .gatherRowTitle()
                .foregroundStyle(Color.gatherPrimaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name.isEmpty ? "Unknown" : name) paid \(amount.asCurrency)")
    }
}
