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

        let calendarEvent = EKEvent(eventStore: eventStore)
        calendarEvent.title = event.title
        calendarEvent.startDate = event.startDate
        calendarEvent.endDate = event.endDate ?? event.startDate.addingTimeInterval(3600 * 2)
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

    func addFunctionToCalendar(function: EventFunction, eventTitle: String) async -> String {
        guard await requestAccess() else {
            return "Calendar access denied. Please enable in Settings."
        }

        let calendarEvent = EKEvent(eventStore: eventStore)
        calendarEvent.title = "\(eventTitle) - \(function.name)"
        calendarEvent.startDate = function.date
        calendarEvent.endDate = function.endTime ?? function.date.addingTimeInterval(3600 * 2)
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
