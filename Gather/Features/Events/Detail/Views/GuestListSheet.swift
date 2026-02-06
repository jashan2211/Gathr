import SwiftUI

struct GuestListSheet: View {
    let event: Event
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedFilter: RSVPStatus? = nil

    var body: some View {
        NavigationStack {
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
                            GuestRow(guest: guest)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Guests (\(event.guests.count))")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search guests")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                FilterChip(
                    label: "All",
                    count: event.guests.count,
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
            .horizontalPadding()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.gatherSecondaryText)

            Text("No guests found")
                .font(GatherFont.headline)

            Text(emptyMessage)
                .font(GatherFont.callout)
                .foregroundStyle(Color.gatherSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyMessage: String {
        if !searchText.isEmpty {
            return "No guests match your search"
        } else if let filter = selectedFilter {
            return "No guests with status: \(filter.displayName)"
        } else {
            return "Invite some friends!"
        }
    }

    // MARK: - Filtered Guests

    private var filteredGuests: [Guest] {
        var guests = event.guests

        // Apply status filter
        if let filter = selectedFilter {
            guests = guests.filter { $0.status == filter }
        }

        // Apply search filter
        if !searchText.isEmpty {
            guests = guests.filter { guest in
                guest.name.localizedCaseInsensitiveContains(searchText) ||
                (guest.email?.localizedCaseInsensitiveContains(searchText) ?? false)
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Text(label)
                    .font(GatherFont.callout)

                Text("\(count)")
                    .font(GatherFont.caption)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        isSelected ? color.opacity(0.2) : Color.gatherTertiaryBackground
                    )
                    .clipShape(Capsule())
            }
            .foregroundStyle(isSelected ? color : Color.gatherSecondaryText)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                isSelected ? color.opacity(0.1) : Color.gatherSecondaryBackground
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : .clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - Guest Row

struct GuestRow: View {
    let guest: Guest

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
                    Text(guest.name)
                        .font(GatherFont.body)

                    if guest.role != .guest {
                        Text(guest.role.displayName)
                            .font(GatherFont.caption2)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(Color.forGuestRole(guest.role).opacity(0.15))
                            .foregroundStyle(Color.forGuestRole(guest.role))
                            .clipShape(Capsule())
                    }
                }

                if let contact = guest.displayContact {
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

            // Status indicator
            Image(systemName: guest.status.icon)
                .font(.title3)
                .foregroundStyle(Color.forRSVPStatus(guest.status))
        }
        .padding(.vertical, Spacing.xs)
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
