import Foundation
import SwiftData

// MARK: - Guest Model

@Model
final class Guest {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String?
    var phone: String?
    var status: RSVPStatus
    var plusOneCount: Int
    var role: GuestRole
    var metadata: GuestMetadata?
    var invitedAt: Date
    var respondedAt: Date?

    // Store user ID for reference
    var userId: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        email: String? = nil,
        phone: String? = nil,
        status: RSVPStatus = .pending,
        plusOneCount: Int = 0,
        role: GuestRole = .guest,
        metadata: GuestMetadata? = nil,
        userId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.status = status
        self.plusOneCount = plusOneCount
        self.role = role
        self.metadata = metadata
        self.invitedAt = Date()
        self.userId = userId
    }
}

// MARK: - RSVP Status

enum RSVPStatus: String, Codable, CaseIterable {
    case pending
    case attending
    case maybe
    case declined
    case waitlisted

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .attending: return "Going"
        case .maybe: return "Maybe"
        case .declined: return "Can't Go"
        case .waitlisted: return "Waitlisted"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .attending: return "checkmark.circle.fill"
        case .maybe: return "questionmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .waitlisted: return "list.bullet"
        }
    }
}

// MARK: - Guest Role

enum GuestRole: String, Codable, CaseIterable {
    case guest
    case vip
    case cohost
    case vendor

    var displayName: String {
        switch self {
        case .guest: return "Guest"
        case .vip: return "VIP"
        case .cohost: return "Co-host"
        case .vendor: return "Vendor"
        }
    }

    var icon: String {
        switch self {
        case .guest: return "person"
        case .vip: return "star.fill"
        case .cohost: return "person.2.fill"
        case .vendor: return "bag.fill"
        }
    }
}

// MARK: - Guest Metadata

struct GuestMetadata: Codable, Equatable, Hashable {
    var mealChoice: String?
    var dietaryRestrictions: String?
    var notes: String?
    var assignedTasks: [String]?

    init(
        mealChoice: String? = nil,
        dietaryRestrictions: String? = nil,
        notes: String? = nil,
        assignedTasks: [String]? = nil
    ) {
        self.mealChoice = mealChoice
        self.dietaryRestrictions = dietaryRestrictions
        self.notes = notes
        self.assignedTasks = assignedTasks
    }
}

// MARK: - Guest Helpers

extension Guest {
    var totalHeadcount: Int {
        1 + plusOneCount
    }

    var hasResponded: Bool {
        respondedAt != nil
    }

    var displayContact: String? {
        email ?? phone
    }
}
