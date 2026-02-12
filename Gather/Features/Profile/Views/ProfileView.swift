import SwiftUI
import SwiftData
import AuthenticationServices
import UserNotifications
import EventKit

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Query private var allEvents: [Event]
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showReauthSheet = false
    @State private var isLoadingData = false
    @State private var loadedDataMessage: String?
    @State private var showEditProfile = false

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
                        // Demo mode banner
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "hammer.fill")
                                .font(.caption2)
                            Text("Demo Mode Active")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(Color.gatherBackground)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(Color.sunshineYellow)
                        .clipShape(Capsule())

                        devToolsSection
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.lg)
                                    .strokeBorder(
                                        style: StrokeStyle(lineWidth: 1, dash: [5, 3])
                                    )
                                    .foregroundStyle(Color.sunshineYellow.opacity(0.5))
                            )
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.lg)
                                    .fill(Color.sunshineYellow.opacity(0.04))
                            )
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
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
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
                showEditProfile = true
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
            .accessibilityLabel("Edit profile")
        }
        .padding(Spacing.md)
        .glassCard()
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
            HStack(spacing: Spacing.xs) {
                Image(systemName: "ticket.fill")
                    .foregroundStyle(Color.accentPurpleFallback)
                Text("My Tickets")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)
            }

            NavigationLink {
                MyTicketsView()
            } label: {
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
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Preferences")
                .font(GatherFont.headline)
                .foregroundStyle(Color.gatherPrimaryText)
                .accessibilityAddTraits(.isHeader)

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
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 1) {
                ProfileMenuItem(icon: "questionmark.circle", title: "Help", color: Color.mintGreen) {
                    HelpCenterView()
                }
                ProfileMenuItem(icon: "envelope", title: "Send Feedback", color: Color.accentPurpleFallback) {
                    Text("Feedback")
                }
                ProfileMenuItem(icon: "info.circle", title: "About Gather", color: Color.neonBlue) {
                    AboutGatherView()
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
                    .accessibilityAddTraits(.isHeader)
            }

            // Data stats
            HStack(spacing: Spacing.md) {
                DevToolStat(value: allEvents.count, label: "Events", color: Color.accentPurpleFallback)
                DevToolStat(value: profileStats.totalGuests, label: "Guests", color: Color.accentPinkFallback)
                DevToolStat(value: profileStats.publicCount, label: "Public", color: Color.mintGreen)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
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
                    .foregroundStyle(Color.sunshineYellow)
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
                    .foregroundStyle(Color.sunshineYellow)
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
                        .padding(Spacing.sm)
                        .background(Color.gatherSecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .padding(.horizontal)

                if let email = authManager.currentUser?.email {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Email")
                            .font(GatherFont.headline)
                            .foregroundStyle(Color.gatherPrimaryText)

                        Text(email)
                            .font(GatherFont.body)
                            .foregroundStyle(Color.gatherSecondaryText)
                            .padding(Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gatherSecondaryBackground.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }
                    .padding(.horizontal)
                }

                Spacer()

                Button {
                    saveProfile()
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient.gatherAccentGradient)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    } else {
                        Text("Save Changes")
                            .font(GatherFont.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient.gatherAccentGradient)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }
                }
                .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                .padding(.horizontal)
                .padding(.bottom)
            }
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

        authManager.currentUser?.name = trimmed

        HapticService.success()

        Task {
            try? await Task.sleep(for: .seconds(0.3))
            isSaving = false
            dismiss()
        }
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
                        .font(.system(.title2, design: .rounded, weight: .bold))
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
                    if let url = URL(string: "mailto:support@gatherapp.com") {
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
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient.gatherAccentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
            }
            .padding()
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
        .glassCard(cornerRadius: CornerRadius.md)
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
                    aboutRow(icon: "sparkles", title: "Glassmorphism Design", subtitle: "Modern, beautiful event management")
                }
                .padding()
                .glassCard()

                // Links
                VStack(spacing: 1) {
                    linkRow(icon: "doc.text", title: "Privacy Policy")
                    linkRow(icon: "doc.plaintext", title: "Terms of Service")
                    linkRow(icon: "star.fill", title: "Rate on App Store")
                }
                .glassCard(cornerRadius: CornerRadius.md)

                Text("\u{00A9} 2026 Gather App. All rights reserved.")
                    .font(.caption2)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .padding(.top, Spacing.lg)
            }
            .padding()
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

    private func linkRow(icon: String, title: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accentPurpleFallback)
                .frame(width: 30)
            Text(title)
                .font(GatherFont.callout)
                .foregroundStyle(Color.gatherPrimaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.gatherSecondaryText)
        }
        .padding(Spacing.sm)
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
        .modelContainer(for: Event.self, inMemory: true)
}
