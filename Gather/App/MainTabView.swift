import SwiftUI
import SwiftData

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
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
            // Pull the signed-in user's events down from the cloud on launch.
            await FirestoreService.shared.mergeRemoteEvents(into: modelContext)
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

        let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == eventId })
        if let event = try? modelContext.fetch(descriptor).first {
            deepLinkEvent = event
        } else {
            // Not on this device — load the shared event from the cloud.
            Task { @MainActor in
                deepLinkEvent = await FirestoreService.shared.fetchEvent(id: eventId, into: modelContext)
            }
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        Group {
            switch appState.selectedTab {
            case .going:
                GoingView()
            case .myEvents:
                MyEventsView()
            case .explore:
                ExploreView()
            case .profile:
                ProfileView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            floatingTabBar
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
            .navigationTitle("Gather")
        } detail: {
            switch appState.selectedTab {
            case .going:
                GoingView()
            case .myEvents:
                MyEventsView()
            case .explore:
                ExploreView()
            case .profile:
                ProfileView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Floating Tab Bar

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppState.Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        appState.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            // Glow behind selected icon
                            if appState.selectedTab == tab {
                                Circle()
                                    .fill(Color.accentPurpleFallback.opacity(0.15))
                                    .frame(width: 44, height: 44)
                            }

                            Image(systemName: appState.selectedTab == tab ? tab.selectedIcon : tab.icon)
                                .font(.system(size: 20, weight: appState.selectedTab == tab ? .semibold : .regular))
                                .foregroundStyle(
                                    appState.selectedTab == tab
                                        ? Color.accentPurpleFallback
                                        : Color.gatherSecondaryText
                                )
                                .scaleEffect(appState.selectedTab == tab ? 1.1 : 1.0)
                        }
                        .frame(height: 36)

                        Text(tab.title)
                            .font(.caption2)
                            .fontWeight(appState.selectedTab == tab ? .bold : .medium)
                            .foregroundStyle(
                                appState.selectedTab == tab
                                    ? Color.accentPurpleFallback
                                    : Color.gatherSecondaryText
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(appState.selectedTab == tab ? [.isSelected] : [])
                .accessibilityHint(appState.selectedTab == tab ? "Currently selected" : "Double tap to switch")
            }
        }
        .accessibilityElement(children: .contain)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .background(
            // Glass stays here by design: a floating bar hovering over scrolling content.
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 15, y: -6)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
