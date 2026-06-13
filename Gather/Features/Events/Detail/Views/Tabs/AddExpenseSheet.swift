import SwiftUI
import SwiftData

// MARK: - Add Expense Sheet (for specific category)

struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var category: BudgetCategory
    let functions: [EventFunction]

    @State private var name = ""
    @State private var amount: Double = 0
    @State private var vendorName = ""
    @State private var paidByName = ""
    @State private var paidSoFar: Double = 0
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var notes = ""
    @State private var selectedFunctionId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    TextField("Name", text: $name)
                        .submitLabel(.done)
                    TextField("Amount", value: $amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                }
                .listRowBackground(Color.gatherSecondaryBackground)

                Section("Vendor (Optional)") {
                    TextField("Vendor name", text: $vendorName)
                        .submitLabel(.done)
                }
                .listRowBackground(Color.gatherSecondaryBackground)

                Section("Who Paid?") {
                    TextField("e.g. You, Aisha, Jordan", text: $paidByName)
                        .submitLabel(.done)
                }
                .listRowBackground(Color.gatherSecondaryBackground)

                Section("Payment") {
                    HStack(spacing: Spacing.sm) {
                        TextField("Paid so far", value: $paidSoFar, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .keyboardType(.decimalPad)
                            .submitLabel(.done)
                            .accessibilityLabel("Amount paid so far")

                        Button {
                            HapticService.buttonTap()
                            paidSoFar = amount
                        } label: {
                            Text("Full amount")
                                .font(GatherFont.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentPurpleFallback)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.gatherTertiaryBackground)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.borderless)
                        .disabled(amount <= 0)
                        .opacity(amount <= 0 ? 0.5 : 1)
                        .accessibilityLabel("Mark the full amount as paid")
                    }

                    if paidSoFar < amount || amount <= 0 {
                        Toggle("Set Due Date", isOn: $hasDueDate)
                        if hasDueDate {
                            DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        }
                    }
                }
                .listRowBackground(Color.gatherSecondaryBackground)

                if !functions.isEmpty {
                    Section("Link to Function") {
                        Picker("Function", selection: $selectedFunctionId) {
                            Text("General").tag(UUID?.none)
                            ForEach(functions.sorted { $0.date < $1.date }) { function in
                                Text(function.name).tag(Optional(function.id))
                            }
                        }
                    }
                    .listRowBackground(Color.gatherSecondaryBackground)
                }

                Section("Notes (Optional)") {
                    TextField("e.g. 50% deposit, balance on event day", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                .listRowBackground(Color.gatherSecondaryBackground)
            }
            .scrollContentBackground(.hidden)
            .background(Color.gatherBackground)
            .safeAreaInset(edge: .bottom) {
                Button {
                    let expense = Expense(
                        name: name,
                        amount: amount,
                        isPaid: false,
                        paidDate: nil,
                        dueDate: hasDueDate ? dueDate : nil,
                        notes: notes.isEmpty ? nil : notes,
                        vendorName: vendorName.isEmpty ? nil : vendorName,
                        paidByName: paidByName.isEmpty ? nil : paidByName,
                        functionId: selectedFunctionId
                    )
                    category.expenses.append(expense)
                    if paidSoFar > 0 {
                        expense.recordPayment(amount: min(paidSoFar, amount))
                    }
                    category.reconcileSpent()
                    modelContext.safeSave()
                    dismiss()
                } label: {
                    Text("Add Expense")
                        .font(GatherFont.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                }
                .disabled(name.isEmpty || amount <= 0)
                .opacity(name.isEmpty || amount <= 0 ? 0.5 : 1)
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
            .navigationTitle("Add to \(category.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
