import SwiftUI

struct RSVPSheet: View {
    let event: Event
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedStatus: RSVPStatus = .attending
    @State private var plusOnes: Int = 0
    @State private var comment: String = ""
    @State private var step: Step = .status
    @State private var isSubmitting = false
    @State private var isEditingExisting = false

    enum Step {
        case status
        case details
        case confirmation
    }

    // Check for existing guest entry
    private var existingGuest: Guest? {
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
                .padding(.horizontal)

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
                .font(GatherFont.title2)
                .padding(.top, Spacing.lg)

            VStack(spacing: Spacing.md) {
                RSVPOptionCard(
                    status: .attending,
                    isSelected: selectedStatus == .attending
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedStatus = .attending
                        hapticFeedback()
                    }
                }

                RSVPOptionCard(
                    status: .maybe,
                    isSelected: selectedStatus == .maybe
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedStatus = .maybe
                        hapticFeedback()
                    }
                }

                RSVPOptionCard(
                    status: .declined,
                    isSelected: selectedStatus == .declined
                ) {
                    withAnimation(.spring(response: 0.3)) {
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
                .font(GatherFont.title2)
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

            VStack(spacing: Spacing.sm) {
                Text(confirmationTitle)
                    .font(GatherFont.title2)

                Text(confirmationSubtitle)
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
            }

            // Add to calendar prompt
            if selectedStatus == .attending {
                Button {
                    // Add to calendar
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text("Add to Calendar")
                    }
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.accentPurpleFallback)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentPurpleFallback.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            switch step {
            case .status:
                Button {
                    withAnimation {
                        if selectedStatus == .declined {
                            step = .details // Skip to details for decline
                        } else {
                            step = .details
                        }
                    }
                } label: {
                    Text("Continue")
                        .font(GatherFont.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }

            case .details:
                HStack(spacing: Spacing.md) {
                    Button {
                        withAnimation {
                            step = .status
                        }
                    } label: {
                        Text("Back")
                            .font(GatherFont.headline)
                            .foregroundStyle(Color.gatherPrimaryText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gatherSecondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }

                    Button {
                        submitRSVP()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient.gatherAccentGradient)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        } else {
                            Text("Submit")
                                .font(GatherFont.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient.gatherAccentGradient)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
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
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
            }
        }
        .padding()
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

    private func submitRSVP() {
        isSubmitting = true

        guard let currentUser = authManager.currentUser else {
            isSubmitting = false
            return
        }

        // Find or create guest entry
        if let existingGuest = existingGuest {
            // Update existing
            existingGuest.status = selectedStatus
            existingGuest.plusOneCount = plusOnes
            existingGuest.respondedAt = Date()
            if !comment.isEmpty {
                if existingGuest.metadata != nil {
                    existingGuest.metadata?.notes = comment
                } else {
                    existingGuest.metadata = GuestMetadata(notes: comment)
                }
            }
        } else {
            // Create new guest
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
        }

        try? modelContext.save()

        // Send notification to host
        Task {
            await NotificationService.shared.scheduleRSVPNotification(
                guestName: currentUser.name,
                eventTitle: event.title,
                functionName: nil,
                response: rsvpResponseFromStatus(selectedStatus)
            )
        }

        // Haptic success feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            withAnimation(.spring(response: 0.4)) {
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
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
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
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.gatherSecondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(isSelected ? Color.forRSVPStatus(status) : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
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
