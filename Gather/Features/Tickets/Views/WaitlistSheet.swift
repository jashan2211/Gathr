import SwiftUI
import SwiftData

struct WaitlistSheet: View {
    let event: Event
    let tier: TicketTier?  // nil = general waitlist, specific tier if tier-specific
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @Query private var allWaitlistEntries: [WaitlistEntry]

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var waitlistPosition: Int = 0
    @State private var existingEntry: WaitlistEntry?

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
            .padding()
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

                Text(tier != nil
                     ? "Get notified when \(tier!.name) tickets become available."
                     : "Get notified when tickets become available for \(event.title).")
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
            }

            // Form fields
            VStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Name")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)

                    TextField("Your name", text: $name)
                        .textContentType(.name)
                        .padding()
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Email")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)

                    TextField("you@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.gatherSecondaryBackground)
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
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                } else {
                    Text("Join Waitlist")
                        .font(GatherFont.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
            }
            .disabled(name.isEmpty || email.isEmpty || isSubmitting)
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: Spacing.lg) {
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
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
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentPurpleFallback)

                Text("in the waitlist")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gatherSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))

            Spacer()

            // Done button
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

                Text("You joined on \(formatDate(existingEntry!.createdAt))")
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            // Position card
            VStack(spacing: Spacing.sm) {
                Text("Your position")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)

                Text("#\(existingEntry!.position)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentPurpleFallback)

                Text("in the waitlist")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gatherSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))

            // Info text
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundStyle(Color.accentPurpleFallback)
                Text("We'll email you when tickets are available")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding()
            .background(Color.accentPurpleFallback.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

            Spacer()

            // Leave waitlist option
            Button {
                leaveWaitlist()
            } label: {
                Text("Leave Waitlist")
                    .font(GatherFont.headline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            }

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
        existingEntry = allWaitlistEntries.first { entry in
            entry.eventId == event.id && entry.userId == userId
        }
    }

    private var eventWaitlistCount: Int {
        allWaitlistEntries.filter { $0.eventId == event.id }.count
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
        try? modelContext.save()

        waitlistPosition = position

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            withAnimation {
                isSubmitting = false
                showSuccess = true
            }
        }
    }

    private func leaveWaitlist() {
        if let entry = existingEntry {
            modelContext.delete(entry)
            try? modelContext.save()
        }
        dismiss()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let event = Event(title: "Sold Out Concert", startDate: Date())
    WaitlistSheet(event: event, tier: nil)
        .environmentObject(AuthManager())
}
