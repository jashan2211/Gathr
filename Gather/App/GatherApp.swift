import SwiftUI
import SwiftData

@main
struct GatherApp: App {
    // MARK: - SwiftData Container

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Event.self,
            Guest.self,
            Comment.self,
            MediaItem.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - State

    @StateObject private var authManager = AuthManager()
    @StateObject private var appState = AppState()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
    }
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var isShowingCreateEvent: Bool = false
    @Published var deepLinkEventId: UUID?

    enum Tab: Int, CaseIterable {
        case home
        case myEvents
        case create
        case contacts
        case profile

        var title: String {
            switch self {
            case .home: return "Home"
            case .myEvents: return "My Events"
            case .create: return "Create"
            case .contacts: return "Contacts"
            case .profile: return "Profile"
            }
        }

        var icon: String {
            switch self {
            case .home: return "house"
            case .myEvents: return "calendar"
            case .create: return "plus.circle.fill"
            case .contacts: return "person.2"
            case .profile: return "person.circle"
            }
        }

        var selectedIcon: String {
            switch self {
            case .home: return "house.fill"
            case .myEvents: return "calendar"
            case .create: return "plus.circle.fill"
            case .contacts: return "person.2.fill"
            case .profile: return "person.circle.fill"
            }
        }
    }
}
