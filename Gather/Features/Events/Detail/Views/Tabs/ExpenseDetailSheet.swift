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
                            .font(GatherFont.largeTitle)
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
                .listRowBackground(Color.gatherSecondaryBackground)

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
                }
                .listRowBackground(Color.gatherSecondaryBackground)
            }
            .scrollContentBackground(.hidden)
            .background(Color.gatherBackground)
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(GatherFont.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                }
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
