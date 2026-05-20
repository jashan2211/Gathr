import Foundation
import AuthenticationServices
import CryptoKit
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
    private let appleUserIdKey = "appleUserIdentifier"
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

    /// Derives a stable UUID from an account identifier. The same account
    /// (Apple ID, email) always maps to the same user ID — across sign-ins
    /// and launches — so hosted events and RSVPs are never orphaned.
    /// `String.hashValue` can't be used here: it is seeded per process.
    static func deterministicUUID(from seed: String) -> UUID {
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50  // version 5
        bytes[8] = (bytes[8] & 0x3F) | 0x80  // RFC 4122 variant
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    // MARK: - Demo Sign In (for testing)

    func signInAsDemo() {
        let user = User(
            id: Self.deterministicUUID(from: "demo:demo@gather.app"),
            name: "Demo User",
            email: "demo@gather.app"
        )
        persistUser(user)
        KeychainService.save(key: authProviderKey, value: "demo")
        currentUser = user
        isAuthenticated = true
    }

    // MARK: - Apple Sign In

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        isLoading = true
        authError = nil

        // `credential.user` is Apple's opaque identifier — not a UUID. Map it
        // to a stable UUID so the session can be restored on relaunch.
        let appleUserId = credential.user
        let userId = Self.deterministicUUID(from: "apple:\(appleUserId)")

        // Apple only returns name/email on the *first* authorization; on
        // subsequent sign-ins they are nil. Fall back to the stored values
        // so re-signing in never wipes the user's name or email.
        let providedName = [
            credential.fullName?.givenName,
            credential.fullName?.familyName
        ].compactMap { $0 }.joined(separator: " ")
        let storedName = KeychainService.load(key: userNameKey)
        let storedEmail = KeychainService.load(key: userEmailKey)

        let name = !providedName.isEmpty ? providedName : (storedName ?? "User")
        let email = credential.email ?? storedEmail

        let user = User(
            id: userId,
            name: name,
            email: email,
            authProviders: [.apple]
        )

        KeychainService.save(key: userIdKey, value: userId.uuidString)
        KeychainService.save(key: userNameKey, value: name)
        KeychainService.save(key: userEmailKey, value: email ?? "")
        KeychainService.save(key: authProviderKey, value: "apple")
        KeychainService.save(key: appleUserIdKey, value: appleUserId)

        currentUser = user
        isAuthenticated = true
        isLoading = false
    }

    // MARK: - Email Sign In

    func signInWithEmail(email: String) {
        isLoading = true
        authError = nil

        // Derive a stable UUID from the normalized email so signing out and
        // back in with the same address restores the same identity (and the
        // events the user hosts).
        let normalizedEmail = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let userId = Self.deterministicUUID(from: "email:\(normalizedEmail)")

        let user = User(
            id: userId,
            name: normalizedEmail.components(separatedBy: "@").first ?? "User",
            email: normalizedEmail,
            authProviders: [.email]
        )

        persistUser(user)
        KeychainService.save(key: authProviderKey, value: "email")
        currentUser = user
        isAuthenticated = true
        isLoading = false
    }

    // MARK: - Profile Updates

    /// Updates the signed-in user's display name and persists it to the
    /// keychain so it survives relaunch. `currentUser` is a reference type, so
    /// mutating it in place doesn't notify observers — `objectWillChange` is
    /// sent manually so the UI refreshes.
    func updateDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let user = currentUser else { return }

        objectWillChange.send()
        user.name = trimmed
        user.updatedAt = Date()
        KeychainService.save(key: userNameKey, value: trimmed)
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
