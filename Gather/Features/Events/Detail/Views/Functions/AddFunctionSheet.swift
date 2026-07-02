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
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    titleHeader
                    detailsCard
                    whenCard
                    whereCard
                    dressCodeCard
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.gatherCanvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                addFunctionBar
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.gatherSecondaryText)
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

    // MARK: - Editorial Header

    /// Eyebrow (parent event) + serif display title — the Gathr signature.
    private var titleHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title.isEmpty ? "NEW FUNCTION" : event.title.uppercased())
                .gatherEyebrow()
                .foregroundStyle(Color.gatherSecondaryText)
                .lineLimit(1)
            Text("Add Function")
                .gatherSerifPosterTitle()
                .foregroundStyle(Color.gatherPrimaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.xs)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("DETAILS")
                .gatherEyebrow()
                .foregroundStyle(Color.gatherSecondaryText)

            TextField("Function Name", text: $name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.gatherPrimaryText)
                .padding(.horizontal, Spacing.md)
                .eventFormInputSurface(isActive: !name.isEmpty)

            // Quick-fill suggestions (same action as the old Quick Fill section)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(suggestedNames, id: \.self) { suggestion in
                        Button {
                            name = suggestion
                        } label: {
                            Text(suggestion)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(name == suggestion ? .white : Color.gatherPrimaryText)
                                .padding(.horizontal, Spacing.md)
                                .frame(minHeight: Layout.minTouchTarget)
                                .background(
                                    name == suggestion
                                        ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                                        : AnyShapeStyle(Color.gatherElevated)
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            name == suggestion ? Color.clear : Color.gatherSeparator.opacity(0.6),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Use suggested name \(suggestion)")
                        .accessibilityAddTraits(name == suggestion ? [.isSelected] : [])
                    }
                }
            }

            TextField("Description (optional)", text: $functionDescription, axis: .vertical)
                .font(.system(size: 16))
                .foregroundStyle(Color.gatherPrimaryText)
                .lineLimit(3...6)
                .padding(Spacing.md)
                .eventFormInputSurface(isActive: !functionDescription.isEmpty, minHeight: 88)
        }
        .eventFormCard()
    }

    // MARK: - When Card

    private var whenCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("WHEN")
                .gatherEyebrow()
                .foregroundStyle(Color.gatherSecondaryText)

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundStyle(Color.accentPurpleFallback)
                    Text("Date & Time")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.gatherPrimaryText)
                }
                Spacer()
                DatePicker("", selection: $date)
                    .labelsHidden()
                    .tint(Color.accentPurpleFallback)
                    .accessibilityLabel("Date & Time")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .eventFormInputSurface(isActive: false)

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "stop.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.rsvpNoFallback.opacity(0.7))
                    Text("End Time")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.gatherPrimaryText)
                }
                Spacer()
                if hasEndTime {
                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(Color.accentPurpleFallback)
                        .accessibilityLabel("End Time")
                }
                Toggle("", isOn: $hasEndTime.animation())
                    .labelsHidden()
                    .tint(Color.accentPurpleFallback)
                    .scaleEffect(0.85)
                    .accessibilityLabel("Add End Time")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .eventFormInputSurface(isActive: hasEndTime)
        }
        .eventFormCard()
        .onChange(of: date) { _, newDate in reconcileEndTimeDay(to: newDate) }
        .onChange(of: hasEndTime) { _, on in if on { reconcileEndTimeDay(to: date) } }
    }

    /// Keeps the end time on the same calendar day as the start `date` (preserving
    /// its hour/minute) so a function's end can't accidentally precede its start —
    /// the end picker only edits time, so a start-date change would otherwise
    /// leave the end stranded on the old day.
    private func reconcileEndTimeDay(to day: Date) {
        let cal = Calendar.current
        let t = cal.dateComponents([.hour, .minute], from: endTime)
        guard let snapped = cal.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: 0, of: day) else { return }
        endTime = snapped < day ? day.addingTimeInterval(3600) : snapped
    }

    // MARK: - Where Card

    private var whereCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("WHERE")
                .gatherEyebrow()
                .foregroundStyle(Color.gatherSecondaryText)

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(Color.accentPinkFallback)
                    Text("Add Location")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.gatherPrimaryText)
                }
                Spacer()
                Toggle("", isOn: $hasLocation.animation())
                    .labelsHidden()
                    .tint(Color.accentPurpleFallback)
                    .accessibilityLabel("Add Location")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .eventFormInputSurface(isActive: hasLocation)

            if hasLocation {
                // Map search — fills name/address/coords like the main create
                // flow. Manual name below stays as a fallback.
                Button {
                    HapticService.buttonTap()
                    showLocationPicker = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.headline)
                        Text(locationLat == nil ? "Search for a place" : "Change place")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Image(systemName: "map.fill")
                            .font(.callout)
                    }
                    .foregroundStyle(.white)
                    .padding(Spacing.md)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)

                // Show the resolved place (from the map) as a summary row.
                if locationLat != nil {
                    HStack(spacing: Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(Color.gatherSuccess.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(Color.gatherSuccess)
                        }

                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(locationName)
                                .gatherRowTitle()
                                .foregroundStyle(Color.gatherPrimaryText)
                                .lineLimit(1)
                            if !locationAddress.isEmpty {
                                Text(locationAddress)
                                    .gatherMetaText()
                                    .foregroundStyle(Color.gatherSecondaryText)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: Spacing.xs)

                        Button {
                            clearLocation()
                        } label: {
                            Text("Clear place")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.gatherError)
                        }
                    }
                    .padding(Spacing.sm)
                    .eventFormInputSurface(isActive: true)
                }

                // Manual fallback — always available for a venue with no map
                // match (a home, a marquee, etc.).
                TextField("Venue name", text: $locationName)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.gatherPrimaryText)
                    .padding(.horizontal, Spacing.md)
                    .eventFormInputSurface(isActive: !locationName.isEmpty)

                if locationLat == nil {
                    TextField("Address (optional)", text: $locationAddress)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.gatherPrimaryText)
                        .padding(.horizontal, Spacing.md)
                        .eventFormInputSurface(isActive: !locationAddress.isEmpty)
                }

                Text("Search for a place to pin it on the map, or just type a venue name.")
                    .gatherMetaText()
                    .foregroundStyle(Color.gatherTertiaryText)
            }
        }
        .eventFormCard()
    }

    // MARK: - Dress Code Card

    private var dressCodeCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("DRESS CODE")
                .gatherEyebrow()
                .foregroundStyle(Color.gatherSecondaryText)

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tshirt.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentPurpleFallback)
                    Text("Add Dress Code")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.gatherPrimaryText)
                }
                Spacer()
                Toggle("", isOn: $hasDressCode.animation())
                    .labelsHidden()
                    .tint(Color.accentPurpleFallback)
                    .accessibilityLabel("Add Dress Code")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .eventFormInputSurface(isActive: hasDressCode)

            if hasDressCode {
                HStack {
                    Text("Dress Code")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.gatherPrimaryText)
                    Spacer()
                    Picker("Dress Code", selection: $dressCode) {
                        ForEach(DressCode.allCases, id: \.self) { code in
                            HStack {
                                Image(systemName: code.icon)
                                Text(code.displayName)
                            }
                            .tag(code)
                        }
                    }
                    .labelsHidden()
                    .tint(Color.accentPurpleFallback)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .eventFormInputSurface(isActive: true)

                if dressCode == .custom {
                    TextField("Custom Dress Code", text: $customDressCode)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.gatherPrimaryText)
                        .padding(.horizontal, Spacing.md)
                        .eventFormInputSurface(isActive: !customDressCode.isEmpty)
                } else {
                    Text(dressCode.description)
                        .gatherMetaText()
                        .foregroundStyle(Color.gatherTertiaryText)
                }
            }
        }
        .eventFormCard()
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
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.gatherCanvas.opacity(0), Color.gatherCanvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            Button {
                addFunction()
            } label: {
                Text("Add Function")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
                    .accentGlow(name.isEmpty ? .clear : Color.accentPurpleFallback, radius: 12)
            }
            .disabled(name.isEmpty)
            .opacity(name.isEmpty ? 0.5 : 1)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, Spacing.md)
            .background(Color.gatherCanvas)
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
