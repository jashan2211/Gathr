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
    @State private var locationCountry = ""
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
    @State private var step: CreateStep = .typeAndTitle
    @State private var showDiscardAlert = false

    // Optional: pre-fill from template
    var template: EventTemplate? = nil

    // MARK: - Steps

    enum CreateStep: Int, CaseIterable {
        case typeAndTitle, whenAndWhere, features, settings

        var title: String {
            switch self {
            case .typeAndTitle: return "Type & Title"
            case .whenAndWhere: return "When & Where"
            case .features: return "Features"
            case .settings: return "Privacy & Settings"
            }
        }
    }

    /// Whether the user has entered anything worth confirming before discard.
    private var hasInput: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty ||
        !description.isEmpty ||
        !locationName.isEmpty ||
        heroImage != nil ||
        selectedCategory != .custom
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepProgressBar

                ScrollView {
                    stepContent
                        .id(step)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                navigationBar
            }
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasInput)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if hasInput {
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
                    .accessibilityLabel("Close")
                }
            }
            .confirmationDialog("Discard Event?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You've started creating an event. Your changes won't be saved.")
            }
        }
    }

    // MARK: - Step Progress Bar

    private var stepProgressBar: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                ForEach(CreateStep.allCases, id: \.self) { item in
                    Capsule()
                        .fill(
                            item.rawValue <= step.rawValue
                                ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                                : AnyShapeStyle(Color.gatherSecondaryBackground)
                        )
                        .frame(height: 4)
                }
            }

            HStack {
                Text("Step \(step.rawValue + 1) of \(CreateStep.allCases.count)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.gatherSecondaryText)
                Spacer()
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .typeAndTitle:
            VStack(spacing: 0) {
                EventHeroImagePicker(
                    selectedPhoto: $selectedPhoto,
                    heroImage: $heroImage,
                    selectedCategory: selectedCategory
                )

                VStack(spacing: Spacing.lg) {
                    if showTemplates && template == nil {
                        templateSection
                    }

                    EventCategorySelector(
                        selectedCategory: $selectedCategory,
                        enabledFeatures: $enabledFeatures,
                        headerTitle: "What kind of event?"
                    )

                    EventBasicsSection(
                        title: $title,
                        description: $description
                    )
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.lg)
                .padding(.bottom, 100)
            }

        case .whenAndWhere:
            VStack(spacing: Spacing.lg) {
                EventDateTimeSection(
                    startDate: $startDate,
                    endDate: $endDate,
                    hasEndDate: $hasEndDate,
                    allowPastDates: false
                )
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
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)
            .padding(.bottom, 100)

        case .features:
            VStack(spacing: Spacing.lg) {
                EventFeaturesSection(enabledFeatures: $enabledFeatures)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)
            .padding(.bottom, 100)

        case .settings:
            VStack(spacing: Spacing.lg) {
                EventSettingsSection(
                    privacy: $privacy,
                    guestListVisibility: $guestListVisibility,
                    capacity: $capacity,
                    hasCapacity: $hasCapacity
                )
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)
            .padding(.bottom, 100)
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

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.gatherBackground.opacity(0), Color.gatherBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            VStack(spacing: Spacing.xs) {
                if let hint = stepHint {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption2)
                        Text(hint)
                            .font(.caption2)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .foregroundStyle(Color.gatherSecondaryText)
                    .transition(.opacity)
                }

                HStack(spacing: Spacing.sm) {
                    if step != .typeAndTitle {
                        Button {
                            goBack()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.caption)
                                Text("Back")
                                    .font(GatherFont.callout)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(Color.gatherSecondaryText)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.gatherSecondaryBackground)
                            .clipShape(Capsule())
                        }
                        .disabled(isSubmitting)
                    }

                    Button {
                        primaryAction()
                    } label: {
                        HStack(spacing: 6) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else if step == .settings {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.callout)
                            }
                            Text(step == .settings ? "Create Event" : "Continue")
                                .font(GatherFont.callout)
                                .fontWeight(.bold)
                            if step != .settings && !isSubmitting {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            canProceed
                                ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                                : AnyShapeStyle(Color.gatherSecondaryText.opacity(0.3))
                        )
                        .clipShape(Capsule())
                    }
                    .disabled(!canProceed || isSubmitting)
                }

                if step == .settings {
                    Button {
                        createEvent(asDraft: true)
                    } label: {
                        Text("Save as draft instead")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentPurpleFallback)
                    }
                    .disabled(!isValid || isSubmitting)
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
            .background(Color.gatherBackground)
            .animation(.easeInOut(duration: 0.2), value: stepHint)
        }
    }

    // MARK: - Step Navigation

    private func primaryAction() {
        if step == .settings {
            createEvent(asDraft: false)
        } else {
            goNext()
        }
    }

    private func goNext() {
        guard canProceed, let next = CreateStep(rawValue: step.rawValue + 1) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            step = next
        }
        HapticService.buttonTap()
    }

    private func goBack() {
        guard let previous = CreateStep(rawValue: step.rawValue - 1) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            step = previous
        }
    }

    // MARK: - Validation

    /// The reason the current step can't be completed yet, or `nil` if it's valid.
    private var stepHint: String? {
        hint(for: step)
    }

    private func hint(for step: CreateStep) -> String? {
        switch step {
        case .typeAndTitle:
            let trimmed = title.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return "Add an event name to continue" }
            if trimmed.count > 100 { return "Event name is too long (100 characters max)" }
            return nil
        case .whenAndWhere:
            if startDate <= Date().addingTimeInterval(-300) { return "Choose a start date in the future" }
            if hasEndDate, let end = endDate, end <= startDate { return "End time must be after the start time" }
            if isVirtual, !virtualURL.isEmpty, URL(string: virtualURL) == nil { return "Enter a valid meeting link" }
            return nil
        case .features:
            return nil
        case .settings:
            if hasCapacity, let cap = capacity, cap <= 0 { return "Capacity must be at least 1 guest" }
            return nil
        }
    }

    /// Whether every step is valid — required before the event can be created.
    private var isValid: Bool {
        CreateStep.allCases.allSatisfy { hint(for: $0) == nil }
    }

    /// Whether the primary button is enabled: the current step for Continue,
    /// or all steps for the final Create.
    private var canProceed: Bool {
        step == .settings ? isValid : (hint(for: step) == nil)
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
                country: locationCountry.isEmpty ? nil : locationCountry,
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

        modelContext.safeSave()
        FirestoreService.shared.pushEvent(event)

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
