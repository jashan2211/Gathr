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
                .listRowBackground(Color.gatherSecondaryBackground)

                Section("Share Amount") {
                    TextField("Amount", value: $shareAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                }
                .listRowBackground(Color.gatherSecondaryBackground)
            }
            .scrollContentBackground(.hidden)
            .background(Color.gatherBackground)
            .safeAreaInset(edge: .bottom) {
                Button {
                    let split = PaymentSplit(
                        name: name,
                        email: email.isEmpty ? nil : email,
                        shareAmount: shareAmount
                    )
                    budget.splits.append(split)
                    dismiss()
                } label: {
                    Text("Add Split")
                        .font(GatherFont.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                }
                .disabled(name.isEmpty || shareAmount <= 0)
                .opacity(name.isEmpty || shareAmount <= 0 ? 0.5 : 1)
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
            .navigationTitle("Add Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
