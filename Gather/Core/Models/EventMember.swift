import Foundation
import SwiftData

// MARK: - Event Role

enum EventRole: String, Codable, CaseIterable, Identifiable {
    case owner = "Owner"
    case admin = "Admin"
    case manager = "Manager"
    case viewer = "Viewer"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .owner: return "crown.fill"
        case .admin: return "shield.checkered"
        case .manager: return "person.badge.key.fill"
        case .viewer: return "eye.fill"
        }
    }

    var description: String {
        switch self {
        case .owner: return "Full control, can delete event"
        case .admin: return "Can edit event, manage guests & budget"
        case .manager: return "Can manage guests and send invites"
        case .viewer: return "Can view event details only"
        }
    }

    var permissions: Set<EventPermission> {
        switch self {
        case .owner: return Set(EventPermission.allCases)
        case .admin: return [.editEvent, .manageGuests, .manageBudget, .sendInvites, .viewDetails]
        case .manager: return [.manageGuests, .sendInvites, .viewDetails]
        case .viewer: return [.viewDetails]
        }
    }
}

enum EventPermission: String, Codable, CaseIterable {
    case editEvent
    case manageGuests
    case manageBudget
    case sendInvites
    case viewDetails
    case deleteEvent
}

// MARK: - Member Invite Status

enum MemberInviteStatus: String, Codable {
    case pending = "Pending"
    case accepted = "Accepted"
    case declined = "Declined"
}

// MARK: - Event Member Model

@Model
final class EventMember {
    var id: UUID
    var eventId: UUID
    var userId: UUID?
    var name: String
    var email: String?
    var phone: String?
    var roleRaw: String
    var inviteStatusRaw: String
    var invitedAt: Date
    var respondedAt: Date?
    var inviteCode: String?

    init(
        id: UUID = UUID(),
        eventId: UUID,
        userId: UUID? = nil,
        name: String,
        email: String? = nil,
        phone: String? = nil,
        role: EventRole = .viewer,
        inviteStatus: MemberInviteStatus = .pending
    ) {
        self.id = id
        self.eventId = eventId
        self.userId = userId
        self.name = name
        self.email = email
        self.phone = phone
        self.roleRaw = role.rawValue
        self.inviteStatusRaw = inviteStatus.rawValue
        self.invitedAt = Date()
        self.inviteCode = Self.generateInviteCode()
    }

    var role: EventRole {
        get { EventRole(rawValue: roleRaw) ?? .viewer }
        set { roleRaw = newValue.rawValue }
    }

    var inviteStatus: MemberInviteStatus {
        get { MemberInviteStatus(rawValue: inviteStatusRaw) ?? .pending }
        set { inviteStatusRaw = newValue.rawValue }
    }

    var isActive: Bool {
        inviteStatus == .accepted
    }

    private static func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
