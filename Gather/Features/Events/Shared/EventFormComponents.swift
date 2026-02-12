import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Event Form Section Header

/// Shared section header used across Create and Edit event forms
struct EventFormSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentPurpleFallback)
            Text(title)
                .font(GatherFont.headline)
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

/// Vibrant category-tinted placeholder shown when no hero image is selected
struct EventFormCategoryGradientPlaceholder: View {
    let category: EventCategory

    var body: some View {
        ZStack {
            LinearGradient.categoryGradientVibrant(for: category)
                .opacity(0.8)

            // Floating emoji watermark
            Text(category.emoji)
                .font(.system(size: 80))
                .opacity(0.15)
                .rotationEffect(.degrees(-15))

            // Subtle pattern overlay
            LinearGradient(
                colors: [.white.opacity(0.1), .clear, .white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
            EventFormSectionHeader(title: headerTitle, icon: "sparkles")

            // Horizontal scrolling category chips with emoji + gradient
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(EventCategory.allCases, id: \.self) { category in
                        EventFormCategoryChip(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            EventFormSectionHeader(title: "Event Details", icon: "textformat")

            // Title field with gradient accent
            VStack(alignment: .leading, spacing: 6) {
                Text("EVENT NAME")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .tracking(0.5)

                TextField("Give your event a vibe...", text: $title, axis: .vertical)
                    .font(GatherFont.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1...2)
                    .padding(Spacing.md)
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .strokeBorder(
                                LinearGradient(
                                    colors: title.isEmpty
                                        ? [Color.clear, Color.clear]
                                        : [Color.accentPurpleFallback, Color.accentPinkFallback],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )

                HStack {
                    Spacer()
                    Text("\(title.count)/100")
                        .font(.caption2)
                        .foregroundStyle(title.count > 90 ? Color.warmCoral : Color.gatherSecondaryText)
                }
            }

            // Description field
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("DESCRIPTION")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .tracking(0.5)
                    Text("optional")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherTertiaryText)
                }

                TextField("Tell people what to expect...", text: $description, axis: .vertical)
                    .font(GatherFont.body)
                    .lineLimit(3...6)
                    .padding(Spacing.md)
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
        }
        .padding(Spacing.md)
        .background(Color.gatherSecondaryBackground.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
    }
}

// MARK: - Event Features Section

/// Feature toggle chips in a wrapping LazyVGrid layout
struct EventFeaturesSection: View {
    @Binding var enabledFeatures: Set<EventFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            EventFormSectionHeader(title: "Features", icon: "slider.horizontal.3")

            Text("Tap to toggle what you need")
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)

            // Feature chips in a wrapping flow layout
            EventFormWrappingFeatureChips(
                enabledFeatures: $enabledFeatures
            )
        }
        .padding(Spacing.md)
        .background(Color.gatherSecondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
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
                            .font(GatherFont.callout)
                            .fontWeight(.medium)
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
                .padding(Spacing.sm)
                .background(Color.gatherSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

                // End time toggle + picker
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.rsvpNoFallback.opacity(0.7))
                        Text("Ends")
                            .font(GatherFont.callout)
                            .fontWeight(.medium)
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
                .padding(Spacing.sm)
                .background(Color.gatherSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
        }
        .padding(Spacing.md)
        .background(Color.gatherSecondaryBackground.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
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
    @Binding var locationLatitude: Double?
    @Binding var locationLongitude: Double?

    @State private var showLocationPicker = false

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
                    withAnimation(.spring(response: 0.3)) { isVirtual = false }
                }
                EventFormLocationTypeButton(
                    label: "Virtual",
                    icon: "video.fill",
                    isSelected: isVirtual
                ) {
                    withAnimation(.spring(response: 0.3)) { isVirtual = true }
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
                VStack(spacing: Spacing.xs) {
                    // Search on Map button
                    Button {
                        showLocationPicker = true
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "map.fill")
                                .foregroundStyle(Color.accentPinkFallback)
                            Text("Search on Map")
                                .font(GatherFont.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.accentPinkFallback)
                            Spacer()
                            if locationLatitude != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.gatherSuccess)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                        .padding(Spacing.sm)
                        .background(Color.accentPinkFallback.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }

                    EventFormStyledTextField(
                        placeholder: "Venue name",
                        text: $locationName,
                        icon: "mappin"
                    )
                    EventFormStyledTextField(
                        placeholder: "Address (optional)",
                        text: $locationAddress,
                        icon: "map"
                    )
                    HStack(spacing: Spacing.xs) {
                        EventFormStyledTextField(
                            placeholder: "City",
                            text: $locationCity,
                            icon: "building.2"
                        )
                        EventFormStyledTextField(
                            placeholder: "State",
                            text: $locationState,
                            icon: "globe.americas"
                        )
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.gatherSecondaryBackground.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView { name, address, city, state, lat, lon in
                locationName = name
                if let address { locationAddress = address }
                if let city { locationCity = city }
                if let state { locationState = state }
                locationLatitude = lat
                locationLongitude = lon
            }
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
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .tracking(0.5)

                HStack(spacing: Spacing.xs) {
                    EventFormPrivacyCard(
                        option: .publicEvent,
                        icon: "globe",
                        isSelected: privacy == .publicEvent
                    ) { withAnimation(.spring(response: 0.3)) { privacy = .publicEvent } }

                    EventFormPrivacyCard(
                        option: .unlisted,
                        icon: "link",
                        isSelected: privacy == .unlisted
                    ) { withAnimation(.spring(response: 0.3)) { privacy = .unlisted } }

                    EventFormPrivacyCard(
                        option: .inviteOnly,
                        icon: "lock.fill",
                        isSelected: privacy == .inviteOnly
                    ) { withAnimation(.spring(response: 0.3)) { privacy = .inviteOnly } }
                }
            }

            // Guest list visibility
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("GUEST LIST")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .tracking(0.5)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.xs) {
                    ForEach(GuestListVisibility.allCases, id: \.self) { option in
                        Button {
                            withAnimation(.spring(response: 0.3)) { guestListVisibility = option }
                        } label: {
                            Text(option.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(guestListVisibility == option ? .white : Color.gatherPrimaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.xs)
                                .background(
                                    guestListVisibility == option
                                        ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                                        : AnyShapeStyle(Color.gatherSecondaryBackground)
                                )
                                .clipShape(Capsule())
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
                        .font(GatherFont.callout)
                }
                Spacer()
                Toggle("", isOn: $hasCapacity)
                    .labelsHidden()
                    .tint(Color.accentPurpleFallback)
            }
            .padding(Spacing.sm)
            .background(Color.gatherSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

            if hasCapacity {
                HStack(spacing: Spacing.sm) {
                    Text("Max guests")
                        .font(GatherFont.callout)
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
                            .font(GatherFont.headline)
                            .fontWeight(.bold)
                            .frame(width: 60)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.gatherSecondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                        Button {
                            capacity = (capacity ?? 50) + 10
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.accentPurpleFallback)
                        }
                    }
                }
                .padding(Spacing.sm)
                .background(Color.gatherSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
        }
        .padding(Spacing.md)
        .background(Color.gatherSecondaryBackground.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
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
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient.categoryGradientVibrant(for: category))
                    : AnyShapeStyle(Color.gatherSecondaryBackground)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Color.gatherSeparator,
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

// MARK: Event Form Wrapping Feature Chips

struct EventFormWrappingFeatureChips: View {
    @Binding var enabledFeatures: Set<EventFeature>

    var body: some View {
        // Using LazyVGrid as a simple wrapping layout
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 120), spacing: Spacing.xs)
        ], spacing: Spacing.xs) {
            ForEach(EventFeature.allCases, id: \.self) { feature in
                let isEnabled = enabledFeatures.contains(feature)
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        if isEnabled {
                            enabledFeatures.remove(feature)
                        } else {
                            enabledFeatures.insert(feature)
                        }
                    }
                    HapticService.buttonTap()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 10))
                            .fontWeight(.semibold)
                        Text(feature.displayName)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .lineLimit(1)
                    }
                    .foregroundStyle(isEnabled ? .white : Color.gatherPrimaryText)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        isEnabled
                            ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                            : AnyShapeStyle(Color.gatherTertiaryBackground)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .scaleEffect(isEnabled ? 1.03 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isEnabled)
                .accessibilityLabel("\(feature.displayName) feature")
                .accessibilityAddTraits(isEnabled ? [.isSelected] : [])
            }
        }
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
                    .font(.caption)
                    .foregroundStyle(Color.accentPurpleFallback.opacity(0.7))
                    .frame(width: 20)
            }
            TextField(placeholder, text: $text)
                .font(GatherFont.body)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
        }
        .padding(Spacing.sm)
        .background(Color.gatherSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
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
                    .font(.system(size: 10))
                Text(label)
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Color.accentPurpleFallback)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
            .background(Color.accentPurpleFallback.opacity(0.1))
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
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(label)
                    .font(GatherFont.callout)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                    : AnyShapeStyle(Color.gatherSecondaryBackground)
            )
            .clipShape(Capsule())
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
                            : AnyShapeStyle(Color.gatherTertiaryBackground)
                    )
                    .clipShape(Circle())

                Text(option.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(isSelected ? Color.accentPurpleFallback : Color.gatherSecondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                isSelected
                    ? Color.accentPurpleFallback.opacity(0.08)
                    : Color.gatherSecondaryBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .strokeBorder(
                        isSelected ? Color.accentPurpleFallback.opacity(0.3) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .accessibilityLabel("\(option.displayName) privacy")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
