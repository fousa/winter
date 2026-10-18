import Foundation
import SwiftData

/// The club's own settings, as a single stored row.
///
/// These live in SwiftData rather than UserDefaults because they belong to the
/// club's data (and are shown in the app), while connection details and secrets
/// belong to the device and live in UserDefaults and the Keychain
/// (`docs/configuration.md`).
@Model
final class AppSettings {
    /// Fetched from zweef.app `GET /club.json`, or typed during setup; nil
    /// until one of the two happens, when the app shows "Winter" instead.
    var clubName: String?
    /// Set when a person typed the name rather than zweef.app supplying it.
    ///
    /// A typed name is never overwritten by a later refresh: `club.json`
    /// answers 500 for a real club, so someone had to type it, and a recovery
    /// of that endpoint should not rename their club behind their back
    /// (ADR 0012).
    var clubNameIsManual: Bool
    var clubFetchedAt: Date?
    var closingHour: Int
    var closingMinute: Int
    /// The language of the text uploaded to zweef.app, so the board reads one
    /// consistent list instead of whatever language each member's device is in
    /// (ADR 0010).
    var reportingLanguageCode: String
    var activePeriodId: Int?
    var lastSuccessfulUploadAt: Date?
    var lastRefreshAt: Date?
    var lastAttemptAt: Date?

    init(
        clubName: String? = nil,
        clubNameIsManual: Bool = false,
        clubFetchedAt: Date? = nil,
        closingHour: Int = 21,
        closingMinute: Int = 0,
        reportingLanguageCode: String = "en",
        activePeriodId: Int? = nil,
        lastSuccessfulUploadAt: Date? = nil,
        lastRefreshAt: Date? = nil,
        lastAttemptAt: Date? = nil
    ) {
        self.clubName = clubName
        self.clubNameIsManual = clubNameIsManual
        self.clubFetchedAt = clubFetchedAt
        self.closingHour = closingHour
        self.closingMinute = closingMinute
        self.reportingLanguageCode = reportingLanguageCode
        self.activePeriodId = activePeriodId
        self.lastSuccessfulUploadAt = lastSuccessfulUploadAt
        self.lastRefreshAt = lastRefreshAt
        self.lastAttemptAt = lastAttemptAt
    }

    /// The closing time as calendar components, for ``ClosingTime``.
    var closingComponents: DateComponents {
        DateComponents(hour: closingHour, minute: closingMinute)
    }

    /// The club name to show, falling back to the app's own name.
    var displayName: String {
        ClubName.display(stored: clubName)
    }

    /// Stores a name typed by a person, and remembers that they typed it.
    func setClubName(typed: String) {
        clubName = ClubName.sanitised(typed: typed)
        clubNameIsManual = clubName != nil
    }

    /// Stores a name fetched from zweef.app, unless someone typed one.
    func applyFetchedClubName(_ fetched: String?, at date: Date = .now) {
        clubFetchedAt = date
        guard ClubName.shouldAdopt(fetched: fetched, isManual: clubNameIsManual) else { return }
        clubName = fetched?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
