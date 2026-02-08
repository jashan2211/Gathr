import SwiftUI

struct AddFunctionSheet: View {
    @Bindable var event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var functionDescription = ""
    @State private var date = Date()
    @State private var hasEndTime = false
    @State private var endTime = Date().addingTimeInterval(3600 * 4)
    @State private var hasLocation = false
    @State private var locationName = ""
    @State private var locationAddress = ""
    @State private var hasDressCode = false
    @State private var dressCode: DressCode = .formal
    @State private var customDressCode = ""

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section {
                    TextField("Function Name", text: $name)
                        .font(GatherFont.body)

                    TextField("Description (optional)", text: $functionDescription, axis: .vertical)
                        .font(GatherFont.body)
                        .lineLimit(3...6)
                } header: {
                    Text("Details")
                }

                // Date & Time
                Section {
                    DatePicker("Date & Time", selection: $date)
                        .font(GatherFont.body)

                    Toggle("Add End Time", isOn: $hasEndTime.animation())
                        .font(GatherFont.body)

                    if hasEndTime {
                        DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                            .font(GatherFont.body)
                    }
                } header: {
                    Text("When")
                }

                // Location
                Section {
                    Toggle("Add Location", isOn: $hasLocation.animation())
                        .font(GatherFont.body)

                    if hasLocation {
                        TextField("Venue Name", text: $locationName)
                            .font(GatherFont.body)

                        TextField("Address (optional)", text: $locationAddress)
                            .font(GatherFont.body)
                    }
                } header: {
                    Text("Where")
                }

                // Dress Code
                Section {
                    Toggle("Add Dress Code", isOn: $hasDressCode.animation())
                        .font(GatherFont.body)

                    if hasDressCode {
                        Picker("Dress Code", selection: $dressCode) {
                            ForEach(DressCode.allCases, id: \.self) { code in
                                HStack {
                                    Image(systemName: code.icon)
                                    Text(code.displayName)
                                }
                                .tag(code)
                            }
                        }
                        .font(GatherFont.body)

                        if dressCode == .custom {
                            TextField("Custom Dress Code", text: $customDressCode)
                                .font(GatherFont.body)
                        }
                    }
                } header: {
                    Text("Dress Code")
                } footer: {
                    if hasDressCode && dressCode != .custom {
                        Text(dressCode.description)
                            .font(GatherFont.caption)
                    }
                }

                // Suggested Functions
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(suggestedNames, id: \.self) { suggestion in
                                Button {
                                    name = suggestion
                                } label: {
                                    Text(suggestion)
                                        .font(GatherFont.caption)
                                        .foregroundStyle(name == suggestion ? .white : Color.gatherPrimaryText)
                                        .padding(.horizontal, Spacing.md)
                                        .padding(.vertical, Spacing.xs)
                                        .background(name == suggestion ? Color.accentPurpleFallback : Color.gatherSecondaryBackground)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Quick Fill")
                }
            }
            .navigationTitle("Add Function")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addFunction()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    // MARK: - Suggested Names

    private var suggestedNames: [String] {
        [
            "Mehendi",
            "Sangeet",
            "Haldi",
            "Ceremony",
            "Reception",
            "Cocktail Hour",
            "Rehearsal Dinner",
            "Welcome Party",
            "Brunch"
        ]
    }

    // MARK: - Add Function

    private func addFunction() {
        let location: EventLocation? = hasLocation && !locationName.isEmpty
            ? EventLocation(name: locationName, address: locationAddress.isEmpty ? nil : locationAddress)
            : nil

        let finalEndTime: Date? = hasEndTime ? endTime : nil

        let newFunction = EventFunction(
            name: name,
            functionDescription: functionDescription.isEmpty ? nil : functionDescription,
            date: date,
            endTime: finalEndTime,
            location: location,
            dressCode: hasDressCode ? dressCode : nil,
            customDressCode: dressCode == .custom ? customDressCode : nil,
            sortOrder: event.functions.count,
            eventId: event.id
        )

        event.functions.append(newFunction)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var event = Event(title: "Wedding", startDate: Date())
    AddFunctionSheet(event: event)
}
