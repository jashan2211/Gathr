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
                            .opacity(0.3)
                            .offset(x: -8, y: -8)
                    }

                // Date chip - top left
                VStack {
                    HStack {
                        VStack(spacing: 0) {
                            Text(dayOfMonth)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text(monthAbbrev)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                        .padding(Spacing.xs)

                        Spacer()

                        // Sample badge for demo events
                        if event.isDemo {
                            Text("SAMPLE")
                                .font(.caption2)
                                .fontWeight(.heavy)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.85))
                                .clipShape(Capsule())
                                .padding(Spacing.xs)
                        }
                    }
                    Spacer()
                }
            }
            .frame(width: 200, height: 110)
            .clipped()

            // Info
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(event.title)
                    .font(GatherFont.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .lineLimit(1)

                if let location = event.location {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin")
                            .font(.system(size: 8))
                        Text(location.shortLocation ?? location.name)
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundStyle(Color.gatherSecondaryText)
                }

                HStack(spacing: 4) {
                    Text(relativeDay)
                        .font(.caption2)
                        .fontWeight(.semibold)
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
                            Text("\(event.totalAttendingHeadcount)")
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
        .glassCardLite()
        .drawingGroup()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), \(relativeDay). \(event.location?.name ?? ""). \(event.totalAttendingHeadcount) attending")
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
        if days <= 3 { return Color.sunshineYellow }
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
                    .overlay(alignment: .bottomLeading) {
                        Text(event.category.emoji)
                            .font(.title)
                            .padding(Spacing.xs)
                    }

                VStack(alignment: .trailing, spacing: 4) {
                    // Price tag
                    Text(priceLabel)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 3)
                        .background(priceColor)
                        .clipShape(Capsule())

                    // Sample badge for demo events
                    if event.isDemo {
                        Text("SAMPLE")
                            .font(.caption2)
                            .fontWeight(.heavy)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.85))
                            .clipShape(Capsule())
                    }
                }
                .padding(Spacing.xs)
            }
            .clipped()

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(GatherFont.callout)
                    .fontWeight(.semibold)
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
                    .font(.caption2)
                    .foregroundStyle(Color.gatherSecondaryText)
                }

                // Relative date
                HStack(spacing: 3) {
                    Image(systemName: "calendar")
                        .font(.system(size: 8))
                    Text(smartDate)
                        .lineLimit(1)
                }
                .font(.caption2)
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
                        if event.totalAttendingHeadcount > 3 {
                            Text("+\(event.totalAttendingHeadcount - 3)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                    } else {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.gatherSecondaryText)
                        Text("\(event.totalAttendingHeadcount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.gatherPrimaryText)
                    }

                    Spacer()

                    if let capacity = event.capacity, capacity > 0 {
                        let remaining = capacity - event.totalAttendingHeadcount
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
        .glassCardLite()
        .drawingGroup()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title). \(priceLabel). \(smartDate). \(event.location?.name ?? ""). \(event.totalAttendingHeadcount) attending")
    }

    private var priceLabel: String {
        guard event.hasTicketing else { return "RSVP" }
        let tiers = event.ticketTiers
        if let cheapest = tiers.min(by: { $0.price < $1.price }) {
            return cheapest.price == 0 ? "FREE" : GatherPriceFormatter.formatShort(cheapest.price)
        }
        return "FREE"
    }

    private var priceColor: Color {
        guard event.hasTicketing else { return Color.softLavender }
        let tiers = event.ticketTiers
        if let cheapest = tiers.min(by: { $0.price < $1.price }),
           cheapest.price > 0 {
            return Color.accentPurpleFallback
        }
        return Color.mintGreen
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
