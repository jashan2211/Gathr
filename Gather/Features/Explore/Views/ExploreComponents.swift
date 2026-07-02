import SwiftUI

// MARK: - Happening Soon Card

struct HappeningSoonCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Gradient hero with date overlay
            ZStack {
                CategoryMeshBackground(category: event.category)
                    .frame(width: 200, height: 110)
                    .overlay(alignment: .bottomTrailing) {
                        Text(event.category.emoji)
                            .font(.system(size: 36))
                            .opacity(0.35)
                            .offset(x: -8, y: -8)
                    }

                // Scrim for legibility of the date chip / emoji
                LinearGradient(
                    colors: [.black.opacity(0.25), .clear],
                    startPoint: .top,
                    endPoint: .center
                )

                // Date chip - top left
                VStack {
                    HStack {
                        VStack(spacing: 0) {
                            Text(dayOfMonth)
                                .font(.system(size: 18, weight: .heavy))
                            Text(monthAbbrev)
                                .font(.system(size: 10, weight: .bold))
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous))
                        .padding(Spacing.xs)

                        Spacer()

                        // Sample badge for demo events
                        if event.isDemo {
                            Text("SAMPLE")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.9), in: Capsule())
                                .padding(Spacing.xs)
                        }
                    }
                    Spacer()
                }
            }
            .frame(width: 200, height: 110)
            .grain(0.07) // printed-poster texture, applied before the clip
            .clipped()

            // Info
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(event.title)
                    .gatherRowTitle()
                    .foregroundStyle(Color.gatherPrimaryText)
                    .lineLimit(1)

                if let location = event.location {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin")
                            .font(.system(size: 8))
                        Text(location.shortLocation ?? location.name)
                            .lineLimit(1)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gatherSecondaryText)
                }

                HStack(spacing: 4) {
                    Text(relativeDay)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(urgencyColor)

                    Spacer()

                    // Mini attendee avatars
                    let attendingNames = event.guests
                        .filter { $0.status == .attending }
                        .prefix(2)
                        .map { $0.name }
                    if !attendingNames.isEmpty {
                        AvatarStack(names: Array(attendingNames), maxDisplay: 2, size: 16)
                    } else {
                        HStack(spacing: 2) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 8))
                            Text("\(event.displayAttendingCount)")
                                .fontWeight(.semibold)
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                    }
                }
            }
            .padding(Spacing.sm)
        }
        .frame(width: 200)
        .surfaceCard()
        .categoryAccentBar(Color.forCategory(event.category))
        .drawingGroup()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), \(relativeDay). \(event.location?.name ?? ""). \(event.displayAttendingCount) attending")
    }

    private var dayOfMonth: String {
        GatherDateFormatter.dayNumber.string(from: event.startDate)
    }

    private var monthAbbrev: String {
        GatherDateFormatter.monthAbbrev.string(from: event.startDate)
    }

    private var relativeDay: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: event.startDate)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return GatherDateFormatter.weekdayFull.string(from: event.startDate)
    }

    private var urgencyColor: Color {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: event.startDate)).day ?? 0
        if days <= 1 { return Color.warmCoral }
        if days <= 3 { return Color.sunshineYellowText }
        return Color.accentPurpleFallback
    }
}

// MARK: - Explore Grid Card

struct ExploreGridCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero with accent line
            ZStack(alignment: .topTrailing) {
                CategoryMeshBackground(category: event.category)
                    .frame(height: 100)
                    .overlay(alignment: .topTrailing) {
                        LinearGradient(
                            colors: [.black.opacity(0.22), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    }
                    .overlay(alignment: .bottomLeading) {
                        Text(event.category.emoji)
                            .font(.title)
                            .padding(Spacing.xs)
                    }

                VStack(alignment: .trailing, spacing: 4) {
                    // Price tag
                    Text(priceLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 3)
                        .background(priceColor, in: Capsule())

                    // Sample badge for demo events
                    if event.isDemo {
                        Text("SAMPLE")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.9), in: Capsule())
                    }
                }
                .padding(Spacing.xs)
            }
            .grain(0.07) // printed-poster texture, applied before the clip
            .clipped()

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .gatherRowTitle()
                    .foregroundStyle(Color.gatherPrimaryText)
                    .lineLimit(2)
                    .frame(minHeight: 36, alignment: .topLeading)

                if let location = event.location {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin")
                            .font(.system(size: 8))
                        Text(location.shortLocation ?? location.name)
                            .lineLimit(1)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gatherSecondaryText)
                }

                // Relative date
                HStack(spacing: 3) {
                    Image(systemName: "calendar")
                        .font(.system(size: 8))
                    Text(smartDate)
                        .lineLimit(1)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.accentPurpleFallback)

                // Attendee preview + capacity
                HStack(spacing: 4) {
                    let attendingNames = event.guests
                        .filter { $0.status == .attending }
                        .prefix(3)
                        .map { $0.name }

                    if !attendingNames.isEmpty {
                        AvatarStack(
                            names: Array(attendingNames),
                            maxDisplay: 3,
                            size: 20
                        )
                        if event.displayAttendingCount > 3 {
                            Text("+\(event.displayAttendingCount - 3)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                    } else {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.gatherSecondaryText)
                        Text("\(event.displayAttendingCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.gatherPrimaryText)
                    }

                    Spacer()

                    if let capacity = event.capacity, capacity > 0 {
                        let remaining = capacity - event.displayAttendingCount
                        if remaining <= 10 && remaining > 0 {
                            Text("\(remaining) left!")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.warmCoral)
                        }
                    }
                }
            }
            .padding(Spacing.sm)
        }
        .surfaceCard()
        .categoryAccentBar(Color.forCategory(event.category))
        .drawingGroup()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title). \(priceLabel). \(smartDate). \(event.location?.name ?? ""). \(event.displayAttendingCount) attending")
    }

    private var priceLabel: String {
        guard event.hasTicketing else { return "RSVP" }
        let tiers = event.ticketTiers
        if let cheapest = tiers.min(by: { $0.price < $1.price }) {
            return cheapest.price == 0 ? "FREE" : GatherPriceFormatter.formatShort(cheapest.price)
        }
        return "FREE"
    }

    // Darker fills than the pastel palette — these chips carry white text
    private var priceColor: Color {
        guard event.hasTicketing else { return Color.customSlateDark }
        let tiers = event.ticketTiers
        if let cheapest = tiers.min(by: { $0.price < $1.price }),
           cheapest.price > 0 {
            return Color.accentPurpleFallback
        }
        return Color.rsvpYesFallback
    }

    /// Smart date: shows "Tomorrow", "This Sat", or "Feb 12"
    private var smartDate: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: event.startDate)).day ?? 0

        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        if days <= 6 {
            return "This \(GatherDateFormatter.weekdayFull.string(from: event.startDate))"
        }

        return GatherDateFormatter.shortWeekdayMonthDay.string(from: event.startDate)
    }
}
