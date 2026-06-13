import Foundation

// MARK: - Event Category

enum EventCategory: String, Codable, CaseIterable {
    case wedding
    case party
    case office
    case conference
    case concert
    case meetup
    case sports
    case custom

    var displayName: String {
        switch self {
        case .wedding: return "Wedding"
        case .party: return "Party"
        case .office: return "Office"
        case .conference: return "Conference"
        case .concert: return "Concert"
        case .meetup: return "Meetup"
        case .sports: return "Sports"
        case .custom: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .wedding: return "heart.fill"
        case .party: return "party.popper.fill"
        case .office: return "building.2.fill"
        case .conference: return "person.3.fill"
        case .concert: return "music.mic"
        case .meetup: return "person.2.fill"
        case .sports: return "sportscourt.fill"
        case .custom: return "star.fill"
        }
    }

    var defaultFeatures: Set<EventFeature> {
        let defaults: Set<EventFeature>
        switch self {
        case .wedding:
            defaults = [.functions, .guestManagement, .budget, .seating, .activity, .photos]
        case .party:
            defaults = [.guestManagement, .budget, .activity, .photos]
        case .office:
            defaults = [.guestManagement, .budget, .schedule, .activity]
        case .conference:
            defaults = [.ticketing, .schedule, .activity]
        case .concert:
            defaults = [.ticketing, .activity]
        case .meetup:
            defaults = [.guestManagement, .activity]
        case .sports:
            defaults = [.guestManagement, .ticketing, .budget, .activity]
        case .custom:
            defaults = [.guestManagement, .activity]
        }
        // Coming-soon features are never auto-enabled.
        return defaults.filter { $0.isAvailable }
    }

    var color: String {
        switch self {
        case .wedding: return "pink"
        case .party: return "purple"
        case .office: return "blue"
        case .conference: return "orange"
        case .concert: return "red"
        case .meetup: return "green"
        case .sports: return "green"
        case .custom: return "gray"
        }
    }
}

// MARK: - Event Feature

enum EventFeature: String, Codable, CaseIterable, Hashable {
    case functions
    case guestManagement
    case ticketing
    case budget
    case seating
    case schedule
    case activity
    case photos

    var displayName: String {
        switch self {
        case .functions: return "Functions"
        case .guestManagement: return "Guest Management"
        case .ticketing: return "Ticketing"
        case .budget: return "Finance"
        case .seating: return "Seating Chart"
        case .schedule: return "Schedule"
        case .activity: return "Activity Feed"
        case .photos: return "Photo Gallery"
        }
    }

    var description: String {
        switch self {
        case .functions: return "Add sub-events like Mehendi, Sangeet, Reception"
        case .guestManagement: return "Track RSVPs and send invitations"
        case .ticketing: return "Sell tickets or manage free registrations"
        case .budget: return "Track expenses and manage vendors"
        case .seating: return "Create seating arrangements"
        case .schedule: return "Multi-day agenda and timeline"
        case .activity: return "Q&A, announcements, polls, and updates"
        case .photos: return "Shared photo gallery for your event"
        }
    }

    var icon: String {
        switch self {
        case .functions: return "calendar.badge.clock"
        case .guestManagement: return "person.2.fill"
        case .ticketing: return "ticket.fill"
        case .budget: return "chart.bar.fill"
        case .seating: return "tablecells"
        case .schedule: return "list.bullet.rectangle"
        case .activity: return "bubble.left.and.bubble.right"
        case .photos: return "photo.on.rectangle.angled"
        }
    }

    /// Coming-soon features are shown greyed out and can't be enabled yet.
    var isAvailable: Bool {
        switch self {
        case .photos, .seating, .schedule: return false
        default: return true
        }
    }
}
