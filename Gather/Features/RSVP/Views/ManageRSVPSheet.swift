import SwiftUI

// MARK: - Manage RSVP Sheet

/// Sheet for users who have already RSVPed to view/modify their response
struct ManageRSVPSheet: View {
    let event: Event
    let guest: Guest
    let ticket: Ticket?

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false
    @State private var selectedStatus: RSVPStatus
    @State private var plusOnes: Int
    @State private var notes: String
    @State private var showCancelConfirmation = false
    @State private var showRequestCancellation = false
    @State private var isSubmitting = false
    @State private var cancellationReason = ""
    @State private var calendarMessage: String?
    @State private var isAddingToCalendar = false

    init(event: Event, guest: Guest, ticket: Ticket? = nil) {
        self.event = event
        self.guest = guest
        self.ticket = ticket
        _selectedStatus = State(initialValue: guest.status)
        _plusOnes = State(initialValue: guest.plusOneCount)
        _notes = State(initialValue: guest.metadata?.notes ?? "")
    }

    private var isPaidTicket: Bool {
        if let ticket = ticket {
            return ticket.unitPrice > 0
        }
        return false
    }

    private var canModify: Bool {
        // Free events can always modify, paid tickets cannot cancel
        !isPaidTicket
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Current Status Card
                    currentStatusCard

                    // Ticket Info (if applicable)
                    if let ticket = ticket {
                        ticketInfoCard(ticket)
                    }

                    // Edit Section (only if editing and can modify)
                    if isEditing && canModify {
                        editSection
                    }

                    // Actions
                    actionButtons
                }
                .horizontalPadding()
                .padding(.vertical)
            }
            .background(Color.gatherBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Your RSVP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Cancel RSVP?",
                isPresented: $showCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Cancel RSVP", role: .destructive) {
                    cancelRSVP()
                }
                Button("Keep RSVP", role: .cancel) {}
            } message: {
                Text("You can always RSVP again if your plans change.")
            }
            .sheet(isPresented: $showRequestCancellation) {
                if let ticket = ticket {
                    RequestCancellationSheet(
                        ticket: ticket,
                        event: event,
                        reason: $cancellationReason
                    ) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Current Status Card

    private var currentStatusCard: some View {
        VStack(spacing: Spacing.md) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(Color.forRSVPStatus(guest.status).opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: guest.status.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(Color.forRSVPStatus(guest.status))
            }

            VStack(spacing: Spacing.xs) {
                Text(statusTitle)
                    .font(GatherFont.title2)
                    .fontWeight(.semibold)

                Text(statusSubtitle)
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
            }

            // Details Row
            HStack(spacing: Spacing.lg) {
                if guest.status == .attending || guest.status == .maybe {
                    VStack {
                        Text("\(guest.totalHeadcount)")
                            .font(GatherFont.headline)
                        Text("People")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }

                if let respondedAt = guest.respondedAt {
                    VStack {
                        Text(formatDate(respondedAt))
                            .font(GatherFont.headline)
                        Text("Responded")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }
            }
            .padding(.top, Spacing.sm)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .surfaceCard(cornerRadius: CornerRadius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("RSVP status: \(statusTitle). \(statusSubtitle)")
    }

    // MARK: - Ticket Info Card

    private func ticketInfoCard(_ ticket: Ticket) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundStyle(Color.accentPurpleFallback)
                Text("Your Ticket")
                    .font(GatherFont.headline)
                Spacer()
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.ticketNumber)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    Text("\(ticket.quantity) ticket\(ticket.quantity > 1 ? "s" : "")")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                if ticket.totalPrice > 0 {
                    Text(formatPrice(ticket.totalPrice))
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.accentPurpleFallback)
                } else {
                    Text("Free")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.rsvpYesFallback)
                }
            }

            if isPaidTicket {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.gatherSecondaryText)
                    Text("Paid tickets cannot be cancelled. Contact the host for refund requests.")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .padding(.top, Spacing.xs)
            }
        }
        .padding()
        .surfaceCard(cornerRadius: CornerRadius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ticket \(ticket.ticketNumber), \(ticket.quantity) ticket\(ticket.quantity > 1 ? "s" : ""), \(ticket.totalPrice > 0 ? formatPrice(ticket.totalPrice) : "Free")")
    }

    // MARK: - Edit Section

    private var editSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Update Your Response")
                .font(GatherFont.headline)

            // Status Options
            VStack(spacing: Spacing.sm) {
                ForEach([RSVPStatus.attending, .maybe, .declined], id: \.self) { status in
                    EditStatusOption(
                        status: status,
                        isSelected: selectedStatus == status
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            selectedStatus = status
                        }
                    }
                }
            }

            // Plus ones (only if attending or maybe)
            if selectedStatus == .attending || selectedStatus == .maybe {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Party size")
                        .font(GatherFont.headline)

                    Stepper(value: $plusOnes, in: 0...5) {
                        HStack {
                            Text("Additional guests")
                            Spacer()
                            Text("\(plusOnes)")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentPurpleFallback)
                        }
                    }
                    .accessibilityLabel("Additional guests")
                    .accessibilityValue("\(plusOnes)")
                    .padding()
                    .background(Color.gatherTertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .padding(.top, Spacing.sm)
            }

            // Notes
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Notes (optional)")
                    .font(GatherFont.headline)

                TextField("Any dietary restrictions, requests...", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...5)
                    .padding()
                    .background(Color.gatherTertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }
            .padding(.top, Spacing.sm)
        }
        .padding()
        .surfaceCard(cornerRadius: CornerRadius.lg)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.md) {
            if isEditing {
                // Save / Cancel edit buttons
                HStack(spacing: Spacing.md) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            isEditing = false
                            // Reset to original values
                            selectedStatus = guest.status
                            plusOnes = guest.plusOneCount
                            notes = guest.metadata?.notes ?? ""
                        }
                    } label: {
                        Text("Cancel")
                            .font(GatherFont.headline)
                            .foregroundStyle(Color.gatherPrimaryText)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color.gatherSecondaryBackground)
                            .clipShape(Capsule())
                    }

                    Button {
                        saveChanges()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(LinearGradient.gatherAccentGradient)
                                .clipShape(Capsule())
                        } else {
                            Text("Save Changes")
                                .font(GatherFont.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(LinearGradient.gatherAccentGradient)
                                .clipShape(Capsule())
                        }
                    }
                    .disabled(isSubmitting || !hasChanges)
                }
            } else {
                // View mode buttons
                if canModify {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            isEditing = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Modify Response")
                        }
                        .font(GatherFont.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                    }
                    .accessibilityLabel("Modify Response")
                    .accessibilityHint("Opens editor to change your RSVP status")

                    if guest.status == .attending || guest.status == .maybe {
                        Button {
                            showCancelConfirmation = true
                        } label: {
                            Text("Cancel RSVP")
                                .font(GatherFont.headline)
                                .foregroundStyle(Color.gatherError)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.gatherError.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .accessibilityLabel("Cancel RSVP")
                        .accessibilityHint("Cancels your attendance for this event")
                    }
                } else if isPaidTicket {
                    // Paid ticket - can only request cancellation
                    Button {
                        showRequestCancellation = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Request Cancellation")
                        }
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.rsvpMaybeFallback)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.rsvpMaybeFallback.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .accessibilityLabel("Request Cancellation")
                    .accessibilityHint("Sends a cancellation request to the event host for your paid ticket")
                }

                // Add to calendar (if attending)
                if guest.status == .attending {
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
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusTitle: String {
        switch guest.status {
        case .attending: return "You're Going!"
        case .maybe: return "Marked as Maybe"
        case .declined: return "Not Attending"
        case .pending: return "Awaiting Response"
        case .waitlisted: return "On Waitlist"
        }
    }

    private var statusSubtitle: String {
        switch guest.status {
        case .attending:
            return "We'll see you at \(event.title)"
        case .maybe:
            return "Let us know when you're sure"
        case .declined:
            return "Hope to see you at the next one"
        case .pending:
            return "Please respond to complete your RSVP"
        case .waitlisted:
            return "We'll notify you if a spot opens up"
        }
    }

    private var hasChanges: Bool {
        selectedStatus != guest.status ||
        plusOnes != guest.plusOneCount ||
        notes != (guest.metadata?.notes ?? "")
    }

    private func formatDate(_ date: Date) -> String {
        GatherDateFormatter.monthDay.string(from: date)
    }

    private func formatPrice(_ price: Decimal) -> String {
        GatherPriceFormatter.format(price)
    }

    private func saveChanges() {
        isSubmitting = true

        // Update guest
        guest.status = selectedStatus
        guest.plusOneCount = plusOnes
        guest.respondedAt = Date()

        if !notes.isEmpty {
            if guest.metadata != nil {
                guest.metadata?.notes = notes
            } else {
                guest.metadata = GuestMetadata(notes: notes)
            }
        }

        modelContext.safeSave()

        // Haptic feedback
        HapticService.success()

        Task {
            try? await Task.sleep(for: .seconds(0.5))
            isSubmitting = false
            isEditing = false
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

    private func cancelRSVP() {
        guest.status = .declined
        guest.respondedAt = Date()

        // Cancel the guest's ticket too, so declining doesn't leave a live QR
        // that still counts as sold / could be checked in at the door.
        if let ticket, ticket.cancelledAt == nil {
            ticket.cancelledAt = Date()
            ticket.cancellationReason = "Guest cancelled RSVP"
            ticket.paymentStatus = .cancelled
            if let tier = event.ticketTiers.first(where: { $0.id == ticket.tierId }), tier.soldCount > 0 {
                tier.soldCount -= 1
            }
        }
        modelContext.safeSave()

        HapticService.success()

        dismiss()
    }
}

// MARK: - Edit Status Option

private struct EditStatusOption: View {
    let status: RSVPStatus
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: status.icon)
                    .foregroundStyle(isSelected ? .white : Color.forRSVPStatus(status))
                    .frame(width: 32, height: 32)
                    .background(isSelected ? Color.forRSVPStatus(status) : Color.forRSVPStatus(status).opacity(0.1))
                    .clipShape(Circle())

                Text(status.displayName)
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherPrimaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.forRSVPStatus(status))
                }
            }
            .padding()
            // Semantic selected state: status-colored wash + border on a solid row.
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(isSelected ? Color.forRSVPStatus(status).opacity(0.1) : Color.gatherTertiaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .strokeBorder(isSelected ? Color.forRSVPStatus(status) : .clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Request Cancellation Sheet

struct RequestCancellationSheet: View {
    let ticket: Ticket
    let event: Event
    @Binding var reason: String
    let onComplete: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var isSending = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.rsvpMaybeFallback.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.rsvpMaybeFallback)
                }
                .padding(.top, Spacing.lg)

                if showSuccess {
                    // Success state
                    VStack(spacing: Spacing.md) {
                        Text("Request Sent")
                            .font(GatherFont.title2)

                        Text("The host has been notified of your cancellation request. They will review and respond soon.")
                            .font(GatherFont.body)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding()

                    Spacer()

                    Button {
                        onComplete()
                    } label: {
                        Text("Done")
                            .font(GatherFont.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(LinearGradient.gatherAccentGradient)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.vertical)
                } else {
                    // Request form
                    VStack(spacing: Spacing.md) {
                        Text("Request Cancellation")
                            .font(GatherFont.title2)

                        Text("Paid tickets require host approval for cancellation. Tell them why you can't attend.")
                            .font(GatherFont.body)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding()

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Reason for cancellation")
                            .font(GatherFont.headline)

                        TextField("I need to cancel because...", text: $reason, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(4...6)
                            .padding()
                            .background(Color.gatherSecondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }
                    .padding(.horizontal, Layout.horizontalPadding)

                    Spacer()

                    VStack(spacing: Spacing.md) {
                        Button {
                            sendRequest()
                        } label: {
                            if isSending {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .background(LinearGradient.gatherAccentGradient)
                                    .clipShape(Capsule())
                            } else {
                                Text("Send Request")
                                    .font(GatherFont.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .background(LinearGradient.gatherAccentGradient)
                                    .clipShape(Capsule())
                            }
                        }
                        .disabled(reason.isEmpty || isSending)

                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(GatherFont.headline)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                    }
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.vertical)
                }
            }
            .background(Color.gatherBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func sendRequest() {
        isSending = true

        // Simulate sending request
        Task {
            try? await Task.sleep(for: .seconds(1))
            HapticService.success()

            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isSending = false
                showSuccess = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let event = Event(title: "Summer Party", startDate: Date())
    let guest = Guest(name: "John Doe", email: "john@example.com", status: .attending, plusOneCount: 1)

    ManageRSVPSheet(event: event, guest: guest, ticket: nil)
}
