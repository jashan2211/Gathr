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
        .task {
            // Pull the signed-in user's hosted events and their invitations
            // down from the cloud on launch.
            await FirestoreService.shared.mergeRemoteEvents(into: modelContext)
            await FirestoreService.shared.fetchInvitedEvents(into: modelContext)
        }
        .fullScreenCover(item: $deepLinkEvent, onDismiss: {
            pendingRSVP = false
            appState.showRSVPForDeepLink = false
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
        case .explore:
            ExploreView()
        case .calendar:
            CalendarView()
        case .profile:
            ProfileView()
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        NavigationSplitView {
            List(AppState.Tab.allCases, id: \.self, selection: Binding(
                get: { appState.selectedTab },
                set: { if let tab = $0 { appState.selectedTab = tab } }
            )) { tab in
                Label(tab.title, systemImage: tab.icon)
            }
            .navigationTitle("Gathr")
        } detail: {
            selectedTabView
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Floating Tab Bar

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.explore)
            createButton
            tabButton(.calendar)
            tabButton(.profile)
        }
        .accessibilityElement(children: .contain)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .background(
            // Glass floating bar hovering over scrolling content.
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.25), radius: 15, y: -6)
                .ignoresSafeArea(edges: .bottom)
        )
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
                        .frame(width: 50, height: 50)
                        .shadow(color: Color.accentPurpleFallback.opacity(0.5), radius: 10, y: 4)
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
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
