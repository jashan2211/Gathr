import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Profile Header
                Section {
                    HStack(spacing: Spacing.md) {
                        // Avatar
                        Circle()
                            .fill(LinearGradient.gatherAccentGradient)
                            .frame(width: AvatarSize.lg, height: AvatarSize.lg)
                            .overlay {
                                Text(authManager.currentUser?.name.prefix(1).uppercased() ?? "?")
                                    .font(.title)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(authManager.currentUser?.name ?? "User")
                                .font(GatherFont.title3)

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
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }

                // Preferences
                Section("Preferences") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }

                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        Label("Privacy", systemImage: "lock")
                    }

                    NavigationLink {
                        CalendarSettingsView()
                    } label: {
                        Label("Calendar Sync", systemImage: "calendar")
                    }

                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                }

                // Support
                Section("Support") {
                    NavigationLink {
                        Text("Help Center")
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }

                    NavigationLink {
                        Text("Feedback")
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                    }

                    NavigationLink {
                        Text("About")
                    } label: {
                        Label("About Gather", systemImage: "info.circle")
                    }
                }

                // Account Actions
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }

                // Version
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }
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
                    Task {
                        await authManager.deleteAccount()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
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

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
}
