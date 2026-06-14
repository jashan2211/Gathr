import SwiftUI
import SwiftData

struct GoingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @State private var selectedEvent: Event?
    @State private var filter: TimeFilter = .upcoming
    @Namespace private var zoomNamespace

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

                    // Next Up Hero (only for upcoming, swipeable top 3)
                    if filter == .upcoming, !filteredEvents.isEmpty {
                        let heroEvents = Array(filteredEvents.prefix(3))
                        if heroEvents.count > 1 {
                            TabView {
                                ForEach(heroEvents, id: \.id) { event in
                                    // Only the first hero is a zoom source — the others
                                    // also appear as rows below and ids must be unique.
                                    nextUpHero(event: event, isZoomSource: event.id == heroEvents.first?.id)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .automatic))
                            .frame(height: Layout.heroHeight + 40)
                            .bouncyAppear()
                        } else if let next = heroEvents.first {
                            nextUpHero(event: next, isZoomSource: true)
                                .bouncyAppear()
                        }
                    }

                    if filteredEvents.isEmpty {
                        emptyState
                    } else {
                        // Events List (2-column on iPad)
                        let list = filter == .upcoming ? Array(filteredEvents.dropFirst()) : filteredEvents
                        let eventCards = ForEach(list, id: \.id) { event in
                            Button {
                                selectedEvent = event
                            } label: {
                                GoingEventCard(event: event)
                            }
                            .buttonStyle(CardPressStyle())
                            .zoomSource(id: event.id, in: zoomNamespace)
                        }
                        if horizontalSizeClass == .regular {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                                eventCards
                            }
                        } else {
                            LazyVStack(spacing: Spacing.sm) {
                                eventCards
                            }
                        }
                    }
                }
                .horizontalPadding()
                .padding(.vertical)
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
                    .zoomDestination(id: event.id, in: zoomNamespace)
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
                        HapticService.tabSwitch()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
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
                                            : Color.accentPurpleFallback.opacity(0.7)
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
                                : AnyShapeStyle(Color.gatherSecondaryBackground)
                        )
                        .clipShape(Capsule())
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

    @ViewBuilder
    private func nextUpHero(event: Event, isZoomSource: Bool = false) -> some View {
        let card = Button {
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

        if isZoomSource {
            card.zoomSource(id: event.id, in: zoomNamespace)
        } else {
            card
        }
    }

    // MARK: - Empty State

    private var emptyStateTitle: String {
        switch filter {
        case .upcoming: return "No upcoming events"
        case .thisWeek: return "Nothing this week"
        case .thisMonth: return "Nothing this month"
        case .past: return "No past events yet"
        }
    }

    private var emptyStateSubtitle: String {
        switch filter {
        case .upcoming: return "Explore events to find something you love"
        case .thisWeek: return "Check upcoming for your next event"
        case .thisMonth: return "Your next event might be coming soon"
        case .past: return "Your event history will appear here"
        }
    }

    private var emptyState: some View {
        GatherEmptyState(
            icon: "ticket",
            title: emptyStateTitle,
            message: emptyStateSubtitle,
            actionTitle: filter == .upcoming ? "Explore Events" : nil,
            action: filter == .upcoming ? { appState.selectedTab = .explore } : nil
        )
        .padding(.top, Spacing.xl)
    }

    // MARK: - Helpers

    private var attendingEvents: [Event] {
        guard let userId = authManager.currentUser?.id else { return [] }
        return allEvents.filter { event in
            event.guests.contains { $0.userId == userId && $0.status == .attending }
        }
    }

    private var filteredEvents: [Event] {
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
    @State private var todayPulse: Bool = false

    private var isHappeningToday: Bool {
        daysUntilCount == 0
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Date badge with category tint
            VStack(spacing: 1) {
                Text(event.category.emoji)
                    .font(.callout)
                Text(dayNumber)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.gatherPrimaryText)
                Text(monthAbbrev)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.forCategory(event.category))
            }
            .frame(width: 48, height: 56)
            .background(Color.gatherTertiaryBackground)
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
                    .font(.caption2)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .frame(width: 44)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .padding(.top, 3) // clear the accent bar
        .surfaceCard()
        .categoryAccentBar(Color.forCategory(event.category))
        .overlay(
            Group {
                if isHappeningToday {
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .strokeBorder(
                            Color.warmCoral.opacity(todayPulse ? 0.8 : 0.4),
                            lineWidth: todayPulse ? 2 : 1.5
                        )
                        .shadow(color: Color.warmCoral.opacity(todayPulse ? 0.35 : 0.15), radius: todayPulse ? 8 : 4, y: 0)
                }
            }
        )
        .onAppear {
            if isHappeningToday {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    todayPulse = true
                }
            }
        }
        .drawingGroup()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title). \(daysUntilCount <= 0 ? "Happening now" : daysUntilCount == 1 ? "Tomorrow" : "In \(daysUntilCount) days")")
        .accessibilityValue("\(event.location?.name ?? ""). \(formattedTime)")
        .accessibilityHint("Double tap to view event details")
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
        if d < 0 { return "\(abs(d))" }
        if d == 0 { return "Now" }
        if d == 1 { return "1" }
        return "\(d)"
    }

    private var daysLeftLabel: String {
        let d = daysUntilCount
        if d < 0 { return abs(d) == 1 ? "day ago" : "days ago" }
        if d == 0 { return "today" }
        if d == 1 { return "day" }
        return "days"
    }

    private var daysLeftColor: Color {
        let d = daysUntilCount
        if d < 0 { return Color.gatherSecondaryText }
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

// MARK: - Home (2026 redesign)

/// The unified landing screen: your next event as a poster hero, invites
/// waiting on a reply, everything else upcoming, and your drafts. Replaces the
/// old split between Going and My Events.
struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @State private var selectedEvent: Event?
    @State private var showCreate = false

    private var myId: UUID? { authManager.currentUser?.id }
    private var horizon: Date { Date().addingTimeInterval(-3600) }

    private func isHost(_ e: Event) -> Bool { e.hostId != nil && e.hostId == myId }
    private func isGuest(_ e: Event) -> Bool {
        guard let myId else { return false }
        return e.guests.contains { $0.userId == myId }
    }
    private func mine(_ e: Event) -> Bool { isHost(e) || isGuest(e) }

    /// A pending invitation belongs in "Invites waiting", not "Upcoming", so it
    /// never shows in both sections at once.
    private func isPendingInvite(_ e: Event) -> Bool {
        guard let myId else { return false }
        return e.guests.contains { $0.userId == myId && $0.status == .pending }
    }

    private var upcoming: [Event] {
        allEvents.filter { !$0.isDraft && $0.startDate >= horizon && mine($0) && !isPendingInvite($0) }
    }
    private var nextEvent: Event? { upcoming.first }
    private var laterEvents: [Event] { Array(upcoming.dropFirst()) }

    private var invitesWaiting: [Event] {
        allEvents.filter { !$0.isDraft && $0.startDate >= horizon && isPendingInvite($0) }
    }

    private var drafts: [Event] {
        allEvents.filter { $0.isDraft && isHost($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header

                    if let nextEvent {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            sectionLabel(isHost(nextEvent) ? "You're hosting next" : "Your next event")
                            HomePosterHero(event: nextEvent, hosting: isHost(nextEvent)) {
                                selectedEvent = nextEvent
                            }
                        }
                    }

                    if !invitesWaiting.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            sectionLabel("Invites waiting", badge: invitesWaiting.count)
                            ForEach(invitesWaiting, id: \.id) { event in
                                HomeInviteCard(
                                    event: event,
                                    onRespond: { respond(to: event, status: $0) },
                                    onOpen: { selectedEvent = event }
                                )
                            }
                        }
                    }

                    if !laterEvents.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            sectionLabel("Upcoming")
                            ForEach(laterEvents, id: \.id) { event in
                                Button { selectedEvent = event } label: {
                                    HomeUpcomingRow(event: event, hosting: isHost(event))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !drafts.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            sectionLabel("Drafts")
                            ForEach(drafts, id: \.id) { event in
                                Button { selectedEvent = event } label: {
                                    HomeUpcomingRow(event: event, hosting: true, isDraft: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if upcoming.isEmpty && invitesWaiting.isEmpty && drafts.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, Spacing.xs)
                .padding(.bottom, 120)
            }
            .background(Color.gatherCanvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedEvent) { EventDetailView(event: $0) }
            .sheet(isPresented: $showCreate) {
                CreateEventView().presentationDragIndicator(.visible)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundStyle(Color.gatherSecondaryText)
                Text("Home")
                    .font(.system(size: 34, weight: .heavy))
                    .kerning(-1)
                    .foregroundStyle(Color.gatherPrimaryText)
            }
            Spacer()
            NotificationBellButton()
        }
    }

    private func sectionLabel(_ text: String, badge: Int? = nil) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(text)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.gatherPrimaryText)
            if let badge, badge > 0 {
                Text("\(badge)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.accentPinkFallback, in: Capsule())
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(LinearGradient.gatherAccentGradient)
            Text("Nothing on the calendar")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.gatherPrimaryText)
            Text("Create your first event, or explore what's happening near you.")
                .font(.subheadline)
                .foregroundStyle(Color.gatherSecondaryText)
                .multilineTextAlignment(.center)
            Button { showCreate = true } label: {
                Text("Create event")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(LinearGradient.gatherAccentGradient, in: Capsule())
            }
            .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 12 ? "Good morning" : (h < 18 ? "Good afternoon" : "Good evening")
        if let name = authManager.currentUser?.name.split(separator: " ").first {
            return "\(part), \(name)"
        }
        return part
    }

    private func respond(to event: Event, status: RSVPStatus) {
        guard let myId, let guest = event.guests.first(where: { $0.userId == myId }) else { return }
        guest.status = status
        guest.respondedAt = Date()
        modelContext.safeSave()
        FirestoreService.shared.submitRSVP(
            eventId: event.id, guestId: guest.id, status: status,
            partySize: guest.plusOneCount, name: guest.name, note: nil
        )
        FirestoreService.shared.recordInvitedEvent(event, guestId: guest.id, status: status)
        HapticService.success()
    }
}

// MARK: - Home poster hero

struct HomePosterHero: View {
    let event: Event
    let hosting: Bool
    let onTap: () -> Void

    private var attendingCount: Int {
        event.guests.filter { $0.status == .attending }.count + (hosting ? 1 : 0)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                LinearGradient.categoryGradientVibrant(for: event.category)

                Text(event.category.emoji)
                    .font(.system(size: 130))
                    .opacity(0.16)
                    .rotationEffect(.degrees(-12))
                    .offset(x: 110, y: -34)

                LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(countdown)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.22), in: Capsule())
                        Spacer()
                        Text(hosting ? "HOSTING" : "GOING")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.25), in: Capsule())
                    }
                    Spacer()
                    Text(event.title)
                        .font(.system(size: 26, weight: .heavy))
                        .kerning(-0.5)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.bottom, 6)
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                        Text(dateString)
                        if let loc = event.location?.name {
                            Text("·")
                            Image(systemName: "mappin")
                            Text(loc).lineLimit(1)
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.bottom, 12)
                    HStack {
                        Text("\(attendingCount) going")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.2), in: Circle())
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.title), \(dateString), \(attendingCount) going")
    }

    private var countdown: String {
        let interval = event.startDate.timeIntervalSinceNow
        if interval < 0 { return "HAPPENING NOW" }
        let hours = interval / 3600
        if hours < 1 { return "IN \(max(1, Int(interval / 60))) MIN" }
        if hours < 24 { return "IN \(Int(hours)) HOURS" }
        let days = Int(hours / 24)
        if days == 1 { return "TOMORROW" }
        if days < 7 { return "IN \(days) DAYS" }
        return event.startDate.formatted(.dateTime.month(.abbreviated).day()).uppercased()
    }

    private var dateString: String {
        event.startDate.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}

// MARK: - Home compact row

struct HomeUpcomingRow: View {
    let event: Event
    let hosting: Bool
    var isDraft: Bool = false

    private var tagColor: Color {
        isDraft ? Color.gatherSecondaryText : (hosting ? Color.accentPurpleFallback : Color.rsvpYesFallback)
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            VStack(spacing: 0) {
                Text(event.startDate.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.forCategory(event.category))
                Text(event.startDate.formatted(.dateTime.day()))
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color.gatherPrimaryText)
            }
            .frame(width: 52, height: 52)
            .background(Color.gatherElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.gatherPrimaryText)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(event.startDate.formatted(.dateTime.hour().minute()))
                    if let loc = event.location?.name {
                        Text("· \(loc)").lineLimit(1)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.gatherSecondaryText)
            }
            Spacer()
            Text(isDraft ? "Draft" : (hosting ? "Hosting" : "Going"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tagColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tagColor.opacity(0.15), in: Capsule())
        }
        .padding(12)
        .background(Color.gatherSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Home invite card

struct HomeInviteCard: View {
    let event: Event
    let onRespond: (RSVPStatus) -> Void
    let onOpen: () -> Void

    private var subtitle: String {
        var s = event.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        if let loc = event.location?.city ?? event.location?.name {
            s += " · \(loc)"
        }
        return s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    Text(event.category.emoji).font(.system(size: 30))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.gatherPrimaryText)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.gatherSecondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                respondButton("Going", .attending, Color.rsvpYesFallback)
                respondButton("Maybe", .maybe, Color.rsvpMaybeFallback)
                respondButton("Can't", .declined, Color.rsvpNoFallback)
            }
        }
        .padding(14)
        .background(Color.gatherSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.accentPinkFallback.opacity(0.4), lineWidth: 1)
        )
    }

    private func respondButton(_ label: String, _ status: RSVPStatus, _ color: Color) -> some View {
        Button { onRespond(status) } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(color.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("RSVP \(label) to \(event.title)")
    }
}
