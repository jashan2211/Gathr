import SwiftUI
import SwiftData

struct MyEventsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \Event.startDate) private var events: [Event]
    @State private var selectedTab: EventTab = .active
    @State private var selectedEvent: Event?
    @State private var showCreateEvent = false
    @Namespace private var zoomNamespace

    enum EventTab: String, CaseIterable {
        case active = "Active"
        case drafts = "Drafts"
        case past = "Past"

        var icon: String {
            switch self {
            case .active: return "flame"
            case .drafts: return "doc.text"
            case .past: return "clock"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom tab bar
                customTabBar

                // Event List
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        // Quick stats (only on Active tab)
                        if selectedTab == .active && !filteredEvents.isEmpty {
                            quickStats
                                .bouncyAppear()
                        }

                        // Create Event Card (only on Active tab; empty state carries the CTA otherwise)
                        if selectedTab == .active && !filteredEvents.isEmpty {
                            createEventCard
                                .bouncyAppear(delay: 0.03)
                        }

                        // 2-column grid on iPad
                        let cards = ForEach(filteredEvents, id: \.id) { event in
                            Button {
                                selectedEvent = event
                            } label: {
                                MyEventCard(event: event)
                            }
                            .buttonStyle(CardPressStyle())
                            .zoomSource(id: event.id, in: zoomNamespace)
                        }
                        if horizontalSizeClass == .regular {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                                cards
                            }
                        } else {
                            cards
                        }

                        if filteredEvents.isEmpty {
                            emptyState
                        }
                    }
                    .horizontalPadding()
                    .padding(.vertical)
                    .padding(.bottom, 20)
                }
                .refreshable {
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
            .navigationTitle("My Events")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NotificationBellButton()
                }
            }
            .navigationDestination(item: $selectedEvent) { event in
                EventDetailView(event: event)
                    .zoomDestination(id: event.id, in: zoomNamespace)
            }
            .sheet(isPresented: $showCreateEvent) {
                CreateEventView()
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(EventTab.allCases, id: \.self) { tab in
                let count = countForTab(tab)
                Button {
                    HapticService.tabSwitch()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(tab.rawValue)
                            .font(GatherFont.callout)
                            .fontWeight(.semibold)
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(selectedTab == tab ? Color.accentPurpleFallback : .white)
                                .frame(width: 20, height: 20)
                                .background(
                                    selectedTab == tab
                                        ? Color.gatherBackground.opacity(0.9)
                                        : Color.accentPurpleFallback.opacity(0.7)
                                )
                                .clipShape(Circle())
                                .contentTransition(.numericText())
                        }
                    }
                    .foregroundStyle(selectedTab == tab ? .white : Color.gatherPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        selectedTab == tab
                            ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                            : AnyShapeStyle(Color.gatherSecondaryBackground)
                    )
                    .clipShape(Capsule())
                }
                .scaleEffect(selectedTab == tab ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedTab == tab)
            }
        }
        .horizontalPadding()
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Quick Stats

    private var quickStats: some View {
        HStack(spacing: Spacing.sm) {
            QuickStatBubble(
                value: filteredEvents.count,
                label: "Events",
                icon: "calendar",
                gradient: LinearGradient(colors: [Color.accentPurpleFallback, Color.accentPurpleFallback.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            QuickStatBubble(
                value: filteredEvents.reduce(0) { $0 + $1.guests.count },
                label: "Guests",
                icon: "person.2.fill",
                gradient: LinearGradient(colors: [Color.accentPinkFallback, Color.accentPinkFallback.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            QuickStatBubble(
                value: filteredEvents.reduce(0) { $0 + $1.totalAttendingHeadcount },
                label: "Going",
                icon: "checkmark.circle.fill",
                gradient: LinearGradient(colors: [Color.rsvpYesFallback, Color.rsvpYesFallback.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
    }

    // MARK: - Create Event Card

    private var createEventCard: some View {
        Button {
            showCreateEvent = true
        } label: {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(LinearGradient.gatherAccentGradient)
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Create New Event")
                        .font(GatherFont.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.gatherPrimaryText)

                    Text("Start planning your next gathering")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(Spacing.sm)
            .surfaceCard()
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        Group {
            switch selectedTab {
            case .active:
                GatherEmptyState(
                    icon: "sparkles",
                    title: "Nothing on the calendar",
                    message: "Plan your next get-together and it'll show up right here.",
                    actionTitle: "Create Event",
                    action: { showCreateEvent = true }
                )
            case .drafts:
                GatherEmptyState(
                    icon: "doc.badge.plus",
                    title: "No drafts yet",
                    message: "Events you save before publishing will wait for you here."
                )
            case .past:
                GatherEmptyState(
                    icon: "clock.arrow.circlepath",
                    title: "No past events",
                    message: "Once an event wraps up, it'll move here for the memories."
                )
            }
        }
        .padding(.top, Spacing.xl)
    }

    // MARK: - Filtered Events

    private var hostedEvents: [Event] {
        guard let userId = authManager.currentUser?.id else { return [] }
        return events.filter { $0.hostId == userId }
    }

    private var filteredEvents: [Event] {
        switch selectedTab {
        case .active:
            return hostedEvents.filter { $0.isUpcoming && !$0.isDraft }
        case .drafts:
            return hostedEvents.filter { $0.isDraft }
        case .past:
            return hostedEvents.filter { $0.isPast && !$0.isDraft }
        }
    }

    private func countForTab(_ tab: EventTab) -> Int {
        switch tab {
        case .active: return hostedEvents.filter { $0.isUpcoming && !$0.isDraft }.count
        case .drafts: return hostedEvents.filter { $0.isDraft }.count
        case .past: return hostedEvents.filter { $0.isPast && !$0.isDraft }.count
        }
    }

}

// MARK: - Quick Stat Bubble

struct QuickStatBubble: View {
    let value: Int
    let label: String
    let icon: String
    let gradient: LinearGradient

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(gradient)
                .clipShape(Circle())

            Text("\(value)")
                .font(GatherFont.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.gatherPrimaryText)
                .contentTransition(.numericText())

            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .surfaceCard()
    }
}

// MARK: - My Event Card

struct MyEventCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Top row: emoji + title + badges
                HStack(alignment: .top, spacing: Spacing.sm) {
                    // Date badge
                    VStack(spacing: 1) {
                        Text(event.category.emoji)
                            .font(.footnote)
                        Text(dayNumber)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.gatherPrimaryText)
                        Text(monthAbbrev)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.forCategory(event.category))
                    }
                    .frame(width: 48, height: 54)
                    .background(Color.gatherTertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                    VStack(alignment: .leading, spacing: 3) {
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

                        // Time
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text(formattedTime)
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.forCategory(event.category))
                    }

                    Spacer()

                    // Badges column
                    VStack(alignment: .trailing, spacing: 4) {
                        if event.isDraft {
                            Text("Draft")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.rsvpMaybeFallback)
                                .clipShape(Capsule())
                        } else if event.privacy == .publicEvent {
                            Text("Public")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.rsvpYesFallback)
                                .clipShape(Capsule())
                        }
                    }
                }

                // RSVP progress bar
                if !event.guests.isEmpty {
                    VStack(spacing: 4) {
                        // Mini progress
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gatherSecondaryText.opacity(0.1))
                                    .frame(height: 6)

                                // Attending (green)
                                let attendingRatio = event.guests.isEmpty ? 0 : CGFloat(event.totalAttendingHeadcount) / CGFloat(max(event.capacity ?? event.guests.count, 1))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(colors: [Color.rsvpYesFallback, Color.rsvpYesFallback.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: min(geo.size.width * attendingRatio, geo.size.width), height: 6)
                            }
                        }
                        .frame(height: 6)

                        // Stats row
                        HStack(spacing: Spacing.md) {
                            EventStatPill(icon: "person.2.fill", value: "\(event.guests.count)", label: "Guests")
                            EventStatPill(icon: "checkmark.circle.fill", value: "\(event.totalAttendingHeadcount)", label: "Going")
                            if !event.functions.isEmpty {
                                EventStatPill(icon: "calendar.badge.clock", value: "\(event.functions.count)", label: "Functions")
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(Spacing.sm)
            .padding(.top, 3) // clear the accent bar
        }
        .surfaceCard()
        .categoryAccentBar(Color.forCategory(event.category))
        .drawingGroup()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.title)\(event.isDraft ? ", Draft" : "")")
        .accessibilityValue("\(formattedTime). \(event.guests.count) guests, \(event.totalAttendingHeadcount) attending")
        .accessibilityHint("Double tap to view event details")
    }

    private var monthAbbrev: String {
        GatherDateFormatter.monthAbbrev.string(from: event.startDate).uppercased()
    }

    private var dayNumber: String {
        GatherDateFormatter.dayNumber.string(from: event.startDate)
    }

    private var formattedTime: String {
        GatherDateFormatter.fullEventDate.string(from: event.startDate)
    }
}

// MARK: - Event Stat Pill

struct EventStatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(Color.accentPurpleFallback)
            Text(value)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(Color.gatherPrimaryText)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)
        }
    }
}

// MARK: - Preview

#Preview {
    MyEventsView()
        .environmentObject(AuthManager())
        .modelContainer(for: Event.self, inMemory: true)
}

// MARK: - Calendar (2026 redesign)

/// An agenda of every event you host or attend, grouped by month. Reuses the
/// Home compact row for a consistent look.
struct CalendarView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @State private var selectedEvent: Event?

    private var myId: UUID? { authManager.currentUser?.id }
    private func mine(_ e: Event) -> Bool {
        e.hostId == myId || (myId != nil && e.guests.contains { $0.userId == myId })
    }
    private var events: [Event] {
        allEvents.filter { !$0.isDraft && mine($0) }
    }

    private var grouped: [(title: String, key: Int, events: [Event])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: events) { event -> Int in
            let c = cal.dateComponents([.year, .month], from: event.startDate)
            return (c.year ?? 0) * 100 + (c.month ?? 0)
        }
        return groups
            .sorted { $0.key < $1.key }
            .map { (title: monthTitle($0.value.first?.startDate ?? Date()), key: $0.key, events: $0.value.sorted { $0.startDate < $1.startDate }) }
    }

    private func monthTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("Calendar")
                        .gatherScreenTitle()
                        .foregroundStyle(Color.gatherPrimaryText)
                        .padding(.top, Spacing.xs)

                    if events.isEmpty {
                        emptyState
                    } else {
                        ForEach(grouped, id: \.key) { group in
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                HStack(spacing: Spacing.xs) {
                                    Text(group.title.uppercased())
                                        .gatherEyebrow()
                                        .foregroundStyle(Color.accentPurpleFallback)
                                    Rectangle()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 1)
                                }
                                VStack(spacing: Spacing.xs) {
                                    ForEach(group.events, id: \.id) { event in
                                        Button { selectedEvent = event } label: {
                                            HomeUpcomingRow(event: event, hosting: event.hostId == myId)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                // The agenda is a single column of rows; on the wide iPad
                // canvas cap it to a comfortable reading width and center it
                // rather than letting rows stretch edge to edge.
                .frame(maxWidth: horizontalSizeClass == .regular ? 700 : .infinity, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, Spacing.xs)
                .padding(.bottom, 120)
            }
            .background(Color.gatherCanvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedEvent) { EventDetailView(event: $0) }
        }
    }

    private var emptyState: some View {
        GatherEmptyState(
            icon: "calendar",
            title: "No events yet",
            message: "Events you host or join show up here, organized by month."
        )
        .padding(.top, Spacing.xl)
    }
}
