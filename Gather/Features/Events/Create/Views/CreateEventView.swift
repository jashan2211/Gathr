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
    @State private var startDate = CreateEventView.defaultStartDate()
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
    /// Honours the "Default Event Privacy" preference set in Profile.
    @AppStorage("defaultPrivacy") private var defaultPrivacyRaw = "inviteOnly"
    @State private var didSeedPrivacy = false
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
    @State private var showCoverDetails = false
    /// Briefly names the applied template so the tap visibly did something.
    @State private var appliedTemplateName: String?
    @FocusState private var titleFocused: Bool

    // Optional: pre-fill from template
    var template: EventTemplate? = nil

    // MARK: - Steps

    enum CreateStep: Int, CaseIterable {
        // Features used to be a step of their own — one grid card the common
        // path just tapped Continue through. It now lives at the top of the
        // final step, so the wizard is 3 steps instead of 4.
        case typeAndTitle, whenAndWhere, settings

        var title: String {
            switch self {
            case .typeAndTitle: return "Type & Title"
            case .whenAndWhere: return "When & Where"
            case .settings: return "Features & Settings"
            }
        }
    }

    /// Whether the user has entered anything worth confirming before discard.
    private var hasInput: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !description.isEmpty ||
        !locationName.isEmpty ||
        heroImage != nil ||
        selectedCategory != .custom
    }

    /// Drafts only need a name — everything else can be filled in later, which
    /// is the whole point of a draft.
    private var canSaveDraft: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            .background(Color.gatherCanvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                navigationBar
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Apply the user's default-privacy preference once, before they've
                // touched anything (a chosen template or manual change wins after).
                if !didSeedPrivacy {
                    privacy = EventPrivacy(rawValue: defaultPrivacyRaw) ?? .inviteOnly
                    didSeedPrivacy = true
                }
            }
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
                if canSaveDraft {
                    Button("Save as Draft") { createEvent(asDraft: true) }
                }
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text(
                    canSaveDraft
                        ? "Save your progress as a draft, or discard it."
                        : "You've started creating an event. Your changes won't be saved."
                )
            }
        }
    }

    // MARK: - Step Progress Bar

    private var stepProgressBar: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                ForEach(CreateStep.allCases, id: \.self) { item in
                    Capsule()
                        .fill(
                            item.rawValue <= step.rawValue
                                ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                                : AnyShapeStyle(Color.gatherElevated)
                        )
                        .frame(height: 5)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("STEP \(step.rawValue + 1) OF \(CreateStep.allCases.count)")
                    .gatherEyebrow()
                    .foregroundStyle(Color.gatherSecondaryText)
                Text(step.title)
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(Color.gatherPrimaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(Color.gatherCanvas)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .typeAndTitle:
            // Minimum-ask step: template shortcut, category, title.
            // Cover photo + description live in a collapsed optional section.
            VStack(spacing: Spacing.md) {
                if showTemplates && template == nil {
                    templateSection
                } else if let appliedTemplateName {
                    templateAppliedBanner(appliedTemplateName)
                }

                EventCategorySelector(
                    selectedCategory: $selectedCategory,
                    enabledFeatures: $enabledFeatures,
                    headerTitle: "What kind of event?"
                )

                titleSection

                coverDetailsSection
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)

        case .whenAndWhere:
            VStack(spacing: Spacing.md) {
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
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)

        case .settings:
            VStack(spacing: Spacing.lg) {
                EventFeaturesSection(enabledFeatures: $enabledFeatures)

                EventSettingsSection(
                    privacy: $privacy,
                    guestListVisibility: $guestListVisibility,
                    capacity: $capacity,
                    hasCapacity: $hasCapacity
                )
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            EventFormSectionHeader(
                title: "Name your event",
                icon: "textformat",
                accent: Color.forCategory(selectedCategory)
            )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("EVENT NAME")
                    .gatherEyebrow()
                    .foregroundStyle(Color.gatherSecondaryText)

                TextField("Give your event a vibe...", text: $title)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Color.gatherPrimaryText)
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onSubmit { titleFocused = false }
                    .padding(Spacing.md)
                    .eventFormInputSurface(isActive: !title.isEmpty, isError: titleFieldHasError)
                    // Event names are single-line everywhere they render, so
                    // strip pasted newlines and enforce the 100-char limit.
                    .onChange(of: title) { _, newValue in
                        let cleaned = String(
                            newValue.replacingOccurrences(of: "\n", with: " ").prefix(100)
                        )
                        if cleaned != newValue { title = cleaned }
                    }

                HStack {
                    Spacer()
                    Text("\(title.count)/100")
                        .font(.caption2)
                        .foregroundStyle(title.count > 90 ? Color.warmCoral : Color.gatherSecondaryText)
                }
            }
        }
        .eventFormCard()
    }

    /// The name field only has content that fails validation (e.g. whitespace
    /// only) — pristine emptiness stays neutral guidance, not an error.
    private var titleFieldHasError: Bool {
        !title.isEmpty && hint(for: .typeAndTitle) != nil
    }

    // MARK: - Optional Cover & Details

    /// Collapsed by default so step 1 asks only for the minimum.
    private var coverDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    showCoverDetails.toggle()
                }
                HapticService.buttonTap()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(.callout, weight: .semibold))
                        .foregroundStyle(Color.forCategory(selectedCategory))
                        .frame(width: 40, height: 40)
                        .background(Color.gatherElevated)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add a cover & details")
                            .font(.system(.callout, weight: .semibold))
                            .foregroundStyle(Color.gatherPrimaryText)
                        Text(coverDetailsSummary)
                            .font(.system(.footnote))
                            .foregroundStyle(Color.gatherSecondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(Color.gatherSecondaryText)
                        .rotationEffect(.degrees(showCoverDetails ? 180 : 0))
                }
                .frame(minHeight: Layout.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a cover photo and description")
            .accessibilityValue(showCoverDetails ? "Expanded" : "Collapsed")
            .accessibilityHint("Double tap to \(showCoverDetails ? "collapse" : "expand")")

            if showCoverDetails {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    coverPickerRow
                    descriptionField
                }
                .padding(.top, Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .eventFormCard()
    }

    private var coverDetailsSummary: String {
        switch (heroImage != nil, !description.isEmpty) {
        case (true, true): return "Cover and description added"
        case (true, false): return "Cover added"
        case (false, true): return "Description added"
        case (false, false): return "Optional — you can add these later"
        }
    }

    private var coverPickerRow: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            HStack(spacing: Spacing.sm) {
                if let heroImage {
                    heroImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                } else {
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .fill(LinearGradient.categoryGradientVibrant(for: selectedCategory))
                        .frame(width: 64, height: 48)
                        .grain(0.07)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                        .overlay {
                            Image(systemName: "photo.badge.plus")
                                .font(.callout)
                                .foregroundStyle(Color.onCategory(selectedCategory))
                        }
                }

                Text(heroImage == nil ? "Add a cover photo" : "Change cover photo")
                    .font(.system(.callout, weight: .medium))
                    .foregroundStyle(Color.gatherPrimaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(Spacing.sm)
            .eventFormInputSurface(isActive: heroImage != nil)
        }
        .accessibilityLabel(heroImage == nil ? "Add a cover photo" : "Change cover photo")
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    heroImage = Image(uiImage: uiImage)
                }
            }
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("DESCRIPTION")
                    .gatherEyebrow()
                    .foregroundStyle(Color.gatherSecondaryText)
                Text("optional")
                    .font(.caption2)
                    .foregroundStyle(Color.gatherTertiaryText)
            }

            TextField("Tell people what to expect...", text: $description, axis: .vertical)
                .font(.system(.callout))
                .foregroundStyle(Color.gatherPrimaryText)
                .lineLimit(3...6)
                .padding(Spacing.md)
                .eventFormInputSurface(isActive: !description.isEmpty, minHeight: 88)
        }
    }

    // MARK: - Template Section

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                EventFormSectionHeader(title: "Quick Start", icon: "wand.and.stars")

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showTemplates = false }
                    // The user is ready to name the event — focus the only
                    // required field so they can type immediately.
                    titleFocused = true
                } label: {
                    Text("Skip")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(Color.gatherSecondaryText)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.gatherElevated)
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
                                    Color.forCategory(tmpl.category)
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

                                    Image(systemName: tmpl.icon)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        // Conference/meetup fills are light; white glyphs fail contrast
                                        .foregroundStyle(
                                            tmpl.category == .conference || tmpl.category == .meetup
                                                ? Color.black.opacity(0.85)
                                                : Color.white
                                        )
                                }

                                Text(tmpl.name)
                                    .font(.system(.footnote, weight: .semibold))
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
        .eventFormCard()
    }

    /// A clearly-future default so a quickly-created event isn't a near-now time
    /// that becomes "past" within the hour: tomorrow at 7 PM.
    static func defaultStartDate() -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
        return cal.date(bySettingHour: 19, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private func applyTemplate(_ tmpl: EventTemplate) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            selectedCategory = tmpl.category
            // Only enable features that actually ship — otherwise a template could
            // switch on a "coming soon" feature (e.g. seating) that the category
            // and manual toggles both filter out, leaving a dead tab.
            enabledFeatures = tmpl.suggestedFeatures.filter { $0.isAvailable }
            description = tmpl.suggestedDescription
            privacy = tmpl.suggestedPrivacy
            // Make the change visible and the step immediately completable: a
            // starter title the user can overwrite, plus a confirmation banner.
            if title.trimmingCharacters(in: .whitespaces).isEmpty {
                title = tmpl.name
            }
            appliedTemplateName = tmpl.name
            showTemplates = false
        }
        HapticService.mediumImpact()
        titleFocused = true
    }

    /// Small confirmation shown where the template row was, so applying one
    /// doesn't read as "nothing happened" (description + privacy are set out
    /// of view).
    private func templateAppliedBanner(_ name: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.rsvpYesFallback)
            Text("\(name) template applied — description & privacy prefilled")
                .gatherMetaText()
                .foregroundStyle(Color.gatherSecondaryText)
            Spacer(minLength: 0)
        }
        .padding(Spacing.sm)
        .background(Color.rsvpYesFallback.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.gatherCanvas.opacity(0), Color.gatherCanvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            VStack(spacing: Spacing.sm) {
                if let hint = stepHint {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                        Text(hint)
                            .font(.system(size: 13, weight: .medium))
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
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(Color.gatherPrimaryText)
                            .padding(.horizontal, Spacing.lg)
                            .frame(height: Layout.buttonHeight)
                            .background(Color.gatherElevated)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.gatherSeparator.opacity(0.6), lineWidth: 1)
                            )
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
                                .font(.system(size: 17, weight: .bold))
                            if step != .settings && !isSubmitting {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: Layout.buttonHeight)
                        .background(
                            canProceed
                                ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                                : AnyShapeStyle(Color.gatherElevated)
                        )
                        .clipShape(Capsule())
                        .accentGlow(canProceed ? Color.accentPurpleFallback : .clear, radius: 12)
                        .opacity(canProceed ? 1 : 0.6)
                    }
                    .disabled(!canProceed || isSubmitting)
                    .accessibilityIdentifier("wizardPrimaryButton")
                }

                if step == .settings {
                    Button {
                        createEvent(asDraft: true)
                    } label: {
                        Text("Save as draft instead")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentPurpleFallback)
                    }
                    .disabled(!isValid || isSubmitting)
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, Spacing.md)
            .background(Color.gatherCanvas)
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            step = next
        }
        HapticService.buttonTap()
    }

    private func goBack() {
        guard let previous = CreateStep(rawValue: step.rawValue - 1) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
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
        case .settings:
            if hasCapacity {
                guard let cap = capacity else { return "Enter a capacity, or turn off the limit" }
                if cap <= 0 { return "Capacity must be at least 1 guest" }
            }
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
            EventFormSectionHeader(title: title, icon: icon)

            // Content
            content
        }
        .eventFormCard()
    }
}

// MARK: - Preview

#Preview {
    CreateEventView()
        .environmentObject(AuthManager())
}
