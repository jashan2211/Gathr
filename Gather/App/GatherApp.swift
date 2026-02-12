import SwiftUI
import SwiftData

@main
struct GatherApp: App {
    // MARK: - SwiftData Container

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: GatherSchemaV2.self)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: GatherMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            // If persistent store fails (e.g. schema migration), fall back to in-memory
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: GatherMigrationPlan.self,
                    configurations: [fallbackConfig]
                )
            } catch {
                // Both persistent and in-memory stores failed — the data layer is
                // completely non-functional and no meaningful UI can be shown.
                // This mirrors Apple's recommended pattern for ModelContainer init.
                fatalError("Could not create ModelContainer (persistent + in-memory both failed): \(error)")
            }
        }
    }()

    // MARK: - State

    @StateObject private var authManager = AuthManager()
    @StateObject private var appState = AppState()
    @StateObject private var eventService = EventService()
    @StateObject private var notificationService = NotificationService.shared

    // MARK: - Body

    @AppStorage("colorScheme") private var colorSchemeSetting = "system"

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeSetting {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(appState)
                .environmentObject(eventService)
                .environmentObject(notificationService)
                .preferredColorScheme(preferredColorScheme)
                .onAppear {
                    eventService.setModelContext(sharedModelContainer.mainContext)
                    notificationService.setupNotificationCategories()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Event") {
                    appState.isShowingCreateEvent = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Navigate") {
                Button("Going") {
                    appState.selectedTab = .going
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("My Events") {
                    appState.selectedTab = .myEvents
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Explore") {
                    appState.selectedTab = .explore
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Profile") {
                    appState.selectedTab = .profile
                }
                .keyboardShortcut("4", modifiers: .command)
            }
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        // Handle gather://rsvp/{eventId}/{guestId}
        // Handle gather://event/{eventId}
        guard url.scheme == "gather" else { return }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch url.host {
        case "event":
            if let eventIdString = pathComponents.first,
               let eventId = UUID(uuidString: eventIdString) {
                appState.deepLinkEventId = eventId
            }
        case "rsvp":
            if pathComponents.count >= 2,
               let eventIdString = pathComponents.first,
               let eventId = UUID(uuidString: eventIdString) {
                appState.deepLinkEventId = eventId
                if let guestIdString = pathComponents.dropFirst().first,
                   let guestId = UUID(uuidString: guestIdString) {
                    appState.deepLinkGuestId = guestId
                    appState.showRSVPForDeepLink = true
                }
            }
        default:
            break
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                AuthView()
            } else if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
        .animation(.easeInOut, value: hasCompletedOnboarding)
    }
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: Tab = .going
    @Published var isShowingCreateEvent: Bool = false
    @Published var deepLinkEventId: UUID?
    @Published var deepLinkGuestId: UUID?
    @Published var showRSVPForDeepLink: Bool = false

    enum Tab: Int, CaseIterable {
        case going
        case myEvents
        case explore
        case profile

        var title: String {
            switch self {
            case .going: return "Going"
            case .myEvents: return "My Events"
            case .explore: return "Explore"
            case .profile: return "Profile"
            }
        }

        var icon: String {
            switch self {
            case .going: return "ticket"
            case .myEvents: return "calendar"
            case .explore: return "magnifyingglass"
            case .profile: return "person.circle"
            }
        }

        var selectedIcon: String {
            switch self {
            case .going: return "ticket.fill"
            case .myEvents: return "calendar"
            case .explore: return "magnifyingglass"
            case .profile: return "person.circle.fill"
            }
        }
    }
}
