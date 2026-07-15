import SwiftUI

struct GuestsTab: View {
    @Bindable var event: Event
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    /// Multi-select mode only. Sends no longer borrow this set — they write
    /// `invitePreselection` — so the two states can't leak into each other.
    @State private var selectedGuests: Set<UUID> = []
    @State private var isSelectionMode = false
    /// Who the send sheet opens with. Set fresh by every send entry point.
    @State private var invitePreselection: Set<UUID> = []
    @State private var showAddGuest = false
    @State private var showSendInvites = false
    @State private var selectedGuest: Guest?
    @State private var filterStatus: GuestFilter = .all
    @State private var guestPendingRemoval: Guest?
    @State private var showBulkRemoveConfirmation = false
    @State private var guestPendingPromotion: Guest?
    /// Holds a pending bulk "Mark Going" that would exceed capacity, until
    /// the host confirms.
    @State private var bulkStatusOverCapacity: RSVPStatus?
    @State private var dietaryExpanded = false
    // Bulk-invite action row (host)
    @State private var showShareLinkSheet = false
    @State private var shareLinkCopied = false
    // Export guest list (host)
    @State private var showExportSheet = false
    // Default to status sort so the roster opens grouped (Going / Maybe /
    // Pending …) — the most useful organizing view for a host.
    @AppStorage("guestSortOrder") private var guestSortOrderRaw = GuestSortOrder.status.rawValue
    @EnvironmentObject var authManager: AuthManager

    private var sortOrder: GuestSortOrder {
        GuestSortOrder(rawValue: guestSortOrderRaw) ?? .name
    }

    private var isHost: Bool {
        event.hostId == authManager.currentUser?.id
    }

    /// Guests who haven't been sent an invite yet — the natural target for
    /// "Invite everyone". Falls back to all guests if everyone's been invited.
    private var guestsNotYetInvited: [Guest] {
        event.guests.filter { $0.inviteSentAt == nil }
    }

    /// Guests who were sent an invite but still haven't responded — the
    /// natural target for "Remind pending".
    private var pendingInvitedGuests: [Guest] {
        event.guests.filter { $0.status == .pending && $0.inviteSentAt != nil }
    }

    /// A single link anyone can RSVP through, for pasting into a group chat.
    private var shareLinkURLString: String {
        InviteService.shared.generateShareableLink(event: event)?.absoluteString ?? ""
    }

    private var shareLinkItems: [Any] {
        ["You're invited to \(event.title)!\nRSVP: \(shareLinkURLString)"]
    }

    /// Lookup dictionary: [functionId: [guestId: FunctionInvite]]
    /// Avoids O(i) scans per guest per function in FunctionStatusChip.
    private var inviteLookup: [UUID: [UUID: FunctionInvite]] {
        var lookup: [UUID: [UUID: FunctionInvite]] = [:]
        for function in event.functions {
            var guestMap: [UUID: FunctionInvite] = [:]
            for invite in function.invites {
                guestMap[invite.guestId] = invite
            }
            lookup[function.id] = guestMap
        }
        return lookup
    }

    /// Privacy: non-hosts on public events see first names only
    private var isPrivacyMode: Bool {
        !isHost && event.privacy == .publicEvent &&
        (event.guestListVisibility == .firstNamesOnly || event.guestListVisibility == .visible)
    }

    enum GuestSortOrder: String, CaseIterable {
        case name
        case status
        case recentlyAdded
        case partySize

        var displayName: String {
            switch self {
            case .name: return "Name"
            case .status: return "RSVP status"
            case .recentlyAdded: return "Recently added"
            case .partySize: return "Party size"
            }
        }

        var icon: String {
            switch self {
            case .name: return "textformat"
            case .status: return "envelope.open"
            case .recentlyAdded: return "clock"
            case .partySize: return "person.3"
            }
        }
    }

    /// One filter model for the whole tab. "Not invited" and "Awaiting reply"
    /// are disjoint (they sum to the old catch-all "Pending"), and Maybe /
    /// Waitlist are first-class cases now — no parallel side-pill booleans.
    /// Labels track RSVPStatus.displayName ("Going" / "Can't Go").
    enum GuestFilter: String, CaseIterable {
        case all = "All"
        case notInvited = "Not invited"
        case awaitingReply = "Awaiting reply"
        case going = "Going"
        case maybe = "Maybe"
        case cantGo = "Can't Go"
        case waitlist = "Waitlist"

        var icon: String {
            switch self {
            case .all: return "person.3"
            case .notInvited: return "envelope"
            case .awaitingReply: return "paperplane"
            case .going: return "checkmark.circle"
            case .maybe: return "questionmark.circle"
            case .cantGo: return "xmark.circle"
            case .waitlist: return "list.bullet"
            }
        }

        var color: Color {
            switch self {
            case .all: return .accentPurpleFallback
            case .notInvited: return .gatherSecondaryText
            case .awaitingReply: return .neonBlue
            case .going: return .rsvpYesFallback
            case .maybe: return .rsvpMaybeFallback
            case .cantGo: return .rsvpNoFallback
            case .waitlist: return .rsvpMaybeFallback
            }
        }

        /// The single source of truth for both the pill count and the list —
        /// so a pill's number always matches the rows it shows.
        func matches(_ guest: Guest) -> Bool {
            switch self {
            case .all: return true
            case .notInvited: return guest.status == .pending && guest.inviteSentAt == nil
            case .awaitingReply: return guest.status == .pending && guest.inviteSentAt != nil
            case .going: return guest.status == .attending
            case .maybe: return guest.status == .maybe
            case .cantGo: return guest.status == .declined
            case .waitlist: return guest.status == .waitlisted
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isPrivacyMode && !isHost {
                // Privacy mode: first names + avatars only
                privacyGuestList
            } else if event.guestListVisibility == .countOnly && !isHost {
                // Count only mode
                countOnlyView
            } else if event.guestListVisibility == .hidden && !isHost {
                // Hidden mode
                hiddenView
            } else {
                // Roster-first: the guest list is the point of this tab, so
                // the header, search, filters and invite actions sit above it
                // and the reference summaries (headcount, dietary) move below.
                // Previously ~7 chrome rows pushed every guest off the screen.

                // Header with actions
                headerSection

                // Search Bar
                searchBar

                // Status Summary Bar (filter pills)
                statusSummaryBar

                // Prominent bulk-invite actions
                if isHost, !event.guests.isEmpty {
                    bulkInviteRow

                    // Nudge invited-but-unresponded guests in one tap
                    if !pendingInvitedGuests.isEmpty {
                        remindPendingRow
                    }
                }

                // Guest List
                if filteredGuests.isEmpty {
                    emptyState
                } else {
                    guestList
                }

                // Reference summaries live below the roster, still one scroll away.
                if isHost {
                    // Headcount summary strip
                    headcountSummaryStrip

                    // Dietary needs summary
                    dietarySummaryCard
                }
            }
        }
        .sheet(isPresented: $showAddGuest) {
            AddGuestSheet(event: event)
                // Tall enough that the Add Guest CTA stays visible above the
                // keyboard during rapid batch entry.
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSendInvites) {
            SendInvitesSheet(
                event: event,
                preselectedGuests: Array(invitePreselection)
            )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedGuest) { guest in
            GuestDetailSheet(guest: guest, event: event, isHost: isHost)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareLinkSheet) {
            ShareActivitySheet(items: shareLinkItems)
        }
        .sheet(isPresented: $showExportSheet) {
            ShareActivitySheet(items: [exportGuestListText])
        }
        .alert(
            "Remove Guest",
            isPresented: Binding(
                get: { guestPendingRemoval != nil },
                set: { if !$0 { guestPendingRemoval = nil } }
            )
        ) {
            Button("Remove", role: .destructive) {
                if let guest = guestPendingRemoval {
                    removeGuest(guest)
                }
                guestPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { guestPendingRemoval = nil }
        } message: {
            Text("Are you sure you want to remove \(guestPendingRemoval?.name ?? "this guest") from this event? This action cannot be undone.")
        }
        .alert(
            "Remove \(selectedGuests.count) Guest\(selectedGuests.count == 1 ? "" : "s")",
            isPresented: $showBulkRemoveConfirmation
        ) {
            Button("Remove", role: .destructive) { bulkRemoveSelected() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove \(selectedGuests.count) guest\(selectedGuests.count == 1 ? "" : "s") from this event? This action cannot be undone.")
        }
        .confirmationDialog(
            "Event is at capacity — promote anyway?",
            isPresented: Binding(
                get: { guestPendingPromotion != nil },
                set: { if !$0 { guestPendingPromotion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Promote") {
                if let guest = guestPendingPromotion {
                    applyStatus(.attending, to: guest)
                }
                guestPendingPromotion = nil
            }
            Button("Cancel", role: .cancel) { guestPendingPromotion = nil }
        }
        .confirmationDialog(
            "This will exceed capacity",
            isPresented: Binding(
                get: { bulkStatusOverCapacity != nil },
                set: { if !$0 { bulkStatusOverCapacity = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Mark Going Anyway") {
                if let status = bulkStatusOverCapacity {
                    performBulkApplyStatus(status)
                }
                bulkStatusOverCapacity = nil
            }
            Button("Cancel", role: .cancel) { bulkStatusOverCapacity = nil }
        } message: {
            if let capacity = event.capacity {
                Text("Marking these guests Going puts attendance over the \(capacity)-guest capacity.")
            }
        }
    }

    // MARK: - Status Summary Bar

    private var statusSummaryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(GuestFilter.allCases, id: \.self) { filter in
                    let count = countForFilter(filter)
                    // Maybe / Waitlist only appear once someone is in that
                    // state — no dead zero-count pills cluttering the row.
                    if !(count == 0 && (filter == .maybe || filter == .waitlist)) {
                        StatusPill(
                            filter: filter,
                            count: count,
                            isSelected: filterStatus == filter,
                            onTap: { selectFilter(filter) }
                        )
                    }
                }
            }
            .horizontalPadding()
            .padding(.vertical, Spacing.sm)
        }
    }

    /// Tap a status pill to filter; tap the active pill again to clear back to All.
    private func selectFilter(_ filter: GuestFilter) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            filterStatus = (filterStatus == filter) ? .all : filter
        }
        HapticService.selection()
    }

    // MARK: - Headcount Summary Strip

    /// Expected headcount: everyone going or maybe, including party members.
    private var expectedHeadcount: Int {
        event.guests
            .filter { $0.status == .attending || $0.status == .maybe }
            .reduce(0) { $0 + $1.totalHeadcount }
    }

    @ViewBuilder
    private var headcountSummaryStrip: some View {
        if !event.guests.isEmpty {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(event.attendingCount) going · \(event.maybeCount) maybe · \(event.pendingCount) pending")
                        .font(GatherFont.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .contentTransition(.numericText())

                    Text("\(expectedHeadcount) expected")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .contentTransition(.numericText())
                }

                Spacer()

                if let capacity = event.capacity, capacity > 0 {
                    capacityChip(capacity: capacity)
                }
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(cornerRadius: CornerRadius.md)
            .horizontalPadding()
            .padding(.bottom, Spacing.sm)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(headcountAccessibilityLabel)
        }
    }

    private func capacityChip(capacity: Int) -> some View {
        let tint: Color = event.isFull
            ? .rsvpNoFallback
            : (Double(event.attendingCount) >= Double(capacity) * 0.9
                ? .rsvpMaybeFallback
                : .gatherSecondaryText)

        return Text("\(event.attendingCount) of \(capacity) capacity")
            .font(GatherFont.caption)
            .fontWeight(.medium)
            .foregroundStyle(tint)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private var headcountAccessibilityLabel: String {
        var label = "\(event.attendingCount) going, \(event.maybeCount) maybe, \(event.pendingCount) pending. \(expectedHeadcount) expected."
        if let capacity = event.capacity, capacity > 0 {
            label += " \(event.attendingCount) of \(capacity) capacity."
        }
        return label
    }

    // MARK: - Bulk Invite Row

    /// Two prominent, effortless bulk actions for the host: invite every
    /// not-yet-invited guest in one tap, or grab a single shareable RSVP link
    /// to drop into a group chat.
    private var bulkInviteRow: some View {
        HStack(spacing: Spacing.sm) {
            // Invite everyone → SendInvitesSheet preselected with not-yet-invited
            Button {
                inviteEveryone()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                        .font(.caption)
                    Text("Invite everyone")
                        .gatherRowTitle()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Layout.minTouchTarget)
                .background(LinearGradient.gatherAccentGradient)
                .clipShape(Capsule())
            }
            .accessibilityLabel(
                inviteEveryoneCount > 0
                    ? "Invite everyone, \(inviteEveryoneCount) not yet invited"
                    : "Invite everyone"
            )

            // Share event link → copy + system share sheet
            Button {
                shareEventLink()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: shareLinkCopied ? "checkmark" : "link")
                        .font(.caption)
                    Text(shareLinkCopied ? "Copied!" : "Share link")
                        .gatherRowTitle()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(shareLinkCopied ? Color.rsvpYesFallback : Color.gatherPrimaryText)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Layout.minTouchTarget)
                .background(Color.gatherElevated)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.gatherSeparator.opacity(0.6), lineWidth: 1)
                )
            }
            .accessibilityLabel(shareLinkCopied ? "Event link copied" : "Share event link")
            .accessibilityHint("Copies a link anyone can RSVP through and opens the share sheet")
        }
        .horizontalPadding()
        .padding(.bottom, Spacing.sm)
    }

    /// How many guests "Invite everyone" would target — used for the label.
    private var inviteEveryoneCount: Int {
        guestsNotYetInvited.isEmpty ? event.guests.count : guestsNotYetInvited.count
    }

    /// Preselect the not-yet-invited guests (or all, if everyone's been invited)
    /// and open the send sheet — without flipping into multi-select mode.
    private func inviteEveryone() {
        let targets = guestsNotYetInvited.isEmpty ? event.guests : guestsNotYetInvited
        invitePreselection = Set(targets.map { $0.id })
        HapticService.buttonTap()
        showSendInvites = true
    }

    // MARK: - Remind Pending Row

    /// Compact nudge affordance below the bulk-invite actions: preselects
    /// every guest who was sent an invite but hasn't responded and opens
    /// SendInvitesSheet — its remind mode auto-detects already-invited guests
    /// and switches to reminder copy.
    private var remindPendingRow: some View {
        Button {
            remindPending()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bell.badge")
                    .font(.caption)
                    .foregroundStyle(Color.rsvpMaybeFallback)
                Text("Remind \(pendingInvitedGuests.count) pending")
                    .font(GatherFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .contentTransition(.numericText())
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .imageScale(.small)
                    .foregroundStyle(Color.gatherTertiaryText)
            }
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Layout.minTouchTarget)
            .background(Color.rsvpMaybeFallback.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.rsvpMaybeFallback.opacity(0.25), lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .horizontalPadding()
        .padding(.bottom, Spacing.sm)
        .accessibilityLabel("Remind \(pendingInvitedGuests.count) pending guest\(pendingInvitedGuests.count == 1 ? "" : "s")")
        .accessibilityHint("Opens the send sheet with invited guests who haven't responded preselected")
    }

    /// Preselect exactly the invited-but-pending guests and open the send
    /// sheet (same pattern as inviteEveryone).
    private func remindPending() {
        invitePreselection = Set(pendingInvitedGuests.map { $0.id })
        HapticService.buttonTap()
        showSendInvites = true
    }

    /// Copy the shareable RSVP link, flash a "Copied!" confirmation, and present
    /// the system share sheet so the host can paste it anywhere.
    private func shareEventLink() {
        UIPasteboard.general.string = shareLinkURLString
        HapticService.success()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            shareLinkCopied = true
        }
        showShareLinkSheet = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                shareLinkCopied = false
            }
        }
    }

    // MARK: - Dietary Needs Summary

    /// Grouped dietary needs across guests and party members.
    /// Free-form fields are split on commas and grouped case-insensitively.
    /// Declined guests are excluded; entries are deduped per restriction by
    /// guest/member id (not display name, which can collide).
    private var dietaryNeeds: [(label: String, names: [String])] {
        var order: [String] = []
        var groups: [String: (label: String, entries: [(id: UUID, name: String)])] = [:]

        func add(_ raw: String?, id: UUID, name: String) {
            guard let raw else { return }
            for part in raw.split(separator: ",") {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let key = trimmed.lowercased()
                if groups[key] == nil {
                    groups[key] = (label: trimmed, entries: [])
                    order.append(key)
                }
                if groups[key]?.entries.contains(where: { $0.id == id }) == false {
                    groups[key]?.entries.append((id: id, name: name))
                }
            }
        }

        for guest in event.guests where guest.status != .declined {
            add(guest.metadata?.dietaryRestrictions, id: guest.id, name: guest.name)
            add(guest.metadata?.mealChoice, id: guest.id, name: guest.name)
            for member in guest.partyMembers {
                add(member.dietaryRestrictions, id: member.id, name: "\(member.name) (\(guest.name)'s party)")
            }
        }

        return order
            .compactMap { groups[$0] }
            .map { (label: $0.label, names: $0.entries.map { $0.name }) }
            .sorted { lhs, rhs in
                if lhs.names.count != rhs.names.count {
                    return lhs.names.count > rhs.names.count
                }
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
    }

    @ViewBuilder
    private var dietarySummaryCard: some View {
        let needs = dietaryNeeds
        if !needs.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        dietaryExpanded.toggle()
                    }
                    HapticService.buttonTap()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "fork.knife")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentPurpleFallback)

                            Text("Dietary needs")
                                .font(GatherFont.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.gatherPrimaryText)

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.gatherSecondaryText)
                                .rotationEffect(.degrees(dietaryExpanded ? 180 : 0))
                        }

                        Text(needs.map { "\($0.names.count) \($0.label)" }.joined(separator: " · "))
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .lineLimit(dietaryExpanded ? nil : 1)
                            .multilineTextAlignment(.leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dietary needs: \(needs.map { "\($0.names.count) \($0.label)" }.joined(separator: ", "))")
                .accessibilityHint(dietaryExpanded ? "Double tap to collapse" : "Double tap to expand and see who")
                .accessibilityAddTraits(dietaryExpanded ? [.isSelected] : [])

                if dietaryExpanded {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        ForEach(needs, id: \.label) { need in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(need.label)
                                    .font(GatherFont.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.gatherPrimaryText)
                                Text(need.names.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundStyle(Color.gatherSecondaryText)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.top, Spacing.xxs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(cornerRadius: CornerRadius.md)
            .horizontalPadding()
            .padding(.bottom, Spacing.sm)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            if isSelectionMode {
                Button("Cancel") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isSelectionMode = false
                        selectedGuests.removeAll()
                    }
                }
                .font(GatherFont.callout)

                Button(allFilteredSelected ? "Deselect All" : "Select All") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        if allFilteredSelected {
                            selectedGuests.subtract(filteredGuests.map { $0.id })
                        } else {
                            selectedGuests.formUnion(filteredGuests.map { $0.id })
                        }
                    }
                    HapticService.buttonTap()
                }
                .font(GatherFont.callout)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentPurpleFallback)
                .padding(.leading, Spacing.sm)
                .accessibilityLabel(allFilteredSelected ? "Deselect all filtered guests" : "Select all filtered guests")

                Spacer()

                Text("\(selectedGuests.count) selected")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .contentTransition(.numericText())

                Spacer()

                Button {
                    // Selection mode → send: hand the current picks to the sheet.
                    invitePreselection = selectedGuests
                    showSendInvites = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                        Text("Send")
                    }
                    .font(GatherFont.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        selectedGuests.isEmpty
                            ? AnyShapeStyle(Color.gatherSecondaryText.opacity(0.4))
                            : AnyShapeStyle(LinearGradient.gatherAccentGradient)
                    )
                    .clipShape(Capsule())
                }
                .disabled(selectedGuests.isEmpty)

                // Bulk status changes + bulk remove
                Menu {
                    Button {
                        bulkApplyStatus(.attending)
                    } label: {
                        Label("Mark Going", systemImage: "checkmark.circle")
                    }
                    Button {
                        bulkApplyStatus(.maybe)
                    } label: {
                        Label("Mark Maybe", systemImage: "questionmark.circle")
                    }
                    Button {
                        bulkApplyStatus(.declined)
                    } label: {
                        Label("Mark Can't Go", systemImage: "xmark.circle")
                    }
                    Button {
                        bulkApplyStatus(.pending)
                    } label: {
                        Label("Mark Pending", systemImage: "clock")
                    }
                    Divider()
                    Button(role: .destructive) {
                        HapticService.warning()
                        showBulkRemoveConfirmation = true
                    } label: {
                        Label(
                            "Remove \(selectedGuests.count) Guest\(selectedGuests.count == 1 ? "" : "s")",
                            systemImage: "trash"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(
                            selectedGuests.isEmpty
                                ? Color.gatherSecondaryText.opacity(0.4)
                                : Color.gatherSecondaryText
                        )
                        .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .disabled(selectedGuests.isEmpty)
                .accessibilityLabel("More bulk actions")
                .accessibilityHint("Change RSVP status or remove the selected guests")
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(event.guests.count) Guests")
                        .font(GatherFont.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .accessibilityAddTraits(.isHeader)
                    if event.attendingCount > 0 {
                        Text("\(event.attendingCount) confirmed")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }

                Spacer()

                if isHost {
                    hostActionButtons
                }
            }
        }
        .horizontalPadding()
        .padding(.vertical, Spacing.sm)
    }

    /// Sort / select / send / add affordances — host only.
    private var hostActionButtons: some View {
        HStack(spacing: Spacing.xs) {
            if !event.guests.isEmpty {
                // Sort menu
                Menu {
                    Picker("Sort guests", selection: $guestSortOrderRaw) {
                        ForEach(GuestSortOrder.allCases, id: \.rawValue) { order in
                            Label(order.displayName, systemImage: order.icon)
                                .tag(order.rawValue)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.title3)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Sort guests")
                .accessibilityValue("Sorted by \(sortOrder.displayName)")

                // Select button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { isSelectionMode = true }
                } label: {
                    Image(systemName: "checklist")
                        .font(.title3)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Select guests")

                // Quick send button
                Button {
                    invitePreselection = Set(event.guests.map { $0.id })
                    showSendInvites = true
                } label: {
                    Image(systemName: "paperplane")
                        .font(.title3)
                        .foregroundStyle(Color.accentPurpleFallback)
                        .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Send invites")

                // More actions (export)
                Menu {
                    Button {
                        HapticService.buttonTap()
                        showExportSheet = true
                    } label: {
                        Label("Export guest list", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More guest actions")
            }

            // Add button — the primary action, so it gets a labeled pill
            // instead of a fifth bare icon.
            Button {
                HapticService.buttonTap()
                showAddGuest = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Add")
                        .gatherRowTitle()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: Layout.minTouchTarget)
                .background(LinearGradient.gatherAccentGradient)
                .clipShape(Capsule())
                .contentShape(Capsule())
            }
            .accessibilityLabel("Add guest")
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.gatherSecondaryText)
                .font(.callout)

            TextField("Search guests...", text: $searchText)
                .font(GatherFont.body)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.gatherSecondaryText)
                        .font(.callout)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(Spacing.sm)
        .background(Color.gatherElevated)
        .clipShape(Capsule())
        .horizontalPadding()
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        // Content-only: Spacers don't expand inside the outer page scroll,
        // so use fixed vertical breathing room instead.
        Group {
            if event.guests.isEmpty {
                GatherEmptyState(
                    icon: "person.2",
                    title: "No Guests Yet",
                    message: isHost
                        ? "Add your first guest to start building the list."
                        : "The host hasn't added any guests yet.",
                    actionTitle: isHost ? "Add Guest" : nil,
                    action: isHost ? { showAddGuest = true } : nil
                )
            } else {
                GatherEmptyState(
                    icon: "person.2",
                    title: "No Matching Guests",
                    message: "Try adjusting your search or filters.",
                    actionTitle: "Clear Filters",
                    action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            searchText = ""
                            filterStatus = .all
                        }
                        HapticService.buttonTap()
                    }
                )
            }
        }
        .padding(.vertical, Spacing.xl)
        .horizontalPadding()
    }

    // MARK: - Guest List

    private var guestList: some View {
        // Content-only: EventDetailView owns the page scroll.
        Group {
            LazyVStack(spacing: Spacing.sm) {
                if groupByStatus {
                    // Section landmarks make a long roster scannable when the
                    // host is sorting by status and hasn't narrowed the list.
                    ForEach(statusGroups, id: \.status) { group in
                        Section {
                            ForEach(group.guests) { guest in
                                guestCard(guest)
                            }
                        } header: {
                            guestGroupHeader(group.status, count: group.guests.count)
                        }
                    }
                } else {
                    ForEach(filteredGuests) { guest in
                        guestCard(guest)
                    }
                }
            }
            .horizontalPadding()
            .padding(.bottom, Layout.scrollBottomInset)
        }
    }

    /// Group into status sections only when sorting by status with no active
    /// filter/search — otherwise a flat list reads cleaner.
    private var groupByStatus: Bool {
        sortOrder == .status && filterStatus == .all && searchText.isEmpty
    }

    private var statusGroups: [(status: RSVPStatus, guests: [Guest])] {
        let order: [RSVPStatus] = [.attending, .maybe, .pending, .waitlisted, .declined]
        return order.compactMap { status in
            let guests = filteredGuests.filter { $0.status == status }
            return guests.isEmpty ? nil : (status, guests)
        }
    }

    private func guestGroupHeader(_ status: RSVPStatus, count: Int) -> some View {
        HStack {
            Text("\(status.displayName) · \(count)")
                .gatherEyebrow()
                .foregroundStyle(Color.gatherSecondaryText)
            Spacer()
        }
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xxs)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func guestCard(_ guest: Guest) -> some View {
        ImprovedGuestCard(
            guest: guest,
            event: event,
            inviteLookup: inviteLookup,
            isSelected: selectedGuests.contains(guest.id),
            isSelectionMode: isSelectionMode,
            onTap: {
                if isSelectionMode {
                    toggleSelection(guest)
                } else {
                    selectedGuest = guest
                }
            },
            onSetStatus: isHost ? { status in
                setStatus(status, for: guest)
            } : nil,
            onSendInvite: isHost ? {
                sendInvite(to: guest)
            } : nil,
            onRemove: isHost ? {
                HapticService.warning()
                guestPendingRemoval = guest
            } : nil
        )
    }

    // MARK: - Helpers

    private func countForFilter(_ filter: GuestFilter) -> Int {
        event.guests.filter { filter.matches($0) }.count
    }

    private var filteredGuests: [Guest] {
        var guests = event.guests

        // Search filter
        if !searchText.isEmpty {
            guests = guests.filter { guest in
                guest.name.localizedCaseInsensitiveContains(searchText) ||
                (guest.email?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (guest.phone?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Status filter — one predicate shared with the pill counts.
        guests = guests.filter { filterStatus.matches($0) }

        return sorted(guests)
    }

    private func sorted(_ guests: [Guest]) -> [Guest] {
        switch sortOrder {
        case .name:
            return guests.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .status:
            return guests.sorted {
                if statusRank($0.status) != statusRank($1.status) {
                    return statusRank($0.status) < statusRank($1.status)
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .recentlyAdded:
            return guests.sorted {
                if $0.invitedAt != $1.invitedAt {
                    return $0.invitedAt > $1.invitedAt
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .partySize:
            return guests.sorted {
                if $0.totalHeadcount != $1.totalHeadcount {
                    return $0.totalHeadcount > $1.totalHeadcount
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    private func statusRank(_ status: RSVPStatus) -> Int {
        switch status {
        case .attending: return 0
        case .maybe: return 1
        case .pending: return 2
        case .waitlisted: return 3
        case .declined: return 4
        }
    }

    private var allFilteredSelected: Bool {
        let guests = filteredGuests
        return !guests.isEmpty && guests.allSatisfy { selectedGuests.contains($0.id) }
    }

    private func toggleSelection(_ guest: Guest) {
        if selectedGuests.contains(guest.id) {
            selectedGuests.remove(guest.id)
        } else {
            selectedGuests.insert(guest.id)
        }
    }

    // MARK: - Quick Actions

    /// RSVP change from row menu / context menu. Mirrors GuestDetailSheet:
    /// any non-pending status stamps respondedAt. Promoting a waitlisted
    /// guest while the event is full asks for confirmation first.
    private func setStatus(_ status: RSVPStatus, for guest: Guest) {
        guard guest.status != status else { return }
        if status == .attending && guest.status == .waitlisted && event.isFull {
            guestPendingPromotion = guest
            return
        }
        applyStatus(status, to: guest)
    }

    private func applyStatus(_ status: RSVPStatus, to guest: Guest) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            guest.status = status
            if status != .pending {
                guest.respondedAt = Date()
            }
        }
        modelContext.safeSave()
        HapticService.buttonTap()
    }

    /// Single-guest invite via the existing SendInvitesSheet path.
    private func sendInvite(to guest: Guest) {
        invitePreselection = [guest.id]
        showSendInvites = true
    }

    // MARK: - Bulk Actions

    /// Apply an RSVP status to every selected guest in one pass. Mirrors
    /// applyStatus (non-pending statuses stamp respondedAt) with a single
    /// save and haptic for the whole batch. Selection stays active so the
    /// host can follow up (e.g. send invites to the same group).
    private func bulkApplyStatus(_ status: RSVPStatus) {
        let targets = event.guests.filter { selectedGuests.contains($0.id) }
        guard !targets.isEmpty else { return }
        // Capacity guard: marking a batch Going can blow past capacity — the
        // single-row waitlist promotion already confirms this, so mirror it
        // for bulk instead of silently overfilling the event.
        if status == .attending, let capacity = event.capacity, capacity > 0 {
            let newlyAttending = targets.filter { $0.status != .attending }.count
            if event.attendingCount + newlyAttending > capacity {
                bulkStatusOverCapacity = status
                return
            }
        }
        performBulkApplyStatus(status)
    }

    private func performBulkApplyStatus(_ status: RSVPStatus) {
        let targets = event.guests.filter { selectedGuests.contains($0.id) }
        guard !targets.isEmpty else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            for guest in targets where guest.status != status {
                guest.status = status
                if status != .pending {
                    guest.respondedAt = Date()
                }
            }
        }
        modelContext.safeSave()
        HapticService.success()
    }

    /// Remove every selected guest (after the confirmation alert). Mirrors
    /// removeGuest — deletes function invites and cloud RSVPs too — with a
    /// single save, then exits selection mode.
    private func bulkRemoveSelected() {
        let targets = event.guests.filter { selectedGuests.contains($0.id) }
        guard !targets.isEmpty else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            for guest in targets {
                event.guests.removeAll { $0.id == guest.id }
                for function in event.functions {
                    let orphanedInvites = function.invites.filter { $0.guestId == guest.id }
                    for invite in orphanedInvites {
                        modelContext.delete(invite)
                    }
                    function.invites.removeAll { $0.guestId == guest.id }
                }
                FirestoreService.shared.deleteRSVP(eventId: event.id, guestId: guest.id)
                modelContext.delete(guest)
            }
            isSelectionMode = false
            selectedGuests.removeAll()
        }
        modelContext.safeSave()
        HapticService.success()
    }

    private func removeGuest(_ guest: Guest) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            event.guests.removeAll { $0.id == guest.id }
        }
        // Delete related function invites (not just unlink — avoids orphaned rows)
        for function in event.functions {
            let orphanedInvites = function.invites.filter { $0.guestId == guest.id }
            for invite in orphanedInvites {
                modelContext.delete(invite)
            }
            function.invites.removeAll { $0.guestId == guest.id }
        }
        selectedGuests.remove(guest.id)
        // Also drop any cloud RSVP so this guest can't be re-created from an
        // orphaned rsvps doc on the next sync.
        FirestoreService.shared.deleteRSVP(eventId: event.id, guestId: guest.id)
        modelContext.delete(guest)
        modelContext.safeSave()
        HapticService.success()
    }

    // MARK: - Export Guest List

    /// Plain-text guest list for pasting into a message to caterers/venues:
    /// totals header, then one section per status with one line per guest
    /// (name, status, party size, contact, dietary needs).
    private var exportGuestListText: String {
        var lines: [String] = []
        lines.append("Guest list — \(event.title)")
        lines.append("\(event.attendingCount) going / \(event.maybeCount) maybe / \(event.pendingCount) pending")
        lines.append("Expected headcount: \(expectedHeadcount)")

        let sections: [(status: RSVPStatus, title: String)] = [
            (.attending, "GOING"),
            (.maybe, "MAYBE"),
            (.pending, "PENDING"),
            (.waitlisted, "WAITLISTED"),
            (.declined, "DECLINED")
        ]

        for section in sections {
            let group = event.guests
                .filter { $0.status == section.status }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            guard !group.isEmpty else { continue }

            lines.append("")
            lines.append("\(section.title) (\(group.count))")
            for guest in group {
                lines.append(exportLine(for: guest))
            }
        }

        return lines.joined(separator: "\n")
    }

    /// One line per guest: name, status, +N party, contact, dietary — the
    /// optional fields only appear when present.
    private func exportLine(for guest: Guest) -> String {
        var parts: [String] = []

        var name = "• \(guest.name) — \(guest.status.displayName)"
        if guest.totalHeadcount > 1 {
            name += " (+\(guest.totalHeadcount - 1) party)"
        }
        parts.append(name)

        if let phone = guest.phone, !phone.isEmpty {
            parts.append(phone)
        }
        if let email = guest.email, !email.isEmpty {
            parts.append(email)
        }

        let dietary = [guest.metadata?.dietaryRestrictions, guest.metadata?.mealChoice]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let memberDietary = guest.partyMembers
            .compactMap { $0.dietaryRestrictions?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let allDietary = dietary + memberDietary
        if !allDietary.isEmpty {
            parts.append("Dietary: \(allDietary.joined(separator: ", "))")
        }

        return parts.joined(separator: " — ")
    }

    // MARK: - Privacy Mode Guest List (first names + avatars)

    private var privacyGuestList: some View {
        VStack(spacing: Spacing.md) {
            // Header with count
            HStack {
                let attendingGuests = event.guests.filter { $0.status == .attending }
                AvatarStack(
                    names: attendingGuests.map { $0.name },
                    maxDisplay: 5,
                    size: AvatarSize.md
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(event.attendingCount) Going")
                        .font(GatherFont.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .accessibilityAddTraits(.isHeader)
                    if event.maybeCount > 0 {
                        Text("\(event.maybeCount) maybe")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }

                Spacer()
            }
            .horizontalPadding()
            .padding(.vertical, Spacing.md)

            // Simple first-name list — content-only; the outer page scroll
            // owns scrolling, so no nested ScrollView here.
            LazyVStack(spacing: Spacing.xs) {
                ForEach(event.guests.filter { $0.status == .attending }) { guest in
                    FirstNameGuestCard(guest: guest)
                }
            }
            .horizontalPadding()
            .padding(.bottom, Layout.scrollBottomInset)
        }
    }

    // MARK: - Count Only View

    private var countOnlyView: some View {
        // Content-only: fixed vertical padding instead of Spacers, which
        // collapse inside the outer page scroll.
        VStack(spacing: Spacing.lg) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentPurpleFallback.opacity(0.5))

            Text("\(event.attendingCount) attending")
                .font(GatherFont.title2)
                .foregroundStyle(Color.gatherPrimaryText)
                .accessibilityAddTraits(.isHeader)

            if event.maybeCount > 0 {
                Text("\(event.maybeCount) maybe")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Hidden View

    private var hiddenView: some View {
        // Content-only: fixed vertical padding instead of Spacers.
        GatherEmptyState(
            icon: "eye.slash",
            title: "Guest list is private",
            message: "Only the host can see who's attending."
        )
        .padding(.vertical, Spacing.xl)
        .horizontalPadding()
    }
}

// MARK: - First Name Guest Card (Privacy Mode)

struct FirstNameGuestCard: View {
    let guest: Guest

    private var firstName: String {
        guest.name.components(separatedBy: " ").first ?? guest.name
    }

    private var avatarColor: Color {
        let colors: [Color] = [.accentPurpleFallback, .accentPinkFallback, .warmCoral, .mintGreen, .neonBlue]
        let index = guest.name.stableHash % colors.count
        return colors[index]
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(avatarColor)
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String(firstName.prefix(1)).uppercased())
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }

            Text(firstName)
                .font(GatherFont.body)
                .foregroundStyle(Color.gatherPrimaryText)

            Spacer()
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(firstName)
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let filter: GuestsTab.GuestFilter
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    /// Amber and mid-gray fills need dark text to pass contrast in light mode
    /// (white on amber/gray fails WCAG) — mirrors GuestListSheet's FilterChip.
    private var usesDarkText: Bool {
        filter == .maybe || filter == .waitlist || filter == .notInvited
    }

    private var selectedForeground: Color {
        usesDarkText ? Color.black.opacity(0.85) : .white
    }

    private var selectedBadgeBackground: Color {
        usesDarkText ? Color.black.opacity(0.12) : Color.white.opacity(0.3)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text("\(filter.rawValue)")
                    .font(GatherFont.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)")
                    .font(GatherFont.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? selectedBadgeBackground : filter.color.opacity(0.2))
                    .clipShape(Capsule())
                    .contentTransition(.numericText())
            }
            .foregroundStyle(isSelected ? selectedForeground : Color.gatherPrimaryText)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(isSelected ? filter.color : Color.gatherElevated)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? filter.color : Color.gatherSeparator.opacity(0.5),
                    lineWidth: isSelected ? 1.5 : 1
                )
            )
            // Keep the pill visually compact but give it a full 44pt tap target.
            .frame(minHeight: Layout.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityLabel("\(filter.rawValue) filter, \(count) guests")
        .accessibilityHint(isSelected ? "Double tap to clear filter" : "Double tap to filter by \(filter.rawValue.lowercased())")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Improved Guest Card

struct ImprovedGuestCard: View {
    let guest: Guest
    let event: Event
    var inviteLookup: [UUID: [UUID: FunctionInvite]] = [:]
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    var onSetStatus: ((RSVPStatus) -> Void)? = nil
    var onSendInvite: (() -> Void)? = nil
    var onRemove: (() -> Void)? = nil

    private var hasQuickActions: Bool {
        !isSelectionMode && (onSetStatus != nil || onSendInvite != nil || onRemove != nil)
    }

    /// "Invited 4d ago" for pending guests whose invite went out — helps the
    /// host decide who's overdue for a nudge. Nil for everyone else.
    private var invitedAgoText: String? {
        guard guest.status == .pending, let sentAt = guest.inviteSentAt else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: sentAt),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
        if days <= 0 { return "Invited today" }
        if days == 1 { return "Invited yesterday" }
        return "Invited \(days)d ago"
    }

    var body: some View {
        Button(action: onTap) {
            if isSelected {
                rowContent
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .fill(Color.accentPurpleFallback.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .strokeBorder(Color.accentPurpleFallback, lineWidth: 1.5)
                    )
            } else {
                rowContent
                    .surfaceCard(cornerRadius: CornerRadius.md)
            }
        }
        .buttonStyle(CardPressStyle())
        .contextMenu {
            if hasQuickActions {
                quickActionMenuItems
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(guest.name), \(guest.status.displayName)\(guest.totalHeadcount > 1 ? ", plus \(guest.totalHeadcount - 1)" : "")\(invitedAgoText.map { ", \($0.lowercased())" } ?? "")")
        .accessibilityHint(isSelectionMode ? "Double tap to toggle selection" : "Double tap for details")
        .accessibilityValue(isSelectionMode ? (isSelected ? "Selected" : "Not selected") : "")
        .accessibilityActions {
            if hasQuickActions {
                accessibilityQuickActions
            }
        }
    }

    // MARK: - Quick Actions

    /// Shared between the long-press context menu and the inline status menu.
    @ViewBuilder
    private var statusMenuItems: some View {
        if let onSetStatus {
            Button {
                onSetStatus(.attending)
            } label: {
                Label(guest.status == .waitlisted ? "Promote to Going" : "Mark Going",
                      systemImage: "checkmark.circle")
            }
            Button {
                onSetStatus(.maybe)
            } label: {
                Label("Mark Maybe", systemImage: "questionmark.circle")
            }
            Button {
                onSetStatus(.declined)
            } label: {
                Label("Mark Can't Go", systemImage: "xmark.circle")
            }
            Button {
                onSetStatus(.pending)
            } label: {
                Label("Mark Pending", systemImage: "clock")
            }
        }
    }

    @ViewBuilder
    private var quickActionMenuItems: some View {
        statusMenuItems

        if let onSendInvite {
            Divider()
            Button {
                onSendInvite()
            } label: {
                Label("Send Invite", systemImage: "paperplane")
            }
        }

        if let onRemove {
            Divider()
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove Guest", systemImage: "trash")
            }
        }
    }

    /// VoiceOver equivalents — the card is one combined element, so the inline
    /// menu and context menu aren't directly reachable.
    @ViewBuilder
    private var accessibilityQuickActions: some View {
        if let onSetStatus {
            Button(guest.status == .waitlisted ? "Promote to Going" : "Mark Going") {
                onSetStatus(.attending)
            }
            Button("Mark Maybe") { onSetStatus(.maybe) }
            Button("Mark Can't Go") { onSetStatus(.declined) }
            Button("Mark Pending") { onSetStatus(.pending) }
        }
        if let onSendInvite {
            Button("Send Invite") { onSendInvite() }
        }
        if let onRemove {
            Button("Remove Guest") { onRemove() }
        }
    }

    private var rowContent: some View {
        HStack(spacing: Spacing.md) {
            // Selection checkbox
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentPurpleFallback : Color.gatherSecondaryText)
            }

            // Avatar with status ring
            ZStack {
                Circle()
                    .stroke(statusColor, lineWidth: 2)
                    .frame(width: 48, height: 48)

                Circle()
                    .fill(avatarColor)
                    .frame(width: 42, height: 42)
                    .overlay {
                        Text(guest.name.prefix(1).uppercased())
                            .font(GatherFont.headline)
                            .foregroundStyle(.white)
                    }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.xs) {
                    Text(guest.name)
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .lineLimit(1)
                        // Shrink a long name before truncating, and let it win
                        // width over the fixed +N / role capsules beside it.
                        .minimumScaleFactor(0.7)
                        .layoutPriority(1)

                    if guest.totalHeadcount > 1 {
                        Text("+\(guest.totalHeadcount - 1)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentPurpleFallback)
                            .clipShape(Capsule())
                    }

                    if guest.role != .guest {
                        Text(guest.role.displayName)
                            .font(.caption2)
                            .foregroundStyle(Color.rsvpMaybeFallback)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.rsvpMaybeFallback.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                // Contact info
                if let contact = guest.displayContact {
                    HStack(spacing: 4) {
                        Image(systemName: guest.email != nil ? "envelope" : "phone")
                            .font(.caption2)
                        Text(contact)
                            .font(GatherFont.caption)
                    }
                    .foregroundStyle(Color.gatherSecondaryText)
                    .lineLimit(1)
                }

                // Invite-age meta: pending + invite sent → show how long ago,
                // so the host can spot who's overdue for a reminder.
                if let invitedAgo = invitedAgoText {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane")
                            .font(.caption2)
                            .imageScale(.small)
                        Text(invitedAgo)
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.gatherTertiaryText)
                    .lineLimit(1)
                }

                // Function status chips (if has functions)
                if !event.functions.isEmpty {
                    functionStatusRow
                }
            }

            Spacer()

            // One trailing control: the status badge IS the menu, holding
            // every row action (status change + Send Invite + Remove). This
            // replaces the old badge-menu + separate ellipsis pair, which ate
            // ~44pt and truncated longer names.
            if !isSelectionMode {
                if hasQuickActions {
                    Menu {
                        quickActionMenuItems
                    } label: {
                        HStack(spacing: 2) {
                            StatusBadge(status: guest.status)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .imageScale(.small)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                        .frame(minHeight: Layout.minTouchTarget)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Actions for \(guest.name), currently \(guest.status.displayName)")
                } else {
                    StatusBadge(status: guest.status)
                }
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.sm)
    }

    private var functionStatusRow: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(event.functions.prefix(3).sorted { $0.date < $1.date }) { function in
                FunctionStatusChip(
                    function: function,
                    guest: guest,
                    invite: inviteLookup[function.id]?[guest.id]
                )
            }
            if event.functions.count > 3 {
                Text("+\(event.functions.count - 3)")
                    .font(.caption2)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
        }
    }

    private var statusColor: Color {
        switch guest.status {
        case .attending: return .rsvpYesFallback
        case .declined: return .rsvpNoFallback
        case .maybe: return .rsvpMaybeFallback
        case .pending, .waitlisted: return Color.gatherSecondaryText.opacity(0.3)
        }
    }

    private var avatarColor: Color {
        let colors: [Color] = [.accentPurpleFallback, .neonBlue, .mintGreen, .warmCoral, .accentPinkFallback, .softLavender]
        let index = guest.name.stableHash % colors.count
        return colors[index]
    }
}

// MARK: - Function Status Chip

struct FunctionStatusChip: View {
    let function: EventFunction
    let guest: Guest
    var invite: FunctionInvite?

    init(function: EventFunction, guest: Guest, invite: FunctionInvite? = nil) {
        self.function = function
        self.guest = guest
        // Use pre-computed invite if provided, otherwise fall back to lookup
        self.invite = invite ?? function.invites.first { $0.guestId == guest.id }
    }

    private var abbreviation: String {
        let trimmed = function.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let words = trimmed.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }

    private var chipColor: Color {
        guard let invite = invite else { return Color.gatherSecondaryText.opacity(0.3) }
        switch invite.inviteStatus {
        case .notSent: return .gatherSecondaryText
        case .sent: return .neonBlue
        case .responded:
            switch invite.response {
            case .yes: return .rsvpYesFallback
            case .no: return .rsvpNoFallback
            case .maybe: return .rsvpMaybeFallback
            case .none: return .neonBlue
            }
        }
    }

    private var statusIcon: String? {
        guard let invite = invite, invite.inviteStatus == .responded else { return nil }
        switch invite.response {
        case .yes: return "checkmark"
        case .no: return "xmark"
        case .maybe: return "questionmark"
        case .none: return nil
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            if let icon = statusIcon {
                Image(systemName: icon)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .imageScale(.small)
            }
            Text(abbreviation)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(chipColor == .gatherSecondaryText || chipColor == Color.gatherSecondaryText.opacity(0.3) ? Color.gatherSecondaryText : .white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(chipColor)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            let status: String
            if let invite = invite {
                switch invite.inviteStatus {
                case .notSent: status = "not invited"
                case .sent: status = "invite sent"
                case .responded:
                    switch invite.response {
                    case .yes: status = "attending"
                    case .no: status = "declined"
                    case .maybe: status = "maybe"
                    case .none: status = "responded"
                    }
                }
            } else {
                status = "not invited"
            }
            return "\(function.name): \(status)"
        }())
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: RSVPStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption)
            Text(status.displayName)
                .font(GatherFont.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(Color.forRSVPStatus(status))
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Color.forRSVPStatus(status).opacity(0.15))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.displayName)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var previewEvent = Event(
        title: "Wedding",
        startDate: Date()
    )
    GuestsTab(event: previewEvent)
}
