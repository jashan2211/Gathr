import SwiftUI
import SwiftData

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
                        .submitLabel(.done)
                    TextField("Amount", value: $amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
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
                        .submitLabel(.done)
                }

                Section("Who Paid?") {
                    TextField("e.g. You, Aisha, Jordan", text: $paidByName)
                        .submitLabel(.done)
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
