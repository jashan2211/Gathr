import Foundation
import AuthenticationServices
import SwiftData

// MARK: - Auth Manager

@MainActor
class AuthManager: ObservableObject {
    // MARK: - Published Properties

    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var authError: AuthError?

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let userIdKey = "currentUserId"
    private let userNameKey = "currentUserName"
    private let userEmailKey = "currentUserEmail"
    private let authProviderKey = "currentAuthProvider"
    private let migratedToKeychainKey = "authMigratedToKeychain"

    // MARK: - Initialization

    init() {
        migrateToKeychainIfNeeded()
        checkExistingAuth()
    }

    // MARK: - Migration

    private func migrateToKeychainIfNeeded() {
        guard !userDefaults.bool(forKey: migratedToKeychainKey) else { return }

        // Migrate from UserDefaults to Keychain
        if let userId = userDefaults.string(forKey: userIdKey) {
            KeychainService.save(key: userIdKey, value: userId)
        }
        if let name = userDefaults.string(forKey: userNameKey) {
            KeychainService.save(key: userNameKey, value: name)
        }
        if let email = userDefaults.string(forKey: userEmailKey) {
            KeychainService.save(key: userEmailKey, value: email)
        }
        if let provider = userDefaults.string(forKey: authProviderKey) {
            KeychainService.save(key: authProviderKey, value: provider)
        }

        // Clean up UserDefaults auth data
        userDefaults.removeObject(forKey: userIdKey)
        userDefaults.removeObject(forKey: userNameKey)
        userDefaults.removeObject(forKey: userEmailKey)
        userDefaults.removeObject(forKey: authProviderKey)
        userDefaults.set(true, forKey: migratedToKeychainKey)
    }

    // MARK: - Auth State

    private func checkExistingAuth() {
        if let storedUserId = KeychainService.load(key: userIdKey),
           let uuid = UUID(uuidString: storedUserId) {
            let name = KeychainService.load(key: userNameKey) ?? "User"
            let email = KeychainService.load(key: userEmailKey) ?? ""
            currentUser = User(id: uuid, name: name, email: email)
            isAuthenticated = true
        }
    }

    private func persistUser(_ user: User) {
        KeychainService.save(key: userIdKey, value: user.id.uuidString)
        KeychainService.save(key: userNameKey, value: user.name)
        KeychainService.save(key: userEmailKey, value: user.email ?? "")
    }

    /// The auth provider used for the current session
    var currentAuthProvider: String? {
        KeychainService.load(key: authProviderKey)
    }

    // MARK: - Demo Sign In (for testing)

    func signInAsDemo() {
        let user = User(name: "Demo User", email: "demo@gather.app")
        persistUser(user)
        KeychainService.save(key: authProviderKey, value: "demo")
        currentUser = user
        isAuthenticated = true
    }

    // MARK: - Apple Sign In

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        isLoading = true
        authError = nil

        let userId = credential.user
        let email = credential.email
        let fullName = [
            credential.fullName?.givenName,
            credential.fullName?.familyName
        ].compactMap { $0 }.joined(separator: " ")

        let user = User(
            name: fullName.isEmpty ? "User" : fullName,
            email: email,
            authProviders: [.apple]
        )

        KeychainService.save(key: userIdKey, value: userId)
        KeychainService.save(key: userNameKey, value: user.name)
        KeychainService.save(key: userEmailKey, value: user.email ?? "")
        KeychainService.save(key: authProviderKey, value: "apple")

        currentUser = user
        isAuthenticated = true
        isLoading = false
    }

    // MARK: - Email Sign In

    func signInWithEmail(email: String) {
        isLoading = true
        authError = nil

        let user = User(
            name: email.components(separatedBy: "@").first ?? "User",
            email: email,
            authProviders: [.email]
        )

        persistUser(user)
        KeychainService.save(key: authProviderKey, value: "email")
        currentUser = user
        isAuthenticated = true
        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainService.deleteAll()
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Delete Account

    func deleteAccount(modelContext: ModelContext) async -> Bool {
        isLoading = true

        guard let userId = currentUser?.id else {
            isLoading = false
            return false
        }

        do {
            try await Task.sleep(nanoseconds: 500_000_000)

            // Delete user's hosted events
            let eventDescriptor = FetchDescriptor<Event>(
                predicate: #Predicate { $0.hostId == userId }
            )
            if let events = try? modelContext.fetch(eventDescriptor) {
                for event in events {
                    modelContext.delete(event)
                }
            }

            // Delete user's guest records
            let guestDescriptor = FetchDescriptor<Guest>(
                predicate: #Predicate { $0.userId == userId }
            )
            if let guests = try? modelContext.fetch(guestDescriptor) {
                for guest in guests {
                    modelContext.delete(guest)
                }
            }

            // Delete user's tickets
            let ticketDescriptor = FetchDescriptor<Ticket>(
                predicate: #Predicate { $0.userId == userId }
            )
            if let tickets = try? modelContext.fetch(ticketDescriptor) {
                for ticket in tickets {
                    modelContext.delete(ticket)
                }
            }

            // Delete user's waitlist entries
            let waitlistDescriptor = FetchDescriptor<WaitlistEntry>(
                predicate: #Predicate { $0.userId == userId }
            )
            if let entries = try? modelContext.fetch(waitlistDescriptor) {
                for entry in entries {
                    modelContext.delete(entry)
                }
            }

            modelContext.safeSave()

            signOut()
            isLoading = false
            return true

        } catch {
            authError = .deleteFailed(error.localizedDescription)
            isLoading = false
            return false
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError, Equatable {
    case signInFailed(String)
    case signOutFailed(String)
    case deleteFailed(String)
    case networkError
    case cancelled

    var errorDescription: String? {
        switch self {
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        case .deleteFailed(let message):
            return "Account deletion failed: \(message)"
        case .networkError:
            return "Network error. Please check your connection."
        case .cancelled:
            return "Sign in was cancelled."
        }
    }
}
