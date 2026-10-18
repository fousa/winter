import Foundation

/// Works out when a running session should be stopped automatically.
///
/// A forgotten timer must not run all night and turn into a 14-hour
/// registration, so at the club's closing time the app stops whatever is still
/// running (ADR 0005). The *stop time* is the closing time itself, not the
/// moment the app happens to notice, which is why this is a pure calculation
/// that does not look at the current date at all.
enum ClosingTime {
    /// The moment a session that started at `start` should be stopped
    /// automatically.
    ///
    /// Normally that is the closing time on the day the session started. A
    /// session that starts *at or after* the closing time — someone arriving at
    /// half past nine in the evening — gets the next day's closing time, so it
    /// is not stopped instantly with a duration of zero.
    ///
    /// The calendar is injected because the club's day is defined by its own
    /// time zone: computing this in UTC would stop timers an hour early or late
    /// around daylight saving.
    static func autoStopDate(
        for start: Date,
        closing: DateComponents,
        calendar: Calendar
    ) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: start)
        components.hour = closing.hour ?? 21
        components.minute = closing.minute ?? 0
        components.second = 0

        guard let sameDay = calendar.date(from: components) else { return start }
        if sameDay > start { return sameDay }

        // Adding a day through the calendar rather than 86400 seconds, so the
        // clock change nights keep landing on the closing time.
        return calendar.date(byAdding: .day, value: 1, to: sameDay) ?? sameDay
    }

    /// Whether a session that started at `start` is past its automatic stop.
    static func shouldAutoStop(
        start: Date,
        now: Date,
        closing: DateComponents,
        calendar: Calendar
    ) -> Bool {
        now >= autoStopDate(for: start, closing: closing, calendar: calendar)
    }
}
