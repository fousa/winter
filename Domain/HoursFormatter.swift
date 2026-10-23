import Foundation

/// Turns minutes into the two shapes the app needs: something a member reads,
/// and something zweef.app accepts.
///
/// Both live here rather than in a view so that the rounding is written down
/// once and tested, instead of being re-derived in every screen.
enum HoursFormatter {
    /// Minutes as decimal hours with two decimals, which is what
    /// `POST /maintenance-hours.json` expects in `hours`.
    ///
    /// Two decimals is enough to represent any whole number of minutes to
    /// within a third of a second, and it keeps 2 h 15 m as the exact 2.25
    /// rather than a long binary fraction.
    static func decimalHours(minutes: Minutes) -> Double {
        ((Double(minutes) / 60) * 100).rounded() / 100
    }

    /// Minutes as text for the UI, in the given locale ("2 h 18 min").
    ///
    /// Formatted by Foundation rather than assembled by hand, because the unit
    /// names and their order differ per language and the app ships in three
    /// (ADR 0010). Zero hours are hidden so a short session reads "18 min"
    /// instead of "0 h 18 min".
    static func durationText(minutes: Minutes, locale: Locale) -> String {
        Duration.seconds(minutes * 60).formatted(
            .units(
                allowed: [.hours, .minutes],
                width: .abbreviated,
                zeroValueUnits: .hide
            )
            .locale(locale)
        )
    }

    /// A running time as short as a tile can take it: "46m", "1h05m",
    /// "12h30m".
    ///
    /// No leading zero on the hours, and no hours at all under one: "00h46m"
    /// made every tile start with the same two characters. The minutes keep
    /// their zero once there are hours, so "1h05m" cannot be misread as
    /// "1h50m". The same in every language — "h" and "m" are what a clock in
    /// the hangar shows too.
    static func compactDuration(minutes: Minutes) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        return hours == 0 ? "\(rest)m" : "\(hours)h" + String(format: "%02dm", rest)
    }
}
