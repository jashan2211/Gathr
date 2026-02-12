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
    @State private var locationLatitude: Double?
    @State private var locationLongitude: Double?
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
            ScrollView {
                VStack(spacing: 0) {
                    // Hero image picker with category tint
                    EventHeroImagePicker(
                        selectedPhoto: $selectedPhoto,
                        heroImage: $heroImage,
                        selectedCategory: selectedCategory
                    )
                    .bouncyAppear()

                    VStack(spacing: Spacing.lg) {
                        // Template selector
                        if showTemplates && template == nil {
                            templateSection
                                .bouncyAppear(delay: 0.05)
                        }

                        // Category pills
                        EventCategorySelector(
                            selectedCategory: $selectedCategory,
                            enabledFeatures: $enabledFeatures,
                            headerTitle: "What kind of event?"
                        )
                        .bouncyAppear(delay: 0.08)

                        // Event details
                        EventBasicsSection(
                            title: $title,
                            description: $description
                        )
                        .bouncyAppear(delay: 0.11)

                        // Features as toggleable chips
                        EventFeaturesSection(
                            enabledFeatures: $enabledFeatures
                        )
                        .bouncyAppear(delay: 0.14)

                        // When
                        EventDateTimeSection(
                            startDate: $startDate,
                            endDate: $endDate,
                            hasEndDate: $hasEndDate,
                            allowPastDates: false
                        )
                        .bouncyAppear(delay: 0.17)

                        // Where
                        EventLocationSection(
                            isVirtual: $isVirtual,
                            virtualURL: $virtualURL,
                            locationName: $locationName,
                            locationAddress: $locationAddress,
                            locationCity: $locationCity,
                            locationState: $locationState,
                            locationLatitude: $locationLatitude,
                            locationLongitude: $locationLongitude
                        )
                        .bouncyAppear(delay: 0.20)

                        // Settings
                        EventSettingsSection(
                            privacy: $privacy,
                            guestListVisibility: $guestListVisibility,
                            capacity: $capacity,
                            hasCapacity: $hasCapacity
                        )
                        .bouncyAppear(delay: 0.23)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.lg)
                }
            }
            .safeAreaInset(edge: .bottom) {
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
                        .padding(.vertical, Spacing.xxs)
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
        HapticService.mediumImpact()
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

    // MARK: - Validation

    private var isValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty && trimmedTitle.count <= 100 else { return false }
        guard startDate > Date().addingTimeInterval(-300) else { return false }
        if hasEndDate, let end = endDate, end <= startDate { return false }
        if hasCapacity, let cap = capacity, cap <= 0 { return false }
        if isVirtual && !virtualURL.isEmpty {
            guard URL(string: virtualURL) != nil else { return false }
        }
        return true
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
                state: locationState.isEmpty ? nil : locationState,
                latitude: locationLatitude,
                longitude: locationLongitude
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

        // Save hero image if selected
        if let selectedPhoto {
            Task {
                if let data = try? await selectedPhoto.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    let maxWidth: CGFloat = 1200
                    let scale = min(1.0, maxWidth / uiImage.size.width)
                    let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
                    let renderer = UIGraphicsImageRenderer(size: newSize)
                    let resized = renderer.image { _ in
                        uiImage.draw(in: CGRect(origin: .zero, size: newSize))
                    }
                    if let jpegData = resized.jpegData(compressionQuality: 0.8) {
                        let filename = "\(event.id.uuidString)_hero.jpg"
                        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
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

        modelContext.safeSave()

        // Haptic feedback
        HapticService.success()

        isSubmitting = false
        dismiss()
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
