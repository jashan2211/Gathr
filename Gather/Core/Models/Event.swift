import Foundation
import SwiftData

// MARK: - Event Model

@Model
final class Event {
    var id: UUID
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

    // Event type and features
    var category: EventCategory
    var enabledFeaturesRaw: [String]  // Store as strings for SwiftData compatibility

    // Draft status
    var isDraft: Bool = false

    // Store host ID for reference
    var hostId: UUID?

    @Relationship(deleteRule: .cascade)
    var guests: [Guest] = []

    @Relationship(deleteRule: .cascade)
    var functions: [EventFunction] = []

    @Relationship(deleteRule: .cascade)
    var ticketTiers: [TicketTier] = []

    @Relationship(deleteRule: .cascade)
    var promoCodes: [PromoCode] = []

    // Computed property to get/set features as Set<EventFeature>
    var enabledFeatures: Set<EventFeature> {
        get {
            Set(enabledFeaturesRaw.compactMap { EventFeature(rawValue: $0) })
        }
        set {
            enabledFeaturesRaw = newValue.map { $0.rawValue }
        }
    }

    // Feature convenience checks
    var hasFunctions: Bool { enabledFeatures.contains(.functions) }
    var hasGuestManagement: Bool { enabledFeatures.contains(.guestManagement) }
    var hasTicketing: Bool { enabledFeatures.contains(.ticketing) }
    var hasBudget: Bool { enabledFeatures.contains(.budget) }
    var hasSeating: Bool { enabledFeatures.contains(.seating) }
    var hasSchedule: Bool { enabledFeatures.contains(.schedule) }
    var hasActivity: Bool { enabledFeatures.contains(.activity) }
    var hasPhotos: Bool { enabledFeatures.contains(.photos) }

    init(
        id: UUID = UUID(),
        title: String,
        eventDescription: String? = nil,
        startDate: Date = Date(),
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
        category: EventCategory = .custom,
        enabledFeatures: Set<EventFeature>? = nil,
        hostId: UUID? = nil,
        isDraft: Bool = false
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
        self.category = category
        // Use provided features or default to category's default features
        self.enabledFeaturesRaw = (enabledFeatures ?? category.defaultFeatures).map { $0.rawValue }
        self.hostId = hostId
        self.isDraft = isDraft
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
    case firstNamesOnly
    case countOnly
    case hidden

    var displayName: String {
        switch self {
        case .visible: return "Show guest list"
        case .firstNamesOnly: return "First names only"
        case .countOnly: return "Show count only"
        case .hidden: return "Hide completely"
        }
    }

    var description: String {
        switch self {
        case .visible: return "Full names, status, and contact info (host only)"
        case .firstNamesOnly: return "First names and avatars visible to attendees"
        case .countOnly: return "Only total count visible"
        case .hidden: return "Guest list not visible"
        }
    }
}

// MARK: - Recurrence Rule

struct RecurrenceRule: Codable, Equatable, Hashable {
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

struct EventLocation: Codable, Equatable, Hashable {
    var name: String
    var address: String?
    var city: String?
    var state: String?
    var country: String?
    var latitude: Double?
    var longitude: Double?
    var virtualURL: URL?

    var isVirtual: Bool {
        virtualURL != nil
    }

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    /// Short display like "Los Angeles, CA"
    var shortLocation: String? {
        if let city = city, let state = state {
            return "\(city), \(state)"
        } else if let city = city {
            return city
        } else if let state = state {
            return state
        }
        return nil
    }

    init(
        name: String,
        address: String? = nil,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        virtualURL: URL? = nil
    ) {
        self.name = name
        self.address = address
        self.city = city
        self.state = state
        self.country = country
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
        (endDate ?? startDate) < Date()
    }

    var isOngoing: Bool {
        let now = Date()
        return startDate <= now && (endDate ?? startDate) >= now
    }

    var attendingCount: Int {
        guests.filter { $0.status == RSVPStatus.attending }.count
    }

    var totalAttendingHeadcount: Int {
        guests.filter { $0.status == RSVPStatus.attending }
            .reduce(0) { $0 + $1.totalHeadcount }
    }

    var maybeCount: Int {
        guests.filter { $0.status == RSVPStatus.maybe }.count
    }

    var declinedCount: Int {
        guests.filter { $0.status == RSVPStatus.declined }.count
    }

    var pendingCount: Int {
        guests.filter { $0.status == RSVPStatus.pending }.count
    }

    var spotsRemaining: Int? {
        guard let capacity = capacity else { return nil }
        return max(0, capacity - attendingCount)
    }

    var isFull: Bool {
        guard let remaining = spotsRemaining else { return false }
        return remaining == 0
    }

    // Note: Activity posts and host are fetched via @Query in views
    // e.g. @Query var allPosts: [ActivityPost] filtered by eventId
}
