import SwiftUI

// MARK: - Event Card

struct EventCard: View {
    let event: Event
    var variant: Variant = .standard

    enum Variant {
        case standard
        case compact
        case host
        case guest
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero Image
            if variant != .compact {
                heroImage
            }

            // Content
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Date & Time
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(formattedDate)
                        .font(GatherFont.caption)
                }
                .foregroundStyle(Color.accentPurpleFallback)

                // Title
                Text(event.title)
                    .font(variant == .compact ? GatherFont.headline : GatherFont.title2)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .lineLimit(2)

                // Location
                if let location = event.location {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: location.isVirtual ? "video" : "mappin")
                            .font(.caption)
                        Text(location.name)
                            .font(GatherFont.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.gatherSecondaryText)
                }

                // Host badge (for guest view)
                if variant == .guest, let host = event.host {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(Color.gatherSecondaryBackground)
                            .frame(width: AvatarSize.xs, height: AvatarSize.xs)
                            .overlay {
                                Text(host.name.prefix(1))
                                    .font(.caption2)
                                    .foregroundStyle(Color.gatherSecondaryText)
                            }
                        Text("Hosted by \(host.name)")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }

                // Guest count (for host view)
                if variant == .host {
                    HStack(spacing: Spacing.md) {
                        GuestCountBadge(count: event.attendingCount, status: .attending)
                        GuestCountBadge(count: event.maybeCount, status: .maybe)
                        GuestCountBadge(count: event.pendingCount, status: .pending)
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(Color.gatherSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Hero Image

    @ViewBuilder
    private var heroImage: some View {
        ZStack(alignment: .bottomLeading) {
            if let heroURL = event.heroMediaURL {
                AsyncImage(url: heroURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderGradient
                }
            } else {
                placeholderGradient
            }
        }
        .frame(height: 140)
        .clipped()
    }

    private var placeholderGradient: some View {
        LinearGradient(
            colors: [
                Color.accentPurpleFallback.opacity(0.6),
                Color.accentPinkFallback.opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Formatted Date

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: event.startDate)
    }
}

// MARK: - Guest Count Badge

struct GuestCountBadge: View {
    let count: Int
    let status: RSVPStatus

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text("\(count)")
                .font(GatherFont.caption)
        }
        .foregroundStyle(Color.forRSVPStatus(status))
    }
}

// MARK: - Preview

#Preview("Standard") {
    EventCard(
        event: Event(
            title: "Birthday Party",
            startDate: Date().addingTimeInterval(86400 * 3),
            location: EventLocation(name: "The Rooftop Bar")
        )
    )
    .padding()
}

#Preview("Compact") {
    EventCard(
        event: Event(
            title: "Team Lunch",
            startDate: Date().addingTimeInterval(86400)
        ),
        variant: .compact
    )
    .padding()
}

#Preview("Host View") {
    EventCard(
        event: Event(
            title: "Product Launch Party",
            startDate: Date().addingTimeInterval(86400 * 7),
            location: EventLocation(name: "HQ Office")
        ),
        variant: .host
    )
    .padding()
}
