import SwiftUI

struct FunctionRSVPSheet: View {
    let function: EventFunction
    let event: Event
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedResponse: RSVPResponse = .yes
    @State private var partySize: Int = 1
    @State private var notes: String = ""
    @State private var step: Step = .response
    @State private var isSubmitting = false
    @State private var isEditingExisting = false

    enum Step {
        case response
        case details
        case confirmation
    }

    /// The current user's Guest record on this event, if one exists.
    private var currentGuest: Guest? {
        guard let currentUser = authManager.currentUser else { return nil }
        return event.guests.first(where: { $0.userId == currentUser.id })
    }

    // Check for existing invite on init
    private var existingInvite: FunctionInvite? {
        guard let guest = currentGuest else { return nil }
        return function.invites.first(where: { $0.guestId == guest.id })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                FunctionRSVPProgressIndicator(currentStep: step)
                    .padding(.top, Spacing.md)

                // Content
                Group {
                    switch step {
                    case .response:
                        responseSelection
                    case .details:
                        detailsForm
                    case .confirmation:
                        confirmationView
                    }
                }
                .padding(.horizontal, Layout.horizontalPadding)

                Spacer()

                // Action buttons
                actionButtons
            }
            .navigationTitle(isEditingExisting ? "Update RSVP" : "RSVP to \(function.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadExistingInvite()
            }
        }
    }

    private func loadExistingInvite() {
        if let invite = existingInvite, let response = invite.response {
            selectedResponse = response
            partySize = invite.partySize
            notes = invite.notes ?? ""
            isEditingExisting = true
        }
    }

    // MARK: - Response Selection

    private var responseSelection: some View {
        VStack(spacing: Spacing.lg) {
            Text("Will you be attending \(function.name)?")
                .font(GatherFont.title3)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.lg)

            VStack(spacing: Spacing.md) {
                FunctionRSVPOptionCard(
                    response: .yes,
                    isSelected: selectedResponse == .yes
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        selectedResponse = .yes
                        hapticFeedback()
                    }
                }

                FunctionRSVPOptionCard(
                    response: .maybe,
                    isSelected: selectedResponse == .maybe
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        selectedResponse = .maybe
                        hapticFeedback()
                    }
                }

                FunctionRSVPOptionCard(
                    response: .no,
                    isSelected: selectedResponse == .no
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        selectedResponse = .no
                        hapticFeedback()
                    }
                }
            }
        }
    }

    // MARK: - Details Form

    private var detailsForm: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Additional details")
                .font(GatherFont.title3)
                .padding(.top, Spacing.lg)

            // Party size (only if attending or maybe)
            if selectedResponse != .no {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("How many in your party?")
                        .font(GatherFont.headline)

                    Stepper(value: $partySize, in: 1...10) {
                        HStack {
                            Text("Party size")
                                .font(GatherFont.body)
                            Spacer()
                            Text("\(partySize)")
                                .font(GatherFont.headline)
                                .foregroundStyle(Color.accentPurpleFallback)
                        }
                    }
                    .accessibilityLabel("Party size")
                    .accessibilityValue("\(partySize)")
                    .padding()
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
            }

            // Notes
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Leave a note (optional)")
                    .font(GatherFont.headline)

                TextField("Any dietary restrictions, etc.", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...5)
                    .padding()
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
        }
    }

    // MARK: - Confirmation View

    private var confirmationView: some View {
        VStack(spacing: Spacing.xl) {
            // Success animation
            ZStack {
                Circle()
                    .fill(responseColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: responseIcon)
                    .font(.system(size: 48))
                    .foregroundStyle(responseColor)
            }
            .padding(.top, Spacing.xl)
            .accessibilityHidden(true)

            VStack(spacing: Spacing.sm) {
                Text(confirmationTitle)
                    .font(GatherFont.title2)

                Text(confirmationSubtitle)
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            // Add to calendar prompt
            if selectedResponse == .yes {
                Button {
                    // Add to calendar
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text("Add to Calendar")
                    }
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.accentPurpleFallback)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.accentPurpleFallback.opacity(0.1))
                    .clipShape(Capsule())
                }
                .accessibilityLabel("Add to Calendar")
                .accessibilityHint("Adds this function to your device calendar")
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            switch step {
            case .response:
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        step = .details
                    }
                } label: {
                    Text("Continue")
                        .font(GatherFont.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                }

            case .details:
                HStack(spacing: Spacing.md) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            step = .response
                        }
                    } label: {
                        Text("Back")
                            .font(GatherFont.headline)
                            .foregroundStyle(Color.gatherPrimaryText)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color.gatherSecondaryBackground)
                            .clipShape(Capsule())
                    }

                    Button {
                        submitRSVP()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(LinearGradient.gatherAccentGradient)
                                .clipShape(Capsule())
                        } else {
                            Text("Submit")
                                .font(GatherFont.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(LinearGradient.gatherAccentGradient)
                                .clipShape(Capsule())
                        }
                    }
                    .disabled(isSubmitting)
                }

            case .confirmation:
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(GatherFont.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical)
        .background(Color.gatherBackground)
    }

    // MARK: - Helpers

    private var responseColor: Color {
        switch selectedResponse {
        case .yes: return .rsvpYesFallback
        case .no: return .rsvpNoFallback
        case .maybe: return .rsvpMaybeFallback
        }
    }

    private var responseIcon: String {
        switch selectedResponse {
        case .yes: return "checkmark.circle.fill"
        case .no: return "xmark.circle.fill"
        case .maybe: return "questionmark.circle.fill"
        }
    }

    private var confirmationTitle: String {
        if isEditingExisting {
            switch selectedResponse {
            case .yes: return "Response Updated"
            case .maybe: return "Response Updated"
            case .no: return "Response Updated"
            }
        } else {
            switch selectedResponse {
            case .yes: return "You're going!"
            case .maybe: return "Marked as maybe"
            case .no: return "Can't make it"
            }
        }
    }

    private var confirmationSubtitle: String {
        if isEditingExisting {
            switch selectedResponse {
            case .yes: return "Your RSVP has been updated to Attending"
            case .maybe: return "Your RSVP has been updated to Maybe"
            case .no: return "Your RSVP has been updated to Not Attending"
            }
        } else {
            switch selectedResponse {
            case .yes: return "We'll remind you before \(function.name)"
            case .maybe: return "You can update your response anytime"
            case .no: return "Hope to see you at other functions!"
            }
        }
    }

    private func submitRSVP() {
        isSubmitting = true

        // Find or create invite for current user
        guard let currentUser = authManager.currentUser else {
            isSubmitting = false
            return
        }

        // Ensure the current user has a Guest record on this event. A
        // FunctionInvite's guestId must reference a Guest.id — keying it on a
        // User.id leaves the response invisible to the host's guest list.
        let guest: Guest
        if let existing = event.guests.first(where: { $0.userId == currentUser.id }) {
            guest = existing
        } else {
            let newGuest = Guest(
                name: currentUser.name,
                email: currentUser.email,
                userId: currentUser.id
            )
            event.guests.append(newGuest)
            guest = newGuest
        }

        // Find existing invite or create new one
        if let existingInvite = function.invites.first(where: { $0.guestId == guest.id }) {
            existingInvite.response = selectedResponse
            existingInvite.partySize = partySize
            existingInvite.notes = notes.isEmpty ? nil : notes
            existingInvite.respondedAt = Date()
            existingInvite.inviteStatus = .responded
        } else {
            // Create new invite (self-RSVP)
            let newInvite = FunctionInvite(
                guestId: guest.id,
                functionId: function.id
            )
            newInvite.response = selectedResponse
            newInvite.partySize = partySize
            newInvite.notes = notes.isEmpty ? nil : notes
            newInvite.respondedAt = Date()
            newInvite.inviteStatus = .responded
            function.invites.append(newInvite)
        }

        // Reflect the response on the Guest so the host's status filters and
        // RSVP counts stay accurate.
        guest.respondedAt = Date()
        guest.status = aggregatedStatus(for: guest)

        modelContext.safeSave()

        // Push the per-function response to the cloud so the host receives it
        // across devices, and keep the event in the guest's invited index.
        FirestoreService.shared.submitFunctionRSVP(
            eventId: event.id,
            functionId: function.id,
            guestId: guest.id,
            response: selectedResponse,
            partySize: partySize,
            name: currentUser.name,
            note: notes.isEmpty ? nil : notes
        )
        if event.hostId != currentUser.id {
            FirestoreService.shared.recordInvitedEvent(event, guestId: guest.id, status: guest.status)
        }

        // Send notification to host
        NotificationService.shared.scheduleRSVPNotification(
            guestName: currentUser.name,
            eventTitle: event.title,
            functionName: function.name,
            response: selectedResponse
        )

        // Haptic success feedback
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            HapticService.success()

            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                step = .confirmation
                isSubmitting = false
            }
        }
    }

    private func hapticFeedback() {
        HapticService.buttonTap()
    }

    /// Derives the guest's overall event status from all of their function responses.
    private func aggregatedStatus(for guest: Guest) -> RSVPStatus {
        let responses = event.functions
            .flatMap { $0.invites }
            .filter { $0.guestId == guest.id }
            .compactMap { $0.response }
        if responses.contains(.yes) { return .attending }
        if responses.contains(.maybe) { return .maybe }
        if !responses.isEmpty { return .declined }
        return .pending
    }
}

// MARK: - Progress Indicator

struct FunctionRSVPProgressIndicator: View {
    let currentStep: FunctionRSVPSheet.Step

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<3) { index in
                Capsule()
                    .fill(index <= stepIndex ? Color.accentPurpleFallback : Color.gatherSecondaryBackground)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(stepIndex + 1) of 3")
    }

    private var stepIndex: Int {
        switch currentStep {
        case .response: return 0
        case .details: return 1
        case .confirmation: return 2
        }
    }
}

// MARK: - Function RSVP Option Card

struct FunctionRSVPOptionCard: View {
    let response: RSVPResponse
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? responseColor : Color.gatherSecondaryBackground)
                        .frame(width: 48, height: 48)

                    Image(systemName: responseIcon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : Color.gatherSecondaryText)
                }

                // Text
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(responseTitle)
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)

                    Text(responseDescription)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(responseColor)
                }
            }
            .padding()
            // Semantic selected state: response-colored wash + border on a solid row.
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .fill(isSelected ? responseColor.opacity(0.1) : Color.gatherSecondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .strokeBorder(isSelected ? responseColor : .clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(responseTitle), \(responseDescription)")
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select \(responseTitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var responseColor: Color {
        switch response {
        case .yes: return .rsvpYesFallback
        case .no: return .rsvpNoFallback
        case .maybe: return .rsvpMaybeFallback
        }
    }

    private var responseIcon: String {
        switch response {
        case .yes: return "checkmark"
        case .no: return "xmark"
        case .maybe: return "questionmark"
        }
    }

    private var responseTitle: String {
        switch response {
        case .yes: return "Yes, I'll be there"
        case .no: return "Can't make it"
        case .maybe: return "Maybe"
        }
    }

    private var responseDescription: String {
        switch response {
        case .yes: return "Count me in!"
        case .no: return "Unfortunately I can't attend"
        case .maybe: return "I'll try to make it"
        }
    }
}

// MARK: - Preview

#Preview {
    let function = EventFunction(
        name: "Sangeet Night",
        date: Date().addingTimeInterval(86400 * 3),
        eventId: UUID()
    )
    let event = Event(title: "Wedding", startDate: Date())

    FunctionRSVPSheet(function: function, event: event)
        .environmentObject(AuthManager())
}
