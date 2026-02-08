import Foundation
import SwiftData

// MARK: - Event Function Model

@Model
final class EventFunction {
    var id: UUID
    var name: String
    var functionDescription: String?
    var date: Date
    var endTime: Date?
    var location: EventLocation?
    var dressCode: DressCode?
    var customDressCode: String?
    var sortOrder: Int
    var eventId: UUID
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var invites: [FunctionInvite] = []

    init(
        id: UUID = UUID(),
        name: String,
        functionDescription: String? = nil,
        date: Date = Date(),
        endTime: Date? = nil,
        location: EventLocation? = nil,
        dressCode: DressCode? = nil,
        customDressCode: String? = nil,
        sortOrder: Int = 0,
        eventId: UUID
    ) {
        self.id = id
        self.name = name
        self.functionDescription = functionDescription
        self.date = date
        self.endTime = endTime
        self.location = location
        self.dressCode = dressCode
        self.customDressCode = customDressCode
        self.sortOrder = sortOrder
        self.eventId = eventId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Dress Code

enum DressCode: String, Codable, CaseIterable {
    case casual
    case smartCasual
    case cocktail
    case formal
    case blackTie
    case traditional
    case custom

    var displayName: String {
        switch self {
        case .casual: return "Casual"
        case .smartCasual: return "Smart Casual"
        case .cocktail: return "Cocktail"
        case .formal: return "Formal"
        case .blackTie: return "Black Tie"
        case .traditional: return "Traditional"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .casual: return "tshirt"
        case .smartCasual: return "tshirt.fill"
        case .cocktail: return "wineglass"
        case .formal: return "suit.club"
        case .blackTie: return "bowtie"
        case .traditional: return "sparkles"
        case .custom: return "pencil"
        }
    }

    var description: String {
        switch self {
        case .casual: return "Comfortable, everyday attire"
        case .smartCasual: return "Neat and stylish but not formal"
        case .cocktail: return "Semi-formal evening wear"
        case .formal: return "Suits and elegant dresses"
        case .blackTie: return "Tuxedos and evening gowns"
        case .traditional: return "Cultural or traditional attire"
        case .custom: return "Custom dress code"
        }
    }
}

// MARK: - Event Function Helpers

extension EventFunction {
    var isUpcoming: Bool {
        date > Date()
    }

    var isPast: Bool {
        (endTime ?? date) < Date()
    }

    var isOngoing: Bool {
        let now = Date()
        return date <= now && (endTime ?? date) >= now
    }

    var attendingCount: Int {
        invites.filter { $0.response == .yes }.reduce(0) { $0 + $1.partySize }
    }

    var maybeCount: Int {
        invites.filter { $0.response == .maybe }.count
    }

    var declinedCount: Int {
        invites.filter { $0.response == .no }.count
    }

    var pendingCount: Int {
        invites.filter { $0.inviteStatus != .responded }.count
    }

    var sentCount: Int {
        invites.filter { $0.inviteStatus == .sent || $0.inviteStatus == .responded }.count
    }

    var notSentCount: Int {
        invites.filter { $0.inviteStatus == .notSent }.count
    }

    var displayDressCode: String? {
        if dressCode == .custom {
            return customDressCode
        }
        return dressCode?.displayName
    }

    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        if let endTime = endTime {
            let endFormatter = DateFormatter()
            endFormatter.timeStyle = .short
            return "\(formatter.string(from: date)) - \(endFormatter.string(from: endTime))"
        }
        return formatter.string(from: date)
    }
}
