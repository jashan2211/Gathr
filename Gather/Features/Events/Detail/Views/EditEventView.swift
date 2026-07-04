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
    @State private var locationCountry: String
    @State private var locationLatitude: Double?
    @State private var locationLongitude: Double?
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
    @State private var showDiscardAlert = false

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
        _locationCountry = State(initialValue: event.location?.country ?? "")
        _locationLatitude = State(initialValue: event.location?.latitude)
        _locationLongitude = State(initialValue: event.location?.longitude)
        _isVirtual = State(initialValue: event.location?.isVirtual ?? false)
        _virtualURL = State(initialValue: event.location?.virtualURL?.absoluteString ?? "")
        _capacity = State(initialValue: event.capacity)
        _hasCapacity = State(initialValue: event.capacity != nil)
        _privacy = State(initialValue: event.privacy)
        _guestListVisibility = State(initialValue: event.guestListVisibility)
        _selectedCategory = State(initialValue: event.category)
        _enabledFeatures = State(initialValue: event.enabledFeatures)
    }

    /// Whether user has made edits compared to original event values.
    /// Split into grouped sub-expressions so the type-checker stays fast — a
    /// single 20-term `||` chain trips SwiftUI's expression-complexity limit.
    private var hasUnsavedChanges: Bool {
        basicsChanged || locationChanged || settingsChanged || heroImage != nil
    }

    private var basicsChanged: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines) != event.title ||
        description != (event.eventDescription ?? "") ||
        startDate != event.startDate ||
        endDate != event.endDate ||
        hasEndDate != (event.endDate != nil) ||
        selectedCategory != event.category ||
        enabledFeatures != event.enabledFeatures
    }

    private var locationChanged: Bool {
        locationName != (event.location?.name ?? "") ||
        locationAddress != (event.location?.address ?? "") ||
        locationCity != (event.location?.city ?? "") ||
        locationState != (event.location?.state ?? "") ||
        locationCountry != (event.location?.country ?? "") ||
        // Coordinates matter on their own: re-picking a venue whose name/address
        // resolve to the same strings still moves the pin, and that edit must count.
        locationLatitude != event.location?.latitude ||
        locationLongitude != event.location?.longitude ||
        isVirtual != (event.location?.isVirtual ?? false) ||
        virtualURL != (event.location?.virtualURL?.absoluteString ?? "")
    }

    private var settingsChanged: Bool {
        privacy != event.privacy ||
        guestListVisibility != event.guestListVisibility ||
        capacity != event.capacity ||
        hasCapacity != (event.capacity != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero image with category tint
                    EventHeroImagePicker(
                        selectedPhoto: $selectedPhoto,
                        heroImage: $heroImage,
                        selectedCategory: selectedCategory,
                        existingImageURL: event.heroMediaURL
                    )
                    .bouncyAppear()

                    VStack(spacing: Spacing.lg) {
                        // Category pills
                        EventCategorySelector(
                            selectedCategory: $selectedCategory,
                            enabledFeatures: $enabledFeatures,
                            headerTitle: "Event Type",
                            // Recategorizing an existing event must never wipe
                            // the host's curated feature set.
                            resetsFeaturesOnChange: false
                        )
                        .bouncyAppear(delay: 0.05)

                        // Event details
                        EventBasicsSection(
                            title: $title,
                            description: $description
                        )
                        .bouncyAppear(delay: 0.08)

                        // Features
                        EventFeaturesSection(
                            enabledFeatures: $enabledFeatures
                        )
                        .bouncyAppear(delay: 0.11)

                        // When
                        EventDateTimeSection(
                            startDate: $startDate,
                            endDate: $endDate,
                            hasEndDate: $hasEndDate,
                            allowPastDates: true
                        )
                        .bouncyAppear(delay: 0.14)

                        // Where
                        EventLocationSection(
                            isVirtual: $isVirtual,
                            virtualURL: $virtualURL,
                            locationName: $locationName,
                            locationAddress: $locationAddress,
                            locationCity: $locationCity,
                            locationState: $locationState,
                            locationCountry: $locationCountry,
                            locationLatitude: $locationLatitude,
                            locationLongitude: $locationLongitude
                        )
                        .bouncyAppear(delay: 0.17)

                        // Settings
                        EventSettingsSection(
                            privacy: $privacy,
                            guestListVisibility: $guestListVisibility,
                            capacity: $capacity,
                            hasCapacity: $hasCapacity
                        )
                        .bouncyAppear(delay: 0.20)

                        // Danger zone
                        dangerZone
                            .bouncyAppear(delay: 0.23)
                    }
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.top, Spacing.lg)
                }
            }
            .background(Color.gatherCanvas.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                saveButtonBar
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if hasUnsavedChanges {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
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
            .confirmationDialog("Discard Changes?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
        }
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
        .surfaceCard(cornerRadius: CornerRadius.lg)
    }

    // MARK: - Floating Save Button

    private var saveButtonBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.gatherCanvas.opacity(0), Color.gatherCanvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            VStack(spacing: Spacing.sm) {
                // Why Save is disabled — the invalid field can be several
                // screens up, so say it right next to the greyed-out button.
                if let hint = validationHint {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                        Text(hint)
                            .font(.system(.footnote, weight: .medium))
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .foregroundStyle(Color.warmCoral)
                    .transition(.opacity)
                }

                HStack(spacing: Spacing.sm) {
                    // Discard changes
                    Button {
                        if hasUnsavedChanges {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
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
                        .frame(height: Layout.buttonHeight)
                        .background(Color.gatherElevated)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.gatherSeparator.opacity(0.6), lineWidth: 1)
                        )
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
                        .frame(height: Layout.buttonHeight)
                        .background(
                            isValid
                                ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                                : AnyShapeStyle(Color.gatherSecondaryText.opacity(0.3))
                        )
                        .clipShape(Capsule())
                    }
                    .disabled(!isValid || isSubmitting)
                    .scaleEffect(isValid ? 1.0 : 0.97)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isValid)
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, Spacing.md)
            .background(Color.gatherCanvas)
            .animation(.easeInOut(duration: 0.2), value: validationHint)
        }
    }

    // MARK: - Validation

    /// The first problem blocking Save, phrased like the create wizard's
    /// hints, or `nil` when everything is valid.
    private var validationHint: String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty { return "Add an event name" }
        if trimmedTitle.count > 100 { return "Event name is too long (100 characters max)" }
        if hasEndDate, let end = endDate, end <= startDate { return "End time must be after the start time" }
        if hasCapacity {
            guard let cap = capacity else { return "Enter a capacity, or turn off the limit" }
            if cap <= 0 { return "Capacity must be at least 1 guest" }
        }
        if isVirtual, !virtualURL.isEmpty, !EventFormValidation.isValidMeetingLink(virtualURL) {
            return "Enter a valid meeting link"
        }
        return nil
    }

    private var isValid: Bool { validationHint == nil }

    // MARK: - Save Changes

    private func saveChanges() {
        isSubmitting = true

        // Update event properties
        event.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.eventDescription = description.isEmpty ? nil : description
        event.startDate = startDate
        event.endDate = hasEndDate ? endDate : nil
        event.privacy = privacy
        event.guestListVisibility = guestListVisibility
        event.capacity = hasCapacity ? capacity : nil
        event.category = selectedCategory
        event.enabledFeatures = enabledFeatures
        event.updatedAt = Date()

        // Save hero image if changed
        if heroImage != nil, let selectedPhoto {
            Task {
                if let data = try? await selectedPhoto.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    // Compress and save to documents
                    let maxWidth: CGFloat = 1200
                    let scale = min(1.0, maxWidth / uiImage.size.width)
                    let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
                    let renderer = UIGraphicsImageRenderer(size: newSize)
                    let resized = renderer.image { _ in
                        uiImage.draw(in: CGRect(origin: .zero, size: newSize))
                    }
                    if let jpegData = resized.jpegData(compressionQuality: 0.8),
                       let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let filename = "\(event.id.uuidString)_hero.jpg"
                        let fileURL = docsDir.appendingPathComponent(filename)
                        try? jpegData.write(to: fileURL)
                        await MainActor.run {
                            event.heroMediaURL = fileURL
                            modelContext.safeSave()
                        }
                    }
                }
            }
        }

        // Build location
        if isVirtual {
            // Preserve the explicit "Virtual" choice even when the link is
            // empty — the event stays virtual; the link can be added later.
            event.location = EventLocation(
                name: "Virtual Event",
                virtualURL: virtualURL.isEmpty ? nil : URL(string: virtualURL)
            )
        } else if !locationName.isEmpty {
            event.location = EventLocation(
                name: locationName,
                address: locationAddress.isEmpty ? nil : locationAddress,
                city: locationCity.isEmpty ? nil : locationCity,
                state: locationState.isEmpty ? nil : locationState,
                country: locationCountry.isEmpty ? nil : locationCountry,
                latitude: locationLatitude,
                longitude: locationLongitude
            )
        } else {
            event.location = nil
        }

        modelContext.safeSave()
        FirestoreService.shared.pushEvent(event)

        // Haptic feedback
        HapticService.success()

        isSubmitting = false
        dismiss()
    }

    // MARK: - Delete Event

    private func deleteEvent() {
        let eventId = event.id
        modelContext.delete(event)
        modelContext.safeSave()
        FirestoreService.shared.deleteEvent(id: eventId)

        HapticService.warning()

        dismiss()
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
