import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "ca.thebighead.gathr", category: "EventService")

// Hardcoded scheme URL — guaranteed valid, safe to force-unwrap at definition site
private let _fallbackShareURL = URL(string: "gather://event")!

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
            logger.error("Failed to fetch events: \(error.localizedDescription)")
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
            logger.error("Failed to fetch events: \(error.localizedDescription)")
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
            logger.error("Failed to fetch event: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Update Event

    func updateEvent(_ event: Event) {
        event.updatedAt = Date()
        modelContext?.safeSave()
    }

    // MARK: - Delete Event

    func deleteEvent(_ event: Event) {
        modelContext?.delete(event)
        modelContext?.safeSave()
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
        modelContext?.safeSave()

        return guest
    }

    func updateRSVP(guest: Guest, status: RSVPStatus, plusOnes: Int) {
        guest.status = status
        guest.plusOneCount = plusOnes
        guest.respondedAt = Date()
        modelContext?.safeSave()
    }

    // MARK: - Share Link Generation

    func generateShareLink(for event: Event) -> URL {
        // UUID.uuidString only contains hex chars and hyphens — always URL-safe
        URL(string: "gather://event/\(event.id.uuidString)") ?? _fallbackShareURL
    }

    func generateShareText(for event: Event) -> String {
        let dateString = GatherDateFormatter.fullEventDate.string(from: event.startDate)

        var text = "You're invited to \(event.title)!\n"
        text += "📅 \(dateString)\n"

        if let location = event.location {
            text += "📍 \(location.name)\n"
        }

        text += "\nRSVP: \(generateShareLink(for: event).absoluteString)"

        return text
    }
}
