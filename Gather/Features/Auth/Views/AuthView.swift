import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showEmailSheet = false
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
                        .font(.system(size: 48, weight: .heavy))
                        .kerning(-1)
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
                        authManager.configureAppleRequest(request)
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
                        authManager.signInWithGoogle()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image("GoogleLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
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

                    // Email — sign in or create an account
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

                    // Demo Sign In (DEBUG only)
                    if AppConfig.isDemoMode {
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
                        .padding(.vertical, Spacing.xxs)
                        .opacity(buttonsVisible ? 1 : 0)

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
                }
                .padding(.horizontal, Spacing.lg)

                // Terms & Privacy (clickable links)
                HStack(spacing: 0) {
                    Text("By continuing, you agree to our ")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherTertiaryText)
                    Link("Terms", destination: AppConfig.termsOfServiceURL)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.accentPurpleFallback)
                    Text(" and ")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherTertiaryText)
                    Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.accentPurpleFallback)
                }
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
                            .tint(Color.accentPurpleFallback)

                        Text("Signing in...")
                            .font(GatherFont.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.gatherPrimaryText)
                    }
                    .padding(Spacing.xl)
                    .surfaceCard(cornerRadius: CornerRadius.lg)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.1)) {
                logoVisible = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.4)) {
                buttonsVisible = true
            }
        }
        .sheet(isPresented: $showEmailSheet) {
            EmailAuthSheet()
        }
        // Apple sign-in errors surface here; email errors show inside the sheet.
        .alert("Sign In Error", isPresented: .constant(authManager.authError != nil && !showEmailSheet)) {
            Button("OK") { authManager.authError = nil }
        } message: {
            if let error = authManager.authError {
                Text(error.localizedDescription)
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                await authManager.signInWithApple(authorization: authorization)
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                authManager.authError = .signInFailed(error.localizedDescription)
            }
        }
    }
}

// MARK: - Email Auth Sheet (Sign In / Create Account / Forgot Password)

struct EmailAuthSheet: View {
    enum Mode { case signIn, createAccount, forgotPassword }

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var infoMessage: String?
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case name, email, password }

    // MARK: - Validation

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isValidEmail: Bool {
        let regex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
        return trimmedEmail.wholeMatch(of: regex) != nil
    }

    private var isValidName: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var canSubmit: Bool {
        switch mode {
        case .signIn: return isValidEmail && !password.isEmpty
        case .createAccount: return isValidName && isValidEmail && password.count >= 6
        case .forgotPassword: return isValidEmail
        }
    }

    private var title: String {
        switch mode {
        case .signIn: return "Welcome back"
        case .createAccount: return "Create your account"
        case .forgotPassword: return "Reset password"
        }
    }

    private var subtitle: String {
        switch mode {
        case .signIn: return "Sign in to continue to Gather"
        case .createAccount: return "Join Gather to host and attend events"
        case .forgotPassword: return "We'll email you a link to set a new password"
        }
    }

    private var primaryButtonTitle: String {
        switch mode {
        case .signIn: return "Sign In"
        case .createAccount: return "Create Account"
        case .forgotPassword: return "Send Reset Link"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    header

                    VStack(spacing: Spacing.md) {
                        if mode == .createAccount {
                            field(
                                label: "NAME",
                                icon: "person",
                                placeholder: "Your name",
                                text: $name,
                                field: .name,
                                contentType: .name
                            )
                        }

                        field(
                            label: "EMAIL",
                            icon: "envelope",
                            placeholder: "email@example.com",
                            text: $email,
                            field: .email,
                            contentType: .emailAddress,
                            keyboard: .emailAddress
                        )

                        if mode != .forgotPassword {
                            passwordField
                        }
                    }

                    if let infoMessage {
                        banner(infoMessage, icon: "checkmark.circle.fill", color: Color.rsvpYesFallback)
                    }

                    if let error = authManager.authError?.errorDescription {
                        banner(error, icon: "exclamationmark.triangle.fill", color: Color.gatherError)
                    }

                    primaryButton

                    modeSwitcher

                    Spacer(minLength: Spacing.lg)
                }
                .horizontalPadding()
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("")
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
                    .accessibilityLabel("Close")
                }
            }
            .onChange(of: mode) { _, _ in
                authManager.authError = nil
                infoMessage = nil
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { authManager.authError = nil }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.accentPurpleFallback.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: mode == .forgotPassword ? "lock.rotation" : "envelope.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(LinearGradient.gatherAccentGradient)
            }

            Text(title)
                .font(GatherFont.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.gatherPrimaryText)

            Text(subtitle)
                .font(GatherFont.caption)
                .foregroundStyle(Color.gatherSecondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Fields

    private func field(
        label: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        contentType: UITextContentType,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(Color.gatherSecondaryText)
                .tracking(0.5)

            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Color.accentPurpleFallback.opacity(0.7))
                    .frame(width: 20)
                TextField(placeholder, text: text)
                    .font(GatherFont.body)
                    .keyboardType(keyboard)
                    .textContentType(contentType)
                    .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                    .autocorrectionDisabled(keyboard == .emailAddress)
                    .focused($focusedField, equals: field)
                    .submitLabel(.next)
            }
            .padding(Spacing.sm)
            .background(Color.gatherSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PASSWORD")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(Color.gatherSecondaryText)
                .tracking(0.5)

            HStack(spacing: Spacing.xs) {
                Image(systemName: "lock")
                    .font(.caption)
                    .foregroundStyle(Color.accentPurpleFallback.opacity(0.7))
                    .frame(width: 20)

                Group {
                    if showPassword {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                }
                .font(GatherFont.body)
                .textContentType(mode == .createAccount ? .newPassword : .password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { submit() }

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .accessibilityLabel(showPassword ? "Hide password" : "Show password")
            }
            .padding(Spacing.sm)
            .background(Color.gatherSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

            if mode == .createAccount {
                Text("At least 6 characters")
                    .font(.caption2)
                    .foregroundStyle(Color.gatherTertiaryText)
            }
        }
    }

    private func banner(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(GatherFont.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private var primaryButton: some View {
        Button {
            submit()
        } label: {
            ZStack {
                if authManager.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(primaryButtonTitle)
                        .font(GatherFont.callout)
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                canSubmit
                    ? AnyShapeStyle(LinearGradient.gatherAccentGradient)
                    : AnyShapeStyle(Color.gatherSecondaryText.opacity(0.3))
            )
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
        .disabled(!canSubmit || authManager.isLoading)
    }

    private var modeSwitcher: some View {
        VStack(spacing: Spacing.sm) {
            switch mode {
            case .signIn:
                Button("Forgot password?") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { mode = .forgotPassword }
                }
                .font(GatherFont.caption)
                .foregroundStyle(Color.accentPurpleFallback)

                HStack(spacing: 4) {
                    Text("New to Gather?")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                    Button("Create an account") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { mode = .createAccount }
                    }
                    .font(GatherFont.caption.weight(.bold))
                    .foregroundStyle(Color.accentPurpleFallback)
                }

            case .createAccount:
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                    Button("Sign in") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { mode = .signIn }
                    }
                    .font(GatherFont.caption.weight(.bold))
                    .foregroundStyle(Color.accentPurpleFallback)
                }

            case .forgotPassword:
                Button("Back to sign in") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { mode = .signIn }
                }
                .font(GatherFont.caption)
                .foregroundStyle(Color.accentPurpleFallback)
            }
        }
        .padding(.top, Spacing.xs)
    }

    // MARK: - Submit

    private func submit() {
        guard canSubmit, !authManager.isLoading else { return }
        authManager.authError = nil
        infoMessage = nil
        focusedField = nil

        Task {
            switch mode {
            case .signIn:
                await authManager.signIn(email: email, password: password)
            case .createAccount:
                await authManager.register(name: name, email: email, password: password)
                if authManager.authError == nil {
                    HapticService.success()
                }
            case .forgotPassword:
                let sent = await authManager.sendPasswordReset(email: email)
                if sent {
                    infoMessage = "Password reset link sent to \(trimmedEmail). Check your inbox."
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AuthView()
        .environmentObject(AuthManager())
}
