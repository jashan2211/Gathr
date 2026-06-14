import SwiftUI
import SwiftData

struct WaitlistSheet: View {
    let event: Event
    let tier: TicketTier?  // nil = general waitlist, specific tier if tier-specific
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @Query private var eventWaitlistEntries: [WaitlistEntry]

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var waitlistPosition: Int = 0
    @State private var existingEntry: WaitlistEntry?

    init(event: Event, tier: TicketTier?) {
        self.event = event
        self.tier = tier
        let eventId = event.id
        _eventWaitlistEntries = Query(
            filter: #Predicate<WaitlistEntry> { $0.eventId == eventId }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                if showSuccess {
                    successView
                } else if existingEntry != nil {
                    alreadyOnWaitlistView
                } else {
                    joinForm
                }
            }
            .horizontalPadding()
            .padding(.vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gatherCanvas.ignoresSafeArea())
            .navigationTitle("Waitlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadUserInfo()
                checkExistingEntry()
            }
        }
    }

    // MARK: - Join Form

    private var joinForm: some View {
        VStack(spacing: Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentPurpleFallback.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "bell.badge")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentPurpleFallback)
            }

            VStack(spacing: Spacing.md) {
                Text("Join the Waitlist")
                    .font(GatherFont.title2)

                Text(tier.map { "Get notified when \($0.name) tickets become available." }
                     ?? "Get notified when tickets become available for \(event.title).")
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
            }

            // Form fields
            VStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("NAME")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.gatherSecondaryText)

                    TextField("Your name", text: $name)
                        .textContentType(.name)
                        .submitLabel(.done)
                        .padding()
                        .background(Color.gatherElevated)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("EMAIL")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.gatherSecondaryText)

                    TextField("you@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .submitLabel(.done)
                        .padding()
                        .background(Color.gatherElevated)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
            }

            Spacer()

            // Submit button
            Button {
                joinWaitlist()
            } label: {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                } else {
                    Text("Join Waitlist")
                        .font(GatherFont.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                }
            }
            .disabled(name.isEmpty || email.isEmpty || isSubmitting)
            .accessibilityLabel(isSubmitting ? "Joining waitlist" : "Join Waitlist")
            .accessibilityHint("Adds you to the waitlist for ticket availability notifications")
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: Spacing.lg) {
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.rsvpYesFallback.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.rsvpYesFallback)
            }

            VStack(spacing: Spacing.md) {
                Text("You're on the list!")
                    .font(GatherFont.title2)

                Text("We'll notify you at \(email) when tickets become available.")
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
            }

            // Position card
            VStack(spacing: Spacing.sm) {
                Text("Your position")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)

                Text("#\(waitlistPosition)")
                    .font(.system(size: 48, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(Color.accentPurpleFallback)

                Text("in the waitlist")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .surfaceCard(cornerRadius: CornerRadius.lg)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Your waitlist position is number \(waitlistPosition)")

            Spacer()

            // Done button
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

    // MARK: - Already on Waitlist View

    private var alreadyOnWaitlistView: some View {
        VStack(spacing: Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentPurpleFallback.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentPurpleFallback)
            }

            VStack(spacing: Spacing.md) {
                Text("Already on Waitlist")
                    .font(GatherFont.title2)

                Text("You joined on \(formatDate(existingEntry?.createdAt ?? Date()))")
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            // Position card
            VStack(spacing: Spacing.sm) {
                Text("Your position")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)

                Text("#\(existingEntry?.position ?? 0)")
                    .font(.system(size: 48, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(Color.accentPurpleFallback)

                Text("in the waitlist")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .surfaceCard(cornerRadius: CornerRadius.lg)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Your waitlist position is number \(existingEntry?.position ?? 0)")

            // Info text
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundStyle(Color.accentPurpleFallback)
                Text("We'll email you when tickets are available")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding()
            .background(Color.gatherSurface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .accessibilityElement(children: .combine)

            Spacer()

            // Leave waitlist option
            Button {
                leaveWaitlist()
            } label: {
                Text("Leave Waitlist")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherError)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.gatherError.opacity(0.1))
                    .clipShape(Capsule())
            }
            .accessibilityLabel("Leave Waitlist")
            .accessibilityHint("Removes you from the waitlist for this event")

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
        }
    }

    // MARK: - Helpers

    private func loadUserInfo() {
        if let user = authManager.currentUser {
            name = user.name
            email = user.email ?? ""
        }
    }

    private func checkExistingEntry() {
        guard let userId = authManager.currentUser?.id else { return }
        existingEntry = eventWaitlistEntries.first { entry in
            entry.userId == userId
        }
    }

    private var eventWaitlistCount: Int {
        eventWaitlistEntries.count
    }

    private func joinWaitlist() {
        isSubmitting = true

        let position = eventWaitlistCount + 1

        let entry = WaitlistEntry(
            eventId: event.id,
            email: email,
            tierId: tier?.id,
            name: name
        )
        entry.position = position
        entry.userId = authManager.currentUser?.id

        modelContext.insert(entry)
        modelContext.safeSave()

        waitlistPosition = position

        Task {
            try? await Task.sleep(for: .seconds(0.5))
            HapticService.success()

            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isSubmitting = false
                showSuccess = true
            }
        }
    }

    private func leaveWaitlist() {
        if let entry = existingEntry {
            modelContext.delete(entry)
            modelContext.safeSave()
        }
        dismiss()
    }

    private func formatDate(_ date: Date) -> String {
        GatherDateFormatter.monthDayYear.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let event = Event(title: "Sold Out Concert", startDate: Date())
    WaitlistSheet(event: event, tier: nil)
        .environmentObject(AuthManager())
}
