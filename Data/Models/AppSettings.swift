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
    /// Fetched from zweef.app `GET /club.json`; nil until the first successful
    /// connection, when the app shows "Winter" instead.
    var clubName: String?
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
}
