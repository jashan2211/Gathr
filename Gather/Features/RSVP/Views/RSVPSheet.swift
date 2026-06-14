import SwiftUI

struct RSVPSheet: View {
    let event: Event
    /// When opened from an invite link, the host-created guest this RSVP is for.
    /// Takes priority over matching by signed-in user, so the response updates
    /// the host's existing guest entry instead of creating a duplicate.
    var invitedGuestId: UUID? = nil
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedStatus: RSVPStatus = .attending
    @State private var plusOnes: Int = 0
    @State private var comment: String = ""
    @State private var step: Step = .status
    @State private var isSubmitting = false
    @State private var isEditingExisting = false
    @State private var calendarMessage: String?
    @State private var isAddingToCalendar = false

    enum Step {
        case status
        case details
        case confirmation
    }

    // Check for existing guest entry — the invited guest (from the link) first,
    // then a guest matched to the signed-in user.
    private var existingGuest: Guest? {
        if let invitedGuestId,
           let invited = event.guests.first(where: { $0.id == invitedGuestId }) {
            return invited
        }
        guard let currentUser = authManager.currentUser else { return nil }
        return event.guests.first(where: { $0.userId == currentUser.id })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressIndicator(currentStep: step)
                    .padding(.top, Spacing.md)

                // Content
                Group {
                    switch step {
                    case .status:
                        statusSelection
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
            .navigationTitle(isEditingExisting ? "Update RSVP" : "RSVP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadExistingGuest()
            }
        }
    }

    private func loadExistingGuest() {
        if let guest = existingGuest {
            selectedStatus = guest.status
            plusOnes = guest.plusOneCount
            comment = guest.metadata?.notes ?? ""
            isEditingExisting = true
        }
    }

    // MARK: - Status Selection

    private var statusSelection: some View {
        VStack(spacing: Spacing.lg) {
            Text("Will you be attending?")
                .gatherTitle2()
                .padding(.top, Spacing.lg)

            VStack(spacing: Spacing.md) {
                RSVPOptionCard(
                    status: .attending,
                    isSelected: selectedStatus == .attending
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        selectedStatus = .attending
                        hapticFeedback()
                    }
                }

                RSVPOptionCard(
                    status: .maybe,
                    isSelected: selectedStatus == .maybe
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        selectedStatus = .maybe
                        hapticFeedback()
                    }
                }

                RSVPOptionCard(
                    status: .declined,
                    isSelected: selectedStatus == .declined
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        selectedStatus = .declined
                        hapticFeedback()
                    }
                }
            }
        }
    }

    // MARK: - Details Form

    private var detailsForm: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Any additional details?")
                .gatherTitle2()
                .padding(.top, Spacing.lg)

            // Plus ones
            if selectedStatus != .declined {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Bringing anyone?")
                        .font(GatherFont.headline)

                    Stepper(value: $plusOnes, in: 0...5) {
                        HStack {
                            Text("Plus ones")
                                .font(GatherFont.body)
                            Spacer()
                            Text("\(plusOnes)")
                                .font(GatherFont.headline)
                                .foregroundStyle(Color.accentPurpleFallback)
                        }
                    }
                    .accessibilityLabel("Plus ones")
                    .accessibilityValue("\(plusOnes)")
                    .padding()
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
            }

            // Comment
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Leave a note (optional)")
                    .font(GatherFont.headline)

                TextField("Looking forward to it!", text: $comment, axis: .vertical)
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
            // Success animation placeholder
            ZStack {
                Circle()
                    .fill(Color.forRSVPStatus(selectedStatus).opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: selectedStatus.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(Color.forRSVPStatus(selectedStatus))
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
            if selectedStatus == .attending {
                Button {
                    addToCalendar()
                } label: {
                    HStack {
                        if isAddingToCalendar {
                            ProgressView()
                                .tint(Color.accentPurpleFallback)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: calendarMessage != nil ? "checkmark.circle.fill" : "calendar.badge.plus")
                        }
                        Text(calendarMessage ?? "Add to Calendar")
                    }
                    .font(GatherFont.headline)
                    .foregroundStyle(calendarMessage != nil ? Color.rsvpYesFallback : Color.accentPurpleFallback)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background((calendarMessage != nil ? Color.rsvpYesFallback : Color.accentPurpleFallback).opacity(0.1))
                    .clipShape(Capsule())
                }
                .disabled(isAddingToCalendar || calendarMessage != nil)
                .accessibilityLabel("Add to Calendar")
                .accessibilityHint("Adds this event to your device calendar")
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            switch step {
            case .status:
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        if selectedStatus == .declined {
                            submitRSVP() // Skip details for decline
                        } else {
                            step = .details
                        }
                    }
                } label: {
                    Text(selectedStatus == .declined ? "Submit" : "Continue")
                        .font(GatherFont.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                }
                .disabled(isSubmitting)

            case .details:
                HStack(spacing: Spacing.md) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            step = .status
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

    private var confirmationTitle: String {
        if isEditingExisting {
            return "Response Updated"
        }
        switch selectedStatus {
        case .attending:
            return "You're going!"
        case .maybe:
            return "Marked as maybe"
        case .declined:
            return "Can't make it"
        default:
            return "Response submitted"
        }
    }

    private var confirmationSubtitle: String {
        if isEditingExisting {
            switch selectedStatus {
            case .attending:
                return "Your RSVP has been updated to Attending"
            case .maybe:
                return "Your RSVP has been updated to Maybe"
            case .declined:
                return "Your RSVP has been updated to Not Attending"
            default:
                return "Your response has been updated"
            }
        }
        switch selectedStatus {
        case .attending:
            return "We'll remind you before the event"
        case .maybe:
            return "You can update your response anytime"
        case .declined:
            return "Hope to see you at the next one!"
        default:
            return ""
        }
    }

    private func addToCalendar() {
        isAddingToCalendar = true
        Task {
            let result = await CalendarService.shared.addEventToCalendar(event: event)
            isAddingToCalendar = false
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                calendarMessage = result
            }
            if result.contains("added") {
                HapticService.success()
            } else {
                HapticService.warning()
            }
        }
    }

    private func submitRSVP() {
        isSubmitting = true

        // Resolve which guest this response belongs to, then record it.
        let guestId: UUID
        let guestName: String

        if let existingGuest = existingGuest {
            // Update the invited / matched guest in place.
            existingGuest.status = selectedStatus
            existingGuest.plusOneCount = plusOnes
            existingGuest.respondedAt = Date()
            // Bind this guest entry to the signed-in account so the app knows
            // who accepted, and the guest sees the event under their account.
            if existingGuest.userId == nil, let uid = authManager.currentUser?.id {
                existingGuest.userId = uid
            }
            if !comment.isEmpty {
                if existingGuest.metadata != nil {
                    existingGuest.metadata?.notes = comment
                } else {
                    existingGuest.metadata = GuestMetadata(notes: comment)
                }
            }
            guestId = existingGuest.id
            guestName = existingGuest.name
        } else if let invitedGuestId {
            // Shared event fetched without its guest list — still report the
            // response to the cloud under the invited guest id so the host gets it.
            guestId = invitedGuestId
            guestName = authManager.currentUser?.name ?? "Guest"
        } else if let currentUser = authManager.currentUser {
            // Self-RSVP: create a guest entry tied to the signed-in user.
            let newGuest = Guest(
                name: currentUser.name,
                email: currentUser.email,
                status: selectedStatus,
                plusOneCount: plusOnes,
                metadata: comment.isEmpty ? nil : GuestMetadata(notes: comment),
                userId: currentUser.id
            )
            newGuest.respondedAt = Date()
            event.guests.append(newGuest)
            guestId = newGuest.id
            guestName = newGuest.name
        } else {
            isSubmitting = false
            return
        }

        modelContext.safeSave()

        // Push to the cloud so the host receives the response (cross-user RSVP).
        FirestoreService.shared.submitRSVP(
            eventId: event.id,
            guestId: guestId,
            status: selectedStatus,
            partySize: plusOnes,
            name: guestName,
            note: comment.isEmpty ? nil : comment
        )
        // Keep this event in the guest's own "invited" index (cross-device) —
        // for everyone except the host responding to their own event.
        if event.hostId != authManager.currentUser?.id {
            FirestoreService.shared.recordInvitedEvent(event, guestId: guestId, status: selectedStatus)
        }

        // Send notification to host
        NotificationService.shared.scheduleRSVPNotification(
            guestName: guestName,
            eventTitle: event.title,
            functionName: nil,
            response: rsvpResponseFromStatus(selectedStatus)
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

    private func rsvpResponseFromStatus(_ status: RSVPStatus) -> RSVPResponse {
        switch status {
        case .attending: return .yes
        case .maybe: return .maybe
        case .declined: return .no
        default: return .no
        }
    }

    private func hapticFeedback() {
        HapticService.buttonTap()
    }
}

// MARK: - Progress Indicator

struct ProgressIndicator: View {
    let currentStep: RSVPSheet.Step

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
        case .status: return 0
        case .details: return 1
        case .confirmation: return 2
        }
    }
}

// MARK: - RSVP Option Card

struct RSVPOptionCard: View {
    let status: RSVPStatus
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.forRSVPStatus(status) : Color.gatherSecondaryBackground)
                        .frame(width: 48, height: 48)

                    Image(systemName: status.icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : Color.gatherSecondaryText)
                }

                // Text
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(status.displayName)
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)

                    Text(statusDescription)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.forRSVPStatus(status))
                }
            }
            .padding()
            // Semantic selected state: status-colored wash + border on a solid row.
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .fill(isSelected ? Color.forRSVPStatus(status).opacity(0.1) : Color.gatherSecondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .strokeBorder(isSelected ? Color.forRSVPStatus(status) : .clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.displayName), \(statusDescription)")
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select \(status.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var statusDescription: String {
        switch status {
        case .attending: return "Count me in!"
        case .maybe: return "I'll try to make it"
        case .declined: return "Unfortunately I can't"
        default: return ""
        }
    }
}

// MARK: - Preview

#Preview {
    RSVPSheet(
        event: Event(
            title: "Birthday Party",
            startDate: Date().addingTimeInterval(86400 * 3)
        )
    )
}
