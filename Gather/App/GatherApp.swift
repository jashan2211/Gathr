import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

// MARK: - App Delegate

/// Configures Firebase before any SwiftUI state (including AuthManager) is
/// created. `didFinishLaunching` runs before the first scene, so Firebase is
/// ready by the time AuthManager attaches its auth-state listener.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct GatherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
            // Migration failed (unknown model version from pre-versioned store).
            // Delete the incompatible store and retry with a fresh persistent store.
            let storeURL = modelConfiguration.url
            let relatedFiles = [
                storeURL,
                storeURL.appendingPathExtension("wal"),
                storeURL.appendingPathExtension("shm"),
                URL(fileURLWithPath: storeURL.path + "-wal"),
                URL(fileURLWithPath: storeURL.path + "-shm")
            ]
            for file in relatedFiles {
                try? FileManager.default.removeItem(at: file)
            }

            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: GatherMigrationPlan.self,
                    configurations: [modelConfiguration]
                )
            } catch {
                // The persistent store is unrecoverable even after a reset.
                // Fall back to an in-memory store so the app still launches
                // instead of crash-looping — data won't persist this session.
                do {
                    let inMemoryConfiguration = ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true,
                        cloudKitDatabase: .none
                    )
                    return try ModelContainer(
                        for: schema,
                        configurations: [inMemoryConfiguration]
                    )
                } catch {
                    fatalError("Could not create in-memory ModelContainer: \(error)")
                }
            }
        }
    }()

    // MARK: - State

    @StateObject private var authManager = AuthManager()
    @StateObject private var appState = AppState()
    @StateObject private var eventService = EventService()
    @StateObject private var notificationService = NotificationService.shared
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body

    // Dark is the signature look of the 2026 redesign; new installs start dark.
    @AppStorage("colorScheme") private var colorSchemeSetting = "dark"

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
                    if GIDSignIn.sharedInstance.handle(url) { return }
                    handleDeepLink(url)
                }
                // Universal links (https://thebighead.ca/gathr/invite?...) are
                // delivered as a browsing user activity, not through onOpenURL.
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        handleDeepLink(url)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // Push guest/RSVP changes to the cloud when the app backgrounds.
                    if newPhase == .background {
                        FirestoreService.shared.pushHostedEvents(from: sharedModelContainer.mainContext)
                    }
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
                Button("Home") {
                    appState.selectedTab = .home
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Events") {
                    appState.selectedTab = .events
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Explore") {
                    appState.selectedTab = .explore
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("You") {
                    appState.selectedTab = .profile
                }
                .keyboardShortcut("4", modifiers: .command)
            }
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        // Current form (query string):
        //   https://thebighead.ca/gathr/invite?e={eventId}&g={guestId}
        //   gather://invite?e={eventId}&g={guestId}   (web "Open in app" button)
        // Legacy path forms still accepted:
        //   gather://rsvp/{eventId}/{guestId}, gather://event/{eventId}
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let eventParam = queryItems.first(where: { $0.name == "e" })?.value
        let guestParam = queryItems.first(where: { $0.name == "g" })?.value

        // Preferred: explicit e/g query parameters.
        if let eventParam, let eventId = UUID(uuidString: eventParam) {
            appState.deepLinkEventId = eventId
            if let guestParam, let guestId = UUID(uuidString: guestParam) {
                appState.deepLinkGuestId = guestId
                appState.showRSVPForDeepLink = true
            }
            return
        }

        // Legacy path-based parsing (older links already sent out).
        let kind: String
        let ids: [String]
        if url.scheme == "gather" {
            kind = url.host ?? ""
            ids = url.pathComponents.filter { $0 != "/" }
        } else if url.host == "thebighead.ca" || url.host == "www.thebighead.ca" {
            var parts = url.pathComponents.filter { $0 != "/" }
            guard parts.first == "gathr", parts.count >= 2 else { return }
            parts.removeFirst()
            kind = parts.removeFirst()
            ids = parts
        } else {
            return
        }

        switch kind {
        case "event", "invite":
            if let eventIdString = ids.first, let eventId = UUID(uuidString: eventIdString) {
                appState.deepLinkEventId = eventId
            }
        case "rsvp":
            if let eventIdString = ids.first, let eventId = UUID(uuidString: eventIdString) {
                appState.deepLinkEventId = eventId
                if let guestIdString = ids.dropFirst().first,
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
    @Published var selectedTab: Tab = .home
    @Published var isShowingCreateEvent: Bool = false
    @Published var deepLinkEventId: UUID?
    @Published var deepLinkGuestId: UUID?
    @Published var showRSVPForDeepLink: Bool = false

    /// The four destination tabs. Create is a center action button in the tab
    /// bar, not a destination, so it isn't a case here.
    enum Tab: Int, CaseIterable {
        case home
        case events
        case explore
        case profile

        var title: String {
            switch self {
            case .home: return "Home"
            case .events: return "Events"
            case .explore: return "Explore"
            case .profile: return "You"
            }
        }

        var icon: String {
            switch self {
            case .home: return "house"
            case .events: return "calendar"
            case .explore: return "safari"
            case .profile: return "person.circle"
            }
        }

        var selectedIcon: String {
            switch self {
            case .home: return "house.fill"
            case .events: return "calendar"
            case .explore: return "safari.fill"
            case .profile: return "person.circle.fill"
            }
        }
    }
}
