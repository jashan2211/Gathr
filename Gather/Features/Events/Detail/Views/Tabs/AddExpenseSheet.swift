import SwiftUI
import SwiftData

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
                        .submitLabel(.done)
                    TextField("Amount", value: $amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                }

                Section("Vendor (Optional)") {
                    TextField("Vendor name", text: $vendorName)
                        .submitLabel(.done)
                }

                Section("Who Paid?") {
                    TextField("e.g. You, Aisha, Jordan", text: $paidByName)
                        .submitLabel(.done)
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
