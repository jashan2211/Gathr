import SwiftUI
import SwiftData
import PhotosUI

struct CreateEventView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager

    // Form state
    @State private var title = ""
    @State private var description = ""
    @State private var startDate = Date().addingTimeInterval(3600)
    @State private var endDate: Date?
    @State private var hasEndDate = false
    @State private var locationName = ""
    @State private var locationAddress = ""
    @State private var locationCity = ""
    @State private var locationState = ""
    @State private var isVirtual = false
    @State private var virtualURL = ""
    @State private var capacity: Int?
    @State private var hasCapacity = false
    @State private var privacy: EventPrivacy = .inviteOnly
    @State private var guestListVisibility: GuestListVisibility = .visible

    // Category and features
    @State private var selectedCategory: EventCategory = .custom
    @State private var enabledFeatures: Set<EventFeature> = EventCategory.custom.defaultFeatures

    // Image picker
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var heroImage: Image?

    // UI state
    @State private var isSubmitting = false
    @State private var showTemplates = true
    @State private var currentStep = 0

    // Optional: pre-fill from template
    var template: EventTemplate? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero image picker with category tint
                        heroImagePicker
                            .bouncyAppear()

                        VStack(spacing: Spacing.lg) {
                            // Template selector
                            if showTemplates && template == nil {
                                templateSection
                                    .bouncyAppear(delay: 0.05)
                            }

                            // Category pills
                            categorySection
                                .bouncyAppear(delay: 0.08)

                            // Event details
                            basicsSection
                                .bouncyAppear(delay: 0.11)

                            // Features as toggleable chips
                            featuresSection
                                .bouncyAppear(delay: 0.14)

                            // When
                            whenSection
                                .bouncyAppear(delay: 0.17)

                            // Where
                            whereSection
                                .bouncyAppear(delay: 0.20)

                            // Settings
                            settingsSection
                                .bouncyAppear(delay: 0.23)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.lg)
                        .padding(.bottom, 100) // Space for floating button
                    }
                }

                // Floating create button
                createButtonBar
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }
            }
        }
    }

    // MARK: - Hero Image Picker

    private var heroImagePicker: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            ZStack {
                if let heroImage = heroImage {
                    heroImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                        .overlay {
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.3)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        }
                } else {
                    // Vibrant category-tinted placeholder
                    ZStack {
                        LinearGradient.categoryGradientVibrant(for: selectedCategory)
                            .opacity(0.8)

                        // Floating emoji watermark
                        Text(selectedCategory.emoji)
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
                    .frame(height: 200)
                }

                // Camera button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: heroImage == nil ? "camera.fill" : "arrow.triangle.2.circlepath.camera.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(heroImage == nil ? "Add Cover" : "Change")
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
            .frame(height: 200)
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
        .onChange(of: selectedCategory) { _, _ in
            // Animate category change on hero
        }
    }

    // MARK: - Template Section

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                        .foregroundStyle(Color.accentPurpleFallback)
                    Text("Quick Start")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3)) { showTemplates = false }
                } label: {
                    Text("Skip")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 4)
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(Capsule())
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(EventTemplate.allTemplates) { tmpl in
                        Button {
                            applyTemplate(tmpl)
                        } label: {
                            VStack(spacing: Spacing.xs) {
                                ZStack {
                                    LinearGradient.categoryGradientVibrant(for: tmpl.category)
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

                                    Image(systemName: tmpl.icon)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                }

                                Text(tmpl.name)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.gatherPrimaryText)
                                    .lineLimit(1)
                            }
                            .frame(width: 76)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.gatherSecondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    private func applyTemplate(_ tmpl: EventTemplate) {
        withAnimation(.spring(response: 0.3)) {
            selectedCategory = tmpl.category
            enabledFeatures = tmpl.suggestedFeatures
            description = tmpl.suggestedDescription
            privacy = tmpl.suggestedPrivacy
            showTemplates = false
        }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(title: "What kind of event?", icon: "sparkles")

            // Horizontal scrolling category chips with emoji + gradient
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(EventCategory.allCases, id: \.self) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = category
                                enabledFeatures = category.defaultFeatures
                            }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(title: "Features", icon: "slider.horizontal.3")

            Text("Tap to toggle what you need")
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)

            // Feature chips in a wrapping flow layout
            WrappingFeatureChips(
                enabledFeatures: $enabledFeatures
            )
        }
        .padding(Spacing.md)
        .background(Color.gatherSecondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    // MARK: - Basics Section

    private var basicsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(title: "Event Details", icon: "textformat")

            // Title field with gradient accent
            VStack(alignment: .leading, spacing: 6) {
                Text("EVENT NAME")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .tracking(0.5)

                TextField("Give your event a vibe...", text: $title)
                    .font(GatherFont.title3)
                    .fontWeight(.semibold)
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

    // MARK: - When Section

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(title: "When", icon: "calendar.badge.clock")

            // Quick date chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    QuickDateChip(label: "Tonight", icon: "moon.stars.fill") {
                        let tonight = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
                        withAnimation { startDate = tonight > Date() ? tonight : tonight.addingTimeInterval(86400) }
                    }
                    QuickDateChip(label: "Tomorrow", icon: "sunrise.fill") {
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                        let tomorrowEvening = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow) ?? tomorrow
                        withAnimation { startDate = tomorrowEvening }
                    }
                    QuickDateChip(label: "This Weekend", icon: "sparkles") {
                        let calendar = Calendar.current
                        let today = Date()
                        let weekday = calendar.component(.weekday, from: today)
                        let daysToSaturday = (7 - weekday) % 7
                        let saturday = calendar.date(byAdding: .day, value: daysToSaturday == 0 ? 7 : daysToSaturday, to: today) ?? today
                        let saturdayEvening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: saturday) ?? saturday
                        withAnimation { startDate = saturdayEvening }
                    }
                    QuickDateChip(label: "Next Week", icon: "calendar") {
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
                    DatePicker(
                        "",
                        selection: $startDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .tint(Color.accentPurpleFallback)
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

    // MARK: - Where Section

    private var whereSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(title: "Where", icon: "mappin.and.ellipse")

            // Virtual / In-Person toggle
            HStack(spacing: Spacing.xs) {
                LocationTypeButton(
                    label: "In Person",
                    icon: "building.2.fill",
                    isSelected: !isVirtual
                ) {
                    withAnimation(.spring(response: 0.3)) { isVirtual = false }
                }
                LocationTypeButton(
                    label: "Virtual",
                    icon: "video.fill",
                    isSelected: isVirtual
                ) {
                    withAnimation(.spring(response: 0.3)) { isVirtual = true }
                }
            }

            if isVirtual {
                StyledTextField(
                    placeholder: "Paste meeting link (Zoom, Meet, etc.)",
                    text: $virtualURL,
                    icon: "link",
                    keyboardType: .URL,
                    autocapitalization: .never
                )
            } else {
                VStack(spacing: Spacing.xs) {
                    StyledTextField(
                        placeholder: "Venue name",
                        text: $locationName,
                        icon: "mappin"
                    )
                    StyledTextField(
                        placeholder: "Address (optional)",
                        text: $locationAddress,
                        icon: "map"
                    )
                    HStack(spacing: Spacing.xs) {
                        StyledTextField(
                            placeholder: "City",
                            text: $locationCity,
                            icon: "building.2"
                        )
                        StyledTextField(
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
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader(title: "Settings", icon: "gearshape.fill")

            // Privacy cards
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("WHO CAN SEE THIS EVENT?")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .tracking(0.5)

                HStack(spacing: Spacing.xs) {
                    PrivacyOptionCard(
                        option: .publicEvent,
                        icon: "globe",
                        isSelected: privacy == .publicEvent
                    ) { withAnimation(.spring(response: 0.3)) { privacy = .publicEvent } }

                    PrivacyOptionCard(
                        option: .unlisted,
                        icon: "link",
                        isSelected: privacy == .unlisted
                    ) { withAnimation(.spring(response: 0.3)) { privacy = .unlisted } }

                    PrivacyOptionCard(
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

                HStack(spacing: Spacing.xs) {
                    ForEach(GuestListVisibility.allCases, id: \.self) { option in
                        Button {
                            withAnimation(.spring(response: 0.3)) { guestListVisibility = option }
                        } label: {
                            Text(option.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
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

    // MARK: - Floating Create Button

    private var createButtonBar: some View {
        VStack(spacing: 0) {
            // Top fade
            LinearGradient(
                colors: [Color.gatherBackground.opacity(0), Color.gatherBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            HStack(spacing: Spacing.sm) {
                // Save as Draft
                Button {
                    createEvent(asDraft: true)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill")
                            .font(.caption)
                        Text("Draft")
                            .font(GatherFont.callout)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.accentPurpleFallback)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.accentPurpleFallback.opacity(0.1))
                    .clipShape(Capsule())
                }
                .disabled(!isValid || isSubmitting)
                .opacity(!isValid ? 0.4 : 1)

                // Create Event
                Button {
                    createEvent(asDraft: false)
                } label: {
                    HStack(spacing: 6) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.callout)
                        }
                        Text("Create Event")
                            .font(GatherFont.callout)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        isValid
                            ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                            : AnyShapeStyle(Color.gatherSecondaryText.opacity(0.3))
                    )
                    .clipShape(Capsule())
                }
                .disabled(!isValid || isSubmitting)
                .scaleEffect(isValid ? 1.0 : 0.97)
                .animation(.spring(response: 0.3), value: isValid)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
            .background(Color.gatherBackground)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String) -> some View {
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

    // MARK: - Validation

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Create Event

    private func createEvent(asDraft: Bool = false) {
        isSubmitting = true

        // Build location
        var location: EventLocation?
        if isVirtual, !virtualURL.isEmpty {
            location = EventLocation(name: "Virtual Event", virtualURL: URL(string: virtualURL))
        } else if !locationName.isEmpty {
            location = EventLocation(
                name: locationName,
                address: locationAddress.isEmpty ? nil : locationAddress,
                city: locationCity.isEmpty ? nil : locationCity,
                state: locationState.isEmpty ? nil : locationState
            )
        }

        // Create event
        let event = Event(
            title: title.trimmingCharacters(in: .whitespaces),
            eventDescription: description.isEmpty ? nil : description,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            location: location,
            capacity: hasCapacity ? capacity : nil,
            privacy: privacy,
            guestListVisibility: guestListVisibility,
            category: selectedCategory,
            enabledFeatures: enabledFeatures,
            hostId: authManager.currentUser?.id,
            isDraft: asDraft
        )

        // Save to SwiftData
        modelContext.insert(event)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        isSubmitting = false
        dismiss()
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
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
    }
}

// MARK: - Wrapping Feature Chips

private struct WrappingFeatureChips: View {
    @Binding var enabledFeatures: Set<EventFeature>

    var body: some View {
        // Using LazyVGrid as a simple wrapping layout
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 100), spacing: Spacing.xs)
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
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
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
            }
        }
    }
}

// MARK: - Quick Date Chip

private struct QuickDateChip: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
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
    }
}

// MARK: - Location Type Button

private struct LocationTypeButton: View {
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
    }
}

// MARK: - Styled Text Field

private struct StyledTextField: View {
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
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
        }
        .padding(Spacing.sm)
        .background(Color.gatherSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Privacy Option Card

private struct PrivacyOptionCard: View {
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
    }
}

// MARK: - Form Section (kept for backward compat)

struct FormSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(Color.accentPurpleFallback)

                Text(title)
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)
            }

            // Content
            content
        }
        .padding()
        .background(Color.gatherSecondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
    }
}

// MARK: - Preview

#Preview {
    CreateEventView()
        .environmentObject(AuthManager())
}
