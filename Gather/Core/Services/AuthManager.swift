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
    @Published var pendingGoogleSignIn: Bool = false

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let userIdKey = "currentUserId"
    private let userNameKey = "currentUserName"
    private let userEmailKey = "currentUserEmail"

    // MARK: - Initialization

    init() {
        checkExistingAuth()
    }

    // MARK: - Auth State

    private func checkExistingAuth() {
        if let storedUserId = userDefaults.string(forKey: userIdKey),
           let uuid = UUID(uuidString: storedUserId) {
            let name = userDefaults.string(forKey: userNameKey) ?? "User"
            let email = userDefaults.string(forKey: userEmailKey) ?? ""
            currentUser = User(id: uuid, name: name, email: email)
            isAuthenticated = true
        }
    }

    private func persistUser(_ user: User) {
        userDefaults.set(user.id.uuidString, forKey: userIdKey)
        userDefaults.set(user.name, forKey: userNameKey)
        userDefaults.set(user.email ?? "", forKey: userEmailKey)
    }

    // MARK: - Demo Sign In (for testing)

    func signInAsDemo() {
        let user = User(name: "Demo User", email: "demo@gather.app")
        persistUser(user)
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

        userDefaults.set(userId, forKey: userIdKey)
        userDefaults.set(user.name, forKey: userNameKey)
        userDefaults.set(user.email ?? "", forKey: userEmailKey)

        currentUser = user
        isAuthenticated = true
        isLoading = false
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async {
        // Show the Google sign-in sheet (simulated OAuth)
        pendingGoogleSignIn = true
    }

    func completeGoogleSignIn(name: String, email: String) {
        isLoading = true
        authError = nil

        let user = User(
            name: name.isEmpty ? "Google User" : name,
            email: email,
            authProviders: [.google]
        )

        persistUser(user)
        currentUser = user
        isAuthenticated = true
        isLoading = false
        pendingGoogleSignIn = false
    }

    func cancelGoogleSignIn() {
        pendingGoogleSignIn = false
        isLoading = false
    }

    // MARK: - Email Magic Link

    func sendMagicLink(email: String) async -> Bool {
        isLoading = true
        authError = nil

        do {
            try await Task.sleep(nanoseconds: 500_000_000)
            isLoading = false
            return true
        } catch {
            authError = .signInFailed(error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func verifyMagicLink(email: String, link: String) async {
        isLoading = true
        authError = nil

        do {
            try await Task.sleep(nanoseconds: 500_000_000)

            let user = User(
                name: email.components(separatedBy: "@").first ?? "User",
                email: email,
                authProviders: [.email]
            )

            persistUser(user)
            currentUser = user
            isAuthenticated = true
            isLoading = false

        } catch {
            authError = .signInFailed(error.localizedDescription)
            isLoading = false
        }
    }

    // MARK: - Sign Out

    func signOut() {
        userDefaults.removeObject(forKey: userIdKey)
        userDefaults.removeObject(forKey: userNameKey)
        userDefaults.removeObject(forKey: userEmailKey)
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

            try? modelContext.save()

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
