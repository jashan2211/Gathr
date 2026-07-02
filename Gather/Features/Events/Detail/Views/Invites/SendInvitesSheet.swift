import SwiftUI
import MessageUI

struct SendInvitesSheet: View {
    let event: Event
    let preselectedGuests: [UUID]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var inviteService = InviteService.shared

    // MARK: Routing

    /// How invites get delivered: smart routing (default) buckets guests by
    /// best channel automatically; manual pins everything to one channel.
    private enum SendRoute: Equatable {
        case auto
        case channel(InviteChannel)
    }

    /// One unit of work in the smart-send chain.
    private struct SendBatch {
        enum Kind { case messages, emailBlast }
        let kind: Kind
        let guests: [Guest]
    }

    /// Which in-app compose sheet is up.
    private enum ComposeFlow: String, Identifiable {
        case smsSequential
        case emailSequential
        case emailBlast
        var id: String { rawValue }
    }

    // Selections
    @State private var selectedGuestIds: Set<UUID> = []
    @State private var selectedFunctions: Set<UUID> = []
    @State private var route: SendRoute = .auto

    // Sending state
    @State private var isSending = false          // external-app stepper overlay
    @State private var sentCount = 0
    @State private var failedCount = 0
    @State private var showComplete = false
    @State private var sendingAsReminder = false  // frozen at flow start so wording can't flip mid-batch

    // Smart-send batch chain
    @State private var pendingBatches: [SendBatch] = []

    // In-app compose queue (Messages / Mail, one guest at a time)
    @State private var activeCompose: ComposeFlow?
    @State private var composeGuests: [Guest] = []
    @State private var composeIndex = 0
    @State private var composeAwaitingRetry = false
    @State private var blastGuests: [Guest] = []
    @State private var showEmailStyleDialog = false

    // External-app stepper (WhatsApp always; SMS/Email only as fallback)
    @State private var sendQueue: [Guest] = []
    @State private var currentSendIndex = 0
    @State private var totalToSend = 0
    @State private var externalChannel: InviteChannel = .whatsapp
    @State private var externalAwaitingReturn = false
    @State private var externalConfirmStage = false

    // mailto: blast fallback — confirm once for the whole BCC batch on return
    @State private var blastAwaitingReturn = false
    @State private var showBlastConfirm = false

    // Share-link hero
    @State private var linkCopied = false
    @State private var templateCopied = false
    @State private var showShareSheet = false
    @State private var showQRSheet = false
    @State private var showQRShareSheet = false

    // "Copy all links" confirmation (guest section)
    @State private var allLinksCopied = false

    // "Needs contact info" tap-through
    @State private var contactFixGuest: Guest?

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
        ZStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Share-link hero — zero-friction path that works for everyone
                    shareLinkHero
                        .bouncyAppear()

                    // Quick Actions Header
                    quickActionsSection
                        .bouncyAppear(delay: 0.05)

                    // Smart routing plan (auto mode)
                    if route == .auto {
                        routingPlanSection
                            .bouncyAppear(delay: 0.1)
                    }

                    // Guest Selection Summary
                    guestSelectionSection
                        .bouncyAppear(delay: 0.15)

                    // Function Selection (if applicable)
                    if !event.functions.isEmpty {
                        functionSelectionSection
                            .bouncyAppear(delay: 0.2)
                    }

                    // Channel Selection
                    channelSelectionSection
                        .bouncyAppear(delay: 0.25)
                }
                .horizontalPadding()
                .padding(.vertical, Spacing.md)
            }
            .safeAreaInset(edge: .bottom) { sendButtonBar }
            .disabled(isSending)

            // External-app stepper — kept outside the disabled scope so its
            // own buttons stay tappable.
            if isSending {
                sendingOverlay
            }
        }
        .navigationTitle(isRemindMode ? "Send Reminders" : "Send Invites")
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
        .sheet(item: $activeCompose) { flow in
            composeFlowSheet(flow)
                .interactiveDismissDisabled()
        }
        .sheet(item: $contactFixGuest) { guest in
            GuestDetailSheet(guest: guest, event: event)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareActivitySheet(items: shareItems)
        }
        .sheet(isPresented: $showQRSheet) {
            qrCodeSheet
        }
        .confirmationDialog(
            isRemindMode ? "Send email reminders" : "Send email invites",
            isPresented: $showEmailStyleDialog,
            titleVisibility: .visible
        ) {
            Button("Everyone at once (BCC blast)") {
                startEmailBlast(guests: guestsForChannel(.email))
            }
            Button("Personalized, one by one") {
                startSequentialEmail(guests: guestsForChannel(.email))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The blast sends one email with everyone BCC'd and a shared RSVP link. One-by-one gives each guest their personal link.")
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Returning from WhatsApp/Messages/Mail — ask whether it sent.
            if newPhase == .active && isSending && externalAwaitingReturn {
                externalAwaitingReturn = false
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    externalConfirmStage = true
                }
            }
            if newPhase == .active && blastAwaitingReturn {
                blastAwaitingReturn = false
                showBlastConfirm = true
            }
        }
        .alert("Did the email send?", isPresented: $showBlastConfirm) {
            Button("Yes, Mark All Sent") {
                for guest in blastGuests {
                    markGuestSent(guest, via: .email)
                    sentCount += 1
                }
                HapticService.success()
                runNextBatch()
            }
            Button("No, Didn't Send", role: .cancel) {
                failedCount += blastGuests.count
                runNextBatch()
            }
        } message: {
            Text("If you sent the email to \(blastGuests.count) guests, they'll be marked as invited.")
        }
    }

    // MARK: - Share Link Hero

    private var shareURLString: String {
        inviteService.generateShareableLink(event: event)?.absoluteString ?? ""
    }

    private var shareItems: [Any] {
        ["You're invited to \(event.title)!\nRSVP: \(shareURLString)"]
    }

    private var shareLinkHero: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                Button {
                    HapticService.buttonTap()
                    showQRSheet = true
                } label: {
                    InviteQRCodeView(urlString: shareURLString)
                        .frame(width: 64, height: 64)
                        .padding(6)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .strokeBorder(Color.gatherSecondaryText.opacity(0.15), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Show QR code for the event link")

                VStack(alignment: .leading, spacing: 3) {
                    Text("EVENT LINK")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .tracking(0.5)
                        .foregroundStyle(Color.gatherSecondaryText)

                    Text(shareURLString)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text("Anyone with the link can RSVP")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: Spacing.sm) {
                Button {
                    copyShareLink()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: linkCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(linkCopied ? "Copied!" : "Copy Link")
                            .font(GatherFont.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(linkCopied ? Color.rsvpYesFallback : Color.gatherPrimaryText)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(Capsule())
                }
                .accessibilityLabel(linkCopied ? "Link copied" : "Copy event link")

                Button {
                    HapticService.buttonTap()
                    showShareSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Share…")
                            .font(GatherFont.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.gatherPrimaryText)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(Capsule())
                }
                .accessibilityLabel("Share event link")
            }

            Divider()

            // Ready-to-paste blurb (title, date/functions, location + link) —
            // one tap to copy, one paste into the group chat.
            Button {
                copyMessageTemplate()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: templateCopied ? "checkmark.circle.fill" : "text.bubble.fill")
                        .font(.callout)
                        .foregroundStyle(templateCopied ? Color.rsvpYesFallback : Color.accentPurpleFallback)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("MESSAGE TEMPLATE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .tracking(0.5)
                            .foregroundStyle(Color.gatherSecondaryText)

                        Text(messageTemplatePreviewText)
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherPrimaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: Spacing.xs)

                    Text(templateCopied ? "Copied!" : "Copy")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(templateCopied ? Color.rsvpYesFallback : Color.accentPurpleFallback)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background((templateCopied ? Color.rsvpYesFallback : Color.accentPurpleFallback).opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .accessibilityLabel(templateCopied
                ? "Message template copied"
                : "Copy message template with event details and RSVP link, ready to paste in a group chat")
        }
        .padding(Spacing.md)
        .surfaceCard(cornerRadius: CornerRadius.md)
    }

    /// Group-chat blurb: the blast body already carries the title, the
    /// date/functions, the location, and the universal share link.
    private var messageTemplate: String {
        inviteService.generateEmailBlastBody(event: event, functions: selectedFunctionsList)
    }

    /// The template collapsed to one flowing line for the two-line preview.
    private var messageTemplatePreviewText: String {
        messageTemplate
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "  ")
    }

    private func copyMessageTemplate() {
        UIPasteboard.general.string = messageTemplate
        HapticService.success()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            templateCopied = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                templateCopied = false
            }
        }
    }

    private func copyShareLink() {
        UIPasteboard.general.string = shareURLString
        HapticService.success()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            linkCopied = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                linkCopied = false
            }
        }
    }

    /// Copy every selected guest's personalized RSVP link as a newline block —
    /// "Name: link" per line. Unlike the send-path copy channel, this does not
    /// mark anyone as invited; it's a lightweight grab-and-paste helper.
    private func copyAllPersonalizedLinks() {
        let guests = selectedGuests.sorted { $0.name < $1.name }
        guard !guests.isEmpty else { return }

        let block = guests.compactMap { guest -> String? in
            guard let link = inviteService.generateInviteLink(guest: guest, event: event) else { return nil }
            return "\(guest.name): \(link.absoluteString)"
        }.joined(separator: "\n")

        guard !block.isEmpty else { return }
        UIPasteboard.general.string = block
        HapticService.success()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            allLinksCopied = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                allLinksCopied = false
            }
        }
    }

    private var qrCodeSheet: some View {
        VStack(spacing: Spacing.lg) {
            Text(event.title)
                .font(GatherFont.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.gatherPrimaryText)
                .multilineTextAlignment(.center)

            // QR stays dark-on-white so it scans in dark mode too.
            InviteQRCodeView(urlString: shareURLString)
                .frame(width: 230, height: 230)
                .padding(Spacing.md)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                .accessibilityLabel("QR code for the event RSVP link")

            Text("Anyone with the link can RSVP")
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)

            Button {
                HapticService.buttonTap()
                showQRShareSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.callout)
                    Text("Share Link")
                        .font(GatherFont.callout)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: Layout.buttonHeight)
                .background(LinearGradient.gatherAccentGradient)
                .clipShape(Capsule())
            }
            .accessibilityLabel("Share event link")
        }
        .horizontalPadding()
        .padding(.vertical, Spacing.xl)
        .presentationDetents([.medium])
        .sheet(isPresented: $showQRShareSheet) {
            ShareActivitySheet(items: shareItems)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: Spacing.sm) {
            InviteQuickActionPill(
                title: "All Guests",
                count: event.guests.count,
                icon: "person.2.fill",
                isSelected: allGuestsSelected,
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        selectedGuestIds = Set(event.guests.map { $0.id })
                    }
                    HapticService.buttonTap()
                }
            )

            InviteQuickActionPill(
                title: "Not Sent",
                count: guestsNotSent.count,
                icon: "bell.badge",
                isSelected: selectedGuestIds == Set(guestsNotSent.map { $0.id }) && !guestsNotSent.isEmpty,
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        selectedGuestIds = Set(guestsNotSent.map { $0.id })
                    }
                    HapticService.buttonTap()
                }
            )

            InviteQuickActionPill(
                title: "Custom",
                count: selectedGuestIds.count,
                icon: "hand.tap",
                isSelected: !selectedGuestIds.isEmpty && !allGuestsSelected && selectedGuestIds != Set(guestsNotSent.map { $0.id }),
                isInteractive: false,
                action: {}
            )
        }
    }

    /// Every guest is selected (and there's at least one) — drives the
    /// "All Guests" pill's selected state without lighting up on an empty list.
    private var allGuestsSelected: Bool {
        !event.guests.isEmpty && selectedGuestIds.count == event.guests.count
    }

    // MARK: - Smart Routing Plan

    private var routingPlanSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentPurpleFallback)
                Text(isRemindMode ? "Reminder Plan" : "Delivery Plan")
                    .font(GatherFont.headline)
            }

            if selectedGuests.isEmpty {
                Text("Select guests below and each one is routed to the best channel automatically.")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            } else {
                if !smsBucket.isEmpty {
                    InvitePlanRow(
                        icon: "message.fill",
                        count: smsBucket.count,
                        label: "via Messages",
                        color: Color.rsvpYesFallback
                    )
                }

                if !emailOnlyBucket.isEmpty {
                    InvitePlanRow(
                        icon: "envelope.fill",
                        count: emailOnlyBucket.count,
                        label: emailOnlyBucket.count == 1 ? "via Email" : "via Email (one BCC blast)",
                        color: Color.accentPurpleFallback
                    )
                }

                if !missingContactGuests.isEmpty {
                    InvitePlanRow(
                        icon: "exclamationmark.triangle.fill",
                        count: missingContactGuests.count,
                        label: "missing contact info",
                        color: Color.rsvpMaybeFallback
                    )

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("NEEDS CONTACT INFO")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .tracking(0.5)
                            .foregroundStyle(Color.gatherSecondaryText)

                        ForEach(missingContactGuests) { guest in
                            Button {
                                HapticService.buttonTap()
                                contactFixGuest = guest
                            } label: {
                                HStack {
                                    Text(guest.name)
                                        .font(GatherFont.callout)
                                        .foregroundStyle(Color.gatherPrimaryText)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("Add info")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.accentPurpleFallback)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(Color.gatherSecondaryText)
                                }
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(Color.gatherTertiaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                            }
                            .accessibilityLabel("Add contact info for \(guest.name)")
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
        .surfaceCard(cornerRadius: CornerRadius.md)
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

                // Copy every selected guest's personalized link as one block
                Button {
                    copyAllPersonalizedLinks()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: allLinksCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                        Text(allLinksCopied ? "Copied!" : "Copy all links")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(allLinksCopied ? Color.rsvpYesFallback : Color.accentPurpleFallback)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background((allLinksCopied ? Color.rsvpYesFallback : Color.accentPurpleFallback).opacity(0.1))
                    .clipShape(Capsule())
                }
                .disabled(selectedGuestIds.isEmpty)
                .opacity(selectedGuestIds.isEmpty ? 0.4 : 1)
                .accessibilityLabel(allLinksCopied ? "All links copied" : "Copy all personalized RSVP links")

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
                GatherEmptyState(
                    icon: "person.badge.plus",
                    title: "No guests yet",
                    message: "Add guests from the Guests tab, then come back to invite them."
                )
                .padding(.vertical, Spacing.xs)
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

            // Smart send — the recommended default
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    route = .auto
                }
                HapticService.buttonTap()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "wand.and.stars")
                        .font(.callout)
                        .foregroundStyle(route == .auto ? .white : Color.accentPurpleFallback)
                        .frame(width: 36, height: 36)
                        .background(
                            route == .auto
                                ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                                : AnyShapeStyle(Color.accentPurpleFallback.opacity(0.1))
                        )
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Smart send")
                            .font(GatherFont.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.gatherPrimaryText)
                        Text("Messages for phones, email for the rest")
                            .font(.caption2)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }

                    Spacer()

                    if route == .auto {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(Color.accentPurpleFallback)
                    }
                }
                .padding(Spacing.sm)
                .background(route == .auto ? Color.accentPurpleFallback.opacity(0.08) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            }
            .accessibilityLabel("Smart send, routes each guest to the best channel automatically")

            HStack(spacing: Spacing.sm) {
                ForEach([InviteChannel.whatsapp, .sms, .email, .copied], id: \.self) { channel in
                    ChannelButton(
                        channel: channel,
                        isSelected: route == .channel(channel),
                        availableCount: guestsForChannel(channel).count,
                        totalCount: selectedGuestIds.count,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                route = .channel(channel)
                            }
                            HapticService.buttonTap()
                        }
                    )
                }
            }

            if let warning = routeWarning {
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

    // MARK: - Bottom Send Bar

    private var sendButtonBar: some View {
        VStack(spacing: Spacing.xs) {
            if !bottomCaption.isEmpty {
                Text(bottomCaption)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .lineLimit(1)
            }

            Button {
                startSend()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: ctaIcon)
                        .font(.callout)
                    Text(ctaTitle)
                        .font(GatherFont.callout)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: Layout.buttonHeight)
                .background(
                    canSend
                        ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                        : AnyShapeStyle(Color.gatherSecondaryText.opacity(0.3))
                )
                .clipShape(Capsule())
            }
            .disabled(!canSend)
            .accessibilityLabel(ctaTitle)
            .scaleEffect(canSend ? 1.0 : 0.97)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: canSend)
        }
        .horizontalPadding()
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .background(
            LinearGradient(
                colors: [
                    Color.gatherBackground.opacity(0),
                    Color.gatherBackground.opacity(0.92),
                    Color.gatherBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var ctaTitle: String {
        switch route {
        case .auto:
            return isRemindMode ? "Send Reminders to All" : "Send to All"
        case .channel(let channel):
            return isRemindMode ? "Remind via \(channel.shortName)" : "Send via \(channel.shortName)"
        }
    }

    private var ctaIcon: String {
        switch route {
        case .auto: return "paperplane.fill"
        case .channel(let channel): return channel.icon
        }
    }

    private var bottomCaption: String {
        switch route {
        case .auto:
            return planSummary
        case .channel(let channel):
            let count = guestsForChannel(channel).count
            guard count > 0 else { return "" }
            return isRemindMode
                ? "\(count) reminder\(count == 1 ? "" : "s") ready"
                : "\(count) invite\(count == 1 ? "" : "s") ready"
        }
    }

    private var planSummary: String {
        var parts: [String] = []
        if !smsBucket.isEmpty { parts.append("\(smsBucket.count) via Messages") }
        if !emailOnlyBucket.isEmpty { parts.append("\(emailOnlyBucket.count) via Email") }
        if !missingContactGuests.isEmpty { parts.append("\(missingContactGuests.count) missing contact") }
        return parts.joined(separator: " · ")
    }

    // MARK: - In-App Compose Flow (Messages / Mail)

    @ViewBuilder
    private func composeFlowSheet(_ flow: ComposeFlow) -> some View {
        switch flow {
        case .smsSequential:
            sequentialComposeView(isEmail: false)
        case .emailSequential:
            sequentialComposeView(isEmail: true)
        case .emailBlast:
            emailBlastComposeView
        }
    }

    private func sequentialComposeView(isEmail: Bool) -> some View {
        VStack(spacing: 0) {
            composeProgressHeader

            Divider()

            if composeAwaitingRetry, let guest = currentComposeGuest {
                composeRetryPrompt(guest: guest)
            } else if let guest = currentComposeGuest {
                if isEmail {
                    InviteMailComposeView(
                        toRecipients: [guest.email ?? ""],
                        bccRecipients: [],
                        subject: emailSubject,
                        body: messageBody(for: guest),
                        onFinish: { result in handleSequentialMailResult(result) }
                    )
                    .id(guest.id)
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    InviteMessageComposeView(
                        recipients: [inviteService.sanitizedPhone(guest.phone ?? "")],
                        body: messageBody(for: guest),
                        onFinish: { result in handleSequentialMessageResult(result) }
                    )
                    .id(guest.id)
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .background(Color.gatherBackground)
    }

    private var composeProgressHeader: some View {
        VStack(spacing: Spacing.xs) {
            HStack {
                Text(composeHeaderTitle)
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .lineLimit(1)

                Spacer()

                Button {
                    stopComposeFlow()
                } label: {
                    Text("Stop")
                        .font(GatherFont.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.rsvpNoFallback)
                }
                .accessibilityLabel("Stop sending")
            }

            ProgressView(
                value: Double(min(composeIndex, composeGuests.count)),
                total: Double(max(composeGuests.count, 1))
            )
            .tint(Color.accentPurpleFallback)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Spacing.sm)
        .background(Color.gatherBackground)
    }

    private var composeHeaderTitle: String {
        let position = min(composeIndex + 1, max(composeGuests.count, 1))
        let verb = sendingAsReminder ? "Reminding" : "Sending"
        if let name = currentComposeGuest?.name {
            return "\(verb) \(position) of \(composeGuests.count) — \(name)"
        }
        return "\(verb) \(position) of \(composeGuests.count)"
    }

    private func composeRetryPrompt(guest: Guest) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.bubble")
                .font(.system(size: 44))
                .foregroundStyle(Color.rsvpMaybeFallback)

            VStack(spacing: Spacing.xxs) {
                Text("Message to \(guest.name) wasn't sent")
                    .font(GatherFont.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .multilineTextAlignment(.center)

                Text("Retry to reopen the message, or skip to the next guest.")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
            }

            Button {
                HapticService.buttonTap()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    composeAwaitingRetry = false
                }
            } label: {
                Text("Retry")
                    .font(GatherFont.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: Layout.buttonHeight)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
            }
            .accessibilityLabel("Retry sending to \(guest.name)")

            Button {
                skipCurrentCompose()
            } label: {
                Text("Skip \(guest.name)")
                    .font(GatherFont.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .frame(maxWidth: .infinity, minHeight: Layout.buttonHeight)
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(Capsule())
            }
            .accessibilityLabel("Skip \(guest.name)")

            Spacer()
        }
        .horizontalPadding()
    }

    private var emailBlastComposeView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(sendingAsReminder ? "Reminder Blast" : "Email Blast")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)
                Text("\(blastGuests.count) guest\(blastGuests.count == 1 ? "" : "s") BCC'd — one email, one tap")
                    .font(.caption2)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(Color.gatherBackground)
            .accessibilityElement(children: .combine)

            Divider()

            InviteMailComposeView(
                toRecipients: [],
                bccRecipients: blastGuests.compactMap { $0.email },
                subject: emailSubject,
                body: blastBody,
                onFinish: { result in handleBlastResult(result) }
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .background(Color.gatherBackground)
    }

    // MARK: - Compose Flow Handlers

    private var currentComposeGuest: Guest? {
        guard composeIndex < composeGuests.count else { return nil }
        return composeGuests[composeIndex]
    }

    private func handleSequentialMessageResult(_ result: MessageComposeResult) {
        guard let guest = currentComposeGuest else { return }
        switch result {
        case .sent:
            markGuestSent(guest, via: .sms)
            sentCount += 1
            HapticService.success()
            advanceComposeQueue()
        case .cancelled, .failed:
            HapticService.warning()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                composeAwaitingRetry = true
            }
        @unknown default:
            skipCurrentCompose()
        }
    }

    private func handleSequentialMailResult(_ result: MFMailComposeResult) {
        guard let guest = currentComposeGuest else { return }
        switch result {
        case .sent:
            markGuestSent(guest, via: .email)
            sentCount += 1
            HapticService.success()
            advanceComposeQueue()
        case .cancelled, .saved, .failed:
            HapticService.warning()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                composeAwaitingRetry = true
            }
        @unknown default:
            skipCurrentCompose()
        }
    }

    private func handleBlastResult(_ result: MFMailComposeResult) {
        switch result {
        case .sent:
            for guest in blastGuests {
                markGuestSent(guest, via: .email)
                sentCount += 1
            }
            HapticService.success()
        case .cancelled, .saved, .failed:
            failedCount += blastGuests.count
        @unknown default:
            failedCount += blastGuests.count
        }

        if pendingBatches.isEmpty {
            activeCompose = nil
            finishSending()
        } else {
            runNextBatch()
        }
    }

    private func skipCurrentCompose() {
        failedCount += 1
        HapticService.buttonTap()
        advanceComposeQueue()
    }

    private func advanceComposeQueue() {
        composeAwaitingRetry = false
        composeIndex += 1
        guard composeIndex >= composeGuests.count else { return }

        if pendingBatches.isEmpty {
            activeCompose = nil
            finishSending()
        } else {
            // Next batch swaps the sheet content in place (e.g. SMS -> blast).
            runNextBatch()
        }
    }

    private func stopComposeFlow() {
        HapticService.buttonTap()
        let remaining = composeGuests.count - composeIndex
        failedCount += max(remaining, 0)
        for batch in pendingBatches {
            failedCount += batch.guests.count
        }
        pendingBatches = []
        activeCompose = nil
        finishSending()
    }

    // MARK: - External-App Stepper (WhatsApp + fallbacks)

    /// WhatsApp has no in-app compose API, so it keeps the external stepper:
    /// open the app for one guest, return to Gather, confirm, repeat.
    private var sendingOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Text("\(sendingAsReminder ? "Reminding" : "Sending") \(min(currentSendIndex + 1, totalToSend)) of \(totalToSend)")
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

                    if externalConfirmStage {
                        Text("Did the message send in \(externalChannel.shortName)?")
                            .font(GatherFont.callout)
                            .foregroundStyle(Color.gatherPrimaryText)
                            .multilineTextAlignment(.center)

                        Button {
                            confirmExternalSent()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                Text(currentSendIndex + 1 < totalToSend ? "Mark Sent · Next Guest" : "Mark Sent · Finish")
                                    .fontWeight(.bold)
                            }
                            .font(GatherFont.callout)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: Layout.buttonHeight)
                            .background(LinearGradient.gatherAccentGradient)
                            .clipShape(Capsule())
                        }
                        .accessibilityLabel("Mark \(guest.name) as sent and continue")
                    } else {
                        Button {
                            openExternalForCurrentGuest()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: externalChannel.icon)
                                Text("Open \(externalChannel.shortName)")
                                    .fontWeight(.bold)
                            }
                            .font(GatherFont.callout)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: Layout.buttonHeight)
                            .background(LinearGradient.gatherAccentGradient)
                            .clipShape(Capsule())
                        }
                        .accessibilityLabel("Open \(externalChannel.shortName) for \(guest.name)")
                    }

                    Button("Skip this guest") {
                        skipCurrentExternalGuest()
                    }
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .accessibilityLabel("Skip \(guest.name)")
                }

                Button("Stop sending") {
                    stopExternalStepper()
                }
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.rsvpNoFallback)
                .accessibilityLabel("Stop sending")

                Text(externalConfirmStage
                     ? "Confirm so delivery is tracked for this guest."
                     : "Opens \(externalChannel.shortName) prefilled for one guest. Send it there, then come back to Gather.")
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

    private var currentSendGuest: Guest? {
        guard currentSendIndex < sendQueue.count else { return nil }
        return sendQueue[currentSendIndex]
    }

    private func startExternalStepper(channel: InviteChannel, guests: [Guest]) {
        externalChannel = channel
        sendQueue = guests
        totalToSend = guests.count
        currentSendIndex = 0
        externalAwaitingReturn = false
        externalConfirmStage = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isSending = true
        }
    }

    private func openExternalForCurrentGuest() {
        guard let guest = currentSendGuest else { return }
        HapticService.buttonTap()

        let body = messageBody(for: guest)
        let opened: Bool
        switch externalChannel {
        case .whatsapp:
            opened = inviteService.sendViaWhatsApp(guest: guest, message: body)
        case .sms:
            opened = inviteService.sendViaSMS(guest: guest, message: body)
        case .email:
            opened = inviteService.sendViaEmail(to: [guest.email ?? ""], bcc: [], subject: emailSubject, body: body)
        case .copied, .inAppLink:
            opened = false
        }

        if opened {
            externalAwaitingReturn = true
        } else {
            failedCount += 1
            advanceExternalQueue()
        }
    }

    private func confirmExternalSent() {
        guard let guest = currentSendGuest else { return }
        markGuestSent(guest, via: externalChannel)
        sentCount += 1
        HapticService.success()
        externalConfirmStage = false
        advanceExternalQueue()
    }

    private func skipCurrentExternalGuest() {
        failedCount += 1
        HapticService.buttonTap()
        externalAwaitingReturn = false
        externalConfirmStage = false
        advanceExternalQueue()
    }

    private func advanceExternalQueue() {
        currentSendIndex += 1
        guard currentSendIndex >= totalToSend else { return }

        isSending = false
        if pendingBatches.isEmpty {
            finishSending()
        } else {
            runNextBatch()
        }
    }

    private func stopExternalStepper() {
        HapticService.buttonTap()
        let remaining = totalToSend - currentSendIndex
        failedCount += max(remaining, 0)
        for batch in pendingBatches {
            failedCount += batch.guests.count
        }
        pendingBatches = []
        externalAwaitingReturn = false
        externalConfirmStage = false
        isSending = false
        finishSending()
    }

    // MARK: - Completion View

    private var completionTitle: String {
        if sentCount == 0 { return "Sending Stopped" }
        return sendingAsReminder ? "Reminders Sent!" : "Invites Sent!"
    }

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

                    Image(systemName: sentCount > 0 ? "checkmark.circle.fill" : "stop.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(sentCount > 0 ? Color.rsvpYesFallback : Color.gatherSecondaryText)
                        .bouncyAppear(delay: 0.1)
                }

                VStack(spacing: Spacing.sm) {
                    Text(completionTitle)
                        .gatherTitle()
                        .foregroundStyle(Color.gatherPrimaryText)
                        .bouncyAppear(delay: 0.15)

                    Text(sentCount > 0
                         ? "Delivery is tracked per guest. Reopen this screen anytime to send reminders."
                         : "No invites were sent. You can come back and try again anytime.")
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
                    .frame(maxWidth: .infinity, minHeight: Layout.buttonHeight)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
                }
                .horizontalPadding()
                .padding(.bottom, Spacing.lg)
                .bouncyAppear(delay: 0.4)
                .accessibilityLabel("Done")
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Selection Helpers

    private var guestsNotSent: [Guest] {
        event.guests.filter { $0.inviteSentAt == nil }
    }

    private var selectedGuests: [Guest] {
        event.guests.filter { selectedGuestIds.contains($0.id) }
    }

    /// Guests reachable by phone — routed to the Messages batch.
    private var smsBucket: [Guest] {
        selectedGuests
            .filter { !($0.phone ?? "").isEmpty }
            .sorted { $0.name < $1.name }
    }

    /// Guests with no phone but an email — routed to the one-tap email blast.
    private var emailOnlyBucket: [Guest] {
        selectedGuests
            .filter { ($0.phone ?? "").isEmpty && !($0.email ?? "").isEmpty }
            .sorted { $0.name < $1.name }
    }

    /// Guests with no contact info at all — surfaced for fixing, never silently dropped.
    private var missingContactGuests: [Guest] {
        selectedGuests
            .filter { ($0.phone ?? "").isEmpty && ($0.email ?? "").isEmpty }
            .sorted { $0.name < $1.name }
    }

    /// Every selected guest already got an invite -> the sheet becomes a
    /// reminder flow with shorter nudge copy.
    private var isRemindMode: Bool {
        let guests = selectedGuests
        return !guests.isEmpty && guests.allSatisfy { $0.inviteSentAt != nil }
    }

    private var canSend: Bool {
        guard !selectedGuestIds.isEmpty,
              event.functions.isEmpty || !selectedFunctions.isEmpty else { return false }
        switch route {
        case .auto:
            return !smsBucket.isEmpty || !emailOnlyBucket.isEmpty
        case .channel(let channel):
            if channel == .whatsapp && !inviteService.isWhatsAppInstalled { return false }
            return !guestsForChannel(channel).isEmpty
        }
    }

    /// Accurate, non-misleading warning for the selected route. Distinguishes
    /// "WhatsApp not installed" from "guest has no phone number".
    private var routeWarning: String? {
        switch route {
        case .auto:
            return nil // the plan card surfaces missing-contact guests
        case .channel(let channel):
            if channel == .whatsapp && !inviteService.isWhatsAppInstalled {
                return "WhatsApp isn't installed — choose SMS or Email instead"
            }
            guard channel != .copied else { return nil }
            let missing = selectedGuestIds.count - guestsForChannel(channel).count
            guard missing > 0 else { return nil }
            let contact = channel == .email ? "an email address" : "a phone number"
            let guestWord = missing == 1 ? "guest has" : "guests have"
            return "\(missing) selected \(guestWord) no \(contact)"
        }
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
        let guests = selectedGuests
        switch channel {
        case .whatsapp:
            return guests.filter { inviteService.canSendViaWhatsApp(guest: $0) }
        case .sms:
            return guests.filter { inviteService.canSendViaSMS(guest: $0) }
        case .email:
            return guests.filter { inviteService.canSendViaEmail(guest: $0) }
        case .copied, .inAppLink:
            return guests
        }
    }

    private var selectedFunctionsList: [EventFunction] {
        event.functions.filter { selectedFunctions.contains($0.id) }
    }

    // MARK: - Message Builders

    private var emailSubject: String {
        // Only the frozen flag — isRemindMode flips live as guests get marked
        // sent mid-batch, which would switch later batches to reminder copy.
        sendingAsReminder
            ? "Reminder: \(event.title)"
            : "You're invited to \(event.title)!"
    }

    private var blastBody: String {
        inviteService.generateEmailBlastBody(
            event: event,
            functions: selectedFunctionsList,
            isReminder: sendingAsReminder
        )
    }

    private func messageBody(for guest: Guest) -> String {
        sendingAsReminder
            ? inviteService.generateReminderMessage(guest: guest, event: event, functions: selectedFunctionsList)
            : inviteService.generateInviteMessage(guest: guest, event: event, functions: selectedFunctionsList)
    }

    // MARK: - Send Orchestration

    private func startSend() {
        guard canSend else { return }
        HapticService.buttonTap()
        sendingAsReminder = isRemindMode
        sentCount = 0
        failedCount = 0

        switch route {
        case .auto:
            startSmartSend()
        case .channel(.sms):
            let guests = guestsForChannel(.sms)
            guard !guests.isEmpty else { return }
            prepareInvites(for: guests)
            pendingBatches = [SendBatch(kind: .messages, guests: guests)]
            runNextBatch()
        case .channel(.email):
            guard !guestsForChannel(.email).isEmpty else { return }
            showEmailStyleDialog = true
        case .channel(.whatsapp):
            let guests = guestsForChannel(.whatsapp)
            guard !guests.isEmpty else { return }
            prepareInvites(for: guests)
            pendingBatches = []
            startExternalStepper(channel: .whatsapp, guests: guests)
        case .channel(.copied), .channel(.inAppLink):
            copyAllLinks()
        }
    }

    /// "Send to all": phones go to a Messages batch, email-only guests to one
    /// BCC blast, and the two run back-to-back. Guests with no contact info
    /// stay listed on the plan card for fixing.
    private func startSmartSend() {
        let messages = smsBucket
        let emails = emailOnlyBucket
        guard !messages.isEmpty || !emails.isEmpty else { return }

        prepareInvites(for: messages + emails)

        pendingBatches = []
        if !messages.isEmpty {
            pendingBatches.append(SendBatch(kind: .messages, guests: messages))
        }
        if !emails.isEmpty {
            pendingBatches.append(SendBatch(kind: .emailBlast, guests: emails))
        }
        runNextBatch()
    }

    private func runNextBatch() {
        guard !pendingBatches.isEmpty else {
            activeCompose = nil
            finishSending()
            return
        }

        let batch = pendingBatches.removeFirst()
        switch batch.kind {
        case .messages:
            if MFMessageComposeViewController.canSendText() {
                composeGuests = batch.guests
                composeIndex = 0
                composeAwaitingRetry = false
                activeCompose = .smsSequential
            } else {
                // Simulator / SMS-incapable device — external sms: URL stepper.
                activeCompose = nil
                startExternalStepper(channel: .sms, guests: batch.guests)
            }
        case .emailBlast:
            blastGuests = batch.guests
            if MFMailComposeViewController.canSendMail() {
                activeCompose = .emailBlast
            } else {
                // No mail account configured — fall back to a mailto: with BCC.
                // Don't mark anyone sent yet: the user may discard the draft.
                // Confirm once for the whole blast when they return to the app.
                activeCompose = nil
                let opened = inviteService.sendViaEmail(
                    to: [],
                    bcc: batch.guests.compactMap { $0.email },
                    subject: emailSubject,
                    body: blastBody
                )
                if opened {
                    blastAwaitingReturn = true
                } else {
                    failedCount += batch.guests.count
                    runNextBatch()
                }
            }
        }
    }

    private func startEmailBlast(guests: [Guest]) {
        guard !guests.isEmpty else { return }
        prepareInvites(for: guests)
        pendingBatches = [SendBatch(kind: .emailBlast, guests: guests)]
        runNextBatch()
    }

    private func startSequentialEmail(guests: [Guest]) {
        guard !guests.isEmpty else { return }
        prepareInvites(for: guests)
        pendingBatches = []
        if MFMailComposeViewController.canSendMail() {
            composeGuests = guests
            composeIndex = 0
            composeAwaitingRetry = false
            activeCompose = .emailSequential
        } else {
            startExternalStepper(channel: .email, guests: guests)
        }
    }

    /// "Copy" is the only channel that can genuinely be done in one action:
    /// build a single block of links for all selected guests.
    private func copyAllLinks() {
        let guests = guestsForChannel(.copied)
        guard !guests.isEmpty else { return }

        prepareInvites(for: guests)

        let block = guests.compactMap { guest -> String? in
            guard let link = inviteService.generateInviteLink(guest: guest, event: event) else { return nil }
            return "\(guest.name): \(link.absoluteString)"
        }.joined(separator: "\n")
        UIPasteboard.general.string = block

        for guest in guests {
            markGuestSent(guest, via: .copied)
            sentCount += 1
        }
        finishSending()
    }

    /// Pre-create invite records so per-function status can be tracked.
    private func prepareInvites(for guests: [Guest]) {
        _ = inviteService.createFunctionInvites(
            for: guests,
            functions: selectedFunctionsList,
            modelContext: modelContext
        )
    }

    private func markGuestSent(_ guest: Guest, via channel: InviteChannel) {
        guest.inviteSentAt = Date()
        guest.inviteSentVia = channel
        for function in selectedFunctionsList {
            if let invite = function.invites.first(where: { $0.guestId == guest.id }) {
                inviteService.markInviteSent(invite: invite, channel: channel, modelContext: modelContext)
            }
        }
    }

    private func finishSending() {
        modelContext.safeSave()
        // No success celebration when the user stopped or skipped everything.
        if sentCount > 0 {
            HapticService.success()
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            showComplete = true
        }
    }
}

// MARK: - Preview

#Preview {
    let event = Event(title: "Wedding", startDate: Date())
    SendInvitesSheet(event: event, preselectedGuests: [])
}
