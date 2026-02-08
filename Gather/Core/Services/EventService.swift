import Foundation
import SwiftData

// MARK: - Event Service

@MainActor
class EventService: ObservableObject {
    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Create Event

    func createEvent(
        title: String,
        description: String?,
        startDate: Date,
        endDate: Date?,
        location: EventLocation?,
        capacity: Int?,
        privacy: EventPrivacy,
        guestListVisibility: GuestListVisibility,
        hostId: UUID?
    ) -> Event {
        let event = Event(
            title: title,
            eventDescription: description,
            startDate: startDate,
            endDate: endDate,
            location: location,
            capacity: capacity,
            privacy: privacy,
            guestListVisibility: guestListVisibility,
            hostId: hostId
        )

        modelContext?.insert(event)
        return event
    }

    // MARK: - Fetch Events

    func fetchUpcomingEvents() -> [Event] {
        guard let context = modelContext else { return [] }

        let now = Date()
        let predicate = #Predicate<Event> { event in
            event.startDate > now
        }

        let descriptor = FetchDescriptor<Event>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startDate)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch events: \(error)")
            return []
        }
    }

    func fetchPastEvents() -> [Event] {
        guard let context = modelContext else { return [] }

        let now = Date()
        let predicate = #Predicate<Event> { event in
            event.startDate <= now
        }

        let descriptor = FetchDescriptor<Event>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch events: \(error)")
            return []
        }
    }

    func fetchEvent(by id: UUID) -> Event? {
        guard let context = modelContext else { return nil }

        let predicate = #Predicate<Event> { event in
            event.id == id
        }

        let descriptor = FetchDescriptor<Event>(predicate: predicate)

        do {
            return try context.fetch(descriptor).first
        } catch {
            print("Failed to fetch event: \(error)")
            return nil
        }
    }

    // MARK: - Update Event

    func updateEvent(_ event: Event) {
        event.updatedAt = Date()
        try? modelContext?.save()
    }

    // MARK: - Delete Event

    func deleteEvent(_ event: Event) {
        modelContext?.delete(event)
        try? modelContext?.save()
    }

    // MARK: - RSVP

    func rsvp(
        to event: Event,
        name: String,
        email: String?,
        status: RSVPStatus,
        plusOnes: Int,
        userId: UUID?
    ) -> Guest {
        let guest = Guest(
            name: name,
            email: email,
            status: status,
            plusOneCount: plusOnes,
            userId: userId
        )
        guest.respondedAt = Date()

        event.guests.append(guest)
        try? modelContext?.save()

        return guest
    }

    func updateRSVP(guest: Guest, status: RSVPStatus, plusOnes: Int) {
        guest.status = status
        guest.plusOneCount = plusOnes
        guest.respondedAt = Date()
        try? modelContext?.save()
    }

    // MARK: - Share Link Generation

    func generateShareLink(for event: Event) -> URL {
        let baseURL = "gather://event/"
        // Safe: UUID string + fixed scheme always produces a valid URL
        return URL(string: "\(baseURL)\(event.id.uuidString)") ?? URL(string: "gather://")!
    }

    func generateShareText(for event: Event) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        let dateString = formatter.string(from: event.startDate)

        var text = "You're invited to \(event.title)!\n"
        text += "📅 \(dateString)\n"

        if let location = event.location {
            text += "📍 \(location.name)\n"
        }

        text += "\nRSVP: \(generateShareLink(for: event).absoluteString)"

        return text
    }
}
