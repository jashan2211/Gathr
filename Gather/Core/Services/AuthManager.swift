import Foundation
import AuthenticationServices
import CryptoKit
import Security
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import SwiftData
import UIKit

// MARK: - Auth Manager

/// Wraps Firebase Authentication. The app's own `User` model is UUID-keyed,
/// so the app-side `id` is a stable UUID derived from the Firebase `uid` —
/// this keeps all existing UUID-based code (event.hostId, guest.userId)
/// working unchanged while auth itself is fully server-backed.
@MainActor
class AuthManager: ObservableObject {
    // MARK: - Published Properties

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var authError: AuthError?
    @Published var isEmailVerified = true

    // MARK: - Private

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var appleSignInNonce: String?

    // MARK: - Init

    init() {
        // Restores any saved session and keeps published state in sync with
        // Firebase. Firebase persists the session itself across launches.
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                self?.applyFirebaseUser(firebaseUser)
            }
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    // MARK: - Session Sync

    private func applyFirebaseUser(_ firebaseUser: FirebaseAuth.User?) {
        guard let firebaseUser else {
            currentUser = nil
            isAuthenticated = false
            isEmailVerified = true
            return
        }
        let derivedId = Self.deterministicUUID(from: firebaseUser.uid)
        let fallbackName = firebaseUser.email?.components(separatedBy: "@").first ?? "User"
        let name = (firebaseUser.displayName?.isEmpty == false) ? firebaseUser.displayName! : fallbackName
        currentUser = User(id: derivedId, name: name, email: firebaseUser.email)
        isAuthenticated = true
        // Anonymous (demo) sessions don't have an email to verify.
        isEmailVerified = firebaseUser.isAnonymous || firebaseUser.isEmailVerified

        // Keep the user's cloud profile current (skip anonymous demo sessions).
        if !firebaseUser.isAnonymous {
            FirestoreService.shared.syncUserProfile(
                uid: firebaseUser.uid,
                name: name,
                email: firebaseUser.email
            )
        }
    }

    /// The provider backing the current session: "apple", "email", or "demo".
    var currentAuthProvider: String? {
        guard let firebaseUser = Auth.auth().currentUser else { return nil }
        if firebaseUser.isAnonymous { return "demo" }
        if firebaseUser.providerData.contains(where: { $0.providerID == "apple.com" }) { return "apple" }
        if firebaseUser.providerData.contains(where: { $0.providerID == "password" }) { return "email" }
        return firebaseUser.providerData.first?.providerID
    }

    /// Derives a stable UUID from an account identifier so the app's UUID-keyed
    /// models map consistently to a Firebase account across launches.
    // Pure function (SHA-256 of the seed) — safe to call off the main actor,
    // e.g. from Codable `makeEvent()` builders on background-decoded data.
    nonisolated static func deterministicUUID(from seed: String) -> UUID {
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

    // MARK: - Register

    func register(name: String, email: String, password: String) async {
        isLoading = true
        authError = nil
        do {
            let result = try await Auth.auth().createUser(
                withEmail: normalized(email),
                password: password
            )
            let change = result.user.createProfileChangeRequest()
            change.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            try await change.commitChanges()
            try? await result.user.sendEmailVerification()
            applyFirebaseUser(result.user)
        } catch {
            authError = .signInFailed(Self.friendlyMessage(error))
        }
        isLoading = false
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        isLoading = true
        authError = nil
        do {
            _ = try await Auth.auth().signIn(withEmail: normalized(email), password: password)
        } catch {
            authError = .signInFailed(Self.friendlyMessage(error))
        }
        isLoading = false
    }

    // MARK: - Password Reset

    @discardableResult
    func sendPasswordReset(email: String) async -> Bool {
        authError = nil
        do {
            try await Auth.auth().sendPasswordReset(withEmail: normalized(email))
            return true
        } catch {
            authError = .signInFailed(Self.friendlyMessage(error))
            return false
        }
    }

    // MARK: - Email Verification

    func resendVerificationEmail() async {
        do {
            try await Auth.auth().currentUser?.sendEmailVerification()
        } catch {
            authError = .signInFailed(Self.friendlyMessage(error))
        }
    }

    func refreshVerificationStatus() async {
        do {
            try await Auth.auth().currentUser?.reload()
            applyFirebaseUser(Auth.auth().currentUser)
        } catch {
            // Non-fatal: keep the last known state.
        }
    }

    // MARK: - Demo Sign In (DEBUG only — anonymous Firebase auth)

    func signInAsDemo() {
        isLoading = true
        authError = nil
        Task {
            do {
                let result = try await Auth.auth().signInAnonymously()
                let change = result.user.createProfileChangeRequest()
                change.displayName = "Demo User"
                try? await change.commitChanges()
                applyFirebaseUser(result.user)
            } catch {
                authError = .signInFailed(Self.friendlyMessage(error))
            }
            isLoading = false
        }
    }

    // MARK: - Apple Sign In

    /// Prepares an Apple ID request for Firebase: requests name/email and
    /// attaches a hashed nonce that Firebase validates against Apple's response.
    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        appleSignInNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func signInWithApple(authorization: ASAuthorization) async {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            authError = .signInFailed("Apple sign-in returned no usable credential.")
            return
        }
        guard let nonce = appleSignInNonce else {
            authError = .signInFailed("Apple sign-in expired. Please try again.")
            return
        }
        guard let tokenData = appleCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            authError = .signInFailed("Could not read the Apple identity token.")
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )
        do {
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            authError = .signInFailed(Self.friendlyMessage(error))
        }
        appleSignInNonce = nil
    }

    // MARK: - Google Sign In

    func signInWithGoogle() {
        isLoading = true
        authError = nil

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            authError = .signInFailed("Google Sign-In isn't configured.")
            isLoading = false
            return
        }
        guard let presenter = Self.topViewController() else {
            authError = .signInFailed("Couldn't open Google Sign-In.")
            isLoading = false
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { [weak self] result, error in
            Task { @MainActor in
                await self?.completeGoogleSignIn(result: result, error: error)
            }
        }
    }

    private func completeGoogleSignIn(result: GIDSignInResult?, error: Error?) async {
        defer { isLoading = false }

        if let error {
            // A user cancelling isn't an error worth surfacing.
            if (error as NSError).code != GIDSignInError.canceled.rawValue {
                authError = .signInFailed(error.localizedDescription)
            }
            return
        }
        guard let googleUser = result?.user,
              let idToken = googleUser.idToken?.tokenString else {
            authError = .signInFailed("Google Sign-In returned no token.")
            return
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: googleUser.accessToken.tokenString
        )
        do {
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            authError = .signInFailed(Self.friendlyMessage(error))
        }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    // MARK: - Profile

    func updateDisplayName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let firebaseUser = Auth.auth().currentUser else { return }
        let change = firebaseUser.createProfileChangeRequest()
        change.displayName = trimmed
        do {
            try await change.commitChanges()
            applyFirebaseUser(firebaseUser)
        } catch {
            authError = .signInFailed(Self.friendlyMessage(error))
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            authError = .signOutFailed(error.localizedDescription)
        }
    }

    // MARK: - Delete Account

    /// Re-authenticates with Apple, revokes the Apple token (required by the
    /// App Store for Sign in with Apple), deletes the account, then removes
    /// local data. Local data is cleared only after the account is gone, so a
    /// failed deletion never leaves the user with no data and a live account.
    func reauthenticateAndDeleteWithApple(
        authorization: ASAuthorization,
        modelContext: ModelContext
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        guard let firebaseUser = Auth.auth().currentUser,
              let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = appleSignInNonce,
              let tokenData = appleCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            authError = .deleteFailed("Could not verify your Apple ID. Please try again.")
            return false
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil
        )
        let userId = currentUser?.id
        do {
            try await firebaseUser.reauthenticate(with: credential)
            if let codeData = appleCredential.authorizationCode,
               let authCode = String(data: codeData, encoding: .utf8) {
                try? await Auth.auth().revokeToken(withAuthorizationCode: authCode)
            }
            try await firebaseUser.delete()
            if let userId {
                deleteLocalData(userId: userId, modelContext: modelContext)
            }
            appleSignInNonce = nil
            return true
        } catch {
            authError = .deleteFailed(Self.friendlyMessage(error))
            return false
        }
    }

    /// Re-authenticates with the account password, deletes the account, then
    /// removes local data.
    func reauthenticateAndDeleteWithEmail(
        password: String,
        modelContext: ModelContext
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        guard let firebaseUser = Auth.auth().currentUser,
              let email = firebaseUser.email else {
            authError = .deleteFailed("Could not verify your account.")
            return false
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        let userId = currentUser?.id
        do {
            try await firebaseUser.reauthenticate(with: credential)
            try await firebaseUser.delete()
            if let userId {
                deleteLocalData(userId: userId, modelContext: modelContext)
            }
            return true
        } catch {
            authError = .deleteFailed(Self.friendlyMessage(error))
            return false
        }
    }

    private func deleteLocalData(userId: UUID, modelContext: ModelContext) {
        let eventDescriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.hostId == userId })
        if let events = try? modelContext.fetch(eventDescriptor) {
            events.forEach { modelContext.delete($0) }
        }
        let guestDescriptor = FetchDescriptor<Guest>(predicate: #Predicate { $0.userId == userId })
        if let guests = try? modelContext.fetch(guestDescriptor) {
            guests.forEach { modelContext.delete($0) }
        }
        let ticketDescriptor = FetchDescriptor<Ticket>(predicate: #Predicate { $0.userId == userId })
        if let tickets = try? modelContext.fetch(ticketDescriptor) {
            tickets.forEach { modelContext.delete($0) }
        }
        let waitlistDescriptor = FetchDescriptor<WaitlistEntry>(predicate: #Predicate { $0.userId == userId })
        if let entries = try? modelContext.fetch(waitlistDescriptor) {
            entries.forEach { modelContext.delete($0) }
        }
        modelContext.safeSave()
    }

    // MARK: - Helpers

    private func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func friendlyMessage(_ error: Error) -> String {
        let nsError = error as NSError
        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return nsError.localizedDescription
        }
        switch code {
        case .emailAlreadyInUse:
            return "That email already has an account. Try signing in instead."
        case .invalidEmail:
            return "That doesn't look like a valid email address."
        case .weakPassword:
            return "Password is too weak — use at least 6 characters."
        case .wrongPassword, .invalidCredential:
            return "Incorrect email or password."
        case .userNotFound:
            return "No account found with that email."
        case .userDisabled:
            return "This account has been disabled."
        case .networkError:
            return "Network error. Check your connection and try again."
        case .tooManyRequests:
            return "Too many attempts. Please wait a moment and try again."
        case .requiresRecentLogin:
            return "Please sign out and back in, then try again."
        case .adminRestrictedOperation, .operationNotAllowed:
            // Provider disabled in the Firebase console (e.g. Anonymous off).
            return "This sign-in method isn't available right now. Please use another option."
        default:
            return nsError.localizedDescription
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard status == errSecSuccess else {
            return (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
        }
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
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
            return message
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        case .deleteFailed(let message):
            return "Couldn't delete account: \(message)"
        case .networkError:
            return "Network error. Please check your connection."
        case .cancelled:
            return "Sign in was cancelled."
        }
    }
}
