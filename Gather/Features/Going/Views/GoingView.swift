import SwiftUI
import SwiftData

struct GoingView: View {
    @EnvironmentObject var authManager: AuthManager
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @State private var selectedEvent: Event?
    @State private var filter: TimeFilter = .upcoming

    enum TimeFilter: String, CaseIterable {
        case upcoming = "Upcoming"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case past = "Past"

        var icon: String {
            switch self {
            case .upcoming: return "arrow.right.circle"
            case .thisWeek: return "7.square"
            case .thisMonth: return "calendar"
            case .past: return "clock.arrow.circlepath"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Filter Pills with counts
                    filterPills

                    // Next Up Hero (only for upcoming)
                    if filter == .upcoming, let next = filteredEvents.first {
                        nextUpHero(event: next)
                            .bouncyAppear()
                    }

                    if filteredEvents.isEmpty {
                        emptyState
                    } else {
                        // Events List
                        LazyVStack(spacing: Spacing.sm) {
                            let list = filter == .upcoming ? Array(filteredEvents.dropFirst()) : filteredEvents
                            ForEach(Array(list.enumerated()), id: \.element.id) { index, event in
                                Button {
                                    selectedEvent = event
                                } label: {
                                    GoingEventCard(event: event)
                                }
                                .buttonStyle(CardPressStyle())
                                .bouncyAppear(delay: Double(index) * 0.04)
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
            .refreshable {
                try? await Task.sleep(for: .milliseconds(500))
            }
            .navigationTitle("Going")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NotificationBellButton()
                }
            }
            .navigationDestination(item: $selectedEvent) { event in
                EventDetailView(event: event)
            }
        }
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(TimeFilter.allCases, id: \.self) { timeFilter in
                    let count = countForFilter(timeFilter)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            filter = timeFilter
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: timeFilter.icon)
                                .font(.caption2)
                                .fontWeight(.semibold)
                            Text(timeFilter.rawValue)
                                .font(GatherFont.caption)
                                .fontWeight(.semibold)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(filter == timeFilter ? Color.accentPurpleFallback : .white)
                                    .frame(width: 20, height: 20)
                                    .background(
                                        filter == timeFilter
                                            ? Color.white.opacity(0.9)
                                            : Color.accentPurpleFallback.opacity(0.5)
                                    )
                                    .clipShape(Circle())
                                    .contentTransition(.numericText())
                            }
                        }
                        .foregroundStyle(filter == timeFilter ? .white : Color.gatherPrimaryText)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            filter == timeFilter
                                ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                                : AnyShapeStyle(Color.clear)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    filter == timeFilter
                                        ? AnyShapeStyle(Color.clear)
                                        : AnyShapeStyle(LinearGradient(
                                            colors: [Color.glassBorderTop, Color.glassBorderBottom],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )),
                                    lineWidth: 1
                                )
                        )
                        .background(
                            filter == timeFilter
                                ? nil
                                : Capsule()
                                    .fill(.ultraThinMaterial)
                        )
                    }
                    .scaleEffect(filter == timeFilter ? 1.03 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: filter == timeFilter)
                    .accessibilityLabel("\(timeFilter.rawValue), \(count) events")
                    .accessibilityAddTraits(filter == timeFilter ? [.isSelected] : [])
                }
            }
        }
    }

    // MARK: - Next Up Hero

    private func nextUpHero(event: Event) -> some View {
        Button {
            selectedEvent = event
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Mesh gradient background
                CategoryMeshBackground(category: event.category)
                    .frame(height: Layout.heroHeight)

                // Dark overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Category emoji
                Text(event.category.emoji)
                    .font(.system(size: 60))
                    .opacity(0.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(Spacing.md)

                // Content
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Spacer()

                    // "Next Up" badge with countdown
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text("NEXT UP")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .tracking(1)
                        Text("\u{2022}")
                            .font(.caption2)
                        Text(daysUntil(event.startDate))
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())

                    Text(event.title)
                        .font(GatherFont.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: Spacing.md) {
                        if let location = event.location {
                            Label(location.shortLocation ?? location.name, systemImage: "mappin")
                                .lineLimit(1)
                        }
                        Label(heroFormattedDate(event.startDate), systemImage: "calendar")

                        Spacer()

                        // Attendee avatars
                        let attendingNames = event.guests
                            .filter { $0.status == .attending }
                            .prefix(3)
                            .map { $0.name }
                        if !attendingNames.isEmpty {
                            AvatarStack(names: Array(attendingNames), maxDisplay: 3, size: 22)
                        }
                    }
                    .font(GatherFont.caption)
                    .foregroundStyle(.white.opacity(0.9))
                }
                .padding(Spacing.lg)
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
            .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
        }
        .buttonStyle(CardPressStyle())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
                .frame(height: 50)

            ZStack {
                Circle()
                    .fill(Color.accentPurpleFallback.opacity(0.08))
                    .frame(width: 110, height: 110)
                Circle()
                    .fill(Color.accentPinkFallback.opacity(0.06))
                    .frame(width: 80, height: 80)
                Image(systemName: "ticket.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient.gatherAccentGradient
                    )
            }

            VStack(spacing: Spacing.sm) {
                Text("No Events Yet")
                    .font(GatherFont.title3)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text("Events you RSVP to or purchase tickets for will appear here")
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private var filteredEvents: [Event] {
        let userId = authManager.currentUser?.id

        let attendingEvents = allEvents.filter { event in
            event.guests.contains { guest in
                guest.userId == userId && guest.status == .attending
            }
        }

        let now = Date()
        let calendar = Calendar.current

        switch filter {
        case .upcoming:
            return attendingEvents.filter { $0.startDate > now }
        case .thisWeek:
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: now) ?? now
            return attendingEvents.filter { $0.startDate > now && $0.startDate <= weekEnd }
        case .thisMonth:
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            return attendingEvents.filter { $0.startDate > now && $0.startDate <= monthEnd }
        case .past:
            return attendingEvents.filter { $0.startDate < now }.reversed()
        }
    }

    private func countForFilter(_ f: TimeFilter) -> Int {
        let userId = authManager.currentUser?.id
        let attendingEvents = allEvents.filter { event in
            event.guests.contains { guest in
                guest.userId == userId && guest.status == .attending
            }
        }
        let now = Date()
        let calendar = Calendar.current
        switch f {
        case .upcoming:
            return attendingEvents.filter { $0.startDate > now }.count
        case .thisWeek:
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: now) ?? now
            return attendingEvents.filter { $0.startDate > now && $0.startDate <= weekEnd }.count
        case .thisMonth:
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            return attendingEvents.filter { $0.startDate > now && $0.startDate <= monthEnd }.count
        case .past:
            return attendingEvents.filter { $0.startDate < now }.count
        }
    }

    private func daysUntil(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }

    private func heroFormattedDate(_ date: Date) -> String {
        GatherDateFormatter.fullEventDate.string(from: date)
    }
}

// MARK: - Going Event Card

struct GoingEventCard: View {
    let event: Event

    var body: some View {
        HStack(spacing: 0) {
            // Category color strip
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient.categoryGradient(for: event.category))
                .frame(width: 5)
                .padding(.vertical, 6)

            HStack(spacing: Spacing.sm) {
                // Date badge with category tint
                VStack(spacing: 1) {
                    Text(event.category.emoji)
                        .font(.system(size: 16))
                    Text(dayNumber)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text(monthAbbrev)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.forCategory(event.category))
                }
                .frame(width: 48, height: 56)
                .background(
                    LinearGradient.cardGradient(for: event.category)
                )
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                // Event Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(GatherFont.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .lineLimit(1)

                    if let location = event.location {
                        HStack(spacing: 3) {
                            Image(systemName: location.isVirtual ? "video" : "mappin")
                                .font(.system(size: 8))
                            Text(location.shortLocation ?? location.name)
                                .lineLimit(1)
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                    }

                    Text(formattedTime)
                        .font(.caption2)
                        .foregroundStyle(Color.forCategory(event.category))
                }

                Spacer()

                // Countdown badge
                VStack(spacing: 2) {
                    Text(daysLeft)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(daysLeftColor)
                        .contentTransition(.numericText())
                    Text(daysLeftLabel)
                        .font(.system(size: 8))
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .frame(width: 44)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
        }
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title). \(event.location?.name ?? ""). \(formattedTime). \(daysUntilCount <= 0 ? "Happening now" : daysUntilCount == 1 ? "Tomorrow" : "In \(daysUntilCount) days")")
    }

    private var monthAbbrev: String {
        GatherDateFormatter.monthAbbrev.string(from: event.startDate).uppercased()
    }

    private var dayNumber: String {
        GatherDateFormatter.dayNumber.string(from: event.startDate)
    }

    private var formattedTime: String {
        GatherDateFormatter.shortEventTime.string(from: event.startDate)
    }

    private var daysUntilCount: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: event.startDate).day ?? 0
    }

    private var daysLeft: String {
        let d = daysUntilCount
        if d <= 0 { return "Now" }
        if d == 1 { return "1" }
        return "\(d)"
    }

    private var daysLeftLabel: String {
        let d = daysUntilCount
        if d <= 0 { return "today" }
        if d == 1 { return "day" }
        return "days"
    }

    private var daysLeftColor: Color {
        let d = daysUntilCount
        if d <= 1 { return Color.rsvpNoFallback }
        if d <= 7 { return Color.rsvpMaybeFallback }
        return Color.accentPurpleFallback
    }
}

// MARK: - Preview

#Preview {
    GoingView()
        .environmentObject(AuthManager())
        .modelContainer(for: Event.self, inMemory: true)
}
