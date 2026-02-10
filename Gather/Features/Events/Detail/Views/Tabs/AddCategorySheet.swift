import SwiftUI
import SwiftData

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
                        .submitLabel(.done)
                }

                Section("Budget Amount") {
                    TextField("Allocated budget", value: $allocated, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
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
