import Foundation

/// Which club name to show, and whether a fetched one may replace it.
///
/// Two sources can have an opinion since [ADR 0012](../docs/decisions/0012-club-name-may-be-typed.md):
/// what the club typed during setup, and what `GET /club.json` returns — when
/// it returns anything at all, which for at least one real club it does not.
/// The rule lives here as a pure function so the setup assistant and the sync
/// engine cannot disagree about it.
enum ClubName {
    /// Shown when nobody has typed a name and zweef.app has not given one.
    ///
    /// The app's own name, not a translation: it is a product name, and a club
    /// that sees it knows the real one is still missing.
    static let fallback = "Winter"

    /// The title for the home screen.
    ///
    /// Blank and whitespace-only names are treated as no name, so a stray
    /// space cannot leave the navigation bar empty.
    static func display(stored: String?) -> String {
        guard let name = stored?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
        else { return fallback }
        return name
    }

    /// Whether a name just fetched from zweef.app should be stored.
    ///
    /// A typed name is kept: a refresh must not rename someone's club behind
    /// their back. A fetched name is replaced freely, because zweef.app stays
    /// the source of truth whenever it actually answers.
    static func shouldAdopt(fetched: String?, isManual: Bool) -> Bool {
        guard let fetched = fetched?.trimmingCharacters(in: .whitespacesAndNewlines), !fetched.isEmpty
        else { return false }
        return !isManual
    }

    /// Cleans up a name typed by a person, or nil if they typed nothing.
    static func sanitised(typed: String) -> String? {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}
