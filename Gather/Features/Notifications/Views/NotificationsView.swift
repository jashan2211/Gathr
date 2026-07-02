import SwiftUI
import SwiftData

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
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
        GatherEmptyState(
            icon: "bell",
            title: "You're all caught up",
            message: "RSVPs, payments, and event updates will land here as they happen."
        )
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
                            .font(GatherFont.headline)
                            .foregroundStyle(Color.gatherPrimaryText)
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
                    .textCase(nil)
                }
            }

            // Today
            let today = notifications.filter { $0.isRead && Calendar.current.isDateInToday($0.createdAt) }
            if !today.isEmpty {
                Section {
                    ForEach(today) { notification in
                        notificationRow(notification)
                    }
                } header: {
                    sectionHeader("Today")
                }
            }

            // This Week
            let thisWeek = notifications.filter { n in
                n.isRead &&
                !Calendar.current.isDateInToday(n.createdAt) &&
                n.createdAt > Date().addingTimeInterval(-604800)
            }
            if !thisWeek.isEmpty {
                Section {
                    ForEach(thisWeek) { notification in
                        notificationRow(notification)
                    }
                } header: {
                    sectionHeader("This Week")
                }
            }

            // Older
            let older = notifications.filter { n in
                n.isRead && n.createdAt <= Date().addingTimeInterval(-604800)
            }
            if !older.isEmpty {
                Section {
                    ForEach(older) { notification in
                        notificationRow(notification)
                    }
                } header: {
                    sectionHeader("Earlier")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.gatherBackground)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(GatherFont.headline)
            .foregroundStyle(Color.gatherPrimaryText)
            .textCase(nil)
    }

    // MARK: - Notification Row

    private func notificationRow(_ notification: AppNotification, isUnread: Bool = false) -> some View {
        Button {
            notification.isRead = true
            // Open the related event, if the notification points to one.
            if let eventId = notification.eventId {
                appState.deepLinkEventId = eventId
                dismiss()
            }
        } label: {
            HStack(alignment: .top, spacing: Spacing.sm) {
                // Icon
                Image(systemName: notification.type.icon)
                    .font(.callout)
                    .foregroundStyle(iconColor(notification.type.color))
                    .frame(width: 34, height: 34)
                    .background(Color.gatherTertiaryBackground)
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
                        .padding(.top, Spacing.xxs)
                }
            }
            .padding(Spacing.md)
            .surfaceCard()
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: Spacing.xxs, leading: Layout.horizontalPadding, bottom: Spacing.xxs, trailing: Layout.horizontalPadding))
    }

    // MARK: - Helpers

    private func iconColor(_ colorName: String) -> Color {
        switch colorName {
        case "purple": return .accentPurpleFallback
        case "blue": return .neonBlue
        case "green": return .rsvpYesFallback
        case "orange": return .rsvpMaybeFallback
        case "red": return .rsvpNoFallback
        case "pink": return .accentPinkFallback
        case "teal": return .mintGreen
        case "indigo": return .deepIndigo
        default: return .accentPurpleFallback
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
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xxs)
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
