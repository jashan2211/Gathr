import SwiftUI
import SwiftData

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppNotification.createdAt, order: .reverse) private var notifications: [AppNotification]

    var body: some View {
        NavigationStack {
            Group {
                if notifications.isEmpty {
                    emptyState
                } else {
                    notificationList
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !notifications.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Mark All as Read") {
                                markAllRead()
                            }
                            Button("Clear All", role: .destructive) {
                                clearAll()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "bell.slash")
                .font(.system(size: 56))
                .foregroundStyle(Color.gatherTertiaryText)

            VStack(spacing: Spacing.xs) {
                Text("No Notifications")
                    .font(GatherFont.headline)
                    .foregroundStyle(Color.gatherPrimaryText)

                Text("You're all caught up! Notifications about RSVPs, payments, and event updates will appear here.")
                    .font(GatherFont.callout)
                    .foregroundStyle(Color.gatherSecondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xl)
    }

    // MARK: - Notification List

    private var notificationList: some View {
        List {
            // Unread section
            let unread = notifications.filter { !$0.isRead }
            if !unread.isEmpty {
                Section {
                    ForEach(unread) { notification in
                        notificationRow(notification, isUnread: true)
                    }
                } header: {
                    HStack {
                        Text("New")
                        Spacer()
                        Text("\(unread.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentPurpleFallback)
                            .clipShape(Capsule())
                    }
                }
            }

            // Today
            let today = notifications.filter { $0.isRead && Calendar.current.isDateInToday($0.createdAt) }
            if !today.isEmpty {
                Section("Today") {
                    ForEach(today) { notification in
                        notificationRow(notification)
                    }
                }
            }

            // This Week
            let thisWeek = notifications.filter { n in
                n.isRead &&
                !Calendar.current.isDateInToday(n.createdAt) &&
                n.createdAt > Date().addingTimeInterval(-604800)
            }
            if !thisWeek.isEmpty {
                Section("This Week") {
                    ForEach(thisWeek) { notification in
                        notificationRow(notification)
                    }
                }
            }

            // Older
            let older = notifications.filter { n in
                n.isRead && n.createdAt <= Date().addingTimeInterval(-604800)
            }
            if !older.isEmpty {
                Section("Earlier") {
                    ForEach(older) { notification in
                        notificationRow(notification)
                    }
                }
            }
        }
    }

    // MARK: - Notification Row

    private func notificationRow(_ notification: AppNotification, isUnread: Bool = false) -> some View {
        Button {
            notification.isRead = true
        } label: {
            HStack(alignment: .top, spacing: Spacing.sm) {
                // Icon
                Image(systemName: notification.type.icon)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(iconColor(notification.type.color))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(notification.title)
                            .font(GatherFont.callout)
                            .fontWeight(isUnread ? .semibold : .regular)
                            .foregroundStyle(Color.gatherPrimaryText)

                        Spacer()

                        Text(notification.timeAgo)
                            .font(.caption2)
                            .foregroundStyle(Color.gatherTertiaryText)
                    }

                    Text(notification.body)
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                        .lineLimit(2)

                    if let eventTitle = notification.eventTitle {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                            Text(eventTitle)
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.accentPurpleFallback)
                        .padding(.top, 1)
                    }
                }

                if isUnread {
                    Circle()
                        .fill(Color.accentPurpleFallback)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .listRowBackground(isUnread ? Color.accentPurpleFallback.opacity(0.05) : nil)
    }

    // MARK: - Helpers

    private func iconColor(_ colorName: String) -> Color {
        switch colorName {
        case "purple": return .purple
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "pink": return .pink
        case "teal": return .teal
        case "indigo": return .indigo
        default: return .purple
        }
    }

    private func markAllRead() {
        for notification in notifications {
            notification.isRead = true
        }
    }

    private func clearAll() {
        for notification in notifications {
            modelContext.delete(notification)
        }
    }
}

// MARK: - Notification Bell Button

struct NotificationBellButton: View {
    @Query(filter: #Predicate<AppNotification> { !$0.isRead }) private var unreadNotifications: [AppNotification]
    @State private var showNotifications = false

    var body: some View {
        Button {
            showNotifications = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.body)
                    .foregroundStyle(Color.gatherPrimaryText)

                if !unreadNotifications.isEmpty {
                    Text("\(min(unreadNotifications.count, 99))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.rsvpNoFallback)
                        .clipShape(Capsule())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationsView()
        .modelContainer(for: AppNotification.self, inMemory: true)
}
