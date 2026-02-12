import SwiftUI

struct GuestsTab: View {
    @Bindable var event: Event
    @State private var searchText = ""
    @State private var selectedGuests: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var showAddGuest = false
    @State private var showSendInvites = false
    @State private var selectedGuest: Guest?
    @State private var filterStatus: GuestFilter = .all
    @EnvironmentObject var authManager: AuthManager

    private var isHost: Bool {
        event.hostId == authManager.currentUser?.id
    }

    /// Pre-computed set of guest IDs who have at least one "sent" invite across all functions.
    /// Avoids O(g*f*i) nested loops in filter/count logic.
    private var sentGuestIds: Set<UUID> {
        var ids = Set<UUID>()
        for function in event.functions {
            for invite in function.invites where invite.inviteStatus == .sent {
                ids.insert(invite.guestId)
            }
        }
        return ids
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

    enum GuestFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case sent = "Sent"
        case confirmed = "Confirmed"
        case declined = "Declined"

        var icon: String {
            switch self {
            case .all: return "person.3"
            case .pending: return "clock"
            case .sent: return "paperplane"
            case .confirmed: return "checkmark.circle"
            case .declined: return "xmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .all: return .accentPurpleFallback
            case .pending: return .gatherSecondaryText
            case .sent: return .neonBlue
            case .confirmed: return .rsvpYesFallback
            case .declined: return .rsvpNoFallback
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
                // Full guest management (host view)
                // Status Summary Bar
                statusSummaryBar

                // Header with actions
                headerSection

                // Search Bar
                searchBar

                // Guest List
                if filteredGuests.isEmpty {
                    emptyState
                } else {
                    guestList
                }
            }
        }
        .sheet(isPresented: $showAddGuest) {
            AddGuestSheet(event: event)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSendInvites) {
            SendInvitesSheet(
                event: event,
                preselectedGuests: Array(selectedGuests)
            )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedGuest) { guest in
            GuestDetailSheet(guest: guest, event: event)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Status Summary Bar

    private var statusSummaryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(GuestFilter.allCases, id: \.self) { filter in
                    StatusPill(
                        filter: filter,
                        count: countForFilter(filter),
                        isSelected: filterStatus == filter,
                        onTap: { filterStatus = filter }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, Spacing.sm)
        }
        .background(.ultraThinMaterial.opacity(0.5))
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            if isSelectionMode {
                Button("Cancel") {
                    withAnimation {
                        isSelectionMode = false
                        selectedGuests.removeAll()
                    }
                }
                .font(GatherFont.callout)

                Spacer()

                Text("\(selectedGuests.count) selected")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)

                Spacer()

                Button {
                    showSendInvites = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                        Text("Send")
                    }
                    .font(GatherFont.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(selectedGuests.isEmpty ? Color.gray : Color.accentPurpleFallback)
                    .clipShape(Capsule())
                }
                .disabled(selectedGuests.isEmpty)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(event.guests.count) Guests")
                        .font(GatherFont.headline)
                        .accessibilityAddTraits(.isHeader)
                    if event.attendingCount > 0 {
                        Text("\(event.attendingCount) confirmed")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }

                Spacer()

                HStack(spacing: Spacing.sm) {
                    if !event.guests.isEmpty {
                        // Select button
                        Button {
                            withAnimation { isSelectionMode = true }
                        } label: {
                            Image(systemName: "checklist")
                                .font(.title3)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                        .accessibilityLabel("Select guests")

                        // Quick send button
                        Button {
                            selectedGuests = Set(event.guests.map { $0.id })
                            showSendInvites = true
                        } label: {
                            Image(systemName: "paperplane")
                                .font(.title3)
                                .foregroundStyle(Color.accentPurpleFallback)
                        }
                        .accessibilityLabel("Send invites")
                    }

                    // Add button
                    Button {
                        showAddGuest = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.title3)
                            .foregroundStyle(Color.accentPurpleFallback)
                    }
                    .accessibilityLabel("Add guest")
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.sm)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.glassBorderTop, Color.glassBorderBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .padding(.horizontal)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundStyle(Color.gatherSecondaryText.opacity(0.5))

            VStack(spacing: Spacing.sm) {
                Text(event.guests.isEmpty ? "No Guests Yet" : "No Matching Guests")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .accessibilityAddTraits(.isHeader)

                Text(event.guests.isEmpty
                     ? "Add guests to start managing your event"
                     : "Try adjusting your search or filters")
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
            }

            if event.guests.isEmpty {
                Button {
                    showAddGuest = true
                } label: {
                    Label("Add Guest", systemImage: "person.badge.plus")
                        .font(GatherFont.callout)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.accentPurpleFallback)
                        .clipShape(Capsule())
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Guest List

    private var guestList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(filteredGuests) { guest in
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
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, Layout.scrollBottomInset)
        }
    }

    // MARK: - Helpers

    private func countForFilter(_ filter: GuestFilter) -> Int {
        switch filter {
        case .all:
            return event.guests.count
        case .pending:
            return event.guests.filter { $0.status == .pending }.count
        case .sent:
            // Guests who have been sent invites but not responded
            let ids = sentGuestIds
            return event.guests.filter { ids.contains($0.id) }.count
        case .confirmed:
            return event.guests.filter { $0.status == .attending }.count
        case .declined:
            return event.guests.filter { $0.status == .declined }.count
        }
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

        // Status filter
        switch filterStatus {
        case .all:
            break
        case .pending:
            guests = guests.filter { $0.status == .pending }
        case .sent:
            let ids = sentGuestIds
            guests = guests.filter { ids.contains($0.id) }
        case .confirmed:
            guests = guests.filter { $0.status == .attending }
        case .declined:
            guests = guests.filter { $0.status == .declined }
        }

        return guests.sorted { $0.name < $1.name }
    }

    private func toggleSelection(_ guest: Guest) {
        if selectedGuests.contains(guest.id) {
            selectedGuests.remove(guest.id)
        } else {
            selectedGuests.insert(guest.id)
        }
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
                        .accessibilityAddTraits(.isHeader)
                    if event.maybeCount > 0 {
                        Text("\(event.maybeCount) maybe")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }

                Spacer()
            }
            .padding()

            // Simple first-name list
            ScrollView {
                LazyVStack(spacing: Spacing.xs) {
                    ForEach(event.guests.filter { $0.status == .attending }) { guest in
                        FirstNameGuestCard(guest: guest)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, Layout.scrollBottomInset)
            }
        }
    }

    // MARK: - Count Only View

    private var countOnlyView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

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

            Spacer()
        }
    }

    // MARK: - Hidden View

    private var hiddenView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "eye.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.gatherSecondaryText.opacity(0.5))

            Text("Guest list is private")
                .font(GatherFont.headline)
                .foregroundStyle(Color.gatherPrimaryText)
                .accessibilityAddTraits(.isHeader)

            Text("Only the host can see who's attending")
                .font(GatherFont.callout)
                .foregroundStyle(Color.gatherSecondaryText)

            Spacer()
        }
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
        let index = abs(guest.name.hashValue) % colors.count
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

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text("\(filter.rawValue)")
                    .font(GatherFont.caption)
                Text("\(count)")
                    .font(GatherFont.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? .white.opacity(0.3) : filter.color.opacity(0.2))
                    .clipShape(Capsule())
                    .contentTransition(.numericText())
            }
            .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(isSelected ? AnyShapeStyle(filter.color) : AnyShapeStyle(.ultraThinMaterial))
            .clipShape(Capsule())
            .overlay(
                isSelected ? nil : Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.glassBorderTop, Color.glassBorderBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .accessibilityLabel("\(filter.rawValue) filter, \(count) guests")
        .accessibilityHint("Double tap to filter by \(filter.rawValue.lowercased())")
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

    var body: some View {
        Button(action: onTap) {
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

                    // Function status chips (if has functions)
                    if !event.functions.isEmpty {
                        functionStatusRow
                    }
                }

                Spacer()

                // Main status badge
                if !isSelectionMode {
                    StatusBadge(status: guest.status)
                }
            }
            .padding(Spacing.sm)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.accentPurpleFallback.opacity(0.1))
                } else {
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.glassBorderTop, Color.glassBorderBottom],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                }
            }
        }
        .buttonStyle(CardPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(guest.name), \(guest.status.displayName)\(guest.totalHeadcount > 1 ? ", plus \(guest.totalHeadcount - 1)" : "")")
        .accessibilityHint(isSelectionMode ? "Double tap to toggle selection" : "Double tap for details")
        .accessibilityValue(isSelectionMode ? (isSelected ? "Selected" : "Not selected") : "")
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
        let index = abs(guest.name.hashValue) % colors.count
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
                    .font(.system(size: 8, weight: .bold))
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
