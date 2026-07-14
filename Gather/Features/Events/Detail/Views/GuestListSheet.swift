import SwiftUI

struct GuestListSheet: View {
    let event: Event
    /// Defaults to host so existing host call sites compile unchanged; the
    /// invitee-facing caller passes `false` to enforce guest-list privacy.
    var isHost: Bool = true
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedFilter: RSVPStatus? = nil

    // MARK: - Privacy

    /// Non-hosts never see contact details, and only see who's actually coming.
    private var showsContact: Bool { isHost }

    /// Public events (or the "first names only" setting) hide surnames from guests.
    private var firstNamesOnly: Bool {
        !isHost && (event.guestListVisibility == .firstNamesOnly || event.privacy == .publicEvent)
    }

    private var navTitle: String {
        isHost ? "Guests (\(event.guests.count))" : "Who's Going (\(baseGuests.count))"
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color.gatherBackground)
                .navigationTitle(navTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !isHost && event.guestListVisibility == .hidden {
            GatherEmptyState(
                icon: "lock.fill",
                title: "Guest List Is Private",
                message: "The host has hidden who's coming to this event."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !isHost && event.guestListVisibility == .countOnly {
            countOnlyView
        } else {
            VStack(spacing: 0) {
                // Filter chips
                filterChips
                    .padding(.vertical, Spacing.sm)

                // Guest list
                if filteredGuests.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filteredGuests) { guest in
                            GuestRow(guest: guest, showsContact: showsContact, firstNameOnly: firstNamesOnly)
                                .listRowBackground(Color.gatherBackground)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .searchable(text: $searchText, prompt: "Search guests")
        }
    }

    private var countOnlyView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentPurpleFallback)
            Text("\(event.attendingCount)")
                .font(.system(.largeTitle, weight: .heavy))
                .foregroundStyle(Color.gatherPrimaryText)
            Text("attending")
                .gatherMetaText()
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                FilterChip(
                    label: "All",
                    count: baseGuests.count,
                    isSelected: selectedFilter == nil
                ) {
                    selectedFilter = nil
                }

                FilterChip(
                    label: "Going",
                    count: event.attendingCount,
                    isSelected: selectedFilter == .attending,
                    color: .gatherSuccess
                ) {
                    selectedFilter = .attending
                }

                FilterChip(
                    label: "Maybe",
                    count: event.maybeCount,
                    isSelected: selectedFilter == .maybe,
                    color: .gatherWarning
                ) {
                    selectedFilter = .maybe
                }

                // Pending/declined are host bookkeeping — invitees only see
                // who's coming (All / Going / Maybe).
                if isHost {
                    FilterChip(
                        label: "Can't Go",
                        count: event.declinedCount,
                        isSelected: selectedFilter == .declined,
                        color: .gatherDestructive
                    ) {
                        selectedFilter = .declined
                    }

                    FilterChip(
                        label: "Pending",
                        count: event.pendingCount,
                        isSelected: selectedFilter == .pending,
                        color: .gatherSecondaryText
                    ) {
                        selectedFilter = .pending
                    }
                }
            }
            .horizontalPadding()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        GatherEmptyState(
            icon: "person.2",
            title: "No Guests Found",
            message: emptyMessage
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .horizontalPadding()
    }

    private var emptyMessage: String {
        if !searchText.isEmpty {
            return "No guests match your search"
        } else if let filter = selectedFilter {
            return "No guests marked '\(filter.displayName)' yet"
        } else {
            return "Guests you add will appear here"
        }
    }

    // MARK: - Filtered Guests

    /// The roster before search/chip filters. Hosts see everyone; invitees
    /// only ever see confirmed + maybe guests.
    private var baseGuests: [Guest] {
        isHost ? event.guests : event.guests.filter { $0.status == .attending || $0.status == .maybe }
    }

    private var filteredGuests: [Guest] {
        var guests = baseGuests

        // Apply status filter
        if let filter = selectedFilter {
            guests = guests.filter { $0.status == filter }
        }

        // Apply search filter (name-only for guests, who can't see contacts)
        if !searchText.isEmpty {
            guests = guests.filter { guest in
                guest.name.localizedCaseInsensitiveContains(searchText) ||
                (showsContact && (guest.email?.localizedCaseInsensitiveContains(searchText) ?? false))
            }
        }

        return guests
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let count: Int
    let isSelected: Bool
    var color: Color = .accentPurpleFallback
    let action: () -> Void

    /// White fails WCAG contrast (~2.2:1) on the amber "Maybe" chip — use
    /// dark text on light status colors instead.
    private var selectedForeground: Color {
        color == .gatherWarning ? Color.black.opacity(0.85) : .white
    }

    private var selectedBadgeBackground: Color {
        color == .gatherWarning ? Color.black.opacity(0.12) : Color.white.opacity(0.25)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Text(label)
                    .font(GatherFont.callout)
                    .fontWeight(isSelected ? .semibold : .regular)

                Text("\(count)")
                    .font(GatherFont.caption)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        isSelected ? selectedBadgeBackground : Color.gatherTertiaryBackground
                    )
                    .clipShape(Capsule())
            }
            .foregroundStyle(isSelected ? selectedForeground : Color.gatherSecondaryText)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                isSelected ? color : Color.gatherSecondaryBackground
            )
            .clipShape(Capsule())
            // Compact capsule visual, full 44pt hit area.
            .frame(minHeight: Layout.minTouchTarget)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Guest Row

struct GuestRow: View {
    let guest: Guest
    /// Contact line and role are host-only; guests see name + status.
    var showsContact: Bool = true
    /// Public/first-names-only events drop surnames for invitees.
    var firstNameOnly: Bool = false

    private var displayName: String {
        firstNameOnly ? String(guest.name.split(separator: " ").first ?? Substring(guest.name)) : guest.name
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            Circle()
                .fill(Color.gatherSecondaryBackground)
                .frame(width: AvatarSize.md, height: AvatarSize.md)
                .overlay {
                    Text(guest.name.prefix(1).uppercased())
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

            // Info
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text(displayName)
                        .font(GatherFont.body)

                    if showsContact && guest.role != .guest {
                        Text(guest.role.displayName)
                            .font(GatherFont.caption2)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(Color.forGuestRole(guest.role).opacity(0.15))
                            .foregroundStyle(Color.forGuestRole(guest.role))
                            .clipShape(Capsule())
                    }
                }

                if showsContact, let contact = guest.displayContact {
                    Text(contact)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                if guest.plusOneCount > 0 {
                    Text("+\(guest.plusOneCount) guest\(guest.plusOneCount > 1 ? "s" : "")")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }

            Spacer()

            // Status indicator — icon plus a text label so status isn't
            // conveyed by color/shape alone.
            VStack(spacing: 2) {
                Image(systemName: guest.status.icon)
                    .font(.title3)
                    .foregroundStyle(Color.forRSVPStatus(guest.status))
                Text(guest.status.displayName)
                    .font(GatherFont.caption2)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(displayName), \(guest.status.displayName)\(guest.plusOneCount > 0 ? ", plus \(guest.plusOneCount)" : "")"
        )
    }
}

// MARK: - Preview

#Preview {
    GuestListSheet(
        event: Event(
            title: "Birthday Party",
            startDate: Date().addingTimeInterval(86400 * 3)
        )
    )
}
