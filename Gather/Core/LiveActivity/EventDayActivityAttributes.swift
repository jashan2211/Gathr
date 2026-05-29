import ActivityKit
import Foundation

/// Shared between the Gather app and the widget extension. Describes a "live
/// event day" for a multi-function event (e.g. a wedding): the lock screen and
/// Dynamic Island surface the current — or next — function with a live countdown
/// and a tap target that deep-links back into the event.
struct EventDayActivityAttributes: ActivityAttributes {
    /// The parts that change over the activity's lifetime.
    public struct ContentState: Codable, Hashable {
        /// Name of the function happening now, or coming up next.
        var functionName: String
        /// SF Symbol representing the function.
        var functionIcon: String
        /// When the function starts — drives the live countdown.
        var functionStart: Date
        /// Optional end time.
        var functionEnd: Date?
        /// Short, human-readable location label.
        var locationName: String?
        /// True when the function is happening right now.
        var isOngoing: Bool
        /// Name of the function after this one, if any.
        var nextUpName: String?
    }

    /// Title of the overall event (fixed for the activity's lifetime).
    var eventTitle: String
    /// Event id string, used to build the `gather://event/<id>` deep link.
    var eventId: String
}
