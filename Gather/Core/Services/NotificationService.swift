import Foundation
import UserNotifications
import SwiftUI
import os

private let logger = Logger(subsystem: "ca.thebighead.gathr", category: "NotificationService")

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var pendingPermissionRequest = false

    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            return granted
        } catch {
            logger.error("Notification permission error: \(error.localizedDescription)")
            return false
        }
    }

    /// Request permission only if not yet determined. Call at point-of-use (RSVP, create event).
    func requestPermissionIfNeeded() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = await requestPermission()
            }
        }
    }

    // MARK: - RSVP Notifications

    func scheduleRSVPNotification(
        guestName: String,
        eventTitle: String,
        functionName: String?,
        response: RSVPResponse
    ) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()

        let responseText: String
        switch response {
        case .yes:
            responseText = "is coming"
        case .no:
            responseText = "can't make it"
        case .maybe:
            responseText = "might come"
        }

        if let functionName = functionName {
            content.title = "RSVP for \(functionName)"
            content.body = "\(guestName) \(responseText) to \(functionName) at \(eventTitle)"
        } else {
            content.title = "New RSVP"
            content.body = "\(guestName) \(responseText) to \(eventTitle)"
        }

        content.sound = .default
        content.badge = 1

        // Add category for quick actions
        content.categoryIdentifier = "RSVP_RESPONSE"

        // Send immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Event Reminders

    func scheduleEventReminder(
        event: Event,
        function: EventFunction?,
        daysBefore: Int
    ) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()

        let eventDate = function?.date ?? event.startDate
        let eventName = function?.name ?? event.title

        if daysBefore == 0 {
            content.title = "\(eventName) is today!"
            content.body = "Don't forget about \(eventName) at \(formattedTime(eventDate))"
        } else if daysBefore == 1 {
            content.title = "\(eventName) is tomorrow"
            content.body = "Get ready for \(eventName)"
        } else {
            content.title = "\(eventName) in \(daysBefore) days"
            content.body = "Coming up: \(eventName)"
        }

        content.sound = .default

        // Calculate trigger date
        var reminderDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: eventDate) ?? eventDate
        reminderDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: reminderDate) ?? reminderDate

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "event_reminder_\(event.id)_\(function?.id.uuidString ?? "main")_\(daysBefore)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to schedule reminder: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cancel Notifications

    func cancelEventReminders(for eventId: UUID) {
        Task {
            let requests = await notificationCenter.pendingNotificationRequests()
            let identifiersToRemove = requests
                .filter { $0.identifier.contains(eventId.uuidString) }
                .map { $0.identifier }

            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }

    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: - Badge Management

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    // MARK: - Helpers

    private func formattedTime(_ date: Date) -> String {
        GatherDateFormatter.timeOnly.string(from: date)
    }
}

// MARK: - Notification Categories Setup

extension NotificationService {
    func setupNotificationCategories() {
        // RSVP response category
        let viewAction = UNNotificationAction(
            identifier: "VIEW_GUEST",
            title: "View Guest",
            options: .foreground
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: .destructive
        )

        let rsvpCategory = UNNotificationCategory(
            identifier: "RSVP_RESPONSE",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // Event reminder category
        let openEventAction = UNNotificationAction(
            identifier: "OPEN_EVENT",
            title: "Open Event",
            options: .foreground
        )

        let reminderCategory = UNNotificationCategory(
            identifier: "EVENT_REMINDER",
            actions: [openEventAction, dismissAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        notificationCenter.setNotificationCategories([rsvpCategory, reminderCategory])
    }
}
