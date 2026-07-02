import EventKit
import Foundation

@MainActor
class CalendarService {
    static let shared = CalendarService()
    private let eventStore = EKEventStore()

    private init() {}

    func addEventToCalendar(event: Event) async -> String {
        guard await requestAccess() else {
            return "Calendar access denied. Please enable in Settings."
        }

        let start = event.startDate
        let end = event.endDate ?? event.startDate.addingTimeInterval(3600 * 2)

        // Don't create a second entry if this event is already on the calendar
        // (e.g. auto-sync on RSVP followed by a manual "Add to Calendar", or a
        // repeat RSVP).
        if duplicateExists(title: event.title, start: start, end: end) {
            return "Event is already in your calendar!"
        }

        let calendarEvent = EKEvent(eventStore: eventStore)
        calendarEvent.title = event.title
        calendarEvent.startDate = start
        calendarEvent.endDate = end
        calendarEvent.location = event.location?.name
        if let description = event.eventDescription {
            calendarEvent.notes = description
        }
        calendarEvent.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(calendarEvent, span: .thisEvent)
            return "Event added to your calendar!"
        } catch {
            return "Could not save event: \(error.localizedDescription)"
        }
    }

    /// Adds the event to the calendar only if the user enabled "Auto-sync RSVPs
    /// to Calendar" in Profile. Silent and best-effort — used when a guest RSVPs
    /// attending; the explicit "Add to Calendar" button is unaffected.
    func autoSyncIfEnabled(event: Event) async {
        guard UserDefaults.standard.object(forKey: "calendarSyncEnabled") as? Bool ?? true else { return }
        _ = await addEventToCalendar(event: event)
    }

    /// Whether an event with the same title overlapping the given window is
    /// already on any calendar. Requires access to have been granted.
    private func duplicateExists(title: String, start: Date, end: Date) -> Bool {
        let predicate = eventStore.predicateForEvents(
            withStart: start.addingTimeInterval(-60),
            end: end.addingTimeInterval(60),
            calendars: nil
        )
        return eventStore.events(matching: predicate).contains { $0.title == title }
    }

    func addFunctionToCalendar(function: EventFunction, eventTitle: String) async -> String {
        guard await requestAccess() else {
            return "Calendar access denied. Please enable in Settings."
        }

        let title = "\(eventTitle) - \(function.name)"
        let start = function.date
        let end = function.endTime ?? function.date.addingTimeInterval(3600 * 2)
        if duplicateExists(title: title, start: start, end: end) {
            return "\(function.name) is already in your calendar!"
        }

        let calendarEvent = EKEvent(eventStore: eventStore)
        calendarEvent.title = title
        calendarEvent.startDate = start
        calendarEvent.endDate = end
        calendarEvent.location = function.location?.name
        if let description = function.functionDescription {
            calendarEvent.notes = description
        }
        calendarEvent.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(calendarEvent, span: .thisEvent)
            return "\(function.name) added to your calendar!"
        } catch {
            return "Could not save event: \(error.localizedDescription)"
        }
    }

    private func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }
}
