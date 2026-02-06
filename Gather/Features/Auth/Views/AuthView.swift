import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showEmailSheet = false
    @State private var email = ""

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.accentPurpleFallback.opacity(0.1),
                    Color.accentPinkFallback.opacity(0.05),
                    Color.gatherBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                // Logo & Title
                VStack(spacing: Spacing.md) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 64))
                        .foregroundStyle(LinearGradient.gatherAccentGradient)

                    Text("Gather")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.gatherPrimaryText)

                    Text("Plan events. Share moments.")
                        .font(GatherFont.title3)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                // Auth Buttons
                VStack(spacing: Spacing.md) {
                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(CornerRadius.md)

                    // Sign in with Google
                    Button {
                        Task {
                            await authManager.signInWithGoogle()
                        }
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                            Text("Continue with Google")
                                .font(GatherFont.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.gatherSecondaryBackground)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .cornerRadius(CornerRadius.md)
                    }

                    // Email magic link
                    Button {
                        showEmailSheet = true
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "envelope.fill")
                                .font(.title2)
                            Text("Continue with Email")
                                .font(GatherFont.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.gatherSecondaryBackground)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .cornerRadius(CornerRadius.md)
                    }
                }
                .horizontalPadding()

                // Terms
                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(GatherFont.caption)
                    .foregroundStyle(Color.gatherTertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.xl)
            }

            // Loading overlay
            if authManager.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .sheet(isPresented: $showEmailSheet) {
            EmailSignInSheet(email: $email)
        }
        .alert("Error", isPresented: .constant(authManager.authError != nil)) {
            Button("OK") {
                authManager.authError = nil
            }
        } message: {
            if let error = authManager.authError {
                Text(error.localizedDescription)
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    await authManager.signInWithApple(credential: credential)
                }
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                authManager.authError = .signInFailed(error.localizedDescription)
            }
        }
    }
}

// MARK: - Email Sign In Sheet

struct EmailSignInSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @Binding var email: String
    @State private var linkSent = false
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                if linkSent {
                    // Success state
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.gatherSuccess)

                        Text("Check your inbox")
                            .font(GatherFont.title2)

                        Text("We sent a sign-in link to \(email)")
                            .font(GatherFont.body)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Spacing.xxl)
                } else {
                    // Email input
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Enter your email")
                            .font(GatherFont.headline)

                        TextField("email@example.com", text: $email)
                            .textFieldStyle(.plain)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color.gatherSecondaryBackground)
                            .cornerRadius(CornerRadius.md)
                            .focused($isEmailFocused)
                    }
                    .padding(.top, Spacing.lg)

                    Button {
                        Task {
                            let success = await authManager.sendMagicLink(email: email)
                            if success {
                                withAnimation {
                                    linkSent = true
                                }
                            }
                        }
                    } label: {
                        Text("Send Magic Link")
                            .font(GatherFont.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background {
                                if email.isEmpty {
                                    Color.gatherSecondaryBackground
                                } else {
                                    LinearGradient.gatherAccentGradient
                                }
                            }
                            .foregroundStyle(email.isEmpty ? Color.gatherSecondaryText : .white)
                            .cornerRadius(CornerRadius.md)
                    }
                    .disabled(email.isEmpty)
                }

                Spacer()
            }
            .horizontalPadding()
            .navigationTitle(linkSent ? "" : "Sign in with Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isEmailFocused = true
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    AuthView()
        .environmentObject(AuthManager())
}
