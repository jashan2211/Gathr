import SwiftUI
import SwiftData

struct ExploreView: View {
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedCategory: EventCategory?
    @State private var selectedEvent: Event?
    @State private var showCreateEvent = false
    @State private var showFilterSheet = false
    @FocusState private var isSearchFocused: Bool

    // Location filters
    @State private var selectedCity: String?
    @State private var selectedState: String?
    @State private var selectedCountry: String?

    var body: some View {
        let result = filterResult
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Custom Header
                    greetingHeader
                        .padding(.horizontal)
                        .padding(.bottom, Spacing.md)

                    // Search + Filter Row
                    searchAndFilterBar
                        .padding(.horizontal)
                        .padding(.bottom, Spacing.md)

                    // Active Filters
                    if hasActiveFilters {
                        activeFilterChips
                            .padding(.horizontal)
                            .padding(.bottom, Spacing.sm)
                    }

                    // Category Chips
                    categoryChips
                        .padding(.bottom, Spacing.lg)

                    // Featured Event
                    if let featured = result.featuredEvent {
                        featuredCard(event: featured)
                            .padding(.horizontal)
                            .padding(.bottom, Spacing.lg)
                            .bouncyAppear()
                    }

                    // Happening Soon
                    if !result.happeningSoonEvents.isEmpty {
                        happeningSoonSection(events: result.happeningSoonEvents)
                            .padding(.bottom, Spacing.lg)
                            .bouncyAppear(delay: 0.05)
                    }

                    // Events
                    if result.filteredEvents.isEmpty {
                        emptyState
                            .padding(.horizontal)
                            .transition(.opacity)
                    } else {
                        eventsGrid(events: result.nonFeaturedGridEvents)
                            .padding(.horizontal)
                            .animation(.easeInOut(duration: 0.2), value: result.filteredEvents.map(\.id))
                    }

                    // Create Event CTA
                    createEventCTA
                        .padding(.horizontal)
                        .padding(.top, Spacing.lg)
                        .padding(.bottom, Spacing.xl)
                        .bouncyAppear(delay: 0.1)
                }
                .padding(.bottom, Layout.tabBarHeight + 20)
            }
            .refreshable {
                try? await Task.sleep(for: .milliseconds(500))
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedEvent) { event in
                EventDetailView(event: event)
                    .toolbar(.visible, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .sheet(isPresented: $showCreateEvent) {
                CreateEventView()
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showFilterSheet) {
                let cities = Array(Set(publicEvents.compactMap { $0.location?.city })).sorted()
                let states = Array(Set(publicEvents.compactMap { $0.location?.state })).sorted()
                let countries = Array(Set(publicEvents.compactMap { $0.location?.country })).sorted()
                LocationFilterSheet(
                    availableCities: cities,
                    availableStates: states,
                    availableCountries: countries,
                    selectedCity: $selectedCity,
                    selectedState: $selectedState,
                    selectedCountry: $selectedCountry
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await MainActor.run { debouncedSearchText = newValue }
                }
            }
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(timeGreeting)
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)

                Text("Explore")
                    .font(GatherFont.largeTitle)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .accessibilityAddTraits(.isHeader)
            }

            Spacer()

            // Event count pill
            if !publicEvents.isEmpty {
                Text("\(publicEvents.count) events")
                    .font(GatherFont.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.accentPurpleFallback)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.glassBorderTop, Color.glassBorderBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .clipShape(Capsule())
            }
        }
        .padding(.top, Spacing.xl)
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late night vibes"
        }
    }

    // MARK: - Search + Filter Bar

    private var searchAndFilterBar: some View {
        HStack(spacing: Spacing.sm) {
            // Search field - frosted glass
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(isSearchFocused ? Color.accentPurpleFallback : Color.gatherSecondaryText)
                    .fontWeight(.medium)
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSearchFocused)

                TextField("Search events, venues...", text: $searchText)
                    .font(GatherFont.body)
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.gatherSecondaryText)
                            .font(.body)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .strokeBorder(
                        isSearchFocused
                            ? AnyShapeStyle(Color.accentPurpleFallback.opacity(0.5))
                            : AnyShapeStyle(LinearGradient(
                                colors: [Color.glassBorderTop, Color.glassBorderBottom],
                                startPoint: .top,
                                endPoint: .bottom
                              )),
                        lineWidth: isSearchFocused ? 1.5 : 1
                    )
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSearchFocused)

            // Filter button
            Button {
                HapticService.tabSwitch()
                showFilterSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(hasLocationFilter ? .white : Color.gatherSecondaryText)
                        .frame(width: 44, height: 44)
                        .background(
                            hasLocationFilter
                                ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                                : AnyShapeStyle(.ultraThinMaterial)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .strokeBorder(
                                    hasLocationFilter
                                        ? AnyShapeStyle(Color.clear)
                                        : AnyShapeStyle(LinearGradient(
                                            colors: [Color.glassBorderTop, Color.glassBorderBottom],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )),
                                    lineWidth: 1
                                )
                        )

                    if hasLocationFilter {
                        Circle()
                            .fill(Color.accentPinkFallback)
                            .frame(width: 8, height: 8)
                            .offset(x: -4, y: 4)
                    }
                }
            }
            .accessibilityLabel("Filter events")
        }
    }

    // MARK: - Active Filter Chips

    private var activeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                if let city = selectedCity {
                    filterChip(label: city, icon: "building.2") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCity = nil
                        }
                    }
                }
                if let state = selectedState {
                    filterChip(label: state, icon: "map") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedState = nil
                        }
                    }
                }
                if let country = selectedCountry {
                    filterChip(label: country, icon: "globe") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCountry = nil
                        }
                    }
                }
                if let category = selectedCategory {
                    filterChip(label: category.displayName, icon: category.icon) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = nil
                        }
                    }
                }

                // Clear all
                if activeFilterCount > 1 {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCity = nil
                            selectedState = nil
                            selectedCountry = nil
                            selectedCategory = nil
                        }
                    } label: {
                        Text("Clear all")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.accentPurpleFallback)
                    }
                    .padding(.leading, Spacing.xs)
                }
            }
        }
    }

    private func filterChip(label: String, icon: String, onRemove: @escaping () -> Void) -> some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(GatherFont.caption)
                    .fontWeight(.medium)
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
            .background(LinearGradient.gatherAccentGradient)
            .clipShape(Capsule())
        }
        .accessibilityLabel("Remove \(label) filter")
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ExploreCategoryChip(
                    title: "All",
                    emoji: "\u{2728}",
                    count: publicEvents.count,
                    gradient: LinearGradient.gatherAccentGradient,
                    isSelected: selectedCategory == nil
                ) {
                    HapticService.tabSwitch()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedCategory = nil
                    }
                }

                ForEach(EventCategory.allCases, id: \.self) { category in
                    let count = categoryCounts[category] ?? 0
                    ExploreCategoryChip(
                        title: category.displayName,
                        emoji: category.emoji,
                        count: count,
                        gradient: LinearGradient.categoryGradient(for: category),
                        isSelected: selectedCategory == category
                    ) {
                        HapticService.tabSwitch()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Featured Card

    private func featuredCard(event: Event) -> some View {
        Button {
            selectedEvent = event
        } label: {
            ZStack(alignment: .bottom) {
                // Mesh gradient background
                CategoryMeshBackground(category: event.category)
                    .frame(height: Layout.heroHeightFeatured)
                    .overlay(alignment: .topLeading) {
                        Text(event.category.emoji)
                            .font(.system(size: 80))
                            .opacity(0.2)
                            .rotationEffect(.degrees(-15))
                            .offset(x: -10, y: -10)
                    }

                // Dark overlay for readability
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.4), .black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Content
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // Top row - Featured badge + countdown
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                            Text("FEATURED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .tracking(1)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial.opacity(0.8))
                        .clipShape(Capsule())

                        if event.isDemo {
                            Text("SAMPLE")
                                .font(.caption2)
                                .fontWeight(.heavy)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.85))
                                .clipShape(Capsule())
                        }

                        Spacer()

                        // Countdown
                        Text(relativeDate(event.startDate))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial.opacity(0.8))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    // Event info
                    Text(event.title)
                        .font(GatherFont.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Info row with frosted glass
                    HStack(spacing: Spacing.md) {
                        if let location = event.location {
                            Label(location.shortLocation ?? location.name, systemImage: "mappin.circle.fill")
                                .lineLimit(1)
                        }

                        Label(featuredFormattedDate(event.startDate), systemImage: "calendar")

                        Spacer()

                        // Attendee avatars
                        let attendingNames = event.guests
                            .filter { $0.status == .attending }
                            .prefix(3)
                            .map { $0.name }
                        if !attendingNames.isEmpty {
                            HStack(spacing: 4) {
                                AvatarStack(names: Array(attendingNames), maxDisplay: 3, size: 20)
                                Text("\(event.totalAttendingHeadcount)+")
                                    .fontWeight(.semibold)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 10))
                                Text("\(event.totalAttendingHeadcount)+")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .font(GatherFont.caption)
                    .foregroundStyle(.white.opacity(0.95))
                }
                .padding(Spacing.lg)
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        }
        .buttonStyle(CardPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Featured event: \(event.title). \(event.location?.name ?? ""). \(event.totalAttendingHeadcount) attending.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to view event details")
    }

    // MARK: - Happening Soon Section

    private func happeningSoonSection(events: [Event]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section header
            HStack {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.warmCoral)
                        .font(.callout)
                    Text("Happening Soon")
                        .font(GatherFont.title3)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .accessibilityAddTraits(.isHeader)
                }

                Spacer()

                Text("\(events.count) events")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(.horizontal)

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(events, id: \.id) { event in
                        Button {
                            selectedEvent = event
                        } label: {
                            HappeningSoonCard(event: event)
                        }
                        .buttonStyle(CardPressStyle())
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Double tap to view event details")
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Events Grid

    private func eventsGrid(events: [Event]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            HStack(alignment: .firstTextBaseline) {
                Text(sectionTitle)
                    .font(GatherFont.title3)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Text("\(events.count) events")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            // 2-Column Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: Spacing.sm),
                GridItem(.flexible(), spacing: Spacing.sm)
            ], spacing: Spacing.sm) {
                ForEach(events, id: \.id) { event in
                    Button {
                        selectedEvent = event
                    } label: {
                        ExploreGridCard(event: event)
                    }
                    .buttonStyle(CardPressStyle())
                }
            }
        }
    }

    // MARK: - Create Event CTA

    private var createEventCTA: some View {
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
                    Text("Host Your Own Event")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text("Create and share with friends")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentPurpleFallback)
            }
            .padding(Spacing.md)
            .glassCard()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Host your own event. Create and share with friends.")
            .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
                .frame(height: 40)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentPurpleFallback.opacity(0.12), Color.accentPinkFallback.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)

                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient.gatherAccentGradient
                    )
            }

            VStack(spacing: Spacing.sm) {
                Text("No Events Found")
                    .font(GatherFont.title3)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .accessibilityAddTraits(.isHeader)

                Text(emptyMessage)
                    .font(GatherFont.body)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            if hasActiveFilters {
                Button {
                    withAnimation {
                        selectedCity = nil
                        selectedState = nil
                        selectedCountry = nil
                        selectedCategory = nil
                        searchText = ""
                    }
                } label: {
                    Text("Clear Filters")
                        .font(GatherFont.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(LinearGradient.gatherAccentGradient)
                        .clipShape(Capsule())
                }
            }

            Spacer()
        }
    }

    // MARK: - Computed Properties

    private var publicEvents: [Event] {
        allEvents.filter { $0.privacy == .publicEvent && $0.isUpcoming }
    }

    /// Pre-computed category counts to avoid redundant filtering per chip
    private var categoryCounts: [EventCategory: Int] {
        Dictionary(grouping: publicEvents, by: \.category).mapValues(\.count)
    }

    /// Single-pass computation of all filtered/derived event lists
    private struct FilteredResult {
        let filteredEvents: [Event]
        let featuredEvent: Event?
        let happeningSoonEvents: [Event]
        let nonFeaturedGridEvents: [Event]
    }

    private func featuredScore(_ event: Event) -> Int {
        var score = event.totalAttendingHeadcount * 3

        // Hero media bonus
        if event.heroMediaURL != nil { score += 5 }

        // Urgency bonus: events within 7 days get +10
        let daysUntilStart = Calendar.current.dateComponents([.day], from: Date(), to: event.startDate).day ?? 0
        if daysUntilStart >= 0 && daysUntilStart < 7 { score += 10 }
        if daysUntilStart > 30 { score -= 20 }

        // Past events should never be featured
        if daysUntilStart < 0 { return -1 }

        return score
    }

    private var filterResult: FilteredResult {
        // 1. Filter events
        var events = publicEvents

        if !debouncedSearchText.isEmpty {
            events = events.filter { event in
                event.title.localizedStandardContains(debouncedSearchText) ||
                (event.eventDescription?.localizedStandardContains(debouncedSearchText) ?? false) ||
                (event.location?.name.localizedStandardContains(debouncedSearchText) ?? false) ||
                (event.location?.city?.localizedStandardContains(debouncedSearchText) ?? false)
            }
        }

        if let category = selectedCategory {
            events = events.filter { $0.category == category }
        }

        if let city = selectedCity {
            events = events.filter { $0.location?.city == city }
        }

        if let state = selectedState {
            events = events.filter { $0.location?.state == state }
        }

        if let country = selectedCountry {
            events = events.filter { $0.location?.country == country }
        }

        // 2. Determine featured event
        let featured: Event?
        if let best = events.max(by: { featuredScore($0) < featuredScore($1) }),
           featuredScore(best) > 0 {
            featured = best
        } else {
            featured = nil
        }

        // 3. Non-featured events
        let nonFeatured = events.filter { $0.id != featured?.id }

        // 4. Happening soon (within 7 days, excluding featured)
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let happeningSoon = nonFeatured
            .filter { $0.startDate <= weekFromNow }
            .sorted { $0.startDate < $1.startDate }

        // 5. Grid events (excluding featured and happening-soon)
        let soonIds = Set(happeningSoon.map { $0.id })
        let gridEvents = nonFeatured.filter { !soonIds.contains($0.id) }

        return FilteredResult(
            filteredEvents: events,
            featuredEvent: featured,
            happeningSoonEvents: happeningSoon,
            nonFeaturedGridEvents: gridEvents
        )
    }

    private var hasLocationFilter: Bool {
        selectedCity != nil || selectedState != nil || selectedCountry != nil
    }

    private var hasActiveFilters: Bool {
        hasLocationFilter || selectedCategory != nil
    }

    private var activeFilterCount: Int {
        var count = 0
        if selectedCity != nil { count += 1 }
        if selectedState != nil { count += 1 }
        if selectedCountry != nil { count += 1 }
        if selectedCategory != nil { count += 1 }
        return count
    }

    private var sectionTitle: String {
        if let city = selectedCity { return "Events in \(city)" }
        if let state = selectedState { return "Events in \(state)" }
        if let country = selectedCountry { return "Events in \(country)" }
        return "All Events"
    }

    private var emptyMessage: String {
        if hasActiveFilters || !searchText.isEmpty {
            return "Try adjusting your filters or search to find more events"
        }
        return "Check back later or create your own event"
    }

    private func featuredFormattedDate(_ date: Date) -> String {
        GatherDateFormatter.monthDay.string(from: date)
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0

        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        if days <= 7 { return "In \(days) days" }

        return GatherDateFormatter.monthDay.string(from: date)
    }
}

// MARK: - Explore Category Chip

struct ExploreCategoryChip: View {
    let title: String
    let emoji: String
    var count: Int = 0
    let gradient: LinearGradient
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.footnote)
                Text(title)
                    .font(GatherFont.caption)
                    .fontWeight(.semibold)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : Color.gatherSecondaryText)
                        .contentTransition(.numericText())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            isSelected
                                ? .white.opacity(0.2)
                                : Color.gatherTertiaryBackground
                        )
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? AnyShapeStyle(gradient)
                    : AnyShapeStyle(.ultraThinMaterial)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? AnyShapeStyle(Color.clear)
                            : AnyShapeStyle(LinearGradient(
                                colors: [Color.glassBorderTop, Color.glassBorderBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .accessibilityLabel("\(title)\(count > 0 ? ", \(count) events" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - EventCategory Extensions

extension EventCategory {
    var emoji: String {
        switch self {
        case .wedding: return "\u{1F492}"
        case .party: return "\u{1F389}"
        case .office: return "\u{1F3E2}"
        case .conference: return "\u{1F399}"
        case .concert: return "\u{1F3B5}"
        case .meetup: return "\u{1F91D}"
        case .custom: return "\u{2B50}"
        }
    }
}

// MARK: - Category Gradients

extension LinearGradient {
    static func categoryGradient(for category: EventCategory) -> LinearGradient {
        switch category {
        case .wedding:
            return LinearGradient(colors: [.weddingRose, .weddingRoseLight], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .party:
            return LinearGradient(colors: [.accentPurpleFallback, .accentPinkFallback], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .office:
            return LinearGradient(colors: [.officeBlue, .officeBlueLight], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .conference:
            return LinearGradient(colors: [.conferenceAmber, .conferenceGold], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .concert:
            return LinearGradient(colors: [.concertRed, .concertSalmon], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .meetup:
            return LinearGradient(colors: [.meetupTeal, .meetupGreenLight], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .custom:
            return LinearGradient(colors: [.customSlate, .customSlateLight], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static func categoryGradientVibrant(for category: EventCategory) -> LinearGradient {
        switch category {
        case .wedding:
            return LinearGradient(colors: [.weddingRoseDeep, .weddingRoseMid, .weddingBlush], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .party:
            return LinearGradient(colors: [.partyPurple, .accentPinkFallback, .warmOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .office:
            return LinearGradient(colors: [.officeBlueDeep, .officeBlueBright, .officeBlueSky], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .conference:
            return LinearGradient(colors: [.conferenceAmberDeep, .conferenceOrangeGold, .conferenceGoldLight], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .concert:
            return LinearGradient(colors: [.concertRedDeep, .concertCrimson, .warmOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .meetup:
            return LinearGradient(colors: [.meetupTealDeep, .meetupEmerald, .meetupEmeraldLight], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .custom:
            return LinearGradient(colors: [.customSlateDark, .customSlateMid, .customSlatePale], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Preview

#Preview {
    ExploreView()
        .modelContainer(for: Event.self, inMemory: true)
}
