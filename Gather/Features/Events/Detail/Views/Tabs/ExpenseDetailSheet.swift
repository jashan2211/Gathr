import SwiftUI
import SwiftData

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
