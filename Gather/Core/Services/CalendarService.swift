import EventKit
import Foundation

@MainActor
class CalendarService {
    static let shared = CalendarService()
    private let eventStore = EKEventStore()

    private init() {}

    func addEventToCalendar(event: Event, completion: @escaping (String) -> Void) {
        requestAccess { [weak self] granted in
            guard let self, granted else {
                completion("Calendar access denied. Please enable in Settings.")
                return
            }

            let calendarEvent = EKEvent(eventStore: self.eventStore)
            calendarEvent.title = event.title
            calendarEvent.startDate = event.startDate
            calendarEvent.endDate = event.endDate ?? event.startDate.addingTimeInterval(3600 * 2)
            calendarEvent.location = event.location?.name
            if let description = event.eventDescription {
                calendarEvent.notes = description
            }
            calendarEvent.calendar = self.eventStore.defaultCalendarForNewEvents

            do {
                try self.eventStore.save(calendarEvent, span: .thisEvent)
                completion("Event added to your calendar!")
            } catch {
                completion("Could not save event: \(error.localizedDescription)")
            }
        }
    }

    func addFunctionToCalendar(function: EventFunction, eventTitle: String, completion: @escaping (String) -> Void) {
        requestAccess { [weak self] granted in
            guard let self, granted else {
                completion("Calendar access denied. Please enable in Settings.")
                return
            }

            let calendarEvent = EKEvent(eventStore: self.eventStore)
            calendarEvent.title = "\(eventTitle) - \(function.name)"
            calendarEvent.startDate = function.date
            calendarEvent.endDate = function.endTime ?? function.date.addingTimeInterval(3600 * 2)
            calendarEvent.location = function.location?.name
            if let description = function.functionDescription {
                calendarEvent.notes = description
            }
            calendarEvent.calendar = self.eventStore.defaultCalendarForNewEvents

            do {
                try self.eventStore.save(calendarEvent, span: .thisEvent)
                completion("\(function.name) added to your calendar!")
            } catch {
                completion("Could not save event: \(error.localizedDescription)")
            }
        }
    }

    private func requestAccess(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }
}
