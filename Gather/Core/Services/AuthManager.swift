import Foundation
import AuthenticationServices

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

    // MARK: - Initialization

    init() {
        checkExistingAuth()
    }

    // MARK: - Auth State

    private func checkExistingAuth() {
        // Check if user is already signed in
        if let userId = userDefaults.string(forKey: userIdKey) {
            // In production, fetch user from CloudKit/local storage
            // For now, mark as authenticated if we have a stored ID
            isAuthenticated = true
        }
    }

    // MARK: - Apple Sign In

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        isLoading = true
        authError = nil

        do {
            // Extract user info from Apple credential
            let userId = credential.user
            let email = credential.email
            let fullName = [
                credential.fullName?.givenName,
                credential.fullName?.familyName
            ].compactMap { $0 }.joined(separator: " ")

            // Create or fetch user
            let user = User(
                name: fullName.isEmpty ? "User" : fullName,
                email: email,
                authProviders: [.apple]
            )

            // Store user ID
            userDefaults.set(userId, forKey: userIdKey)

            // Update state
            currentUser = user
            isAuthenticated = true
            isLoading = false

        } catch {
            authError = .signInFailed(error.localizedDescription)
            isLoading = false
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async {
        isLoading = true
        authError = nil

        // TODO: Implement Firebase Auth Google Sign-In
        // For now, simulate success

        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_000_000_000)

            let user = User(
                name: "Google User",
                email: "user@gmail.com",
                authProviders: [.google]
            )

            currentUser = user
            isAuthenticated = true
            isLoading = false

        } catch {
            authError = .signInFailed(error.localizedDescription)
            isLoading = false
        }
    }

    // MARK: - Email Magic Link

    func sendMagicLink(email: String) async -> Bool {
        isLoading = true
        authError = nil

        // TODO: Implement Firebase Auth email link
        // For now, simulate success

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

        // TODO: Implement Firebase Auth email link verification

        do {
            try await Task.sleep(nanoseconds: 500_000_000)

            let user = User(
                name: email.components(separatedBy: "@").first ?? "User",
                email: email,
                authProviders: [.email]
            )

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
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Delete Account

    func deleteAccount() async -> Bool {
        isLoading = true

        do {
            // TODO: Delete user data from CloudKit
            // TODO: Revoke Apple/Google credentials

            try await Task.sleep(nanoseconds: 500_000_000)

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
