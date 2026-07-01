import SwiftUI

struct AddFunctionSheet: View {
    @Bindable var event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var functionDescription = ""
    @State private var date: Date
    @State private var hasEndTime = false
    @State private var endTime: Date
    @State private var hasLocation = false
    @State private var locationName = ""
    @State private var locationAddress = ""
    // Resolved coordinates from the map picker (nil when entered manually).
    @State private var locationCity: String?
    @State private var locationState: String?
    @State private var locationCountry: String?
    @State private var locationLat: Double?
    @State private var locationLon: Double?
    @State private var showLocationPicker = false
    @State private var hasDressCode = false
    @State private var dressCode: DressCode = .formal
    @State private var customDressCode = ""

    /// Defaults the new function to the parent event's start date so the host
    /// isn't editing "today" for a wedding six months out. End time seeds to
    /// four hours after the start.
    init(event: Event) {
        self.event = event
        _date = State(initialValue: event.startDate)
        _endTime = State(initialValue: event.startDate.addingTimeInterval(3600 * 4))
    }

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
                        // Map search — fills name/address/coords like the main
                        // create flow. Manual name below stays as a fallback.
                        Button {
                            HapticService.buttonTap()
                            showLocationPicker = true
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Color.accentPinkFallback)
                                Text(locationLat == nil ? "Search for a place" : "Change place")
                                    .gatherRowTitle()
                                    .foregroundStyle(Color.gatherPrimaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Color.gatherTertiaryText)
                            }
                        }

                        // Show the resolved place (from the map) as a summary row.
                        if locationLat != nil {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(locationName)
                                    .gatherRowTitle()
                                    .foregroundStyle(Color.gatherPrimaryText)
                                if !locationAddress.isEmpty {
                                    Text(locationAddress)
                                        .gatherMetaText()
                                        .foregroundStyle(Color.gatherSecondaryText)
                                }
                                Button("Clear place") {
                                    clearLocation()
                                }
                                .font(GatherFont.caption)
                                .foregroundStyle(Color.gatherError)
                            }
                        }

                        // Manual fallback — always available for a venue with no
                        // map match (a home, a marquee, etc.).
                        TextField("Venue name", text: $locationName)
                            .font(GatherFont.body)

                        if locationLat == nil {
                            TextField("Address (optional)", text: $locationAddress)
                                .font(GatherFont.body)
                        }
                    }
                } header: {
                    Text("Where")
                } footer: {
                    if hasLocation {
                        Text("Search for a place to pin it on the map, or just type a venue name.")
                            .font(GatherFont.caption)
                    }
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
                                        .background(name == suggestion ? Color.accentPurpleFallback : Color.gatherTertiaryBackground)
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
            .safeAreaInset(edge: .bottom) {
                addFunctionBar
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView { name, address, city, state, country, lat, lon in
                    locationName = name
                    locationAddress = address ?? ""
                    locationCity = city
                    locationState = state
                    locationCountry = country
                    locationLat = lat
                    locationLon = lon
                }
            }
        }
    }

    private func clearLocation() {
        locationName = ""
        locationAddress = ""
        locationCity = nil
        locationState = nil
        locationCountry = nil
        locationLat = nil
        locationLon = nil
    }

    // MARK: - Primary CTA

    private var addFunctionBar: some View {
        Button {
            addFunction()
        } label: {
            Text("Add Function")
                .font(GatherFont.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(LinearGradient.gatherAccentGradient)
                .clipShape(Capsule())
        }
        .disabled(name.isEmpty)
        .opacity(name.isEmpty ? 0.5 : 1)
        .horizontalPadding()
        .padding(.vertical, Spacing.sm)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .shadow(color: .black.opacity(0.1), radius: 15, y: -6)
        )
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
            ? EventLocation(
                name: locationName,
                address: locationAddress.isEmpty ? nil : locationAddress,
                city: locationCity,
                state: locationState,
                country: locationCountry,
                latitude: locationLat,
                longitude: locationLon
            )
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
        modelContext.safeSave()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var event = Event(title: "Wedding", startDate: Date())
    AddFunctionSheet(event: event)
}
