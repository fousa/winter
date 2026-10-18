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
}
