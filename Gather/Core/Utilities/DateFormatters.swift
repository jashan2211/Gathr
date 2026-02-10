import Foundation

/// Cached DateFormatters to avoid repeated allocation.
/// DateFormatter is expensive to create — reuse these static instances.
enum GatherDateFormatter {
    /// "MMM" → "JAN", "FEB"
    static let monthAbbrev: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    /// "d" → "1", "15"
    static let dayNumber: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    /// "EEE, MMM d 'at' h:mm a" → "Mon, Jan 5 at 7:00 PM"
    static let fullEventDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d 'at' h:mm a"
        return f
    }()

    /// "EEE, h:mm a" → "Mon, 7:00 PM"
    static let shortEventTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, h:mm a"
        return f
    }()

    /// "MMM d" → "Jan 5"
    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// "MMM d, yyyy" → "Jan 5, 2026"
    static let monthDayYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    /// "EEEE, MMMM d" → "Monday, January 5"
    static let fullWeekdayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    /// "h:mm a" → "7:00 PM"
    static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    /// "EEEE" → "Monday"
    static let weekdayFull: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    /// "EEE, MMM d" → "Mon, Jan 5"
    static let shortWeekdayMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    /// "MMM d, h:mm a" → "Jan 5, 7:00 PM"
    static let monthDayTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()

    /// "EEEE, MMMM d, yyyy" → "Monday, January 5, 2026"
    static let fullWeekdayDateYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f
    }()

    /// Medium date + short time (locale-aware) → "Jan 5, 2026 at 7:00 PM"
    static let mediumDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// "EEEE, MMM d 'at' h:mm a" → "Monday, Jan 5 at 7:00 PM"
    static let fullWeekdayDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return f
    }()

    /// "EEEE, MMM d, yyyy 'at' h:mm a" → "Monday, Jan 5, 2026 at 7:00 PM"
    static let fullWeekdayDateTimeYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy 'at' h:mm a"
        return f
    }()
}
