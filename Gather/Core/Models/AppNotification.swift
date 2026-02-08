import Foundation
import SwiftData

// MARK: - Notification Type

enum NotificationType: String, Codable {
    case rsvpUpdate = "rsvp_update"
    case guestAdded = "guest_added"
    case budgetAlert = "budget_alert"
    case paymentDue = "payment_due"
    case paymentReceived = "payment_received"
    case memberInvite = "member_invite"
    case memberJoined = "member_joined"
    case eventUpdate = "event_update"
    case eventReminder = "event_reminder"
    case expenseAdded = "expense_added"

    var icon: String {
        switch self {
        case .rsvpUpdate: return "hand.raised.fill"
        case .guestAdded: return "person.badge.plus"
        case .budgetAlert: return "exclamationmark.triangle.fill"
        case .paymentDue: return "clock.fill"
        case .paymentReceived: return "checkmark.circle.fill"
        case .memberInvite: return "person.crop.circle.badge.plus"
        case .memberJoined: return "person.2.fill"
        case .eventUpdate: return "calendar.badge.exclamationmark"
        case .eventReminder: return "bell.fill"
        case .expenseAdded: return "dollarsign.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .rsvpUpdate: return "purple"
        case .guestAdded: return "blue"
        case .budgetAlert: return "red"
        case .paymentDue: return "orange"
        case .paymentReceived: return "green"
        case .memberInvite: return "purple"
        case .memberJoined: return "teal"
        case .eventUpdate: return "indigo"
        case .eventReminder: return "pink"
        case .expenseAdded: return "orange"
        }
    }
}

// MARK: - App Notification Model

@Model
final class AppNotification {
    var id: UUID
    var typeRaw: String
    var title: String
    var body: String
    var eventId: UUID?
    var eventTitle: String?
    var isRead: Bool
    var createdAt: Date
    var metadata: String?

    init(
        id: UUID = UUID(),
        type: NotificationType,
        title: String,
        body: String,
        eventId: UUID? = nil,
        eventTitle: String? = nil,
        isRead: Bool = false
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.title = title
        self.body = body
        self.eventId = eventId
        self.eventTitle = eventTitle
        self.isRead = isRead
        self.createdAt = Date()
    }

    var type: NotificationType {
        get { NotificationType(rawValue: typeRaw) ?? .eventUpdate }
        set { typeRaw = newValue.rawValue }
    }

    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        return createdAt.formatted(date: .abbreviated, time: .omitted)
    }
}
