import SwiftUI

struct SendInvitesSheet: View {
    let event: Event
    let preselectedGuests: [UUID]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var inviteService = InviteService.shared

    // Selections
    @State private var selectedGuestIds: Set<UUID> = []
    @State private var selectedFunctions: Set<UUID> = []
    @State private var selectedChannel: InviteChannel = .whatsapp

    // Sending state
    @State private var isSending = false
    @State private var sentCount = 0
    @State private var failedCount = 0
    @State private var showComplete = false

    var body: some View {
        NavigationStack {
            if showComplete {
                completionView
            } else {
                mainContent
            }
        }
        .onAppear {
            if !preselectedGuests.isEmpty {
                selectedGuestIds = Set(preselectedGuests)
            }
            selectedFunctions = Set(event.functions.map { $0.id })
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Quick Actions Header
                    quickActionsSection
                        .bouncyAppear()

                    // Guest Selection Summary
                    guestSelectionSection
                        .bouncyAppear(delay: 0.05)

                    // Function Selection (if applicable)
                    if !event.functions.isEmpty {
                        functionSelectionSection
                            .bouncyAppear(delay: 0.1)
                    }

                    // Channel Selection
                    channelSelectionSection
                        .bouncyAppear(delay: 0.15)

                    // Spacer for floating button
                    Color.clear.frame(height: 80)
                }
                .padding()
            }

            // Floating send bar
            sendButtonBar
        }
        .navigationTitle("Send Invites")
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
        .disabled(isSending)
        .overlay {
            if isSending {
                sendingOverlay
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: Spacing.sm) {
            InviteQuickActionPill(
                title: "All Guests",
                count: event.guests.count,
                icon: "person.2.fill",
                isSelected: selectedGuestIds.count == event.guests.count,
                action: { selectedGuestIds = Set(event.guests.map { $0.id }) }
            )

            InviteQuickActionPill(
                title: "Not Sent",
                count: guestsNotSent.count,
                icon: "bell.badge",
                isSelected: selectedGuestIds == Set(guestsNotSent.map { $0.id }) && !guestsNotSent.isEmpty,
                action: { selectedGuestIds = Set(guestsNotSent.map { $0.id }) }
            )

            InviteQuickActionPill(
                title: "Custom",
                count: selectedGuestIds.count,
                icon: "hand.tap",
                isSelected: !selectedGuestIds.isEmpty && selectedGuestIds.count != event.guests.count && selectedGuestIds != Set(guestsNotSent.map { $0.id }),
                action: {}
            )
        }
    }

    // MARK: - Guest Selection

    private var guestSelectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.2")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentPurpleFallback)
                    Text("Guests")
                        .font(GatherFont.headline)
                }

                Spacer()

                Text("\(selectedGuestIds.count) selected")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentPurpleFallback)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Color.accentPurpleFallback.opacity(0.1))
                    .clipShape(Capsule())
            }

            // Compact guest chips using LazyVGrid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Spacing.xs)], spacing: Spacing.xs) {
                ForEach(event.guests.sorted { $0.name < $1.name }) { guest in
                    GuestChip(
                        guest: guest,
                        isSelected: selectedGuestIds.contains(guest.id),
                        onTap: { toggleGuest(guest.id) }
                    )
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.gatherSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    // MARK: - Function Selection

    private var functionSelectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentPinkFallback)
                    Text("Functions")
                        .font(GatherFont.headline)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if selectedFunctions.count == event.functions.count {
                            selectedFunctions.removeAll()
                        } else {
                            selectedFunctions = Set(event.functions.map { $0.id })
                        }
                    }
                } label: {
                    Text(selectedFunctions.count == event.functions.count ? "Deselect All" : "Select All")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.accentPurpleFallback)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 4)
                        .background(Color.accentPurpleFallback.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            VStack(spacing: Spacing.xs) {
                ForEach(event.functions.sorted { $0.date < $1.date }) { function in
                    FunctionChip(
                        function: function,
                        isSelected: selectedFunctions.contains(function.id),
                        onTap: { toggleFunction(function.id) }
                    )
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.gatherSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    // MARK: - Channel Selection

    private var channelSelectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "paperplane.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentPurpleFallback)
                Text("Send via")
                    .font(GatherFont.headline)
            }

            HStack(spacing: Spacing.sm) {
                ForEach([InviteChannel.whatsapp, .sms, .email, .copied], id: \.self) { channel in
                    ChannelButton(
                        channel: channel,
                        isSelected: selectedChannel == channel,
                        availableCount: guestsForChannel(channel).count,
                        totalCount: selectedGuestIds.count,
                        onTap: {
                            withAnimation(.spring(response: 0.25)) {
                                selectedChannel = channel
                            }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    )
                }
            }

            if selectedChannel != .copied {
                let available = guestsForChannel(selectedChannel).count
                if available < selectedGuestIds.count {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("\(selectedGuestIds.count - available) guests missing \(selectedChannel == .email ? "email" : "phone")")
                    }
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .background(Color.rsvpMaybeFallback.opacity(0.9))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.gatherSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    // MARK: - Floating Send Bar

    private var sendButtonBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.gatherBackground.opacity(0), Color.gatherBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            HStack(spacing: Spacing.sm) {
                // Count badge
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(guestsForChannel(selectedChannel).count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text("invites ready")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                Button {
                    sendInvites()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedChannel.icon)
                            .font(.callout)
                        Text("Send via \(selectedChannel.shortName)")
                            .font(GatherFont.callout)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        canSend
                            ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                            : AnyShapeStyle(Color.gatherSecondaryText.opacity(0.3))
                    )
                    .clipShape(Capsule())
                }
                .disabled(!canSend)
                .scaleEffect(canSend ? 1.0 : 0.95)
                .animation(.spring(response: 0.3), value: canSend)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: -4)
            )
        }
    }

    // MARK: - Sending Overlay

    private var sendingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                // Animated ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 80, height: 80)

                    let total = guestsForChannel(selectedChannel).count
                    let progress = total > 0 ? CGFloat(sentCount + failedCount) / CGFloat(total) : 0

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient.gatherAccentGradient,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: sentCount + failedCount)

                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                Text("Sending invites...")
                    .font(GatherFont.headline)
                    .foregroundStyle(.white)

                Text("\(sentCount + failedCount) of \(guestsForChannel(selectedChannel).count)")
                    .font(GatherFont.callout)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(Spacing.xl)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.accentPurpleFallback.opacity(0.08),
                    Color.accentPinkFallback.opacity(0.05),
                    Color.gatherBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating decorative circles
            GeometryReader { geo in
                Circle()
                    .fill(Color.rsvpYesFallback.opacity(0.08))
                    .frame(width: 200, height: 200)
                    .offset(x: geo.size.width * 0.6, y: geo.size.height * 0.1)

                Circle()
                    .fill(Color.accentPurpleFallback.opacity(0.06))
                    .frame(width: 150, height: 150)
                    .offset(x: -60, y: geo.size.height * 0.55)

                Circle()
                    .fill(Color.accentPinkFallback.opacity(0.07))
                    .frame(width: 100, height: 100)
                    .offset(x: geo.size.width * 0.7, y: geo.size.height * 0.65)
            }

            VStack(spacing: Spacing.xl) {
                Spacer()

                // Success badge
                ZStack {
                    Circle()
                        .fill(Color.rsvpYesFallback.opacity(0.1))
                        .frame(width: 140, height: 140)
                        .bouncyAppear()

                    Circle()
                        .fill(Color.rsvpYesFallback.opacity(0.15))
                        .frame(width: 110, height: 110)
                        .bouncyAppear(delay: 0.05)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.rsvpYesFallback)
                        .bouncyAppear(delay: 0.1)
                }

                VStack(spacing: Spacing.sm) {
                    Text("Invites Sent!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.gatherPrimaryText)
                        .bouncyAppear(delay: 0.15)

                    Text("Your guests have been notified")
                        .font(GatherFont.body)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .bouncyAppear(delay: 0.2)
                }

                // Stats cards
                HStack(spacing: Spacing.sm) {
                    if sentCount > 0 {
                        CompletionStatCard(
                            icon: "checkmark.circle.fill",
                            value: "\(sentCount)",
                            label: "Sent",
                            color: Color.rsvpYesFallback
                        )
                        .bouncyAppear(delay: 0.25)
                    }

                    if failedCount > 0 {
                        CompletionStatCard(
                            icon: "exclamationmark.triangle.fill",
                            value: "\(failedCount)",
                            label: "Skipped",
                            color: Color.rsvpMaybeFallback
                        )
                        .bouncyAppear(delay: 0.3)
                    }

                    CompletionStatCard(
                        icon: "person.2.fill",
                        value: "\(event.guests.count)",
                        label: "Total Guests",
                        color: Color.accentPurpleFallback
                    )
                    .bouncyAppear(delay: 0.35)
                }
                .padding(.horizontal)

                Spacer()

                // Done button
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.callout)
                            .fontWeight(.bold)
                        Text("Done")
                            .font(GatherFont.callout)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.lg)
                .bouncyAppear(delay: 0.4)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Helpers

    private var guestsNotSent: [Guest] {
        event.guests.filter { guest in
            if event.functions.isEmpty { return true }
            return event.functions.contains { function in
                !function.invites.contains { $0.guestId == guest.id && $0.inviteStatus != .notSent }
            }
        }
    }

    private var canSend: Bool {
        !selectedGuestIds.isEmpty &&
        (event.functions.isEmpty || !selectedFunctions.isEmpty) &&
        !guestsForChannel(selectedChannel).isEmpty
    }

    private func toggleGuest(_ id: UUID) {
        withAnimation(.spring(response: 0.25)) {
            if selectedGuestIds.contains(id) {
                selectedGuestIds.remove(id)
            } else {
                selectedGuestIds.insert(id)
            }
        }
    }

    private func toggleFunction(_ id: UUID) {
        withAnimation(.spring(response: 0.25)) {
            if selectedFunctions.contains(id) {
                selectedFunctions.remove(id)
            } else {
                selectedFunctions.insert(id)
            }
        }
    }

    private func guestsForChannel(_ channel: InviteChannel) -> [Guest] {
        let selectedGuests = event.guests.filter { selectedGuestIds.contains($0.id) }
        switch channel {
        case .whatsapp:
            return selectedGuests.filter { inviteService.canSendViaWhatsApp(guest: $0) }
        case .sms:
            return selectedGuests.filter { inviteService.canSendViaSMS(guest: $0) }
        case .email:
            return selectedGuests.filter { inviteService.canSendViaEmail(guest: $0) }
        case .copied, .inAppLink:
            return selectedGuests
        }
    }

    private func sendInvites() {
        isSending = true
        sentCount = 0
        failedCount = 0

        let guestsToSend = guestsForChannel(selectedChannel)
        let selectedFunctionsList = event.functions.filter { selectedFunctions.contains($0.id) }

        Task {
            for guest in guestsToSend {
                _ = inviteService.createFunctionInvites(
                    for: [guest],
                    functions: selectedFunctionsList,
                    modelContext: modelContext
                )

                var success = false
                switch selectedChannel {
                case .whatsapp:
                    success = inviteService.sendViaWhatsApp(guest: guest, event: event, functions: selectedFunctionsList)
                case .sms:
                    success = inviteService.sendViaSMS(guest: guest, event: event, functions: selectedFunctionsList)
                case .email:
                    success = inviteService.sendViaEmail(guest: guest, event: event, functions: selectedFunctionsList)
                case .copied:
                    inviteService.copyInviteLink(guest: guest, event: event)
                    success = true
                case .inAppLink:
                    success = true
                }

                if success {
                    for function in selectedFunctionsList {
                        if let invite = function.invites.first(where: { $0.guestId == guest.id }) {
                            inviteService.markInviteSent(invite: invite, channel: selectedChannel, modelContext: modelContext)
                        }
                    }
                    sentCount += 1
                } else {
                    failedCount += 1
                }

                if selectedChannel != .copied {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
            }

            try? modelContext.save()

            await MainActor.run {
                isSending = false
                withAnimation(.spring(response: 0.4)) {
                    showComplete = true
                }
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
}

// MARK: - Invite Quick Action Pill

private struct InviteQuickActionPill: View {
    let title: String
    let count: Int
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .fontWeight(.semibold)

                Text("\(count)")
                    .font(GatherFont.headline)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                    : AnyShapeStyle(Color.gatherSecondaryBackground)
            )
            .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Completion Stat Card

private struct CompletionStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color)
                .clipShape(Circle())

            Text(value)
                .font(GatherFont.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.gatherPrimaryText)

            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(Color.gatherSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }
}

// MARK: - Guest Chip

struct GuestChip: View {
    let guest: Guest
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                // Mini avatar
                Circle()
                    .fill(
                        isSelected
                            ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                            : AnyShapeStyle(Color.gatherSecondaryText.opacity(0.3))
                    )
                    .frame(width: 18, height: 18)
                    .overlay {
                        Text(String(guest.name.prefix(1)).uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isSelected ? .white : Color.gatherSecondaryText)
                    }

                Text(guest.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentPurpleFallback.opacity(0.15) : Color.gatherTertiaryBackground)
            .foregroundStyle(isSelected ? Color.accentPurpleFallback : Color.gatherPrimaryText)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.accentPurpleFallback.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Function Chip

struct FunctionChip: View {
    let function: EventFunction
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentPurpleFallback : Color.gatherSecondaryText.opacity(0.2))
                        .frame(width: 24, height: 24)

                    Image(systemName: isSelected ? "checkmark" : "calendar")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isSelected ? .white : Color.gatherSecondaryText)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(function.name)
                        .font(GatherFont.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text(function.formattedDateRange)
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()
            }
            .padding(Spacing.sm)
            .background(isSelected ? Color.accentPurpleFallback.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        }
    }
}

// MARK: - Channel Button

struct ChannelButton: View {
    let channel: InviteChannel
    let isSelected: Bool
    let availableCount: Int
    let totalCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color(channel.color).opacity(0.15))
                            .frame(width: 52, height: 52)
                    }

                    Image(systemName: channel.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? .white : Color(channel.color))
                        .frame(width: 44, height: 44)
                        .background(
                            isSelected
                                ? AnyShapeStyle(LinearGradient(colors: [Color(channel.color), Color(channel.color).opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Color(channel.color).opacity(0.1))
                        )
                        .clipShape(Circle())
                }

                Text(channel.shortName)
                    .font(.caption2)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundStyle(isSelected ? Color.gatherPrimaryText : Color.gatherSecondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Channel Extensions

extension InviteChannel {
    var shortName: String {
        switch self {
        case .whatsapp: return "WhatsApp"
        case .sms: return "SMS"
        case .email: return "Email"
        case .copied: return "Copy"
        case .inAppLink: return "Link"
        }
    }
}

// MARK: - Preview

#Preview {
    let event = Event(title: "Wedding", startDate: Date())
    SendInvitesSheet(event: event, preselectedGuests: [])
}
