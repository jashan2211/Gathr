import SwiftUI
import SwiftData

struct MyEventsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Query(sort: \Event.startDate) private var events: [Event]
    @State private var selectedTab: EventTab = .active
    @State private var selectedEvent: Event?
    @State private var showCreateEvent = false

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

                        // Create Event Card (only on Active tab)
                        if selectedTab == .active {
                            createEventCard
                                .bouncyAppear(delay: 0.03)
                        }

                        ForEach(Array(filteredEvents.enumerated()), id: \.element.id) { index, event in
                            Button {
                                selectedEvent = event
                            } label: {
                                MyEventCard(event: event)
                            }
                            .buttonStyle(CardPressStyle())
                            .bouncyAppear(delay: Double(index) * 0.04)
                        }

                        if filteredEvents.isEmpty && selectedTab != .active {
                            emptyState
                        }
                    }
                    .padding()
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
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                            : AnyShapeStyle(Color.clear)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                selectedTab == tab
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
                        selectedTab == tab
                            ? nil
                            : Capsule()
                                .fill(.ultraThinMaterial)
                    )
                }
                .scaleEffect(selectedTab == tab ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedTab == tab)
            }
        }
        .padding(.horizontal)
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
            .glassCard()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
                .frame(height: 40)

            ZStack {
                Circle()
                    .fill(Color.accentPurpleFallback.opacity(0.08))
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(Color.accentPinkFallback.opacity(0.06))
                    .frame(width: 70, height: 70)
                Image(systemName: emptyStateIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient.gatherAccentGradient
                    )
            }

            VStack(spacing: Spacing.sm) {
                Text(emptyStateTitle)
                    .font(GatherFont.title3)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text(emptyStateMessage)
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
    }

    // MARK: - Filtered Events

    private var filteredEvents: [Event] {
        let userId = authManager.currentUser?.id
        let hostedEvents = events.filter { $0.hostId == userId }

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
        let userId = authManager.currentUser?.id
        let hostedEvents = events.filter { $0.hostId == userId }
        switch tab {
        case .active: return hostedEvents.filter { $0.isUpcoming && !$0.isDraft }.count
        case .drafts: return hostedEvents.filter { $0.isDraft }.count
        case .past: return hostedEvents.filter { $0.isPast && !$0.isDraft }.count
        }
    }

    private var emptyStateIcon: String {
        switch selectedTab {
        case .active: return "calendar"
        case .drafts: return "doc"
        case .past: return "clock"
        }
    }

    private var emptyStateTitle: String {
        switch selectedTab {
        case .active: return "No active events"
        case .drafts: return "No drafts"
        case .past: return "No past events"
        }
    }

    private var emptyStateMessage: String {
        switch selectedTab {
        case .active: return "Your upcoming events will appear here"
        case .drafts: return "Draft events you haven't published yet"
        case .past: return "Your past events will appear here"
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
        .glassCard()
    }
}

// MARK: - My Event Card

struct MyEventCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category gradient header
            ZStack(alignment: .leading) {
                LinearGradient.categoryGradientVibrant(for: event.category)
                    .frame(height: 6)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Top row: emoji + title + badges
                HStack(alignment: .top, spacing: Spacing.sm) {
                    // Date badge
                    VStack(spacing: 1) {
                        Text(event.category.emoji)
                            .font(.system(size: 14))
                        Text(dayNumber)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.gatherPrimaryText)
                        Text(monthAbbrev)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.forCategory(event.category))
                    }
                    .frame(width: 48, height: 54)
                    .background(LinearGradient.cardGradient(for: event.category))
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
        }
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title). \(formattedTime). \(event.guests.count) guests, \(event.totalAttendingHeadcount) attending\(event.isDraft ? ". Draft" : event.privacy == .publicEvent ? ". Public" : "")")
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
