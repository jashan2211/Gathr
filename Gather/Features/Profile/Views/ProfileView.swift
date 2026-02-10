import SwiftUI
import SwiftData
import AuthenticationServices

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Query private var allEvents: [Event]
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showReauthSheet = false
    @State private var isLoadingData = false
    @State private var loadedDataMessage: String?

    private var hostedEvents: Int {
        guard let userId = authManager.currentUser?.id else { return 0 }
        return allEvents.filter { $0.hostId == userId }.count
    }

    private var attendingEvents: Int {
        guard let userId = authManager.currentUser?.id else { return 0 }
        return allEvents.filter { event in
            event.guests.contains { $0.userId == userId && $0.status == .attending }
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Profile Header Card
                    profileHeader
                        .bouncyAppear()

                    // Stats Row
                    statsRow
                        .bouncyAppear(delay: 0.03)

                    // My Tickets Section
                    myTicketsSection
                        .bouncyAppear(delay: 0.06)

                    // Preferences
                    preferencesSection
                        .bouncyAppear(delay: 0.09)

                    // Support
                    supportSection
                        .bouncyAppear(delay: 0.12)

                    // Account Actions
                    accountSection

                    // Developer Tools (DEBUG only)
                    if AppConfig.isDemoMode {
                        devToolsSection
                    }

                    // Version
                    versionBadge

                    Spacer()
                        .frame(height: Layout.tabBarHeight + 20)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .confirmationDialog("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Delete Account", role: .destructive) {
                    showReauthSheet = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
            .sheet(isPresented: $showReauthSheet) {
                ReauthenticateSheet {
                    Task {
                        await authManager.deleteAccount(modelContext: modelContext)
                    }
                }
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(spacing: Spacing.md) {
            // Avatar with gradient ring
            ZStack {
                Circle()
                    .fill(LinearGradient.gatherAccentGradient)
                    .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                    .overlay {
                        Text(authManager.currentUser?.name.prefix(1).uppercased() ?? "?")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .modifier(GradientRing(color: Color.accentPurpleFallback, lineWidth: 3))
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(authManager.currentUser?.name ?? "User")
                    .font(GatherFont.title3)
                    .foregroundStyle(Color.gatherPrimaryText)

                if let email = authManager.currentUser?.email {
                    Text(email)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
            }

            Spacer()

            Button {
                // Edit profile
            } label: {
                Text("Edit")
                    .font(GatherFont.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.accentPurpleFallback)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.accentPurpleFallback.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(Spacing.md)
        .glassCard()
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: Spacing.sm) {
            ProfileStatCard(
                value: hostedEvents,
                label: "Hosted",
                icon: "calendar.badge.plus",
                color: Color.accentPurpleFallback
            )
            ProfileStatCard(
                value: attendingEvents,
                label: "Attending",
                icon: "ticket.fill",
                color: Color.accentPinkFallback
            )
            ProfileStatCard(
                value: totalGuests,
                label: "Total Guests",
                icon: "person.2.fill",
                color: Color.mintGreen
            )
        }
    }

    // MARK: - My Tickets Section

    private var myTicketsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "ticket.fill")
                    .foregroundStyle(Color.accentPurpleFallback)
                Text("My Tickets")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)
            }

            HStack(spacing: Spacing.md) {
                Image(systemName: "qrcode")
                    .font(.title2)
                    .foregroundStyle(Color.accentPurpleFallback)
                    .frame(width: 44, height: 44)
                    .background(Color.accentPurpleFallback.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text("View Purchased Tickets")
                        .font(GatherFont.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text("Access QR codes and event details")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(Spacing.md)
            .glassCard()
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Preferences")
                .font(GatherFont.headline)
                .foregroundStyle(Color.gatherPrimaryText)

            VStack(spacing: 1) {
                ProfileMenuItem(icon: "bell", title: "Notifications", color: Color.accentPurpleFallback) {
                    NotificationSettingsView()
                }
                ProfileMenuItem(icon: "lock", title: "Privacy", color: Color.accentPinkFallback) {
                    PrivacySettingsView()
                }
                ProfileMenuItem(icon: "calendar", title: "Calendar Sync", color: Color.neonBlue) {
                    CalendarSettingsView()
                }
                ProfileMenuItem(icon: "paintbrush", title: "Appearance", color: Color.sunshineYellow) {
                    AppearanceSettingsView()
                }
            }
            .glassCard(cornerRadius: CornerRadius.md)
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Support")
                .font(GatherFont.headline)
                .foregroundStyle(Color.gatherPrimaryText)

            VStack(spacing: 1) {
                ProfileMenuItem(icon: "questionmark.circle", title: "Help", color: Color.mintGreen) {
                    Text("Help Center")
                }
                ProfileMenuItem(icon: "envelope", title: "Send Feedback", color: Color.accentPurpleFallback) {
                    Text("Feedback")
                }
                ProfileMenuItem(icon: "info.circle", title: "About Gather", color: Color.neonBlue) {
                    Text("About")
                }
            }
            .glassCard(cornerRadius: CornerRadius.md)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                showSignOutConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(Color.warmCoral)
                    Text("Sign Out")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.warmCoral)
                    Spacer()
                }
                .padding(Spacing.md)
                .glassCard()
            }

            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.rsvpNoFallback)
                    Text("Delete Account")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.rsvpNoFallback)
                    Spacer()
                }
                .padding(Spacing.md)
                .glassCard()
            }
        }
    }

    // MARK: - Dev Tools

    private var devToolsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(Color.gatherSecondaryText)
                Text("Developer Tools")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)
            }

            // Data stats
            HStack(spacing: Spacing.md) {
                DevToolStat(value: allEvents.count, label: "Events", color: Color.accentPurpleFallback)
                DevToolStat(value: totalGuests, label: "Guests", color: Color.accentPinkFallback)
                DevToolStat(value: publicEventsCount, label: "Public", color: Color.mintGreen)
            }
            .padding(Spacing.sm)
            .glassCard()

            if isLoadingData {
                HStack {
                    ProgressView()
                        .tint(Color.accentPurpleFallback)
                    Text("Generating data...")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .padding(Spacing.sm)
            }

            if let message = loadedDataMessage {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.mintGreen)
                    Text(message)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .padding(Spacing.sm)
            }

            DataLoadButton(
                title: "Standard",
                subtitle: "13 events, curated demo data",
                icon: "square.and.arrow.down",
                color: Color.accentPurpleFallback,
                isLoading: isLoadingData
            ) { loadData(size: .standard) }

            DataLoadButton(
                title: "Large",
                subtitle: "50 events across 20 cities",
                icon: "square.stack.3d.up",
                color: Color.accentPinkFallback,
                isLoading: isLoadingData
            ) { loadData(size: .large) }

            DataLoadButton(
                title: "Massive",
                subtitle: "150+ events, stress test mode",
                icon: "flame",
                color: Color.sunshineYellow,
                isLoading: isLoadingData
            ) { loadData(size: .massive) }

            Button {
                resetDemoData()
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.warmCoral)
                    Text("Reset All Data")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.warmCoral)
                    Spacer()
                }
                .padding(Spacing.md)
                .glassCard()
            }
            .disabled(isLoadingData)
        }
    }

    // MARK: - Version Badge

    private var versionBadge: some View {
        HStack {
            Spacer()
            Text("Gather v1.0.0")
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)
            Spacer()
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Computed

    private var totalGuests: Int {
        allEvents.reduce(0) { $0 + $1.guests.count }
    }

    private var publicEventsCount: Int {
        allEvents.filter { $0.privacy == .publicEvent }.count
    }

    // MARK: - Data Sizes

    enum DataSize {
        case standard, large, massive
        var eventCount: Int {
            switch self {
            case .standard: return 13
            case .large: return 50
            case .massive: return 150
            }
        }
        var label: String {
            switch self {
            case .standard: return "Standard"
            case .large: return "Large"
            case .massive: return "Massive"
            }
        }
    }

    // MARK: - Demo Data Functions

    private func loadData(size: DataSize) {
        guard let userId = authManager.currentUser?.id else { return }
        isLoadingData = true
        loadedDataMessage = nil

        Task {
            try? await Task.sleep(for: .seconds(0.1))
            if size == .standard {
                DemoDataService.shared.loadDemoData(modelContext: modelContext, hostId: userId)
            } else {
                DemoDataService.shared.loadMassiveData(modelContext: modelContext, hostId: userId, eventCount: size.eventCount)
            }

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            isLoadingData = false
            loadedDataMessage = "\(size.label) data loaded!"

            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation { loadedDataMessage = nil }
            }
        }
    }

    private func resetDemoData() {
        DemoDataService.shared.resetAllData(modelContext: modelContext)
        loadedDataMessage = nil

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - Profile Stat Card

struct ProfileStatCard: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text("\(value)")
                .font(GatherFont.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.gatherPrimaryText)
                .contentTransition(.numericText())

            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .glassCard()
    }
}

// MARK: - Profile Menu Item

struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let color: Color
    let destination: () -> AnyView

    init<V: View>(icon: String, title: String, color: Color, @ViewBuilder destination: @escaping () -> V) {
        self.icon = icon
        self.title = title
        self.color = color
        self.destination = { AnyView(destination()) }
    }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                Text(title)
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherPrimaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
    }
}

// MARK: - Settings Views (Placeholders)

struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("eventReminders") private var eventReminders = true
    @AppStorage("rsvpUpdates") private var rsvpUpdates = true

    var body: some View {
        List {
            Section {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
            }

            Section("Event Notifications") {
                Toggle("Event Reminders", isOn: $eventReminders)
                Toggle("RSVP Updates", isOn: $rsvpUpdates)
            }
        }
        .navigationTitle("Notifications")
    }
}

struct PrivacySettingsView: View {
    @AppStorage("showMeAsAttending") private var showMeAsAttending = true
    @AppStorage("defaultPrivacy") private var defaultPrivacy = "inviteOnly"

    var body: some View {
        List {
            Section {
                Toggle("Show me as attending", isOn: $showMeAsAttending)
            } footer: {
                Text("Allow friends to see when you're attending events")
            }

            Section("Default Event Privacy") {
                Picker("Privacy", selection: $defaultPrivacy) {
                    Text("Public").tag("public")
                    Text("Unlisted").tag("unlisted")
                    Text("Invite Only").tag("inviteOnly")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Privacy")
    }
}

struct CalendarSettingsView: View {
    @AppStorage("calendarSyncEnabled") private var calendarSyncEnabled = true
    @AppStorage("selectedCalendar") private var selectedCalendar = "default"

    var body: some View {
        List {
            Section {
                Toggle("Sync to Calendar", isOn: $calendarSyncEnabled)
            } footer: {
                Text("Automatically add events you RSVP to your calendar")
            }
        }
        .navigationTitle("Calendar")
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("colorScheme") private var colorScheme = "system"

    var body: some View {
        List {
            Section("Theme") {
                Picker("Appearance", selection: $colorScheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Appearance")
    }
}

// MARK: - Dev Tool Stat

struct DevToolStat: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(GatherFont.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Data Load Button

struct DataLoadButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(GatherFont.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(Spacing.sm)
            .glassCard()
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.5 : 1)
    }
}

// MARK: - Re-authenticate Sheet

struct ReauthenticateSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var errorMessage: String?
    @State private var appleSignInCompleted = false
    let onConfirm: () -> Void

    private var isAppleUser: Bool {
        authManager.currentAuthProvider == "apple"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.rsvpNoFallback.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.rsvpNoFallback)
                    }

                    Text("Confirm Your Identity")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.gatherPrimaryText)

                    Text("To delete your account, please verify your identity.")
                        .font(GatherFont.body)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.lg)

                if isAppleUser {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email]
                    } onCompletion: { result in
                        switch result {
                        case .success:
                            appleSignInCompleted = true
                            onConfirm()
                            dismiss()
                        case .failure:
                            errorMessage = "Apple Sign In failed. Please try again."
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(Capsule())
                } else {
                    // Email users re-enter their email
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Enter your email to confirm")
                            .font(GatherFont.callout)
                            .foregroundStyle(Color.gatherSecondaryText)

                        TextField("email@example.com", text: $email)
                            .font(GatherFont.body)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(Spacing.sm)
                            .background(Color.gatherSecondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }

                    Button {
                        verifyEmail()
                    } label: {
                        Text("Delete My Account")
                            .font(GatherFont.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                email.isEmpty
                                    ? Color.gatherSecondaryText
                                    : Color.rsvpNoFallback
                            )
                            .clipShape(Capsule())
                    }
                    .disabled(email.isEmpty)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.rsvpNoFallback)
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func verifyEmail() {
        let currentEmail = authManager.currentUser?.email?.lowercased() ?? ""
        if email.lowercased() == currentEmail {
            onConfirm()
            dismiss()
        } else {
            errorMessage = "Email does not match your account"
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
        .modelContainer(for: Event.self, inMemory: true)
}
