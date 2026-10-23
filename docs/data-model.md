# Data model (SwiftData)

Every tap is written out immediately (`modelContext.save()`), so a crash, a flat battery or a restart never costs any hours.

```swift
@Model final class Member {
    #Unique<Member>([\.zweefId])
    var zweefId: Int
    var firstName: String
    var lastName: String
    var isActive: Bool
    var photoURL: URL?          // unused: accounts.json carries no photo (zweef-api.md)
    var photoFileName: String?  // unused, kept for the day zweef.app adds photos
    var lastSeenAt: Date?
    var updatedAt: Date
}

@Model final class Aircraft {     // from material.json
    #Unique<Aircraft>([\.zweefId])
    var zweefId: Int
    var name: String              // what the club calls it, usually the registration ("OO-ZXA")
    var registration: String?
    var isClubOwned: Bool?        // material.json `kist_category == "club"`; nil before the first fetch
    var typeName: String?         // material.json `type`, e.g. "Schleicher ASK 21"; "" when there is none, nil before the first fetch
    var isGlider: Bool
}


enum SessionStatus: String, Codable { case running, completed }

enum SyncState: String, Codable {
    case local            // completed, the day is not closed yet
    case ready            // the day is closed, ready to upload
    case uploading
    case uploaded
    case rejected         // 4xx from zweef.app, with a reason
}

@Model final class WorkSession {
    #Unique<WorkSession>([\.id])
    var id: UUID
    var memberId: Int
    var start: Date
    var stop: Date?
    var status: SessionStatus
    var taskKey: String?     // TaskDefinition.key
    var aircraftId: Int?
    var autoStopped: Bool
    var stoppedByOther: Bool
    var syncState: SyncState
    var remoteId: Int?
    var lastError: String?
    var attempts: Int
    var lastAttemptAt: Date?   // the last upload someone asked for
    var dayClosedAt: Date?
    var uploadedAt: Date?
}

@Model final class SyncLog {      // for the sync screen
    var at: Date
    var kind: String              // "upload", "refresh", "error"
    var message: String
}

// Configuration: see docs/configuration.md
// - secrets (the API key and the admin code's salted hash) in the Keychain through a SecretStore
// - the other connection settings in UserDefaults through an AppConfiguration type
// - managed configuration (MDM) takes precedence and is read-only

@Model final class TaskDefinition {  // the configurable task list
    #Unique<TaskDefinition>([\.key])
    var key: String
    var label: String             // seeded from the catalog in the setup language;
                                  // once the club edits it, it is club data and is shown as typed
    var symbolName: String
    var colorName: String
    var sortOrder: Int
    var asksForAircraft: Bool
    var isArchived: Bool
}

@Model final class AppSettings {  // singleton
    var clubName: String?          // from GET /club.json or typed; nil → show "Winter"
    var clubNameIsManual: Bool     // typed names survive a refresh (ADR 0012)
    var clubFetchedAt: Date?
    var closingHour: Int = 21
    var closingMinute: Int = 0
    var reportingLanguage: String  // "en"/"nl"/"fr": the language of the text sent to zweef.app
    var activePeriodId: Int?
    var lastSuccessfulUploadAt: Date?
    var lastRefreshAt: Date?
    var lastAttemptAt: Date?
}
```

## Derived rules (pure functions, unit-tested)
- `duration(start:stop:) -> Minutes`
- `decimalHours(minutes:) -> Double` (two decimals)
- `flags(for:) -> [Flag]` → short (< 5 min), long (> 10 h), stopped automatically, stopped by someone else
- `autoStopDate(for start: Date, closing: DateComponents) -> Date`: the closing time on the day the session started; a session that starts *after* the closing time gets the next day's closing time
- `canCloseDay(runningCount:) -> Bool`
- `description(for session:, aircraft:) -> String`
- Retention: uploaded sessions stay on the device for 90 days, then get cleaned up.
