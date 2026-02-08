import SwiftUI
import SwiftData

struct ExploreView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @State private var searchText = ""
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
                    if let featured = featuredEvent {
                        featuredCard(event: featured)
                            .padding(.horizontal)
                            .padding(.bottom, Spacing.lg)
                            .bouncyAppear()
                    }

                    // Happening Soon
                    if !happeningSoonEvents.isEmpty {
                        happeningSoonSection
                            .padding(.bottom, Spacing.lg)
                            .bouncyAppear(delay: 0.05)
                    }

                    // Events
                    if filteredEvents.isEmpty {
                        emptyState
                            .padding(.horizontal)
                    } else {
                        eventsGrid
                            .padding(.horizontal)
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
                LocationFilterSheet(
                    availableCities: availableCities,
                    availableStates: availableStates,
                    availableCountries: availableCountries,
                    selectedCity: $selectedCity,
                    selectedState: $selectedState,
                    selectedCountry: $selectedCountry
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.gatherPrimaryText)
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
                    .animation(.easeInOut(duration: 0.2), value: isSearchFocused)

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
                    }
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
            .animation(.easeInOut(duration: 0.2), value: isSearchFocused)

            // Filter button
            Button {
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
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(GatherFont.caption)
                .fontWeight(.medium)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .background(LinearGradient.gatherAccentGradient)
        .clipShape(Capsule())
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedCategory = nil
                    }
                }

                ForEach(EventCategory.allCases, id: \.self) { category in
                    let count = publicEvents.filter { $0.category == category }.count
                    ExploreCategoryChip(
                        title: category.displayName,
                        emoji: category.emoji,
                        count: count,
                        gradient: LinearGradient.categoryGradient(for: category),
                        isSelected: selectedCategory == category
                    ) {
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
                    .frame(height: 240)
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
                        .font(.system(size: 24, weight: .bold, design: .rounded))
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
    }

    // MARK: - Happening Soon Section

    private var happeningSoonSection: some View {
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
                }

                Spacer()

                Text("\(happeningSoonEvents.count) events")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(.horizontal)

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(Array(happeningSoonEvents.enumerated()), id: \.element.id) { index, event in
                        Button {
                            selectedEvent = event
                        } label: {
                            HappeningSoonCard(event: event)
                                .bouncyAppear(delay: Double(index) * 0.05)
                        }
                        .buttonStyle(CardPressStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Events Grid

    private var eventsGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            HStack(alignment: .firstTextBaseline) {
                Text(sectionTitle)
                    .font(GatherFont.title3)
                    .foregroundStyle(Color.gatherPrimaryText)

                Spacer()

                Text("\(nonFeaturedGridEvents.count) events")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }

            // 2-Column Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: Spacing.sm),
                GridItem(.flexible(), spacing: Spacing.sm)
            ], spacing: Spacing.sm) {
                ForEach(Array(nonFeaturedGridEvents.enumerated()), id: \.element.id) { index, event in
                    Button {
                        selectedEvent = event
                    } label: {
                        ExploreGridCard(event: event)
                            .bouncyAppear(delay: Double(index) * 0.04)
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

    private var filteredEvents: [Event] {
        var events = publicEvents

        if !searchText.isEmpty {
            events = events.filter { event in
                event.title.localizedCaseInsensitiveContains(searchText) ||
                (event.eventDescription?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (event.location?.name.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (event.location?.city?.localizedCaseInsensitiveContains(searchText) ?? false)
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

        return events
    }

    private var featuredEvent: Event? {
        filteredEvents.max(by: { $0.totalAttendingHeadcount < $1.totalAttendingHeadcount })
    }

    private var nonFeaturedEvents: [Event] {
        filteredEvents.filter { $0.id != featuredEvent?.id }
    }

    /// Events happening within 7 days (excluding featured)
    private var happeningSoonEvents: [Event] {
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return nonFeaturedEvents
            .filter { $0.startDate <= weekFromNow }
            .sorted { $0.startDate < $1.startDate }
    }

    /// Events for the grid (excluding featured and happening-soon)
    private var nonFeaturedGridEvents: [Event] {
        let soonIds = Set(happeningSoonEvents.map { $0.id })
        return nonFeaturedEvents.filter { !soonIds.contains($0.id) }
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

    // Available locations from public events
    private var availableCities: [String] {
        Array(Set(publicEvents.compactMap { $0.location?.city })).sorted()
    }

    private var availableStates: [String] {
        Array(Set(publicEvents.compactMap { $0.location?.state })).sorted()
    }

    private var availableCountries: [String] {
        Array(Set(publicEvents.compactMap { $0.location?.country })).sorted()
    }

    private func featuredFormattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0

        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        if days <= 7 { return "In \(days) days" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
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
                    .font(.system(size: 14))
                Text(title)
                    .font(GatherFont.caption)
                    .fontWeight(.semibold)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : Color.gatherSecondaryText)
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
    }
}

// MARK: - Happening Soon Card

struct HappeningSoonCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Gradient hero with date overlay
            ZStack(alignment: .topLeading) {
                CategoryMeshBackground(category: event.category)
                    .frame(width: 200, height: 110)
                    .overlay(alignment: .bottomTrailing) {
                        Text(event.category.emoji)
                            .font(.system(size: 36))
                            .opacity(0.3)
                            .offset(x: -8, y: -8)
                    }

                // Date chip
                VStack(spacing: 0) {
                    Text(dayOfMonth)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(monthAbbrev)
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                }
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                .padding(Spacing.xs)
            }
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
        .glassCard()
    }

    private var dayOfMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: event.startDate)
    }

    private var monthAbbrev: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: event.startDate)
    }

    private var relativeDay: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: event.startDate)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: event.startDate)
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
                            .font(.system(size: 28))
                            .padding(Spacing.xs)
                    }

                // Price tag
                Text(priceLabel)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 3)
                    .background(priceColor)
                    .clipShape(Capsule())
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
        .glassCard()
    }

    private var priceLabel: String {
        let tiers = event.ticketTiers
        if let cheapest = tiers.min(by: { $0.price < $1.price }) {
            return cheapest.price == 0 ? "FREE" : "$\(NSDecimalNumber(decimal: cheapest.price).intValue)"
        }
        return "FREE"
    }

    private var priceColor: Color {
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
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return "This \(formatter.string(from: event.startDate))"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: event.startDate)
    }
}

// MARK: - Location Filter Sheet

struct LocationFilterSheet: View {
    let availableCities: [String]
    let availableStates: [String]
    let availableCountries: [String]

    @Binding var selectedCity: String?
    @Binding var selectedState: String?
    @Binding var selectedCountry: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // City
                    if !availableCities.isEmpty {
                        filterSection(
                            title: "City",
                            icon: "building.2.fill",
                            items: availableCities,
                            selected: selectedCity,
                            gradient: LinearGradient(
                                colors: [Color.accentPurpleFallback, Color.accentPurpleFallback.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        ) { city in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCity = selectedCity == city ? nil : city
                            }
                        }
                    }

                    // State
                    if !availableStates.isEmpty {
                        filterSection(
                            title: "State",
                            icon: "map.fill",
                            items: availableStates,
                            selected: selectedState,
                            gradient: LinearGradient(
                                colors: [Color.accentPinkFallback, Color.accentPinkFallback.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        ) { state in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedState = selectedState == state ? nil : state
                            }
                        }
                    }

                    // Country
                    if !availableCountries.isEmpty {
                        filterSection(
                            title: "Country",
                            icon: "globe",
                            items: availableCountries,
                            selected: selectedCountry,
                            gradient: LinearGradient(
                                colors: [Color.rsvpYesFallback, Color.rsvpYesFallback.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        ) { country in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCountry = selectedCountry == country ? nil : country
                            }
                        }
                    }

                    if availableCities.isEmpty && availableStates.isEmpty && availableCountries.isEmpty {
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "map")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.gatherSecondaryText.opacity(0.5))
                            Text("No location data available")
                                .font(GatherFont.body)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Filter by Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedCity != nil || selectedState != nil || selectedCountry != nil {
                        Button("Reset") {
                            withAnimation {
                                selectedCity = nil
                                selectedState = nil
                                selectedCountry = nil
                            }
                        }
                        .foregroundStyle(Color.accentPurpleFallback)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentPurpleFallback)
                }
            }
        }
    }

    private func filterSection(
        title: String,
        icon: String,
        items: [String],
        selected: String?,
        gradient: LinearGradient,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section header
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(Color.accentPurpleFallback)
                Text(title)
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)
            }

            // Chips
            GatherFlowLayout(spacing: Spacing.xs) {
                ForEach(items, id: \.self) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        Text(item)
                            .font(GatherFont.callout)
                            .fontWeight(selected == item ? .semibold : .regular)
                            .foregroundStyle(selected == item ? .white : Color.gatherPrimaryText)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                selected == item
                                    ? AnyShapeStyle(gradient)
                                    : AnyShapeStyle(Color.gatherSecondaryBackground)
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        selected == item ? Color.clear : Color.gatherSecondaryText.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .scaleEffect(selected == item ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selected == item)
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct GatherFlowLayout: SwiftUI.Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }

        let totalHeight = currentY + rowHeight
        return ArrangementResult(
            positions: positions,
            sizes: sizes,
            size: CGSize(width: maxWidth, height: totalHeight)
        )
    }

    struct ArrangementResult {
        var positions: [CGPoint]
        var sizes: [CGSize]
        var size: CGSize
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
            return LinearGradient(colors: [Color(red: 0.95, green: 0.4, blue: 0.6), Color(red: 0.98, green: 0.6, blue: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .party:
            return LinearGradient(colors: [Color.accentPurpleFallback, Color.accentPinkFallback], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .office:
            return LinearGradient(colors: [Color(red: 0.2, green: 0.5, blue: 0.9), Color(red: 0.4, green: 0.7, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .conference:
            return LinearGradient(colors: [Color(red: 0.95, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.8, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .concert:
            return LinearGradient(colors: [Color(red: 0.9, green: 0.2, blue: 0.3), Color(red: 1.0, green: 0.4, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .meetup:
            return LinearGradient(colors: [Color(red: 0.1, green: 0.7, blue: 0.5), Color(red: 0.3, green: 0.9, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .custom:
            return LinearGradient(colors: [Color(red: 0.5, green: 0.5, blue: 0.6), Color(red: 0.7, green: 0.7, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static func categoryGradientVibrant(for category: EventCategory) -> LinearGradient {
        switch category {
        case .wedding:
            return LinearGradient(colors: [Color(red: 0.9, green: 0.3, blue: 0.5), Color(red: 0.95, green: 0.5, blue: 0.7), Color(red: 1.0, green: 0.7, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .party:
            return LinearGradient(colors: [Color(red: 0.49, green: 0.23, blue: 0.93), Color.accentPinkFallback, Color(red: 1.0, green: 0.5, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .office:
            return LinearGradient(colors: [Color(red: 0.1, green: 0.4, blue: 0.85), Color(red: 0.3, green: 0.6, blue: 1.0), Color(red: 0.5, green: 0.8, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .conference:
            return LinearGradient(colors: [Color(red: 0.9, green: 0.5, blue: 0.1), Color(red: 1.0, green: 0.7, blue: 0.2), Color(red: 1.0, green: 0.85, blue: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .concert:
            return LinearGradient(colors: [Color(red: 0.85, green: 0.1, blue: 0.2), Color(red: 0.95, green: 0.3, blue: 0.4), Color(red: 1.0, green: 0.5, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .meetup:
            return LinearGradient(colors: [Color(red: 0.0, green: 0.6, blue: 0.45), Color(red: 0.2, green: 0.8, blue: 0.55), Color(red: 0.4, green: 0.95, blue: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .custom:
            return LinearGradient(colors: [Color(red: 0.4, green: 0.4, blue: 0.55), Color(red: 0.6, green: 0.6, blue: 0.75), Color(red: 0.75, green: 0.75, blue: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ExploreView()
        .modelContainer(for: Event.self, inMemory: true)
}
