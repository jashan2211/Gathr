import SwiftUI
import SwiftData
import MapKit

// MARK: - Event Detail Tab

enum EventDetailTab: String, CaseIterable {
    case overview = "Overview"
    case activity = "Activity"
    case functions = "Functions"
    case guests = "Guests"
    case photos = "Photos"
    case budget = "Finance"

    var icon: String {
        switch self {
        case .overview: return "house.fill"
        case .activity: return "bubble.left.and.bubble.right.fill"
        case .functions: return "calendar.badge.clock"
        case .guests: return "person.2.fill"
        case .photos: return "photo.on.rectangle.angled"
        case .budget: return "chart.bar.fill"
        }
    }

    // Check if tab should be visible for a given event. `isHost` gates the
    // management-only tabs so an invited guest sees the event's functions,
    // schedule and photos but never the host's finances or guest management.
    func isVisible(for event: Event, isHost: Bool) -> Bool {
        switch self {
        case .overview:
            return true
        case .activity:
            return event.hasActivity
        case .functions:
            return event.hasFunctions
        case .guests:
            // Guest management (add/remove/invite) is host-only.
            return event.hasGuestManagement && isHost
        case .photos:
            return event.hasPhotos && EventFeature.photos.isAvailable
        case .budget:
            // Finances are private to the host — never shown to invitees.
            return event.hasBudget && isHost
        }
    }
}

// MARK: - Floating Bottom Bar Background

private extension View {
    /// Glass background for bottom-pinned action bars; shadow casts upward.
    func floatingBottomBar() -> some View {
        background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 15, y: -6)
        )
    }
}

// MARK: - Event Detail View

struct EventDetailView: View {
    @Bindable var event: Event
    @State private var selectedTab: EventDetailTab = .overview
    @State private var showRSVPSheet = false
    @State private var showManageRSVPSheet = false
    @State private var showShareSheet = false
    @State private var showGuestList = false
    @State private var showEditSheet = false
    @State private var showAddGuest = false
    @State private var showBudget = false
    @State private var showTicketPurchase = false
    @State private var showTicketManagement = false
    @State private var showWaitlist = false
    @State private var isLoadingRSVPs = false
    @State private var showDuplicateConfirmation = false
    @Namespace private var tabNamespace
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var eventTickets: [Ticket]

    /// True when shown in the deep-link fullScreenCover (which already covers the
    /// tab bar). Such an instance must NOT drive `appState.isInEvent`, or
    /// dismissing it would flip the flag off while a different, still-pushed event
    /// is on screen.
    let isPresentedInCover: Bool

    init(event: Event, isPresentedInCover: Bool = false) {
        self.event = event
        self.isPresentedInCover = isPresentedInCover
        let eventId = event.id
        _eventTickets = Query(
            filter: #Predicate<Ticket> { $0.eventId == eventId }
        )
    }

    var body: some View {
        // One scroll owns the whole page: the hero poster scrolls away with
        // content while the tab bar (a pinned section header) rises and
        // settles below the nav controls — the header itself is not sticky.
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                heroSection
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.top, Spacing.xs)

                Section {
                    tabContent
                        .id(selectedTab)
                        .transition(.opacity)
                        .padding(.top, Spacing.md)
                } header: {
                    pinnedTabBar
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.gatherCanvas.ignoresSafeArea())
        .refreshable {
            // Pull-to-refresh: hosts re-sync guest RSVPs (event + per-function).
            if isHost {
                await FirestoreService.shared.fetchRSVPs(for: event, into: modelContext)
                await FirestoreService.shared.fetchFunctionRSVPs(for: event, into: modelContext)
            }
        }
        .task {
            // Host opens the event — pull any RSVPs guests submitted from the
            // web invite page or their own app and merge them into the list.
            if isHost {
                isLoadingRSVPs = true
                await FirestoreService.shared.fetchRSVPs(for: event, into: modelContext)
                await FirestoreService.shared.fetchFunctionRSVPs(for: event, into: modelContext)
                isLoadingRSVPs = false
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isHost && event.isDraft {
                draftPublishBar
            } else if shouldShowRSVPButton {
                rsvpButtonBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // Collapse the main tab bar to a single Home button while this event is
        // open, and close back to Home when that button is tapped. The cover
        // instance skips this — it already sits over the tab bar, and letting it
        // toggle the shared flag would desync a different pushed event underneath.
        .onAppear { if !isPresentedInCover { appState.isInEvent = true } }
        .onDisappear { if !isPresentedInCover { appState.isInEvent = false } }
        .onChange(of: appState.exitEventToken) { _, _ in
            if !isPresentedInCover { dismiss() }
        }
        // Solid canvas behind the nav controls so scrolled content (the serif
        // hero title) slides cleanly under the status bar instead of colliding
        // with the clock and back/edit chips.
        .toolbarBackground(Color.gatherCanvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if isHost {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: Spacing.xs) {
                        Button {
                            showEditSheet = true
                        } label: {
                            heroControlIcon("pencil")
                        }
                        .accessibilityLabel("Edit Event")

                        Menu {
                            Button {
                                showShareSheet = true
                            } label: {
                                Label("Share Event", systemImage: "square.and.arrow.up")
                            }

                            Button {
                                showAddGuest = true
                            } label: {
                                Label("Add Guest", systemImage: "person.badge.plus")
                            }

                            if event.hasTicketing {
                                Button {
                                    showTicketManagement = true
                                } label: {
                                    Label("Manage Tickets", systemImage: "ticket")
                                }
                            }

                            Divider()

                            Button {
                                duplicateEvent()
                            } label: {
                                Label("Duplicate Event", systemImage: "plus.square.on.square")
                            }
                        } label: {
                            heroControlIcon("ellipsis")
                        }
                        .accessibilityLabel("More options")
                    }
                }
            } else {
                // Guests get exactly one action — surface it directly instead
                // of hiding a single-item menu behind an unlabeled "…".
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showShareSheet = true
                    } label: {
                        heroControlIcon("square.and.arrow.up")
                    }
                    .accessibilityLabel("Share Event")
                }
            }
        }
        .sheet(isPresented: $showRSVPSheet) {
            RSVPSheet(event: event)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showManageRSVPSheet) {
            if let guest = currentUserGuest {
                ManageRSVPSheet(
                    event: event,
                    guest: guest,
                    ticket: currentUserTicket
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showTicketPurchase) {
            TicketPurchaseSheet(event: event)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTicketManagement) {
            TicketManagementSheet(event: event)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWaitlist) {
            WaitlistSheet(event: event, tier: nil)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(event: event)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGuestList) {
            GuestListSheet(event: event)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEditSheet) {
            EditEventView(event: event)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddGuest) {
            AddGuestSheet(event: event)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Event Duplicated", isPresented: $showDuplicateConfirmation) {
            Button("Done", role: .cancel) { dismiss() }
        } message: {
            Text("A draft copy was added to your events. Open it from your events list to edit and publish.")
        }
    }

    // MARK: - Hero Section

    /// A circular control chip for the hero toolbar. A semi-opaque dark disc
    /// with a white glyph reads clearly over any category gradient (light or
    /// dark) — unlike the old tinted icon that vanished on purple/pink heroes.
    private func heroControlIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(Color.black.opacity(0.38), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
            // Keep the 34pt visual disc, but give the button a full 44pt
            // hit area so the two side-by-side chips meet the HIG minimum.
            .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
            .contentShape(Rectangle())
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Background
            if let heroURL = event.heroMediaURL {
                AsyncImage(url: heroURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    CategoryMeshBackground(category: event.category)
                }
                .accessibilityLabel("Event cover image for \(event.title)")
            } else {
                CategoryMeshBackground(category: event.category)
            }

            // Category emoji watermark
            Text(event.category.emoji)
                .font(.system(size: 80))
                .opacity(0.15)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(Spacing.lg)

            // Dark gradient overlay — grain sits above the scrim, below the
            // text, so the hero reads printed rather than flat-digital.
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.5), .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            .grain(0.08)

            // Event title overlay — editorial serif poster hierarchy
            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                Text(event.category.displayName.uppercased())
                    .gatherEyebrow()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.28), in: Capsule())

                Text(event.title)
                    .gatherSerifHero()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)

                HStack(spacing: Spacing.md) {
                    Label(heroFormattedDate, systemImage: "calendar")
                    if let location = event.location {
                        Label(location.shortLocation ?? location.name, systemImage: "mappin")
                            .lineLimit(1)
                    }
                }
                .gatherMetaText()
                .foregroundStyle(.white.opacity(0.92))

                // One attendance line: when a capacity is set, fold it in
                // ("12/50 going") instead of a second competing badge in the
                // top corner — one number, one place.
                if let capacity = event.capacity {
                    Label("\(event.totalAttendingHeadcount)/\(capacity) going", systemImage: "person.2.fill")
                        .gatherMetaText()
                        .foregroundStyle(.white)
                } else if event.displayAttendingCount > 0 {
                    Label("\(event.displayAttendingCount) going", systemImage: "person.2.fill")
                        .gatherMetaText()
                        .foregroundStyle(.white)
                }
            }
            .padding(Spacing.lg)
            .padding(.bottom, Spacing.lg)

            // Subtle RSVP sync indicator — top center while the host's list
            // pulls fresh responses from the cloud.
            if isLoadingRSVPs {
                VStack {
                    HStack(spacing: Spacing.xs) {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white)
                        Text("Syncing RSVPs")
                            .gatherMetaText()
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityLabel("Syncing RSVPs")

                    Spacer()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isLoadingRSVPs)
        .frame(height: Layout.heroHeightDetail)
        // Full poster card now that it scrolls with content (matches Home).
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.featured, style: .continuous))
        .accentGlow(categoryAccent)
    }

    /// The tab bar as a pinned section header: a solid canvas backdrop with a
    /// hairline so content scrolls cleanly underneath when it settles at top.
    private var pinnedTabBar: some View {
        floatingTabBar
            .padding(.vertical, Spacing.xs)
            .background(
                Color.gatherCanvas
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.gatherSeparator.opacity(0.5))
                            .frame(height: 1)
                    }
            )
    }

    private var heroFormattedDate: String {
        GatherDateFormatter.fullEventDate.string(from: event.startDate)
    }

    // MARK: - Floating Tab Bar

    private var visibleTabs: [EventDetailTab] {
        EventDetailTab.allCases.filter { $0.isVisible(for: event, isHost: isHost) }
    }

    /// The event's category accent, threaded through the tab bar and CTAs so
    /// the whole screen carries the invitation's color story.
    private var categoryAccent: Color {
        Color.forCategory(event.category)
    }

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs, id: \.self) { tab in
                Button {
                    HapticService.tabSwitch()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            if selectedTab == tab {
                                Circle()
                                    .fill(categoryAccent)
                                    .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                                    .frame(width: 36, height: 36)
                                    .shadow(color: categoryAccent.opacity(0.4), radius: 8, y: 2)
                            }

                            Image(systemName: tab.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(selectedTab == tab ? Color.onCategory(event.category) : Color.gatherSecondaryText)
                                .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                        }

                        Text(tab.rawValue)
                            .font(.caption2)
                            .fontWeight(selectedTab == tab ? .bold : .medium)
                            .foregroundStyle(selectedTab == tab ? Color.gatherPrimaryText : Color.gatherSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
                .accessibilityHint(selectedTab == tab ? "Currently selected" : "Double tap to view \(tab.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .padding(.horizontal, Spacing.xs)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.glassBorderTop, Color.glassBorderBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 15, y: 8)
        )
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            OverviewTab(
                event: event,
                showGuestList: $showGuestList,
                showRSVPSheet: $showRSVPSheet,
                onShowFunctions: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        selectedTab = .functions
                    }
                }
            )
        case .activity:
            ActivityTab(event: event)
        case .functions:
            FunctionsTab(event: event)
        case .guests:
            GuestsTab(event: event)
        case .photos:
            PhotosTab(event: event)
        case .budget:
            BudgetTab(event: event)
        }
    }

    // MARK: - RSVP Button Bar

    private var draftPublishBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.gatherBackground.opacity(0), Color.gatherBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 16)

            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Draft")
                        .font(GatherFont.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.rsvpMaybeFallback)
                    Text("Only you can see this — publish to share it")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                Button {
                    publishEvent()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                            .font(.caption)
                        Text("Publish")
                            .font(GatherFont.callout)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
                    .accentGlow(Color.accentPurpleFallback, radius: 14)
                }
                .accessibilityLabel("Publish event")
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, Spacing.sm)
            .floatingBottomBar()
        }
    }

    private func publishEvent() {
        event.isDraft = false
        event.updatedAt = Date()
        modelContext.safeSave()
        FirestoreService.shared.pushEvent(event)
        HapticService.success()
    }

    /// Creates a fresh draft copy of this event owned by the current user.
    /// Copies the core details and the functions (name/date/location only —
    /// no invites), but deliberately drops guests, RSVPs, budget, and tickets
    /// so the host starts from a clean slate.
    private func duplicateEvent() {
        let copy = Event(
            title: "Copy of \(event.title)",
            eventDescription: event.eventDescription,
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location,
            capacity: event.capacity,
            privacy: event.privacy,
            guestListVisibility: event.guestListVisibility,
            category: event.category,
            enabledFeatures: event.enabledFeatures,
            hostId: authManager.currentUser?.id,
            isDraft: true
        )

        // Copy functions without their invites (name/date/location/etc.).
        copy.functions = event.functions.map { source in
            EventFunction(
                name: source.name,
                functionDescription: source.functionDescription,
                date: source.date,
                endTime: source.endTime,
                location: source.location,
                dressCode: source.dressCode,
                customDressCode: source.customDressCode,
                sortOrder: source.sortOrder,
                eventId: copy.id
            )
        }

        modelContext.insert(copy)
        modelContext.safeSave()
        HapticService.success()
        showDuplicateConfirmation = true
    }

    private var shouldShowRSVPButton: Bool {
        guard !isHost else { return false }
        // Full bar on overview for new RSVPs or ticketed events
        if selectedTab == .overview && (event.functions.isEmpty || event.hasTicketing) {
            return true
        }
        // Compact pill on other tabs if user already RSVPed
        if selectedTab != .overview && currentUserGuest != nil {
            return true
        }
        return false
    }

    private var rsvpButtonBar: some View {
        VStack(spacing: 0) {
            if selectedTab != .overview, let guest = currentUserGuest {
                // Compact pill on non-overview tabs
                compactRSVPPill(guest: guest)
            } else if let guest = currentUserGuest {
                // User has already RSVPed - show status with manage button
                attendingStatusBar(guest: guest)
            } else if event.hasTicketing && !event.ticketTiers.isEmpty {
                // Ticketed event - show ticket purchase
                ticketPurchaseBar
            } else {
                // Standard RSVP
                standardRSVPBar
            }
        }
    }

    // Compact RSVP pill for non-overview tabs
    private func compactRSVPPill(guest: Guest) -> some View {
        Button {
            showManageRSVPSheet = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: guest.status.icon)
                    .font(.caption)
                Text(guest.status.displayName)
                    .font(GatherFont.caption)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.up")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(Color.forRSVPStatus(guest.status))
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(Color.forRSVPStatus(guest.status).opacity(0.12))
            .clipShape(Capsule())
            // Expansion lives INSIDE the label so the whole bar row is the
            // hit area — the pill visual stays compact.
            .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
            .contentShape(Rectangle())
        }
        .padding(.vertical, Spacing.xs)
        .floatingBottomBar()
    }

    // Attending status bar for users who have already RSVPed
    private func attendingStatusBar(guest: Guest) -> some View {
        HStack {
            // Status indicator
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color.forRSVPStatus(guest.status).opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: guest.status.icon)
                        .font(.title3)
                        .foregroundStyle(Color.forRSVPStatus(guest.status))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(guest.status.displayName)
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.forRSVPStatus(guest.status))

                    if guest.status == .attending || guest.status == .maybe {
                        Text("\(guest.totalHeadcount) \(guest.totalHeadcount == 1 ? "person" : "people")")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }
            }

            Spacer()

            // Manage button
            Button {
                showManageRSVPSheet = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "pencil")
                    Text("Manage")
                }
                .font(GatherFont.callout)
                .fontWeight(.medium)
                .foregroundStyle(Color.accentPurpleFallback)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.accentPurpleFallback.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding()
        .floatingBottomBar()
    }

    // Ticket purchase bar for ticketed events
    private var ticketPurchaseBar: some View {
        HStack {
            // Price info
            VStack(alignment: .leading, spacing: 2) {
                if salesNotStarted, let saleDate = earliestSalesDate {
                    Text("On sale \(GatherDateFormatter.monthDayTime.string(from: saleDate))")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.rsvpMaybeFallback)
                    Text("Tickets coming soon")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                } else if isSoldOut {
                    Text("Sold Out")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.rsvpNoFallback)
                    Text("Join waitlist for updates")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                } else if let minPrice = minTicketPrice {
                    if minPrice == 0 {
                        Text("Free")
                            .font(GatherFont.headline)
                            .foregroundStyle(Color.rsvpYesFallback)
                    } else {
                        Text("From \(formatPrice(minPrice))")
                            .font(GatherFont.headline)
                    }
                    Text("\(availableTicketCount) tickets available")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }

            Spacer()

            if salesNotStarted {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "clock.fill")
                    Text("Not Yet Available")
                }
                .font(GatherFont.headline)
                .foregroundStyle(Color.gatherSecondaryText)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(Color.gatherTertiaryBackground)
                .clipShape(Capsule())
            } else if isSoldOut {
                Button {
                    showWaitlist = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "bell.badge")
                        Text("Join Waitlist")
                    }
                    .font(GatherFont.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
                    .accentGlow(Color.accentPurpleFallback, radius: 14)
                }
            } else {
                Button {
                    showTicketPurchase = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "ticket.fill")
                        // Price-aware label — promising a FREE ticket next to
                        // "From $25" reads as bait when the sheet shows a price.
                        Text(minTicketPrice == 0 ? "Get Free Ticket" : "Get Tickets")
                    }
                    .font(GatherFont.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
                    .accentGlow(Color.accentPurpleFallback, radius: 14)
                }
            }
        }
        .padding()
        .floatingBottomBar()
    }

    /// True when all visible tiers have a future salesStartDate
    private var salesNotStarted: Bool {
        guard event.hasTicketing && !event.ticketTiers.isEmpty else { return false }
        let visibleTiers = event.ticketTiers.filter { !$0.isHidden }
        guard !visibleTiers.isEmpty else { return false }
        return visibleTiers.allSatisfy { $0.salesStatus == .upcoming }
    }

    /// Earliest future salesStartDate among visible tiers
    private var earliestSalesDate: Date? {
        event.ticketTiers
            .filter { !$0.isHidden }
            .compactMap { $0.salesStartDate }
            .filter { $0 > Date() }
            .min()
    }

    private var isSoldOut: Bool {
        guard event.hasTicketing && !event.ticketTiers.isEmpty else { return false }
        return event.ticketTiers.allSatisfy { $0.isSoldOut }
    }

    // Standard RSVP bar for non-ticketed events
    private var standardRSVPBar: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Your RSVP")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
                Text("Not responded")
                    .font(GatherFont.headline)
            }

            Spacer()

            Button {
                showRSVPSheet = true
            } label: {
                Text("RSVP")
                    .font(GatherFont.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.sm)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
                    .accentGlow(Color.accentPurpleFallback, radius: 14)
            }
        }
        .padding()
        .floatingBottomBar()
    }

    // MARK: - Helpers

    private var isHost: Bool {
        event.hostId == authManager.currentUser?.id
    }

    private var currentUserGuest: Guest? {
        guard let currentUser = authManager.currentUser else { return nil }
        return event.guests.first(where: { $0.userId == currentUser.id })
    }

    private var currentUserTicket: Ticket? {
        guard let userId = authManager.currentUser?.id else { return nil }
        return eventTickets.first { ticket in
            ticket.userId == userId &&
            ticket.paymentStatus == .completed
        }
    }

    private var currentRSVPStatus: String {
        if let guest = currentUserGuest {
            return guest.status.displayName
        }
        return "Not responded"
    }

    private var minTicketPrice: Decimal? {
        let availableTiers = event.ticketTiers.filter { $0.isAvailable && !$0.isHidden }
        return availableTiers.map { $0.price }.min()
    }

    private var availableTicketCount: Int {
        event.ticketTiers.filter { $0.isAvailable }.reduce(0) { $0 + $1.remainingCount }
    }

    private func formatPrice(_ price: Decimal) -> String {
        GatherPriceFormatter.format(price)
    }
}

// MARK: - Supporting Views

struct CapacityBadge: View {
    let attending: Int
    let capacity: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "person.2.fill")
                .font(.caption)
            Text("\(attending)/\(capacity)")
                .font(GatherFont.caption)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

struct GuestCountPill: View {
    let count: Int
    let label: String
    let status: RSVPStatus

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(Color.forRSVPStatus(status))
                .frame(width: 8, height: 8)
            Text("\(count) \(label)")
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var previewEvent = Event(
        title: "Summer Rooftop Party",
        eventDescription: "Join us for an amazing summer party with great music, food, and drinks. Dress code: summer casual.",
        startDate: Date().addingTimeInterval(86400 * 7),
        endDate: Date().addingTimeInterval(86400 * 7 + 14400),
        location: EventLocation(
            name: "The Rooftop Lounge",
            address: "123 Main Street, San Francisco, CA"
        ),
        capacity: 50
    )
    NavigationStack {
        EventDetailView(event: previewEvent)
            .environmentObject(AuthManager())
            .environmentObject(AppState())
    }
}
