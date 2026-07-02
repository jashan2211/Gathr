import SwiftUI
import SwiftData

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showCreateSheet = false
    @State private var deepLinkEvent: Event?
    @State private var showDeepLinkRSVP = false
    @State private var pendingRSVP = false

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        // Declarative selection haptic — fires on every tab change, including
        // programmatic ones (deep links, iPad sidebar), not just button taps.
        .sensoryFeedback(.selection, trigger: appState.selectedTab)
        .sheet(isPresented: $showCreateSheet) {
            CreateEventView()
                .presentationDragIndicator(.visible)
        }
        // The macOS/iPad "New Event" menu command (Cmd+N) flips this app-level
        // flag; mirror it into the local create sheet.
        .onChange(of: appState.isShowingCreateEvent) { _, show in
            if show {
                showCreateSheet = true
                appState.isShowingCreateEvent = false
            }
        }
        .task {
            // Pull the signed-in user's hosted events and their invitations
            // down from the cloud on launch.
            await FirestoreService.shared.mergeRemoteEvents(into: modelContext)
            await FirestoreService.shared.fetchInvitedEvents(into: modelContext)
        }
        .fullScreenCover(item: $deepLinkEvent, onDismiss: {
            pendingRSVP = false
            appState.showRSVPForDeepLink = false
            appState.deepLinkGuestId = nil
        }) { event in
            NavigationStack {
                EventDetailView(event: event)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                deepLinkEvent = nil
                            }
                        }
                    }
            }
            // The RSVP sheet lives INSIDE the cover so it presents on top of the
            // event, not in conflict with it (presenting both from MainTabView
            // silently dropped the sheet). A short delay lets the cover settle.
            .sheet(isPresented: $showDeepLinkRSVP) {
                RSVPSheet(event: event, invitedGuestId: appState.deepLinkGuestId)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .onDisappear { appState.deepLinkGuestId = nil }
            }
            .onAppear {
                if pendingRSVP {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        showDeepLinkRSVP = true
                    }
                }
            }
        }
        .onChange(of: appState.deepLinkEventId) { _, _ in
            processPendingDeepLink()
        }
        .onAppear {
            // Cold launch: a link parsed before this view existed wouldn't fire
            // onChange, so process whatever is already pending.
            processPendingDeepLink()
        }
    }

    /// Opens the deep-linked event (local or fetched from the cloud) and, when
    /// the link is an invite, queues the RSVP sheet to appear over it.
    private func processPendingDeepLink() {
        guard let eventId = appState.deepLinkEventId else { return }
        appState.deepLinkEventId = nil
        pendingRSVP = appState.showRSVPForDeepLink
        let guestId = appState.deepLinkGuestId

        let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == eventId })
        if let event = try? modelContext.fetch(descriptor).first {
            deepLinkEvent = event
            bindInvitedGuest(to: event, guestId: guestId)
        } else {
            // Not on this device — load the shared event from the cloud.
            Task { @MainActor in
                if let event = await FirestoreService.shared.fetchEvent(id: eventId, into: modelContext) {
                    deepLinkEvent = event
                    bindInvitedGuest(to: event, guestId: guestId)
                }
            }
        }
    }

    /// When the deep link is an invite, tie this account to the event so it
    /// shows in Home/Calendar (even before they RSVP) and follows their account.
    private func bindInvitedGuest(to event: Event, guestId: UUID?) {
        guard let guestId, let user = authManager.currentUser else { return }
        FirestoreService.shared.ensureInvitedGuest(
            on: event, guestId: guestId, userId: user.id, name: user.name, status: .pending
        )
        FirestoreService.shared.recordInvitedEvent(event, guestId: guestId, status: .pending)
        modelContext.safeSave()
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        Group {
            selectedTabView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gatherCanvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            floatingTabBar
        }
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch appState.selectedTab {
        case .home:
            HomeView()
        case .events:
            CalendarView()
        case .explore:
            ExploreView()
        case .profile:
            ProfileView()
        }
    }

    // MARK: - iPad Layout

    /// A branded, premium sidebar: the Gathr wordmark up top, the four tabs as
    /// large icon+label rows with an accent-gradient selection highlight, and a
    /// pinned "Create Event" button that drives the same create sheet as iPhone.
    /// The detail pane still hosts `selectedTabView`, so navigation, deep links,
    /// and the create flow behave exactly as before — only the chrome changed.
    private var iPadLayout: some View {
        NavigationSplitView {
            List {
                Section {
                    ForEach(AppState.Tab.allCases, id: \.self) { tab in
                        sidebarRow(tab)
                    }
                } header: {
                    sidebarBrand
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.gatherCanvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                sidebarCreateButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        } detail: {
            selectedTabView
        }
        .navigationSplitViewStyle(.balanced)
        .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 320)
    }

    /// The wordmark that crowns the sidebar — a gradient "G" mark beside the
    /// Gathr wordmark and a whisper of a tagline, echoing the app-icon treatment.
    private var sidebarBrand: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(LinearGradient.gatherAccentGradient)
                .frame(width: 40, height: 40)
                .overlay(
                    Text("G")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                )
                .shadow(color: Color.accentPurpleFallback.opacity(0.45), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text("Gathr")
                    .font(.system(size: 22, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(Color.gatherPrimaryText)
                    .textCase(nil)
                Text("Bring people together")
                    .gatherEyebrow()
                    .foregroundStyle(Color.gatherSecondaryText)
                    .textCase(nil)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.xs)
        .listRowInsets(EdgeInsets(top: 0, leading: Spacing.xs, bottom: Spacing.xs, trailing: Spacing.xs))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gathr")
        .accessibilityAddTraits(.isHeader)
    }

    /// A large icon+label sidebar row. The selected row rides the accent gradient
    /// with a soft glow; the rest sit quietly on the canvas.
    private func sidebarRow(_ tab: AppState.Tab) -> some View {
        let isSelected = appState.selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                appState.selectedTab = tab
            }
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : Color.gatherSecondaryText)
                    .frame(width: 30)

                Text(tab.title)
                    .font(.system(size: 17, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : Color.gatherPrimaryText)

                Spacer(minLength: 0)
            }
            .padding(.vertical, Spacing.sm + 2)
            .padding(.horizontal, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .fill(LinearGradient.gatherAccentGradient)
                        .shadow(color: Color.accentPurpleFallback.opacity(0.4), radius: 10, y: 4)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 3, leading: Spacing.xs, bottom: 3, trailing: Spacing.xs))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// The pinned "Create Event" call to action at the foot of the sidebar. It
    /// drives the very same `showCreateSheet` the iPhone center button uses, so
    /// the create flow is identical across form factors.
    private var sidebarCreateButton: some View {
        Button {
            HapticService.mediumImpact()
            showCreateSheet = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                Text("Create Event")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.buttonHeight)
            .background(LinearGradient.gatherAccentGradient, in: Capsule())
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.accentPurpleFallback.opacity(0.5), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .background(Color.gatherCanvas.ignoresSafeArea(edges: .bottom))
        .accessibilityLabel("Create event")
        .accessibilityHint("Opens the new event form")
    }

    // MARK: - Floating Tab Bar

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.events)
            createButton
            tabButton(.explore)
            tabButton(.profile)
        }
        .accessibilityElement(children: .contain)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .padding(.horizontal, Spacing.xs)
        .background(
            // A detached glass dock hovering over the content — inset from the
            // edges, hairline-bordered, with a deep drop shadow. The Create
            // circle intentionally overflows its top edge.
            RoundedRectangle(cornerRadius: CornerRadius.full, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.full, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
        )
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.xs)
    }

    private func tabButton(_ tab: AppState.Tab) -> some View {
        let isSelected = appState.selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appState.selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 21, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentPurpleFallback : Color.gatherSecondaryText)
                    .frame(height: 28)
                    .scaleEffect(isSelected ? 1.08 : 1.0)

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.accentPurpleFallback : Color.gatherSecondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to switch")
    }

    private var createButton: some View {
        Button {
            HapticService.mediumImpact()
            showCreateSheet = true
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(LinearGradient.gatherAccentGradient)
                        .frame(width: 54, height: 54)
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: Color.accentPurpleFallback.opacity(0.5), radius: 12, y: 5)
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(y: -14)
                Text("Create")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.gatherSecondaryText)
                    .offset(y: -10)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel("Create event")
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
