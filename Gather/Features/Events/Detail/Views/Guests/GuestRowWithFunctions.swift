import SwiftUI

struct GuestRowWithFunctions: View {
    let guest: Guest
    let event: Event
    let isSelected: Bool
    let isSelectionMode: Bool
    let onToggleSelection: () -> Void

    var body: some View {
        Group {
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
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection()
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: Spacing.md) {
            // Selection checkbox (in selection mode)
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentPurpleFallback : Color.gatherSecondaryText)
                    .onTapGesture {
                        onToggleSelection()
                    }
            }

            // Avatar
            Circle()
                .fill(Color.gatherTertiaryBackground)
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
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)

                    if guest.role != .guest {
                        Text(guest.role.displayName)
                            .font(GatherFont.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(Color.accentPurpleFallback)
                            .clipShape(Capsule())
                    }
                }

                // Contact info
                if let contact = guest.displayContact {
                    Text(contact)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                // Function invite status pills
                if !event.functions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(sortedFunctions) { function in
                                FunctionInvitePill(
                                    function: function,
                                    guest: guest
                                )
                            }
                        }
                    }
                }
            }

            Spacer()

            // Overall status
            if !isSelectionMode {
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Image(systemName: guest.status.icon)
                        .foregroundStyle(Color.forRSVPStatus(guest.status))

                    if guest.plusOneCount > 0 {
                        Text("+\(guest.plusOneCount)")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }
            }
        }
        .padding()
    }

    private var sortedFunctions: [EventFunction] {
        event.functions.sorted { $0.date < $1.date }
    }
}

// MARK: - Function Invite Pill

struct FunctionInvitePill: View {
    let function: EventFunction
    let guest: Guest

    var body: some View {
        let invite = function.invites.first { $0.guestId == guest.id }

        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(for: invite))
                .frame(width: 6, height: 6)

            Text(abbreviatedName)
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 2)
        .background(Color.gatherTertiaryBackground)
        .clipShape(Capsule())
    }

    private var abbreviatedName: String {
        let words = function.name.split(separator: " ")
        if words.count > 1 {
            return String(words.prefix(2).map { $0.prefix(1) }.joined())
        }
        return String(function.name.prefix(3))
    }

    private func statusColor(for invite: FunctionInvite?) -> Color {
        guard let invite = invite else {
            return Color.gatherSecondaryText.opacity(0.5)
        }

        switch invite.inviteStatus {
        case .notSent:
            return .gatherSecondaryText
        case .sent:
            return .neonBlue
        case .responded:
            switch invite.response {
            case .yes:
                return .rsvpYesFallback
            case .no:
                return .rsvpNoFallback
            case .maybe:
                return .rsvpMaybeFallback
            case .none:
                return .neonBlue
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let event = Event(title: "Wedding", startDate: Date())
    let guest = Guest(name: "John Doe", email: "john@example.com", role: .vip)

    VStack {
        GuestRowWithFunctions(
            guest: guest,
            event: event,
            isSelected: false,
            isSelectionMode: false,
            onToggleSelection: {}
        )

        GuestRowWithFunctions(
            guest: guest,
            event: event,
            isSelected: true,
            isSelectionMode: true,
            onToggleSelection: {}
        )
    }
    .padding()
}
