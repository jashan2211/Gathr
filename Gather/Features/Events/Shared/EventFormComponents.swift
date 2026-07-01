import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Form Card Surface (dark poster style)

/// Solid card surface for every form section in the Create/Edit wizards.
/// Replaces the faint `gatherSecondaryBackground.opacity(...)` look with a
/// solid `gatherSurface` fill, `CornerRadius.xl` rounding, `Spacing.md` padding,
/// and a hairline border for definition on the near-black canvas.
struct EventFormCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .background(Color.gatherSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.06 : 0),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    /// Apply the solid form-section card treatment used across the event forms.
    func eventFormCard() -> some View {
        modifier(EventFormCardModifier())
    }
}

/// Nested input surface — `gatherElevated` fill with a 1pt border that turns
/// accent once the field is focused or has content. Used by text fields,
/// pickers and toggle rows so every input reads clearly on dark.
struct EventFormInputSurface: ViewModifier {
    var isActive: Bool
    var cornerRadius: CGFloat = CornerRadius.md
    var minHeight: CGFloat = Layout.minTouchTarget

    func body(content: Content) -> some View {
        content
            .frame(minHeight: minHeight)
            .background(Color.gatherElevated)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.accentPurpleFallback.opacity(0.6) : Color.gatherSeparator.opacity(0.6),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    /// Style a row/field as a nested input on `gatherElevated` with a border
    /// that turns accent when `isActive` (focused or filled). Tap target >= 44pt.
    func eventFormInputSurface(
        isActive: Bool,
        cornerRadius: CGFloat = CornerRadius.md,
        minHeight: CGFloat = Layout.minTouchTarget
    ) -> some View {
        modifier(EventFormInputSurface(isActive: isActive, cornerRadius: cornerRadius, minHeight: minHeight))
    }
}

// MARK: - Event Form Section Header

/// Shared section header used across Create and Edit event forms.
/// Bold 17pt title + an accent-tinted icon so each section is instantly
/// scannable on the dark canvas. Pass `accent` to tint the icon in the event's
/// category color; defaults to the purple app accent.
struct EventFormSectionHeader: View {
    let title: String
    let icon: String
    var accent: Color = .accentPurpleFallback

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.gatherPrimaryText)
        }
    }
}

// MARK: - Event Hero Image Picker

/// Hero image section with PhotosPicker and category gradient placeholder.
/// Supports both create (no existing image) and edit (existing image URL) modes.
struct EventHeroImagePicker: View {
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var heroImage: Image?
    var selectedCategory: EventCategory
    var existingImageURL: URL? = nil

    var body: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            ZStack {
                if let heroImage = heroImage {
                    heroImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: Layout.heroHeight)
                        .clipped()
                        .overlay {
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.3)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        }
                } else if let existingImageURL {
                    AsyncImage(url: existingImageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: Layout.heroHeight)
                            .clipped()
                    } placeholder: {
                        EventFormCategoryGradientPlaceholder(category: selectedCategory)
                    }
                    .accessibilityLabel("Event image")
                } else {
                    EventFormCategoryGradientPlaceholder(category: selectedCategory)
                }

                // Camera button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: cameraIconName)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(cameraLabel)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(Spacing.md)
                    }
                }
            }
            .frame(height: Layout.heroHeight)
            .clipped()
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    heroImage = Image(uiImage: uiImage)
                }
            }
        }
    }

    private var cameraIconName: String {
        if heroImage != nil || existingImageURL != nil {
            return "arrow.triangle.2.circlepath.camera.fill"
        }
        return "camera.fill"
    }

    private var cameraLabel: String {
        if heroImage != nil {
            return existingImageURL != nil ? "Change Cover" : "Change"
        }
        if existingImageURL != nil {
            return "Change Cover"
        }
        return "Add Cover"
    }
}

// MARK: - Category Gradient Placeholder

/// Category mesh placeholder shown when no hero image is selected
struct EventFormCategoryGradientPlaceholder: View {
    let category: EventCategory

    var body: some View {
        ZStack {
            CategoryMeshBackground(category: category)

            // Floating emoji watermark
            Text(category.emoji)
                .font(.system(size: 80))
                .opacity(0.15)
                .rotationEffect(.degrees(-15))
        }
        .frame(height: Layout.heroHeight)
    }
}

// MARK: - Event Category Selector

/// Horizontal scrolling category chips for selecting event category.
/// Also updates enabledFeatures to the category defaults when a new category is selected.
struct EventCategorySelector: View {
    @Binding var selectedCategory: EventCategory
    @Binding var enabledFeatures: Set<EventFeature>
    var headerTitle: String = "What kind of event?"

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            EventFormSectionHeader(title: headerTitle, icon: "sparkles", accent: Color.forCategory(selectedCategory))

            // Horizontal scrolling category chips with emoji + gradient
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(EventCategory.allCases, id: \.self) { category in
                        EventFormCategoryChip(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                selectedCategory = category
                                enabledFeatures = category.defaultFeatures
                            }
                            HapticService.buttonTap()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Event Basics Section

/// Title and description fields with gradient border styling
struct EventBasicsSection: View {
    @Binding var title: String
    @Binding var description: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            EventFormSectionHeader(title: "Event Details", icon: "textformat")

            // Title field with accent-on-fill border
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("EVENT NAME")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.gatherSecondaryText)
                    .tracking(0.5)

                TextField("Give your event a vibe...", text: $title, axis: .vertical)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.gatherPrimaryText)
                    .lineLimit(1...2)
                    .padding(Spacing.md)
                    .eventFormInputSurface(isActive: !title.isEmpty)

                HStack {
                    Spacer()
                    Text("\(title.count)/100")
                        .font(.caption2)
                        .foregroundStyle(title.count > 90 ? Color.warmCoral : Color.gatherSecondaryText)
                }
            }

            // Description field
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("DESCRIPTION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.gatherSecondaryText)
                        .tracking(0.5)
                    Text("optional")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherTertiaryText)
                }

                TextField("Tell people what to expect...", text: $description, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.gatherPrimaryText)
                    .lineLimit(3...6)
                    .padding(Spacing.md)
                    .eventFormInputSurface(isActive: !description.isEmpty, minHeight: 88)
            }
        }
        .eventFormCard()
    }
}

// MARK: - Event Features Section

/// Feature toggle cards in a condensed 2-column grid so every feature fits on
/// one screen without scrolling at the default text size.
struct EventFeaturesSection: View {
    @Binding var enabledFeatures: Set<EventFeature>

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.xs),
        GridItem(.flexible(), spacing: Spacing.xs)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            EventFormSectionHeader(title: "Features", icon: "slider.horizontal.3")

            Text("Choose what this event needs — you can change this anytime")
                .gatherMetaText()
                .foregroundStyle(Color.gatherSecondaryText)

            LazyVGrid(columns: columns, spacing: Spacing.xs) {
                // Only show features that are actually available — coming-soon
                // ones are hidden entirely rather than greyed out.
                ForEach(EventFeature.allCases.filter { $0.isAvailable }, id: \.self) { feature in
                    EventFeatureGridCard(
                        feature: feature,
                        isEnabled: enabledFeatures.contains(feature)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            if enabledFeatures.contains(feature) {
                                enabledFeatures.remove(feature)
                            } else {
                                enabledFeatures.insert(feature)
                            }
                        }
                        HapticService.buttonTap()
                    }
                }
            }
        }
        .eventFormCard()
    }
}

// MARK: - Event Date Time Section

/// Quick date chips + date pickers for start/end dates.
/// Set `allowPastDates` to true when editing existing events.
struct EventDateTimeSection: View {
    @Binding var startDate: Date
    @Binding var endDate: Date?
    @Binding var hasEndDate: Bool
    var allowPastDates: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            EventFormSectionHeader(title: "When", icon: "calendar.badge.clock")

            // Quick date chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    EventFormQuickDateChip(label: "Tonight", icon: "moon.stars.fill") {
                        let tonight = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
                        withAnimation { startDate = tonight > Date() ? tonight : tonight.addingTimeInterval(86400) }
                    }
                    EventFormQuickDateChip(label: "Tomorrow", icon: "sunrise.fill") {
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                        let tomorrowEvening = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow) ?? tomorrow
                        withAnimation { startDate = tomorrowEvening }
                    }
                    EventFormQuickDateChip(label: "This Weekend", icon: "sparkles") {
                        let calendar = Calendar.current
                        let today = Date()
                        let weekday = calendar.component(.weekday, from: today)
                        let daysToSaturday = (7 - weekday) % 7
                        let saturday = calendar.date(byAdding: .day, value: daysToSaturday == 0 ? 7 : daysToSaturday, to: today) ?? today
                        let saturdayEvening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: saturday) ?? saturday
                        withAnimation { startDate = saturdayEvening }
                    }
                    EventFormQuickDateChip(label: "Next Week", icon: "calendar") {
                        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                        let nextWeekEvening = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: nextWeek) ?? nextWeek
                        withAnimation { startDate = nextWeekEvening }
                    }
                }
            }

            // Date pickers in styled cards
            VStack(spacing: Spacing.sm) {
                // Start
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.rsvpYesFallback)
                        Text("Starts")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.gatherPrimaryText)
                    }
                    Spacer()
                    if allowPastDates {
                        DatePicker(
                            "",
                            selection: $startDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .tint(Color.accentPurpleFallback)
                    } else {
                        DatePicker(
                            "",
                            selection: $startDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .tint(Color.accentPurpleFallback)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .eventFormInputSurface(isActive: false)

                // End time toggle + picker
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.rsvpNoFallback.opacity(0.7))
                        Text("Ends")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.gatherPrimaryText)
                    }
                    Spacer()
                    if hasEndDate {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { endDate ?? startDate.addingTimeInterval(3600) },
                                set: { endDate = $0 }
                            ),
                            in: startDate...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .tint(Color.accentPurpleFallback)
                    }
                    Toggle("", isOn: $hasEndDate)
                        .labelsHidden()
                        .tint(Color.accentPurpleFallback)
                        .scaleEffect(0.85)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .eventFormInputSurface(isActive: hasEndDate)
            }
        }
        .eventFormCard()
    }
}

// MARK: - Event Location Section

/// Virtual/in-person toggle + location fields
struct EventLocationSection: View {
    @Binding var isVirtual: Bool
    @Binding var virtualURL: String
    @Binding var locationName: String
    @Binding var locationAddress: String
    @Binding var locationCity: String
    @Binding var locationState: String
    @Binding var locationCountry: String
    @Binding var locationLatitude: Double?
    @Binding var locationLongitude: Double?

    @State private var showLocationPicker = false
    @State private var showManualEntry = false

    /// True once the user has picked a place on the map or typed a venue name.
    private var hasLocation: Bool {
        locationLatitude != nil || !locationName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// One-line address summary for the confirmation card.
    private var addressSummary: String {
        [locationAddress, locationCity, locationState]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            EventFormSectionHeader(title: "Where", icon: "mappin.and.ellipse")

            // Virtual / In-Person toggle
            HStack(spacing: Spacing.xs) {
                EventFormLocationTypeButton(
                    label: "In Person",
                    icon: "building.2.fill",
                    isSelected: !isVirtual
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { isVirtual = false }
                }
                EventFormLocationTypeButton(
                    label: "Virtual",
                    icon: "video.fill",
                    isSelected: isVirtual
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { isVirtual = true }
                }
            }

            if isVirtual {
                EventFormStyledTextField(
                    placeholder: "Paste meeting link (Zoom, Meet, etc.)",
                    text: $virtualURL,
                    icon: "link",
                    keyboardType: .URL,
                    autocapitalization: .never
                )
            } else {
                inPersonContent
            }
        }
        .eventFormCard()
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView { name, address, city, state, country, lat, lon in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    locationName = name
                    locationAddress = address ?? ""
                    locationCity = city ?? ""
                    locationState = state ?? ""
                    locationCountry = country ?? ""
                    locationLatitude = lat
                    locationLongitude = lon
                    showManualEntry = false
                }
                HapticService.success()
            }
        }
    }

    // MARK: In-person layout

    /// Map-first: one prominent search action, the five address fields hidden
    /// behind a collapsed disclosure most guests never need to open.
    @ViewBuilder
    private var inPersonContent: some View {
        if hasLocation {
            selectedLocationCard
        } else {
            searchButton

            // Collapsed "Enter address manually" disclosure — hidden by default
            // so the fresh step stays short. This is the main height offender
            // when expanded, so it never auto-opens.
            manualEntryDisclosure
        }

        if showManualEntry {
            VStack(spacing: Spacing.xs) {
                EventFormStyledTextField(placeholder: "Venue name", text: $locationName, icon: "mappin")
                EventFormStyledTextField(placeholder: "Address (optional)", text: $locationAddress, icon: "map")
                HStack(spacing: Spacing.xs) {
                    EventFormStyledTextField(placeholder: "City", text: $locationCity, icon: "building.2")
                    EventFormStyledTextField(placeholder: "State / Region", text: $locationState, icon: "map")
                }
                EventFormStyledTextField(placeholder: "Country", text: $locationCountry, icon: "globe")
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// Disclosure toggle for the manual address fields. Only shown before a
    /// place is picked; once a location exists the fields live under the card's
    /// "Edit details" menu action instead.
    private var manualEntryDisclosure: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showManualEntry.toggle() }
            HapticService.buttonTap()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentPurpleFallback)
                Text("Enter address manually")
                    .gatherMetaText()
                    .foregroundStyle(Color.gatherSecondaryText)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.gatherSecondaryText)
                    .rotationEffect(.degrees(showManualEntry ? 180 : 0))
            }
            .frame(minHeight: Layout.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Enter address manually")
        .accessibilityValue(showManualEntry ? "Expanded" : "Collapsed")
        .accessibilityHint("Double tap to \(showManualEntry ? "collapse" : "expand")")
    }

    private var searchButton: some View {
        Button {
            HapticService.buttonTap()
            showLocationPicker = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.headline)
                Text("Search for a place")
                    .font(GatherFont.callout)
                    .fontWeight(.semibold)
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
    }

    private var selectedLocationCard: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.gatherSuccess.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: locationLatitude != nil ? "mappin.circle.fill" : "mappin")
                    .foregroundStyle(Color.gatherSuccess)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(locationName.isEmpty ? "Selected location" : locationName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.gatherPrimaryText)
                    .lineLimit(1)
                if !addressSummary.isEmpty {
                    Text(addressSummary)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.xs)

            Menu {
                Button { showLocationPicker = true } label: {
                    Label("Search again", systemImage: "magnifyingglass")
                }
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showManualEntry.toggle() }
                } label: {
                    Label(showManualEntry ? "Hide details" : "Edit details", systemImage: "pencil")
                }
                Button(role: .destructive) { clearLocation() } label: {
                    Label("Remove location", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .accessibilityLabel("Location options")
        }
        .padding(Spacing.sm)
        .eventFormInputSurface(isActive: true)
    }

    private func clearLocation() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            locationName = ""
            locationAddress = ""
            locationCity = ""
            locationState = ""
            locationCountry = ""
            locationLatitude = nil
            locationLongitude = nil
            showManualEntry = false
        }
    }
}

// MARK: - Event Settings Section

/// Privacy cards, guest list visibility, capacity controls
struct EventSettingsSection: View {
    @Binding var privacy: EventPrivacy
    @Binding var guestListVisibility: GuestListVisibility
    @Binding var capacity: Int?
    @Binding var hasCapacity: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            EventFormSectionHeader(title: "Settings", icon: "gearshape.fill")

            // Privacy cards
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("WHO CAN SEE THIS EVENT?")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.gatherSecondaryText)
                    .tracking(0.5)

                HStack(spacing: Spacing.xs) {
                    EventFormPrivacyCard(
                        option: .unlisted,
                        icon: "link",
                        isSelected: privacy == .unlisted
                    ) { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { privacy = .unlisted } }

                    EventFormPrivacyCard(
                        option: .inviteOnly,
                        icon: "lock.fill",
                        isSelected: privacy == .inviteOnly
                    ) { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { privacy = .inviteOnly } }
                }
            }

            // Guest list visibility
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("GUEST LIST")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.gatherSecondaryText)
                    .tracking(0.5)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.xs) {
                    ForEach(GuestListVisibility.allCases, id: \.self) { option in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { guestListVisibility = option }
                        } label: {
                            Text(option.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(guestListVisibility == option ? .white : Color.gatherPrimaryText)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: Layout.minTouchTarget)
                                .background(
                                    guestListVisibility == option
                                        ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                                        : AnyShapeStyle(Color.gatherElevated)
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            guestListVisibility == option ? Color.clear : Color.gatherSeparator.opacity(0.6),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .accessibilityLabel("\(option.displayName) guest list visibility")
                        .accessibilityAddTraits(guestListVisibility == option ? [.isSelected] : [])
                    }
                }
            }

            // Capacity
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.3.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentPurpleFallback)
                    Text("Limit capacity")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.gatherPrimaryText)
                }
                Spacer()
                Toggle("", isOn: $hasCapacity)
                    .labelsHidden()
                    .tint(Color.accentPurpleFallback)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .eventFormInputSurface(isActive: hasCapacity)

            if hasCapacity {
                HStack(spacing: Spacing.sm) {
                    Text("Max guests")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.gatherSecondaryText)
                    Spacer()
                    HStack(spacing: Spacing.xs) {
                        Button {
                            let current = capacity ?? 50
                            if current > 10 { capacity = current - 10 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.accentPinkFallback)
                        }

                        TextField("50", value: $capacity, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.gatherPrimaryText)
                            .frame(width: 64)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.gatherElevated)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .strokeBorder(Color.accentPurpleFallback.opacity(0.6), lineWidth: 1)
                            )

                        Button {
                            capacity = (capacity ?? 50) + 10
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.accentPurpleFallback)
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .eventFormInputSurface(isActive: true)
            }
        }
        .eventFormCard()
    }
}

// MARK: - Shared Helper Views

// MARK: Event Form Category Chip

struct EventFormCategoryChip: View {
    let category: EventCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(category.emoji)
                    .font(.callout)
                Text(category.displayName)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(
                isSelected
                    ? Color.onCategory(category)
                    : Color.gatherPrimaryText
            )
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: Layout.minTouchTarget)
            .background(
                isSelected
                    ? AnyShapeStyle(Color.forCategory(category))
                    : AnyShapeStyle(Color.gatherElevated)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Color.gatherSeparator.opacity(0.6),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .accessibilityLabel("\(category.displayName) category")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .fixedSize()
    }
}

// MARK: Event Feature Card

/// A large, tappable feature card with an icon, name and one-line explanation.
/// Coming-soon features are shown greyed out with a "Soon" badge and can't be
/// toggled on.
struct EventFeatureCard: View {
    let feature: EventFeature
    let isEnabled: Bool
    let onToggle: () -> Void

    private var available: Bool { feature.isAvailable }
    private var active: Bool { isEnabled && available }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: feature.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(active ? .white : Color.gatherSecondaryText)
                    .frame(width: 46, height: 46)
                    .background(
                        active
                            ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                            : AnyShapeStyle(Color.gatherSurface)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(feature.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(available ? Color.gatherPrimaryText : Color.gatherSecondaryText)
                        if !available {
                            Text("SOON")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gatherSecondaryText.opacity(0.55))
                                .clipShape(Capsule())
                        }
                    }
                    Text(feature.description)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.gatherSecondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.xs)

                if available {
                    Image(systemName: active ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(active ? Color.accentPurpleFallback : Color.gatherSecondaryText.opacity(0.4))
                }
            }
            .padding(Spacing.sm)
            .frame(minHeight: Layout.minTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(active ? Color.accentPurpleFallback.opacity(0.14) : Color.gatherElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .strokeBorder(
                        active ? Color.accentPurpleFallback.opacity(0.7) : Color.gatherSeparator.opacity(0.6),
                        lineWidth: active ? 1.5 : 1
                    )
            )
            .opacity(available ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .scaleEffect(active ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: active)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(feature.displayName). \(feature.description)\(available ? "" : ". Coming soon")")
        .accessibilityValue(available ? (isEnabled ? "On" : "Off") : "")
        .accessibilityAddTraits(active ? [.isSelected] : [])
        .accessibilityHint(available ? "Double tap to toggle" : "")
    }
}

// MARK: Event Feature Grid Card (condensed 2-column)

/// A compact, square-ish feature card for the 2-column features grid. Same
/// toggle semantics as `EventFeatureCard` but with a smaller icon tile and a
/// one-line description so all features fit on screen without scrolling.
struct EventFeatureGridCard: View {
    let feature: EventFeature
    let isEnabled: Bool
    let onToggle: () -> Void

    private var available: Bool { feature.isAvailable }
    private var active: Bool { isEnabled && available }

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(active ? .white : Color.gatherSecondaryText)
                        .frame(width: 34, height: 34)
                        .background(
                            active
                                ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                                : AnyShapeStyle(Color.gatherSurface)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                    Spacer(minLength: 0)

                    if available {
                        Image(systemName: active ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(active ? Color.accentPurpleFallback : Color.gatherSecondaryText.opacity(0.4))
                    } else {
                        Text("SOON")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gatherSecondaryText.opacity(0.55))
                            .clipShape(Capsule())
                    }
                }

                Text(feature.displayName)
                    .gatherRowTitle()
                    .foregroundStyle(available ? Color.gatherPrimaryText : Color.gatherSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(feature.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gatherSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(active ? Color.accentPurpleFallback.opacity(0.14) : Color.gatherElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .strokeBorder(
                        active ? Color.accentPurpleFallback.opacity(0.7) : Color.gatherSeparator.opacity(0.6),
                        lineWidth: active ? 1.5 : 1
                    )
            )
            .opacity(available ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .scaleEffect(active ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: active)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(feature.displayName). \(feature.description)\(available ? "" : ". Coming soon")")
        .accessibilityValue(available ? (isEnabled ? "On" : "Off") : "")
        .accessibilityAddTraits(active ? [.isSelected] : [])
        .accessibilityHint(available ? "Double tap to toggle" : "")
    }
}

// MARK: Event Form Styled Text Field

struct EventFormStyledTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentPurpleFallback.opacity(0.8))
                    .frame(width: 20)
            }
            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .foregroundStyle(Color.gatherPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
        }
        .padding(.horizontal, Spacing.sm)
        .eventFormInputSurface(isActive: !text.isEmpty)
    }
}

// MARK: Event Form Quick Date Chip

struct EventFormQuickDateChip: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            HapticService.buttonTap()
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.accentPurpleFallback)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(Color.accentPurpleFallback.opacity(0.16))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set date to \(label)")
    }
}

// MARK: Event Form Location Type Button

struct EventFormLocationTypeButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Layout.minTouchTarget)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                    : AnyShapeStyle(Color.gatherElevated)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Color.gatherSeparator.opacity(0.6),
                        lineWidth: 1
                    )
            )
        }
        .accessibilityLabel("\(label) location")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: Event Form Privacy Card

struct EventFormPrivacyCard: View {
    let option: EventPrivacy
    let icon: String
    let isSelected: Bool
    var isAvailable: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? .white : Color.gatherSecondaryText)
                    .frame(width: 36, height: 36)
                    .background(
                        isSelected
                            ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                            : AnyShapeStyle(Color.gatherSurface)
                    )
                    .clipShape(Circle())

                Text(option.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(isSelected ? Color.accentPurpleFallback : Color.gatherSecondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                isSelected
                    ? Color.accentPurpleFallback.opacity(0.14)
                    : Color.gatherElevated
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentPurpleFallback.opacity(0.7) : Color.gatherSeparator.opacity(0.6),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .overlay(alignment: .topTrailing) {
                if !isAvailable {
                    Text("SOON")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.gatherSecondaryText.opacity(0.65))
                        .clipShape(Capsule())
                        .padding(4)
                }
            }
            .opacity(isAvailable ? 1 : 0.5)
        }
        .disabled(!isAvailable)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .accessibilityLabel("\(option.displayName) privacy\(isAvailable ? "" : ", coming soon")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
