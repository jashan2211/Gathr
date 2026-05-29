import ActivityKit
import Foundation

/// Starts, refreshes and ends the "event day" Live Activity for a multi-function
/// event. The activity shows the current/next function with a live countdown on
/// the Lock Screen and Dynamic Island.
@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private init() {}

    /// Whether the user has Live Activities enabled in Settings.
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// True if a live activity is currently running for this event.
    func isActive(for eventId: UUID) -> Bool {
        Activity<EventDayActivityAttributes>.activities
            .contains { $0.attributes.eventId == eventId.uuidString }
    }

    /// Start (or restart) a Live Activity for the event's current/next function.
    /// Returns `false` if activities are disabled or there's nothing upcoming.
    @discardableResult
    func start(for event: Event) -> Bool {
        guard areActivitiesEnabled else { return false }
        guard let slot = currentAndNext(for: event) else { return false }

        // Avoid duplicates — clear any existing activity for this event first.
        end(for: event.id)

        let current = slot.current
        let state = EventDayActivityAttributes.ContentState(
            functionName: current.name,
            functionIcon: current.iconName,
            functionStart: current.date,
            functionEnd: current.endTime,
            locationName: current.location?.shortLocation ?? current.location?.name,
            isOngoing: current.isOngoing,
            nextUpName: slot.next?.name
        )
        let attributes = EventDayActivityAttributes(
            eventTitle: event.title,
            eventId: event.id.uuidString
        )

        // Keep the activity fresh until the current function ends (or ~2h out).
        let staleDate = current.endTime ?? current.date.addingTimeInterval(2 * 60 * 60)

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: staleDate)
            )
            return true
        } catch {
            return false
        }
    }

    /// End the Live Activity (or activities) for an event immediately.
    func end(for eventId: UUID) {
        for activity in Activity<EventDayActivityAttributes>.activities
        where activity.attributes.eventId == eventId.uuidString {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    // MARK: - Helpers

    /// The function happening now (or the next upcoming one) plus the one after
    /// it. Returns `nil` when every function is already in the past.
    private func currentAndNext(for event: Event) -> (current: EventFunction, next: EventFunction?)? {
        let sorted = event.functions.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return nil }

        func pair(at index: Int) -> (EventFunction, EventFunction?) {
            (sorted[index], index + 1 < sorted.count ? sorted[index + 1] : nil)
        }

        if let ongoing = sorted.firstIndex(where: { $0.isOngoing }) {
            return pair(at: ongoing)
        }
        if let upcoming = sorted.firstIndex(where: { $0.isUpcoming }) {
            return pair(at: upcoming)
        }
        return nil
    }
}
