import Foundation
import SwiftData

// MARK: - Event Model

@Model
final class Event {
    @Attribute(.unique) var id: UUID
    var title: String
    var eventDescription: String?
    var startDate: Date
    var endDate: Date?
    var timezone: String
    var recurrence: RecurrenceRule?
    var location: EventLocation?
    var capacity: Int?
    var privacy: EventPrivacy
    var guestListVisibility: GuestListVisibility
    var heroMediaURL: URL?
    var password: String?
    var requiresApproval: Bool
    var createdAt: Date
    var updatedAt: Date

    // Relationships
    var host: User?

    @Relationship(deleteRule: .cascade, inverse: \Guest.event)
    var guests: [Guest] = []

    @Relationship(deleteRule: .cascade, inverse: \Comment.event)
    var comments: [Comment] = []

    @Relationship(deleteRule: .cascade, inverse: \MediaItem.event)
    var media: [MediaItem] = []

    init(
        id: UUID = UUID(),
        title: String,
        eventDescription: String? = nil,
        startDate: Date,
        endDate: Date? = nil,
        timezone: String = TimeZone.current.identifier,
        recurrence: RecurrenceRule? = nil,
        location: EventLocation? = nil,
        capacity: Int? = nil,
        privacy: EventPrivacy = .inviteOnly,
        guestListVisibility: GuestListVisibility = .visible,
        heroMediaURL: URL? = nil,
        password: String? = nil,
        requiresApproval: Bool = false,
        host: User? = nil
    ) {
        self.id = id
        self.title = title
        self.eventDescription = eventDescription
        self.startDate = startDate
        self.endDate = endDate
        self.timezone = timezone
        self.recurrence = recurrence
        self.location = location
        self.capacity = capacity
        self.privacy = privacy
        self.guestListVisibility = guestListVisibility
        self.heroMediaURL = heroMediaURL
        self.password = password
        self.requiresApproval = requiresApproval
        self.host = host
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Event Privacy

enum EventPrivacy: String, Codable, CaseIterable {
    case publicEvent = "public"
    case unlisted
    case inviteOnly

    var displayName: String {
        switch self {
        case .publicEvent: return "Public"
        case .unlisted: return "Unlisted"
        case .inviteOnly: return "Invite Only"
        }
    }

    var description: String {
        switch self {
        case .publicEvent: return "Anyone can find and join"
        case .unlisted: return "Only people with the link can join"
        case .inviteOnly: return "Only invited guests can join"
        }
    }
}

// MARK: - Guest List Visibility

enum GuestListVisibility: String, Codable, CaseIterable {
    case visible
    case countOnly
    case hidden

    var displayName: String {
        switch self {
        case .visible: return "Show guest list"
        case .countOnly: return "Show count only"
        case .hidden: return "Hide completely"
        }
    }
}

// MARK: - Recurrence Rule

struct RecurrenceRule: Codable, Equatable {
    var frequency: RecurrenceFrequency
    var interval: Int
    var daysOfWeek: [Int]?
    var endDate: Date?
    var occurrenceCount: Int?

    init(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        daysOfWeek: [Int]? = nil,
        endDate: Date? = nil,
        occurrenceCount: Int? = nil
    ) {
        self.frequency = frequency
        self.interval = interval
        self.daysOfWeek = daysOfWeek
        self.endDate = endDate
        self.occurrenceCount = occurrenceCount
    }
}

enum RecurrenceFrequency: String, Codable, CaseIterable {
    case daily
    case weekly
    case monthly
    case custom

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Event Location

struct EventLocation: Codable, Equatable {
    var name: String
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var virtualURL: URL?

    var isVirtual: Bool {
        virtualURL != nil
    }

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    init(
        name: String,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        virtualURL: URL? = nil
    ) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.virtualURL = virtualURL
    }
}

// MARK: - Event Helpers

extension Event {
    var isUpcoming: Bool {
        startDate > Date()
    }

    var isPast: Bool {
        endDate ?? startDate < Date()
    }

    var isOngoing: Bool {
        let now = Date()
        return startDate <= now && (endDate ?? startDate) >= now
    }

    var attendingCount: Int {
        guests.filter { $0.status == .attending }.count
    }

    var maybeCount: Int {
        guests.filter { $0.status == .maybe }.count
    }

    var declinedCount: Int {
        guests.filter { $0.status == .declined }.count
    }

    var pendingCount: Int {
        guests.filter { $0.status == .pending }.count
    }

    var spotsRemaining: Int? {
        guard let capacity = capacity else { return nil }
        return max(0, capacity - attendingCount)
    }

    var isFull: Bool {
        guard let remaining = spotsRemaining else { return false }
        return remaining == 0
    }
}
