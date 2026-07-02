import SwiftUI
import SwiftData
import AuthenticationServices
import UserNotifications
import EventKit

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var allEvents: [Event]
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showReauthSheet = false
    @State private var isLoadingData = false
    @State private var loadedDataMessage: String?
    @State private var showEditProfile = false
    @State private var verificationMessage: String?
    @State private var isResendingVerification = false

    private var profileStats: (hosted: Int, attending: Int, totalGuests: Int, publicCount: Int) {
        let userId = authManager.currentUser?.id
        var hosted = 0, attending = 0, totalGuests = 0, publicCount = 0
        for event in allEvents {
            totalGuests += event.guests.count
            if event.hostId == userId { hosted += 1 }
            if event.privacy == .publicEvent { publicCount += 1 }
            if event.guests.contains(where: { $0.userId == userId && $0.status == .attending }) {
                attending += 1
            }
        }
        return (hosted, attending, totalGuests, publicCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Nudge unverified email accounts to confirm their address.
                    emailVerificationBanner

                    // Editorial header — big avatar + name + handle
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
                        // Demo mode banner
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("DEMO MODE ACTIVE")
                                .gatherEyebrow()
                        }
                        .foregroundStyle(Color.sunshineYellow)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .frame(maxWidth: .infinity)
                        .background(Color.gatherElevated, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.sunshineYellow.opacity(0.4), lineWidth: 1)
                        )

                        devToolsSection
                    }

                    // Version
                    versionBadge

                    Spacer()
                        .frame(height: Layout.tabBarHeight + 20)
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, Spacing.sm)
            }
            .background(Color.gatherCanvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
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
                ReauthenticateSheet()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
            }
        }
    }

    // MARK: - Email Verification Banner

    /// Shown only for real (non-anonymous) email accounts that haven't confirmed
    /// their address yet. Anonymous/demo accounts report as verified, so they
    /// never see this.
    @ViewBuilder
    private var emailVerificationBanner: some View {
        if !authManager.isEmailVerified {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.title3)
                        .foregroundStyle(Color.sunshineYellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Verify your email")
                            .gatherRowTitle()
                            .foregroundStyle(Color.gatherPrimaryText)
                        Text("Confirm \(authManager.currentUser?.email ?? "your address") to secure your account.")
                            .gatherMetaText()
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                    Spacer()
                }

                if let verificationMessage {
                    Text(verificationMessage)
                        .gatherMetaText()
                        .foregroundStyle(Color.rsvpYesFallback)
                }

                HStack(spacing: Spacing.sm) {
                    Button {
                        Task {
                            isResendingVerification = true
                            await authManager.resendVerificationEmail()
                            isResendingVerification = false
                            HapticService.success()
                            withAnimation { verificationMessage = "Verification email sent — check your inbox." }
                        }
                    } label: {
                        Text(isResendingVerification ? "Sending…" : "Resend email")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 8)
                            .background(Color.accentPurpleFallback, in: Capsule())
                    }
                    .disabled(isResendingVerification)

                    Button {
                        Task {
                            await authManager.refreshVerificationStatus()
                            if authManager.isEmailVerified {
                                HapticService.success()
                            } else {
                                withAnimation { verificationMessage = "Still not verified — tap the link in the email first." }
                            }
                        }
                    } label: {
                        Text("I've verified")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentPurpleFallback)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 8)
                            .background(Color.accentPurpleFallback.opacity(0.12), in: Capsule())
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.sunshineYellow.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .strokeBorder(Color.sunshineYellow.opacity(0.3), lineWidth: 1)
            )
            .task { await authManager.refreshVerificationStatus() }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Tiny editorial eyebrow + Edit affordance
            HStack {
                Text("YOUR PROFILE")
                    .gatherEyebrow()
                    .foregroundStyle(Color.gatherSecondaryText)

                Spacer()

                Button {
                    HapticService.selection()
                    showEditProfile = true
                } label: {
                    Text("Edit")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.accentPurpleFallback)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.gatherSurface, in: Capsule())
                }
                .accessibilityLabel("Edit profile")
            }

            HStack(spacing: Spacing.md) {
                // Large avatar / initials with gradient ring
                Circle()
                    .fill(LinearGradient.gatherAccentGradient)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Text(authManager.currentUser?.name.prefix(1).uppercased() ?? "?")
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    .modifier(GradientRing(color: Color.accentPurpleFallback, lineWidth: 3))

                VStack(alignment: .leading, spacing: 4) {
                    // Serif display moment — the editorial signature
                    Text(authManager.currentUser?.name ?? "User")
                        .gatherSerifScreenTitle()
                        .foregroundStyle(Color.gatherPrimaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                    if let email = authManager.currentUser?.email {
                        Text(email)
                            .gatherMetaText()
                            .foregroundStyle(Color.gatherSecondaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: Spacing.sm) {
            ProfileStatCard(
                value: profileStats.hosted,
                label: "Hosted",
                icon: "calendar.badge.plus",
                color: Color.accentPurpleFallback
            )
            ProfileStatCard(
                value: profileStats.attending,
                label: "Attending",
                icon: "ticket.fill",
                color: Color.accentPinkFallback
            )
            ProfileStatCard(
                value: profileStats.totalGuests,
                label: "Total Guests",
                icon: "person.2.fill",
                color: Color.mintGreen
            )
        }
    }

    // MARK: - My Tickets Section

    private var myTicketsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ProfileSectionHeader("My Tickets")

            NavigationLink {
                MyTicketsView()
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentPurpleFallback)
                        .frame(width: 40, height: 40)
                        .background(Color.gatherElevated, in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("View Purchased Tickets")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.gatherPrimaryText)
                        Text("Access QR codes and event details")
                            .gatherMetaText()
                            .foregroundStyle(Color.gatherSecondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .padding(Spacing.md)
                .surfaceCard(cornerRadius: CornerRadius.lg)
            }
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ProfileSectionHeader("Preferences")

            VStack(spacing: 0) {
                ProfileMenuItem(icon: "bell", title: "Notifications", color: Color.accentPurpleFallback) {
                    NotificationSettingsView()
                }
                ProfileRowDivider()
                ProfileMenuItem(icon: "lock", title: "Privacy", color: Color.accentPinkFallback) {
                    PrivacySettingsView()
                }
                ProfileRowDivider()
                ProfileMenuItem(icon: "calendar", title: "Calendar Sync", color: Color.neonBlue) {
                    CalendarSettingsView()
                }
                ProfileRowDivider()
                ProfileMenuItem(icon: "paintbrush", title: "Appearance", color: Color.sunshineYellow) {
                    AppearanceSettingsView()
                }
            }
            .surfaceCard(cornerRadius: CornerRadius.lg)
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ProfileSectionHeader("Support")

            VStack(spacing: 0) {
                ProfileMenuItem(icon: "questionmark.circle", title: "Help", color: Color.mintGreen) {
                    HelpCenterView()
                }
                ProfileRowDivider()
                ProfileMenuLink(icon: "envelope", title: "Send Feedback", color: Color.accentPurpleFallback) {
                    if let url = URL(string: "mailto:\(AppConfig.contactEmail)?subject=Gather%20Feedback") {
                        UIApplication.shared.open(url)
                    }
                }
                ProfileRowDivider()
                ProfileMenuItem(icon: "info.circle", title: "About Gather", color: Color.neonBlue) {
                    AboutGatherView()
                }
            }
            .surfaceCard(cornerRadius: CornerRadius.lg)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ProfileSectionHeader("Account")

            VStack(spacing: 0) {
                Button {
                    HapticService.warning()
                    showSignOutConfirmation = true
                } label: {
                    ProfileDestructiveRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "Sign Out"
                    )
                }
                .accessibilityLabel("Sign Out")

                ProfileRowDivider()

                Button {
                    showDeleteConfirmation = true
                } label: {
                    ProfileDestructiveRow(
                        icon: "trash",
                        title: "Delete Account"
                    )
                }
                .accessibilityLabel("Delete Account")
            }
            .surfaceCard(cornerRadius: CornerRadius.lg)
        }
    }

    // MARK: - Dev Tools

    private var devToolsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.gatherSecondaryText)
                Text("DEVELOPER TOOLS")
                    .gatherEyebrow()
                    .foregroundStyle(Color.gatherSecondaryText)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }

            // Data stats
            HStack(spacing: Spacing.md) {
                DevToolStat(value: allEvents.count, label: "Events", color: Color.accentPurpleFallback)
                DevToolStat(value: profileStats.totalGuests, label: "Guests", color: Color.accentPinkFallback)
                DevToolStat(value: profileStats.publicCount, label: "Public", color: Color.mintGreen)
            }
            .padding(Spacing.md)
            .surfaceCard(cornerRadius: CornerRadius.lg)

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
                color: Color.sunshineYellowText,
                isLoading: isLoadingData
            ) { loadData(size: .massive) }

            Button {
                resetDemoData()
            } label: {
                ProfileDestructiveRow(icon: "trash", title: "Reset All Data")
                    .surfaceCard(cornerRadius: CornerRadius.lg)
            }
            .disabled(isLoadingData)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundStyle(Color.sunshineYellow.opacity(0.4))
        )
    }

    // MARK: - Version Badge

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var versionBadge: some View {
        HStack {
            Spacer()
            Text("GATHER v\(appVersion) (\(buildNumber))")
                .gatherEyebrow()
                .foregroundStyle(Color.gatherTertiaryText)
            Spacer()
        }
        .padding(.top, Spacing.sm)
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

            HapticService.success()
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

        HapticService.warning()
    }
}

// MARK: - Profile Stat Card

struct ProfileStatCard: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(Color.gatherElevated, in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))

            Text("\(value)")
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(color)
                .contentTransition(.numericText())

            Text(label.uppercased())
                .gatherEyebrow()
                .foregroundStyle(Color.gatherSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .surfaceCard(cornerRadius: CornerRadius.lg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - Profile Section Header

/// A small editorial ALL-CAPS section label for the dark poster identity.
struct ProfileSectionHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .gatherEyebrow()
            .foregroundStyle(Color.gatherSecondaryText)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Profile Row Divider

/// A hairline divider for grouped rows on a solid surface card, inset past the
/// leading icon tile so it reads as a list separator rather than a full rule.
struct ProfileRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, Spacing.md + 36 + Spacing.md)
    }
}

// MARK: - Profile Destructive Row

/// A destructive grouped-card row (Sign Out / Delete Account / Reset) with a
/// red icon tile and red title in `rsvpNoFallback`.
struct ProfileDestructiveRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.rsvpNoFallback)
                .frame(width: 36, height: 36)
                .background(Color.gatherElevated, in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.rsvpNoFallback)

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .contentShape(Rectangle())
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(Color.gatherElevated, in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))

                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.gatherPrimaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm + 2)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Profile Menu Link (action-based, no navigation)

struct ProfileMenuLink: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(Color.gatherElevated, in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))

                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.gatherPrimaryText)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm + 2)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Settings Views (Placeholders)

struct NotificationSettingsView: View {
    @AppStorage("eventReminders") private var eventReminders = true
    @AppStorage("rsvpUpdates") private var rsvpUpdates = true
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false

    var body: some View {
        List {
            // MARK: - System Permission Section
            Section {
                permissionRow
            } header: {
                Text("System Permission")
            } footer: {
                Text(permissionFooterText)
            }

            // MARK: - Notification Preferences (only when authorized)
            if authorizationStatus == .authorized {
                Section("Event Notifications") {
                    Toggle("Event Reminders", isOn: $eventReminders)
                    Toggle("RSVP Updates", isOn: $rsvpUpdates)
                }
            }
        }
        .navigationTitle("Notifications")
        .task {
            await checkNotificationStatus()
        }
    }

    // MARK: - Permission Row

    @ViewBuilder
    private var permissionRow: some View {
        switch authorizationStatus {
        case .authorized:
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.gatherSuccess)
                    .font(.title3)
                Text("Notifications enabled")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherPrimaryText)
                Spacer()
            }

        case .denied:
            HStack(spacing: Spacing.sm) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.warmCoral)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications denied")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text("Enable in System Settings")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                Spacer()
                Button {
                    openAppSettings()
                } label: {
                    Text("Open Settings")
                        .font(GatherFont.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.accentPurpleFallback)
                        .clipShape(Capsule())
                }
            }

        case .notDetermined:
            HStack(spacing: Spacing.sm) {
                Image(systemName: "bell.badge")
                    .foregroundStyle(Color.accentPurpleFallback)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Not configured")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text("Allow Gather to send you notifications")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                Spacer()
                Button {
                    Task { await requestNotificationPermission() }
                } label: {
                    HStack(spacing: 4) {
                        if isRequesting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text("Enable")
                            .font(GatherFont.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.accentPurpleFallback)
                    .clipShape(Capsule())
                }
                .disabled(isRequesting)
            }

        case .provisional, .ephemeral:
            HStack(spacing: Spacing.sm) {
                Image(systemName: "bell.circle")
                    .foregroundStyle(Color.sunshineYellowText)
                    .font(.title3)
                Text("Provisional notifications enabled")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherPrimaryText)
                Spacer()
            }

        @unknown default:
            Text("Unknown notification status")
                .font(GatherFont.callout)
                .foregroundStyle(Color.gatherSecondaryText)
        }
    }

    // MARK: - Footer Text

    private var permissionFooterText: String {
        switch authorizationStatus {
        case .authorized:
            return "You'll receive alerts, sounds, and badges for event updates."
        case .denied:
            return "Notifications are blocked. Tap \"Open Settings\" to enable them in iOS Settings."
        case .notDetermined:
            return "Tap \"Enable\" to allow push notifications for event reminders and RSVP updates."
        default:
            return "Manage your notification preferences."
        }
    }

    // MARK: - Actions

    private func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            authorizationStatus = settings.authorizationStatus
        }
    }

    private func requestNotificationPermission() async {
        isRequesting = true
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                authorizationStatus = granted ? .authorized : .denied
                if granted {
                    HapticService.success()
                }
                isRequesting = false
            }
        } catch {
            await MainActor.run {
                isRequesting = false
            }
        }
    }

    private func openAppSettings() {
        #if !targetEnvironment(macCatalyst)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("showMeAsAttending") private var showMeAsAttending = true
    @AppStorage("defaultPrivacy") private var defaultPrivacy = "inviteOnly"
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var exportError: String?

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

            Section {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Label("Export My Data", systemImage: "square.and.arrow.up")
                        Spacer()
                        if isExporting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isExporting)
            } header: {
                Text("Your Data")
            } footer: {
                Text("Download a copy of all your data including events, RSVPs, and tickets in JSON format.")
            }

            if let error = exportError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Privacy")
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ActivitySheet(items: [url])
            }
        }
    }

    private func exportData() {
        guard let user = authManager.currentUser else { return }
        isExporting = true
        exportError = nil

        Task {
            do {
                let url = try DataExportService.shared.exportUserData(
                    userId: user.id,
                    userName: user.name,
                    userEmail: user.email,
                    modelContext: modelContext
                )
                exportURL = url
                showShareSheet = true
            } catch {
                exportError = "Failed to export data: \(error.localizedDescription)"
            }
            isExporting = false
        }
    }
}

// MARK: - Activity Sheet (Data Export)

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct CalendarSettingsView: View {
    @AppStorage("calendarSyncEnabled") private var calendarSyncEnabled = true
    @State private var calendarAuthStatus: EKAuthorizationStatus = .notDetermined
    @State private var isRequesting = false
    private let eventStore = EKEventStore()

    var body: some View {
        List {
            // MARK: - System Permission Section
            Section {
                calendarPermissionRow
            } header: {
                Text("System Permission")
            } footer: {
                Text(calendarFooterText)
            }

            // MARK: - Sync Preferences (only when authorized)
            if calendarAuthStatus == .fullAccess || calendarAuthStatus == .authorized {
                Section {
                    Toggle("Auto-sync RSVPs to Calendar", isOn: $calendarSyncEnabled)
                } footer: {
                    Text("Automatically add events you RSVP to your device calendar")
                }
            }
        }
        .navigationTitle("Calendar")
        .onAppear {
            calendarAuthStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }

    // MARK: - Calendar Permission Row

    @ViewBuilder
    private var calendarPermissionRow: some View {
        if calendarAuthStatus == .fullAccess || calendarAuthStatus == .authorized {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.gatherSuccess)
                    .font(.title3)
                Text("Calendar access enabled")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherPrimaryText)
                Spacer()
            }
        } else if calendarAuthStatus == .denied || calendarAuthStatus == .restricted {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.warmCoral)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calendar access denied")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text("Enable in System Settings")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                Spacer()
                Button {
                    openAppSettings()
                } label: {
                    Text("Open Settings")
                        .font(GatherFont.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.accentPurpleFallback)
                        .clipShape(Capsule())
                }
            }
        } else if calendarAuthStatus == .writeOnly {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(Color.sunshineYellowText)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Write-only access")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text("Full access needed for calendar sync")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                Spacer()
                Button {
                    Task { await requestCalendarAccess() }
                } label: {
                    HStack(spacing: 4) {
                        if isRequesting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text("Upgrade")
                            .font(GatherFont.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.accentPurpleFallback)
                    .clipShape(Capsule())
                }
                .disabled(isRequesting)
            }
        } else {
            // notDetermined
            HStack(spacing: Spacing.sm) {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(Color.neonBlue)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Not configured")
                        .font(GatherFont.callout)
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text("Allow Gather to access your calendar")
                        .font(.caption2)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                Spacer()
                Button {
                    Task { await requestCalendarAccess() }
                } label: {
                    HStack(spacing: 4) {
                        if isRequesting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text("Enable")
                            .font(GatherFont.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.accentPurpleFallback)
                    .clipShape(Capsule())
                }
                .disabled(isRequesting)
            }
        }
    }

    // MARK: - Footer Text

    private var calendarFooterText: String {
        if calendarAuthStatus == .fullAccess || calendarAuthStatus == .authorized {
            return "Gather can read and write events to your device calendar."
        } else if calendarAuthStatus == .denied || calendarAuthStatus == .restricted {
            return "Calendar access is blocked. Tap \"Open Settings\" to enable it in iOS Settings."
        } else if calendarAuthStatus == .writeOnly {
            return "Gather can add events but cannot read your calendar. Upgrade for full sync."
        } else {
            return "Tap \"Enable\" to allow Gather to add RSVPed events to your calendar."
        }
    }

    // MARK: - Actions

    private func requestCalendarAccess() async {
        isRequesting = true
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                calendarAuthStatus = EKEventStore.authorizationStatus(for: .event)
                if granted {
                    HapticService.success()
                }
                isRequesting = false
            }
        } catch {
            await MainActor.run {
                calendarAuthStatus = EKEventStore.authorizationStatus(for: .event)
                isRequesting = false
            }
        }
    }

    private func openAppSettings() {
        #if !targetEnvironment(macCatalyst)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("colorScheme") private var colorScheme = "dark"

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
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label.uppercased())
                .gatherEyebrow()
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
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
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(Color.gatherElevated, in: RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.gatherPrimaryText)
                    Text(subtitle)
                        .gatherMetaText()
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(Spacing.sm)
            .surfaceCard(cornerRadius: CornerRadius.lg)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Load \(title) data. \(subtitle)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(isLoading ? "Loading in progress" : "Double tap to load demo data")
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.5 : 1)
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var displayName: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient.gatherAccentGradient)
                        .frame(width: AvatarSize.xl, height: AvatarSize.xl)
                        .overlay {
                            Text(displayName.prefix(1).uppercased())
                                .font(.largeTitle)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        .modifier(GradientRing(color: Color.accentPurpleFallback, lineWidth: 3))
                }
                .padding(.top, Spacing.lg)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Display Name")
                        .font(GatherFont.headline)
                        .foregroundStyle(Color.gatherPrimaryText)

                    TextField("Your name", text: $displayName)
                        .font(GatherFont.body)
                        .foregroundStyle(Color.gatherPrimaryText)
                        .padding(Spacing.md)
                        .background(Color.gatherElevated)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .horizontalPadding()

                if let email = authManager.currentUser?.email {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Email")
                            .font(GatherFont.headline)
                            .foregroundStyle(Color.gatherPrimaryText)

                        Text(email)
                            .font(GatherFont.body)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .padding(Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gatherSurface)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }
                    .horizontalPadding()
                }

                Spacer()

                Button {
                    saveProfile()
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Save Changes")
                                .font(GatherFont.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
                }
                .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                .horizontalPadding()
                .padding(.bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gatherCanvas.ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            displayName = authManager.currentUser?.name ?? ""
        }
    }

    private func saveProfile() {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true

        Task {
            await authManager.updateDisplayName(trimmed)
            HapticService.success()
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Re-authenticate Sheet

struct ReauthenticateSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isDeleting = false

    private var isAppleUser: Bool {
        authManager.currentAuthProvider == "apple"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.gatherElevated)
                            .frame(width: 80, height: 80)
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.rsvpNoFallback)
                    }

                    Text("Confirm Your Identity")
                        .font(GatherFont.title2)
                        .foregroundStyle(Color.gatherPrimaryText)

                    Text("Deleting your account is permanent. Verify your identity to continue.")
                        .font(GatherFont.body)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.lg)

                if isAppleUser {
                    SignInWithAppleButton(.signIn) { request in
                        authManager.configureAppleRequest(request)
                    } onCompletion: { result in
                        handleAppleReauth(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(Capsule())
                    .disabled(isDeleting)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Enter your password to confirm")
                            .font(GatherFont.callout)
                            .foregroundStyle(Color.gatherSecondaryText)

                        SecureField("Your password", text: $password)
                            .font(GatherFont.body)
                            .foregroundStyle(Color.gatherPrimaryText)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(Spacing.md)
                            .background(Color.gatherElevated)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }

                    Button {
                        deleteWithEmail()
                    } label: {
                        HStack(spacing: 6) {
                            if isDeleting {
                                ProgressView().tint(.white)
                            }
                            Text("Delete My Account")
                                .font(GatherFont.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: Layout.buttonHeight)
                        .background(
                            password.isEmpty
                                ? Color.gatherElevated
                                : Color.rsvpNoFallback
                        )
                        .clipShape(Capsule())
                    }
                    .disabled(password.isEmpty || isDeleting)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.rsvpNoFallback)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .horizontalPadding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gatherCanvas.ignoresSafeArea())
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isDeleting)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isDeleting)
    }

    private func handleAppleReauth(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            errorMessage = nil
            isDeleting = true
            Task {
                let deleted = await authManager.reauthenticateAndDeleteWithApple(
                    authorization: authorization,
                    modelContext: modelContext
                )
                isDeleting = false
                if deleted {
                    dismiss()
                } else {
                    errorMessage = authManager.authError?.errorDescription
                        ?? "Couldn't delete your account. Please try again."
                }
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Apple verification failed. Please try again."
            }
        }
    }

    private func deleteWithEmail() {
        guard !password.isEmpty else { return }
        errorMessage = nil
        isDeleting = true
        Task {
            let deleted = await authManager.reauthenticateAndDeleteWithEmail(
                password: password,
                modelContext: modelContext
            )
            isDeleting = false
            if deleted {
                dismiss()
            } else {
                errorMessage = authManager.authError?.errorDescription
                    ?? "Couldn't delete your account. Please try again."
            }
        }
    }
}

// MARK: - Help Center View

struct HelpCenterView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                FAQItem(
                    question: "How do I create an event?",
                    answer: "Tap the + button on the My Events tab. Fill in your event details, choose a category, and enable the features you need like guest management, ticketing, or budget tracking."
                )
                FAQItem(
                    question: "How do RSVPs work?",
                    answer: "Guests can RSVP as Attending, Maybe, or Decline. If your event has functions (sub-events), guests RSVP to each function individually. You can track all responses on the Guests tab."
                )
                FAQItem(
                    question: "How do tickets work?",
                    answer: "Enable ticketing when creating an event to set up ticket tiers with different prices and perks. Guests can purchase tickets directly from the event page. Group discounts are applied automatically."
                )
                FAQItem(
                    question: "How do I invite guests?",
                    answer: "Go to your event's Guests tab and tap Send Invites. You can select guests individually or in bulk, then send via WhatsApp, SMS, Email, or copy the invite link."
                )
                FAQItem(
                    question: "How do I manage my budget?",
                    answer: "Enable the Budget feature on your event. Add categories and expenses, mark items as paid, and track spending against your allocated budget with visual progress bars."
                )

                Divider()
                    .padding(.vertical, Spacing.sm)

                Button {
                    if let url = URL(string: "mailto:\(AppConfig.contactEmail)") {
                        #if !targetEnvironment(macCatalyst)
                        UIApplication.shared.open(url)
                        #endif
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "envelope.fill")
                        Text("Contact Support")
                    }
                    .font(GatherFont.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(Capsule())
                }
            }
            .horizontalPadding()
            .padding(.vertical)
        }
        .navigationTitle("Help")
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(answer)
                .font(GatherFont.body)
                .foregroundStyle(Color.gatherSecondaryText)
                .padding(.top, Spacing.xs)
        } label: {
            Text(question)
                .font(GatherFont.callout)
                .fontWeight(.semibold)
                .foregroundStyle(Color.gatherPrimaryText)
        }
        .padding(Spacing.sm)
        .surfaceCard(cornerRadius: CornerRadius.md)
    }
}

// MARK: - About Gather View

struct AboutGatherView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // App icon + name
                VStack(spacing: Spacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .fill(LinearGradient.gatherAccentGradient)
                            .frame(width: 80, height: 80)
                        Text("G")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Text("Gather")
                        .font(GatherFont.title2)
                        .foregroundStyle(Color.gatherPrimaryText)

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }
                .padding(.top, Spacing.lg)

                // Info cards
                VStack(spacing: Spacing.sm) {
                    aboutRow(icon: "heart.fill", title: "Made with love", subtitle: "Built for event organizers everywhere")
                    aboutRow(icon: "shield.checkered", title: "Privacy First", subtitle: "Your data stays on your device")
                    aboutRow(icon: "sparkles", title: "Thoughtful Design", subtitle: "Calm, modern event management")
                }
                .padding()
                .surfaceCard()

                // Links
                VStack(spacing: 1) {
                    linkButton(icon: "doc.text", title: "Privacy Policy", url: AppConfig.privacyPolicyURL)
                    linkButton(icon: "doc.plaintext", title: "Terms of Service", url: AppConfig.termsOfServiceURL)
                    linkButton(icon: "questionmark.circle", title: "Support", url: AppConfig.supportURL)
                    linkButton(icon: "star.fill", title: "Rate on App Store", url: AppConfig.appStoreURL)
                }
                .surfaceCard(cornerRadius: CornerRadius.md)

                Text("\u{00A9} 2026 thebighead. All rights reserved.")
                    .font(.caption2)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .padding(.top, Spacing.lg)
            }
            .horizontalPadding()
            .padding(.vertical)
        }
        .navigationTitle("About")
    }

    private func aboutRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accentPurpleFallback)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(GatherFont.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.gatherPrimaryText)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            Spacer()
        }
    }

    private func linkButton(icon: String, title: String, url: URL) -> some View {
        Button {
            #if !targetEnvironment(macCatalyst)
            UIApplication.shared.open(url)
            #endif
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Color.accentPurpleFallback)
                    .frame(width: 30)
                Text(title)
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherPrimaryText)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(Spacing.sm)
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
        .modelContainer(for: Event.self, inMemory: true)
}
