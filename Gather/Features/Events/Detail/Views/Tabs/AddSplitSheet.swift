import SwiftUI
import SwiftData

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
                        .submitLabel(.done)
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                }

                Section("Share Amount") {
                    TextField("Amount", value: $shareAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
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
