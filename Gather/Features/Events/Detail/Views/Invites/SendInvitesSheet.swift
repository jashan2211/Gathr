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

    // Sequential send queue — external apps can only be opened one at a time.
    @State private var sendQueue: [Guest] = []
    @State private var currentSendIndex = 0
    @State private var totalToSend = 0

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
            // Default to the first channel that can actually reach the guests,
            // so the send button isn't dead when WhatsApp isn't installed.
            if let best = [InviteChannel.whatsapp, .sms, .email, .copied]
                .first(where: { channel in
                    if channel == .whatsapp && !inviteService.isWhatsAppInstalled { return false }
                    return !guestsForChannel(channel).isEmpty
                }) {
                selectedChannel = best
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
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
                    .horizontalPadding()
                    .padding(.vertical, Spacing.md)
                }

                // Floating send bar
                sendButtonBar
            }
            .disabled(isSending)

            // Sequential send stepper — kept outside the disabled scope so its
            // own buttons stay tappable.
            if isSending {
                sendingOverlay
            }
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
                .accessibilityLabel("Close")
                .disabled(isSending)
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
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.accentPurpleFallback.opacity(0.1))
                    .clipShape(Capsule())
            }

            if event.guests.isEmpty {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "person.badge.plus")
                        .font(.title2)
                        .foregroundStyle(Color.gatherSecondaryText.opacity(0.5))
                    Text("No guests added yet")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
            } else {
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
        }
        .padding(Spacing.md)
        .surfaceCard(cornerRadius: CornerRadius.md)
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
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
                        .padding(.vertical, Spacing.xxs)
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
        .surfaceCard(cornerRadius: CornerRadius.md)
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
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                selectedChannel = channel
                            }
                            HapticService.buttonTap()
                        }
                    )
                }
            }

            if let warning = channelWarning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(warning)
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
        .padding(Spacing.md)
        .surfaceCard(cornerRadius: CornerRadius.md)
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
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: canSend)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Spacing.sm)
            // Floating bar over scrolling content — glass stays per design whitelist.
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 15, y: -6)
            )
        }
    }

    // MARK: - Sending Stepper

    /// External apps (WhatsApp, Messages, Mail) can only be opened one at a
    /// time, so invites are sent guest-by-guest with an explicit tap each.
    private var sendingOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Text("Guest \(min(currentSendIndex + 1, totalToSend)) of \(totalToSend)")
                    .font(GatherFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.gatherSecondaryText)

                ProgressView(
                    value: Double(currentSendIndex),
                    total: Double(max(totalToSend, 1))
                )
                .tint(Color.accentPurpleFallback)
                .frame(width: 200)

                if let guest = currentSendGuest {
                    VStack(spacing: Spacing.xxs) {
                        Text(guest.name)
                            .font(GatherFont.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.gatherPrimaryText)
                        if let contact = guest.displayContact {
                            Text(contact)
                                .font(GatherFont.caption)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                    }

                    Button {
                        sendToCurrentGuest()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selectedChannel.icon)
                            Text("Send via \(selectedChannel.shortName)")
                                .fontWeight(.bold)
                        }
                        .font(GatherFont.callout)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                    }

                    Button("Skip this guest") {
                        skipCurrentGuest()
                    }
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
                }

                Text("Opens \(selectedChannel.shortName) for one guest. Send the message, then come back here for the next.")
                    .font(.caption2)
                    .foregroundStyle(Color.gatherSecondaryText.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 320)
            .surfaceCard(cornerRadius: CornerRadius.lg)
            .padding(Spacing.xl)
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        ZStack {
            Color.gatherBackground
                .ignoresSafeArea()

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
                    Text("Invites Prepared!")
                        .gatherTitle()
                        .foregroundStyle(Color.gatherPrimaryText)
                        .bouncyAppear(delay: 0.15)

                    Text("Message windows were opened. Please confirm each was sent.")
                        .font(GatherFont.body)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .multilineTextAlignment(.center)
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
                .horizontalPadding()

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
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
                }
                .horizontalPadding()
                .padding(.bottom, Spacing.lg)
                .bouncyAppear(delay: 0.4)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Helpers

    private var guestsNotSent: [Guest] {
        event.guests.filter { $0.inviteSentAt == nil }
    }

    private var currentSendGuest: Guest? {
        guard currentSendIndex < sendQueue.count else { return nil }
        return sendQueue[currentSendIndex]
    }

    private var canSend: Bool {
        guard !selectedGuestIds.isEmpty,
              event.functions.isEmpty || !selectedFunctions.isEmpty,
              !guestsForChannel(selectedChannel).isEmpty else { return false }
        if selectedChannel == .whatsapp && !inviteService.isWhatsAppInstalled { return false }
        return true
    }

    /// Accurate, non-misleading warning for the selected channel. Distinguishes
    /// "WhatsApp not installed" from "guest has no phone number".
    private var channelWarning: String? {
        if selectedChannel == .whatsapp && !inviteService.isWhatsAppInstalled {
            return "WhatsApp isn't installed — choose SMS or Email instead"
        }
        guard selectedChannel != .copied else { return nil }
        let missing = selectedGuestIds.count - guestsForChannel(selectedChannel).count
        guard missing > 0 else { return nil }
        let contact = selectedChannel == .email ? "an email address" : "a phone number"
        let guestWord = missing == 1 ? "guest has" : "guests have"
        return "\(missing) selected \(guestWord) no \(contact)"
    }

    private func toggleGuest(_ id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if selectedGuestIds.contains(id) {
                selectedGuestIds.remove(id)
            } else {
                selectedGuestIds.insert(id)
            }
        }
    }

    private func toggleFunction(_ id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
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

    private var selectedFunctionsList: [EventFunction] {
        event.functions.filter { selectedFunctions.contains($0.id) }
    }

    private func sendInvites() {
        let guestsToSend = guestsForChannel(selectedChannel)
        guard !guestsToSend.isEmpty else { return }

        sentCount = 0
        failedCount = 0

        // Pre-create invite records so per-function status can be tracked.
        _ = inviteService.createFunctionInvites(
            for: guestsToSend,
            functions: selectedFunctionsList,
            modelContext: modelContext
        )

        // "Copy" is the only channel that can genuinely be done in one action:
        // build a single block of links for all selected guests.
        if selectedChannel == .copied {
            let block = guestsToSend.compactMap { guest -> String? in
                guard let link = inviteService.generateInviteLink(guest: guest, event: event) else { return nil }
                return "\(guest.name): \(link.absoluteString)"
            }.joined(separator: "\n")
            UIPasteboard.general.string = block

            let functions = selectedFunctionsList
            for guest in guestsToSend {
                markGuestSent(guest, functions: functions)
                sentCount += 1
            }
            modelContext.safeSave()
            HapticService.success()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showComplete = true }
            return
        }

        // WhatsApp / SMS / Email each open an external app. iOS only honors one
        // open() at a time, so guests are processed sequentially via the stepper.
        sendQueue = guestsToSend
        totalToSend = guestsToSend.count
        currentSendIndex = 0
        isSending = true
    }

    private func sendToCurrentGuest() {
        guard let guest = currentSendGuest else { return }
        let functions = selectedFunctionsList

        var success = false
        switch selectedChannel {
        case .whatsapp:
            success = inviteService.sendViaWhatsApp(guest: guest, event: event, functions: functions)
        case .sms:
            success = inviteService.sendViaSMS(guest: guest, event: event, functions: functions)
        case .email:
            success = inviteService.sendViaEmail(guest: guest, event: event, functions: functions)
        case .copied, .inAppLink:
            success = true
        }

        if success {
            markGuestSent(guest, functions: functions)
            sentCount += 1
        } else {
            failedCount += 1
        }
        advanceSendQueue()
    }

    private func skipCurrentGuest() {
        failedCount += 1
        advanceSendQueue()
    }

    private func advanceSendQueue() {
        currentSendIndex += 1
        guard currentSendIndex >= totalToSend else { return }

        modelContext.safeSave()
        isSending = false
        HapticService.success()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showComplete = true }
    }

    private func markGuestSent(_ guest: Guest, functions: [EventFunction]) {
        guest.inviteSentAt = Date()
        guest.inviteSentVia = selectedChannel
        for function in functions {
            if let invite = function.invites.first(where: { $0.guestId == guest.id }) {
                inviteService.markInviteSent(invite: invite, channel: selectedChannel, modelContext: modelContext)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let event = Event(title: "Wedding", startDate: Date())
    SendInvitesSheet(event: event, preselectedGuests: [])
}
