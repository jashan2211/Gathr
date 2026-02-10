import SwiftUI
import SwiftData

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var showCreateSheet = false
    @State private var deepLinkEvent: Event?
    @State private var showDeepLinkRSVP = false

    var body: some View {
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
        .sheet(isPresented: $showCreateSheet) {
            CreateEventView()
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $deepLinkEvent) { event in
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
        }
        .onChange(of: appState.deepLinkEventId) { _, eventId in
            guard let eventId else { return }
            let descriptor = FetchDescriptor<Event>(
                predicate: #Predicate { $0.id == eventId }
            )
            if let event = try? modelContext.fetch(descriptor).first {
                deepLinkEvent = event
                if appState.showRSVPForDeepLink {
                    showDeepLinkRSVP = true
                }
            }
            appState.deepLinkEventId = nil
        }
        .sheet(isPresented: $showDeepLinkRSVP) {
            if let event = deepLinkEvent {
                RSVPSheet(event: event)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .onDisappear {
                        appState.showRSVPForDeepLink = false
                        appState.deepLinkGuestId = nil
                    }
            }
        }
    }

    // MARK: - Floating Tab Bar

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppState.Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        appState.selectedTab = tab
                    }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
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
                            .font(.system(size: 10, weight: appState.selectedTab == tab ? .bold : .medium))
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
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 12, y: -4)
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
