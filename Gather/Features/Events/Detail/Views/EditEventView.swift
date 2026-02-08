import SwiftUI
import SwiftData
import PhotosUI

struct EditEventView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var event: Event

    // Form state
    @State private var title: String
    @State private var description: String
    @State private var startDate: Date
    @State private var endDate: Date?
    @State private var hasEndDate: Bool
    @State private var locationName: String
    @State private var locationAddress: String
    @State private var locationCity: String
    @State private var locationState: String
    @State private var isVirtual: Bool
    @State private var virtualURL: String
    @State private var capacity: Int?
    @State private var hasCapacity: Bool
    @State private var privacy: EventPrivacy
    @State private var guestListVisibility: GuestListVisibility
    @State private var selectedCategory: EventCategory
    @State private var enabledFeatures: Set<EventFeature>

    // Image picker
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var heroImage: Image?

    // UI state
    @State private var isSubmitting = false
    @State private var showDeleteConfirmation = false
    @State private var hasChanges = false

    init(event: Event) {
        self.event = event
        _title = State(initialValue: event.title)
        _description = State(initialValue: event.eventDescription ?? "")
        _startDate = State(initialValue: event.startDate)
        _endDate = State(initialValue: event.endDate)
        _hasEndDate = State(initialValue: event.endDate != nil)
        _locationName = State(initialValue: event.location?.name ?? "")
        _locationAddress = State(initialValue: event.location?.address ?? "")
        _locationCity = State(initialValue: event.location?.city ?? "")
        _locationState = State(initialValue: event.location?.state ?? "")
        _isVirtual = State(initialValue: event.location?.isVirtual ?? false)
        _virtualURL = State(initialValue: event.location?.virtualURL?.absoluteString ?? "")
        _capacity = State(initialValue: event.capacity)
        _hasCapacity = State(initialValue: event.capacity != nil)
        _privacy = State(initialValue: event.privacy)
        _guestListVisibility = State(initialValue: event.guestListVisibility)
        _selectedCategory = State(initialValue: event.category)
        _enabledFeatures = State(initialValue: event.enabledFeatures ?? EventCategory.custom.defaultFeatures)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero image with category tint
                        heroImagePicker
                            .bouncyAppear()

                        VStack(spacing: Spacing.lg) {
                            // Category pills
                            categorySection
                                .bouncyAppear(delay: 0.05)

                            // Event details
                            basicsSection
                                .bouncyAppear(delay: 0.08)

                            // Features
                            featuresSection
                                .bouncyAppear(delay: 0.11)

                            // When
                            whenSection
                                .bouncyAppear(delay: 0.14)

                            // Where
                            whereSection
                                .bouncyAppear(delay: 0.17)

                            // Settings
                            settingsSection
                                .bouncyAppear(delay: 0.20)

                            // Danger zone
                            dangerZone
                                .bouncyAppear(delay: 0.23)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.lg)
                        .padding(.bottom, 100)
                    }
                }

                // Floating save button
                saveButtonBar
            }
            .navigationTitle("Edit Event")
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
            .alert("Delete Event?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteEvent()
                }
            } message: {
                Text("This action cannot be undone. All guest RSVPs and event data will be permanently deleted.")
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
                } else if event.heroMediaURL != nil {
                    AsyncImage(url: event.heroMediaURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    } placeholder: {
                        categoryGradientPlaceholder
                    }
                } else {
                    categoryGradientPlaceholder
                }

                // Camera button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Change Cover")
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
    }

    private var categoryGradientPlaceholder: some View {
        ZStack {
            LinearGradient.categoryGradientVibrant(for: selectedCategory)
                .opacity(0.8)

            Text(selectedCategory.emoji)
                .font(.system(size: 80))
                .opacity(0.15)
                .rotationEffect(.degrees(-15))

            LinearGradient(
                colors: [.white.opacity(0.1), .clear, .white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .frame(height: 200)
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            editSectionHeader(title: "Event Type", icon: "sparkles")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(EventCategory.allCases, id: \.self) { category in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = category
                                enabledFeatures = category.defaultFeatures
                            }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        } label: {
                            HStack(spacing: 6) {
                                Text(category.emoji)
                                    .font(.callout)
                                Text(category.displayName)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(selectedCategory == category ? .white : Color.gatherPrimaryText)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                selectedCategory == category
                                    ? AnyShapeStyle(LinearGradient.categoryGradientVibrant(for: category))
                                    : AnyShapeStyle(Color.gatherSecondaryBackground)
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        selectedCategory == category ? Color.clear : Color.gatherSeparator,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .scaleEffect(selectedCategory == category ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedCategory == category)
                    }
                }
            }
        }
    }

    // MARK: - Basics Section

    private var basicsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            editSectionHeader(title: "Event Details", icon: "textformat")

            // Title
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

            // Description
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

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            editSectionHeader(title: "Features", icon: "slider.horizontal.3")

            Text("Tap to toggle what you need")
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)

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
        .padding(Spacing.md)
        .background(Color.gatherSecondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    // MARK: - When Section

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            editSectionHeader(title: "When", icon: "calendar.badge.clock")

            // Quick date chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    EditQuickDateChip(label: "Tonight", icon: "moon.stars.fill") {
                        let tonight = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
                        withAnimation { startDate = tonight > Date() ? tonight : tonight.addingTimeInterval(86400) }
                    }
                    EditQuickDateChip(label: "Tomorrow", icon: "sunrise.fill") {
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                        let tomorrowEvening = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow) ?? tomorrow
                        withAnimation { startDate = tomorrowEvening }
                    }
                    EditQuickDateChip(label: "This Weekend", icon: "sparkles") {
                        let calendar = Calendar.current
                        let today = Date()
                        let weekday = calendar.component(.weekday, from: today)
                        let daysToSaturday = (7 - weekday) % 7
                        let saturday = calendar.date(byAdding: .day, value: daysToSaturday == 0 ? 7 : daysToSaturday, to: today) ?? today
                        let saturdayEvening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: saturday) ?? saturday
                        withAnimation { startDate = saturdayEvening }
                    }
                    EditQuickDateChip(label: "Next Week", icon: "calendar") {
                        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                        let nextWeekEvening = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: nextWeek) ?? nextWeek
                        withAnimation { startDate = nextWeekEvening }
                    }
                }
            }

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
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .tint(Color.accentPurpleFallback)
                }
                .padding(Spacing.sm)
                .background(Color.gatherSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

                // End
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
            editSectionHeader(title: "Where", icon: "mappin.and.ellipse")

            // In Person / Virtual toggle buttons
            HStack(spacing: Spacing.xs) {
                EditLocationTypeButton(
                    label: "In Person",
                    icon: "building.2.fill",
                    isSelected: !isVirtual
                ) {
                    withAnimation(.spring(response: 0.3)) { isVirtual = false }
                }
                EditLocationTypeButton(
                    label: "Virtual",
                    icon: "video.fill",
                    isSelected: isVirtual
                ) {
                    withAnimation(.spring(response: 0.3)) { isVirtual = true }
                }
            }

            if isVirtual {
                EditStyledTextField(
                    placeholder: "Paste meeting link (Zoom, Meet, etc.)",
                    text: $virtualURL,
                    icon: "link",
                    keyboardType: .URL,
                    autocapitalization: .never
                )
            } else {
                VStack(spacing: Spacing.xs) {
                    EditStyledTextField(
                        placeholder: "Venue name",
                        text: $locationName,
                        icon: "mappin"
                    )
                    EditStyledTextField(
                        placeholder: "Address (optional)",
                        text: $locationAddress,
                        icon: "map"
                    )
                    HStack(spacing: Spacing.xs) {
                        EditStyledTextField(
                            placeholder: "City",
                            text: $locationCity,
                            icon: "building.2"
                        )
                        EditStyledTextField(
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
            editSectionHeader(title: "Settings", icon: "gearshape.fill")

            // Privacy cards
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("WHO CAN SEE THIS EVENT?")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .tracking(0.5)

                HStack(spacing: Spacing.xs) {
                    EditPrivacyCard(
                        option: .publicEvent,
                        icon: "globe",
                        isSelected: privacy == .publicEvent
                    ) { withAnimation(.spring(response: 0.3)) { privacy = .publicEvent } }

                    EditPrivacyCard(
                        option: .unlisted,
                        icon: "link",
                        isSelected: privacy == .unlisted
                    ) { withAnimation(.spring(response: 0.3)) { privacy = .unlisted } }

                    EditPrivacyCard(
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

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.gatherError)
                Text("Danger Zone")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherError)
            }

            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "trash.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.gatherError)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete Event")
                            .font(GatherFont.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.gatherError)
                        Text("Permanently remove this event and all data")
                            .font(.caption2)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .padding(Spacing.sm)
                .background(Color.gatherError.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .strokeBorder(Color.gatherError.opacity(0.15), lineWidth: 1)
                )
            }
        }
        .padding(Spacing.md)
        .background(Color.gatherSecondaryBackground.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
    }

    // MARK: - Floating Save Button

    private var saveButtonBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.gatherBackground.opacity(0), Color.gatherBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            HStack(spacing: Spacing.sm) {
                // Discard changes
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.caption)
                        Text("Cancel")
                            .font(GatherFont.callout)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.gatherSecondaryText)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(Capsule())
                }

                // Save changes
                Button {
                    saveChanges()
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
                        Text("Save Changes")
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

    private func editSectionHeader(title: String, icon: String) -> some View {
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

    // MARK: - Save Changes

    private func saveChanges() {
        isSubmitting = true

        // Update event properties
        event.title = title.trimmingCharacters(in: .whitespaces)
        event.eventDescription = description.isEmpty ? nil : description
        event.startDate = startDate
        event.endDate = hasEndDate ? endDate : nil
        event.privacy = privacy
        event.guestListVisibility = guestListVisibility
        event.capacity = hasCapacity ? capacity : nil
        event.category = selectedCategory
        event.enabledFeatures = enabledFeatures
        event.updatedAt = Date()

        // Build location
        if isVirtual, !virtualURL.isEmpty {
            event.location = EventLocation(name: "Virtual Event", virtualURL: URL(string: virtualURL))
        } else if !locationName.isEmpty {
            event.location = EventLocation(
                name: locationName,
                address: locationAddress.isEmpty ? nil : locationAddress,
                city: locationCity.isEmpty ? nil : locationCity,
                state: locationState.isEmpty ? nil : locationState
            )
        } else {
            event.location = nil
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        isSubmitting = false
        dismiss()
    }

    // MARK: - Delete Event

    private func deleteEvent() {
        modelContext.delete(event)
        try? modelContext.save()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        dismiss()
    }
}

// MARK: - Edit Quick Date Chip

private struct EditQuickDateChip: View {
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

// MARK: - Edit Location Type Button

private struct EditLocationTypeButton: View {
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

// MARK: - Edit Styled Text Field

private struct EditStyledTextField: View {
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

// MARK: - Edit Privacy Card

private struct EditPrivacyCard: View {
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

// MARK: - Preview

#Preview {
    EditEventView(event: Event(
        title: "Sample Event",
        eventDescription: "A sample event for preview",
        startDate: Date()
    ))
}
