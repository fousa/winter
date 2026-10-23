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

enum MaterialKind: String { case flying = "kist", rolling = "rollend", other = "overig" }  // zweef.app's three tabs

@Model final class Material {     // every visible item of material.json (ADR 0020)
    #Unique<Material>([\.zweefId])
    var zweefId: Int               // sent as material_id
    var name: String               // shown, and sent as project; for aircraft usually the registration
    var kindRaw: String            // MaterialKind
    var typeName: String           // material.json `type`, e.g. "Schleicher ASK 21"; "" when there is none
    var isClubOwned: Bool          // aircraft: `kist_category == "club"`; always true otherwise
    var isGlider: Bool
    var sortOrder: Int             // material.json `order`
}


enum SessionStatus: String, Codable { case running, completed }

enum SyncState: String, Codable {
    case local            // completed, never tried: waiting for "Upload"
    case ready            // an upload was tried and failed: waiting for the next "Upload"
                          // (older versions also set it when the day was closed, ADR 0018)
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
    @Attribute(originalName: "aircraftId") var materialId: Int?  // Material.zweefId, or nil when nothing was picked
    var autoStopped: Bool
    var stoppedByOther: Bool
    var comment: String?           // typed when stopping; goes into the description (ADR 0019)
    var syncState: SyncState
    var remoteId: Int?
    var lastError: String?
    var attempts: Int
    var lastAttemptAt: Date?   // the last upload someone asked for
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

@Model final class AppSettings {  // singleton
    var clubName: String?          // from GET /club.json or typed; nil → show "Winter"
    var clubNameIsManual: Bool     // typed names survive a refresh (ADR 0012)
    @Attribute(.externalStorage) var clubLogo: Data?  // PNG, at most 512 px, picked on the device
    var clubFetchedAt: Date?
    var requiresComment: Bool = false  // no stopping without a comment (ADR 0019)
    var closingHour: Int = 21
    var closingMinute: Int = 0
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
- `description(for session:) -> String`: the times and the comment (ADR 0019)
- Retention: uploaded sessions stay on the device for 90 days, then get cleaned up.
