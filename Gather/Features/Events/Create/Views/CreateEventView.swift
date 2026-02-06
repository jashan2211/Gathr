import SwiftUI
import PhotosUI

struct CreateEventView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    // Form state
    @State private var title = ""
    @State private var description = ""
    @State private var startDate = Date().addingTimeInterval(3600)
    @State private var endDate: Date?
    @State private var hasEndDate = false
    @State private var locationName = ""
    @State private var locationAddress = ""
    @State private var isVirtual = false
    @State private var virtualURL = ""
    @State private var capacity: Int?
    @State private var hasCapacity = false
    @State private var privacy: EventPrivacy = .inviteOnly
    @State private var guestListVisibility: GuestListVisibility = .visible

    // Image picker
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var heroImage: Image?

    // UI state
    @State private var isSubmitting = false
    @State private var showLocationPicker = false
    @State private var currentSection: Section = .basics

    enum Section: String, CaseIterable {
        case basics = "Basics"
        case when = "When"
        case location = "Where"
        case settings = "Settings"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Hero image picker
                    heroImagePicker

                    // Form sections
                    VStack(spacing: Spacing.lg) {
                        basicsSection
                        whenSection
                        whereSection
                        settingsSection
                    }
                    .horizontalPadding()
                }
                .padding(.bottom, Spacing.xxl)
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createEvent()
                    }
                    .disabled(!isValid || isSubmitting)
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
                } else {
                    LinearGradient(
                        colors: [
                            Color.accentPurpleFallback.opacity(0.3),
                            Color.accentPinkFallback.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                VStack(spacing: Spacing.sm) {
                    Image(systemName: heroImage == nil ? "photo.badge.plus" : "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.white)

                    Text(heroImage == nil ? "Add Cover Photo" : "Change Photo")
                        .font(GatherFont.callout)
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 180)
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

    // MARK: - Basics Section

    private var basicsSection: some View {
        FormSection(title: "Event Details", icon: "sparkles") {
            VStack(spacing: Spacing.md) {
                // Title
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Title")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)

                    TextField("Give your event a name", text: $title)
                        .font(GatherFont.body)
                        .padding()
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }

                // Description
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Description (optional)")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)

                    TextField("What's this event about?", text: $description, axis: .vertical)
                        .font(GatherFont.body)
                        .lineLimit(3...6)
                        .padding()
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
            }
        }
    }

    // MARK: - When Section

    private var whenSection: some View {
        FormSection(title: "Date & Time", icon: "calendar") {
            VStack(spacing: Spacing.md) {
                // Start date
                DatePicker(
                    "Starts",
                    selection: $startDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )

                // End date toggle
                Toggle("Add end time", isOn: $hasEndDate)
                    .tint(Color.accentPurpleFallback)

                if hasEndDate {
                    DatePicker(
                        "Ends",
                        selection: Binding(
                            get: { endDate ?? startDate.addingTimeInterval(3600) },
                            set: { endDate = $0 }
                        ),
                        in: startDate...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
        }
    }

    // MARK: - Where Section

    private var whereSection: some View {
        FormSection(title: "Location", icon: "mappin.circle") {
            VStack(spacing: Spacing.md) {
                // Virtual toggle
                Toggle("Virtual Event", isOn: $isVirtual)
                    .tint(Color.accentPurpleFallback)

                if isVirtual {
                    TextField("Meeting link (Zoom, Google Meet, etc.)", text: $virtualURL)
                        .font(GatherFont.body)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                } else {
                    VStack(spacing: Spacing.sm) {
                        TextField("Location name", text: $locationName)
                            .font(GatherFont.body)
                            .padding()
                            .background(Color.gatherSecondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

                        TextField("Address (optional)", text: $locationAddress)
                            .font(GatherFont.body)
                            .padding()
                            .background(Color.gatherSecondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }
                }
            }
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        FormSection(title: "Settings", icon: "gearshape") {
            VStack(spacing: Spacing.md) {
                // Privacy
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Privacy")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)

                    Picker("Privacy", selection: $privacy) {
                        ForEach(EventPrivacy.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Guest list visibility
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Guest List")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)

                    Picker("Guest List", selection: $guestListVisibility) {
                        ForEach(GuestListVisibility.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Capacity
                Toggle("Limit capacity", isOn: $hasCapacity)
                    .tint(Color.accentPurpleFallback)

                if hasCapacity {
                    HStack {
                        Text("Max guests")
                            .font(GatherFont.body)
                        Spacer()
                        TextField("50", value: $capacity, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.gatherSecondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }
                }
            }
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Create Event

    private func createEvent() {
        isSubmitting = true

        // Build location
        var location: EventLocation?
        if isVirtual, !virtualURL.isEmpty {
            location = EventLocation(name: "Virtual Event", virtualURL: URL(string: virtualURL))
        } else if !locationName.isEmpty {
            location = EventLocation(
                name: locationName,
                address: locationAddress.isEmpty ? nil : locationAddress
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
            guestListVisibility: guestListVisibility
        )

        // Save to SwiftData
        modelContext.insert(event)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        dismiss()
    }
}

// MARK: - Form Section

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
}
