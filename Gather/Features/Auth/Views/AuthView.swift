import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showEmailSheet = false
    @State private var email = ""
    @State private var logoVisible = false
    @State private var buttonsVisible = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.accentPurpleFallback.opacity(0.12),
                    Color.accentPinkFallback.opacity(0.06),
                    Color.gatherBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating decorative orbs
            GeometryReader { geo in
                Circle()
                    .fill(Color.accentPurpleFallback.opacity(0.08))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: -80, y: geo.size.height * 0.05)

                Circle()
                    .fill(Color.accentPinkFallback.opacity(0.07))
                    .frame(width: 200, height: 200)
                    .blur(radius: 50)
                    .offset(x: geo.size.width * 0.6, y: geo.size.height * 0.15)

                Circle()
                    .fill(Color.accentPurpleFallback.opacity(0.05))
                    .frame(width: 180, height: 180)
                    .blur(radius: 40)
                    .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.7)
            }

            VStack(spacing: Spacing.xl) {
                Spacer()

                // Logo & Title
                VStack(spacing: Spacing.md) {
                    ZStack {
                        // Glow ring
                        Circle()
                            .fill(Color.accentPurpleFallback.opacity(0.08))
                            .frame(width: 130, height: 130)
                            .scaleEffect(logoVisible ? 1 : 0.5)
                            .opacity(logoVisible ? 1 : 0)

                        Circle()
                            .fill(Color.accentPinkFallback.opacity(0.06))
                            .frame(width: 100, height: 100)
                            .scaleEffect(logoVisible ? 1 : 0.6)
                            .opacity(logoVisible ? 1 : 0)

                        Image(systemName: "sparkles")
                            .font(.system(size: 56))
                            .foregroundStyle(LinearGradient.gatherAccentGradient)
                            .scaleEffect(logoVisible ? 1 : 0.3)
                            .opacity(logoVisible ? 1 : 0)
                    }

                    Text("Gather")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.gatherPrimaryText)
                        .scaleEffect(logoVisible ? 1 : 0.8)
                        .opacity(logoVisible ? 1 : 0)

                    Text("Plan events. Share moments.")
                        .font(GatherFont.title3)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .opacity(logoVisible ? 1 : 0)
                }

                Spacer()

                // Auth Buttons
                VStack(spacing: Spacing.sm) {
                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(Capsule())
                    .offset(y: buttonsVisible ? 0 : 30)
                    .opacity(buttonsVisible ? 1 : 0)

                    // Sign in with Google
                    Button {
                        Task {
                            await authManager.signInWithGoogle()
                        }
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                            Text("Continue with Google")
                                .font(GatherFont.callout)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.gatherSecondaryBackground)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .clipShape(Capsule())
                    }
                    .offset(y: buttonsVisible ? 0 : 30)
                    .opacity(buttonsVisible ? 1 : 0)

                    // Email magic link
                    Button {
                        showEmailSheet = true
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "envelope.fill")
                                .font(.title3)
                            Text("Continue with Email")
                                .font(GatherFont.callout)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.gatherSecondaryBackground)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .clipShape(Capsule())
                    }
                    .offset(y: buttonsVisible ? 0 : 30)
                    .opacity(buttonsVisible ? 1 : 0)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.gatherSecondaryText.opacity(0.2))
                            .frame(height: 1)
                        Text("or")
                            .font(.caption2)
                            .foregroundStyle(Color.gatherSecondaryText)
                        Rectangle()
                            .fill(Color.gatherSecondaryText.opacity(0.2))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 4)
                    .opacity(buttonsVisible ? 1 : 0)

                    // Demo Sign In
                    Button {
                        authManager.signInAsDemo()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "person.fill.viewfinder")
                                .font(.title3)
                            Text("Demo Sign In")
                                .font(GatherFont.callout)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LinearGradient.gatherAccentGradient)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.accentPurpleFallback.opacity(0.3), radius: 12, y: 6)
                    }
                    .scaleEffect(buttonsVisible ? 1 : 0.9)
                    .opacity(buttonsVisible ? 1 : 0)
                }
                .padding(.horizontal, Spacing.lg)

                // Terms
                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption2)
                    .foregroundStyle(Color.gatherTertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.xl)
                    .opacity(buttonsVisible ? 0.8 : 0)
            }

            // Loading overlay
            if authManager.isLoading {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Signing in...")
                            .font(GatherFont.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                    .padding(Spacing.xl)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                logoVisible = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4)) {
                buttonsVisible = true
            }
        }
        .sheet(isPresented: $showEmailSheet) {
            EmailSignInSheet(email: $email)
        }
        .sheet(isPresented: $authManager.pendingGoogleSignIn) {
            GoogleSignInSheet()
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

// MARK: - Google Sign In Sheet (Simulated OAuth)

struct GoogleSignInSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var email = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                // Google logo area
                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.08))
                            .frame(width: 90, height: 90)

                        Circle()
                            .fill(Color.blue.opacity(0.05))
                            .frame(width: 70, height: 70)

                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.blue)
                    }

                    Text("Sign in with Google")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.gatherPrimaryText)

                    Text("Enter your details to simulate Google OAuth")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .padding(.top, Spacing.lg)

                // Name field
                VStack(alignment: .leading, spacing: 6) {
                    Text("NAME")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .tracking(0.5)

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "person")
                            .font(.caption)
                            .foregroundStyle(Color.accentPurpleFallback.opacity(0.7))
                            .frame(width: 20)
                        TextField("Your name", text: $name)
                            .font(GatherFont.body)
                            .textContentType(.name)
                            .focused($isNameFocused)
                    }
                    .padding(Spacing.sm)
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }

                // Email field
                VStack(alignment: .leading, spacing: 6) {
                    Text("EMAIL")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .tracking(0.5)

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "envelope")
                            .font(.caption)
                            .foregroundStyle(Color.accentPurpleFallback.opacity(0.7))
                            .frame(width: 20)
                        TextField("email@gmail.com", text: $email)
                            .font(GatherFont.body)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(Spacing.sm)
                    .background(Color.gatherSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }

                // Sign in button
                Button {
                    authManager.completeGoogleSignIn(name: name, email: email)
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.callout)
                        Text("Sign In")
                            .font(GatherFont.callout)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        email.isEmpty
                            ? AnyShapeStyle(Color.gatherSecondaryBackground)
                            : AnyShapeStyle(LinearGradient.gatherAccentGradient)
                    )
                    .foregroundStyle(email.isEmpty ? Color.gatherSecondaryText : .white)
                    .clipShape(Capsule())
                }
                .disabled(email.isEmpty)

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .navigationTitle("Google Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        authManager.cancelGoogleSignIn()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.medium])
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
                        ZStack {
                            Circle()
                                .fill(Color.rsvpYesFallback.opacity(0.1))
                                .frame(width: 110, height: 110)
                                .bouncyAppear()

                            Circle()
                                .fill(Color.rsvpYesFallback.opacity(0.15))
                                .frame(width: 80, height: 80)
                                .bouncyAppear(delay: 0.05)

                            Image(systemName: "envelope.badge.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.rsvpYesFallback)
                                .bouncyAppear(delay: 0.1)
                        }

                        Text("Check your inbox")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.gatherPrimaryText)
                            .bouncyAppear(delay: 0.15)

                        Text("We sent a sign-in link to **\(email)**")
                            .font(GatherFont.body)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .multilineTextAlignment(.center)
                            .bouncyAppear(delay: 0.2)

                        // Auto-verify button for demo purposes
                        Button {
                            Task {
                                await authManager.verifyMagicLink(email: email, link: "demo-link")
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text("Open Magic Link (Demo)")
                                    .font(GatherFont.callout)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(Color.accentPurpleFallback)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.accentPurpleFallback.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .padding(.top, Spacing.sm)
                        .bouncyAppear(delay: 0.25)
                    }
                    .padding(.top, Spacing.xxl)
                } else {
                    // Email input
                    VStack(spacing: Spacing.lg) {
                        VStack(spacing: Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentPurpleFallback.opacity(0.08))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(LinearGradient.gatherAccentGradient)
                            }

                            Text("Enter your email")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.gatherPrimaryText)

                            Text("We'll send you a magic link to sign in")
                                .font(GatherFont.caption)
                                .foregroundStyle(Color.gatherSecondaryText)
                        }
                        .padding(.top, Spacing.sm)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("EMAIL")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.gatherSecondaryText)
                                .tracking(0.5)

                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "envelope")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentPurpleFallback.opacity(0.7))
                                    .frame(width: 20)
                                TextField("email@example.com", text: $email)
                                    .font(GatherFont.body)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($isEmailFocused)
                            }
                            .padding(Spacing.sm)
                            .background(Color.gatherSecondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                        }

                        Button {
                            Task {
                                let success = await authManager.sendMagicLink(email: email)
                                if success {
                                    withAnimation(.spring(response: 0.4)) {
                                        linkSent = true
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "paperplane.fill")
                                    .font(.callout)
                                Text("Send Magic Link")
                                    .font(GatherFont.callout)
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                email.isEmpty
                                    ? AnyShapeStyle(Color.gatherSecondaryBackground)
                                    : AnyShapeStyle(LinearGradient.gatherAccentGradient)
                            )
                            .foregroundStyle(email.isEmpty ? Color.gatherSecondaryText : .white)
                            .clipShape(Capsule())
                        }
                        .disabled(email.isEmpty)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .navigationTitle(linkSent ? "" : "Sign in with Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.gatherSecondaryText)
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
