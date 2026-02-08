import Foundation
import SwiftData

// MARK: - Party Member Model

@Model
final class PartyMember {
    var id: UUID
    var name: String
    var relationship: PartyRelationship?
    var dietaryRestrictions: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        relationship: PartyRelationship? = nil,
        dietaryRestrictions: String? = nil
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.dietaryRestrictions = dietaryRestrictions
        self.createdAt = Date()
    }
}

// MARK: - Party Relationship

enum PartyRelationship: String, Codable, CaseIterable {
    case spouse
    case partner
    case child
    case parent
    case sibling
    case friend
    case other

    var displayName: String {
        switch self {
        case .spouse: return "Spouse"
        case .partner: return "Partner"
        case .child: return "Child"
        case .parent: return "Parent"
        case .sibling: return "Sibling"
        case .friend: return "Friend"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .spouse: return "heart.fill"
        case .partner: return "heart"
        case .child: return "figure.child"
        case .parent: return "figure.stand"
        case .sibling: return "person.2"
        case .friend: return "person.fill"
        case .other: return "person"
        }
    }
}
