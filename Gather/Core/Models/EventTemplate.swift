import Foundation

// MARK: - Event Template

struct EventTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let category: EventCategory
    let description: String
    let suggestedFeatures: Set<EventFeature>
    let suggestedFunctions: [String]
    let suggestedDescription: String
    let suggestedPrivacy: EventPrivacy

    static let allTemplates: [EventTemplate] = [
        EventTemplate(
            name: "Wedding",
            icon: "heart.fill",
            category: .wedding,
            description: "A complete wedding celebration with multiple functions",
            suggestedFeatures: [.functions, .guestManagement, .budget, .seating, .activity, .photos],
            suggestedFunctions: ["Mehendi", "Sangeet", "Wedding Ceremony", "Reception & Dinner"],
            suggestedDescription: "Join us for our wedding celebration! We're so excited to share this special day with our loved ones.",
            suggestedPrivacy: .inviteOnly
        ),
        EventTemplate(
            name: "Birthday Party",
            icon: "birthday.cake.fill",
            category: .party,
            description: "A fun celebration for a special birthday",
            suggestedFeatures: [.guestManagement, .budget, .activity, .photos],
            suggestedFunctions: [],
            suggestedDescription: "Come celebrate with us! Great food, music, and vibes guaranteed.",
            suggestedPrivacy: .inviteOnly
        ),
        EventTemplate(
            name: "Conference",
            icon: "person.3.fill",
            category: .conference,
            description: "A professional conference with ticketing and schedule",
            suggestedFeatures: [.ticketing, .schedule, .activity, .guestManagement],
            suggestedFunctions: [],
            suggestedDescription: "Join industry leaders for a day of learning, networking, and inspiration.",
            suggestedPrivacy: .publicEvent
        ),
        EventTemplate(
            name: "Concert",
            icon: "music.mic",
            category: .concert,
            description: "A live music event with ticket sales",
            suggestedFeatures: [.ticketing, .activity, .photos],
            suggestedFunctions: [],
            suggestedDescription: "An unforgettable night of live music. Get your tickets before they sell out!",
            suggestedPrivacy: .publicEvent
        ),
        EventTemplate(
            name: "Meetup",
            icon: "person.2.fill",
            category: .meetup,
            description: "A casual community meetup or networking event",
            suggestedFeatures: [.guestManagement, .activity],
            suggestedFunctions: [],
            suggestedDescription: "Come meet like-minded people. All are welcome!",
            suggestedPrivacy: .publicEvent
        ),
        EventTemplate(
            name: "Dinner Party",
            icon: "fork.knife",
            category: .party,
            description: "An intimate dinner gathering",
            suggestedFeatures: [.guestManagement, .budget, .seating, .activity],
            suggestedFunctions: [],
            suggestedDescription: "Join us for an evening of great food, conversation, and company.",
            suggestedPrivacy: .inviteOnly
        )
    ]
}
