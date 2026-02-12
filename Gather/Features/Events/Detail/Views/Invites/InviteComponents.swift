import SwiftUI

// MARK: - Invite Quick Action Pill

struct InviteQuickActionPill: View {
    let title: String
    let count: Int
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            HapticService.buttonTap()
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

struct CompletionStatCard: View {
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
                            .font(.caption2)
                            .fontWeight(.bold)
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
