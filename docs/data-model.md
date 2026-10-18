# Datamodel (SwiftData)

Elke tik wordt meteen weggeschreven (`modelContext.save()`), zodat een crash, lege batterij of herstart nooit uren kost.

```swift
@Model final class Member {
    @Attribute(.unique) var zweefId: Int
    var firstName: String
    var lastName: String
    var isActive: Bool
    var photoURL: URL?          // remote, indien beschikbaar
    var photoFileName: String?  // lokale cache in Application Support/Photos
    var lastSeenAt: Date?
    var updatedAt: Date
}

@Model final class Aircraft {     // uit material.json
    @Attribute(.unique) var zweefId: Int
    var name: String              // bv. "ASK 21"
    var registration: String?
    var isGlider: Bool
}


enum SessionStatus: String, Codable { case running, completed }

enum SyncState: String, Codable {
    case local            // afgerond, dag nog niet afgesloten
    case ready            // dag afgesloten, klaar voor upload
    case uploading
    case uploaded
    case rejected         // 4xx van zweef.app, met reden
}

@Model final class WorkSession {
    @Attribute(.unique) var id: UUID
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
    var dayClosedAt: Date?
    var uploadedAt: Date?
}

@Model final class SyncLog {      // voor het syncscherm
    var at: Date
    var kind: String              // "upload", "refresh", "error"
    var message: String
}

// Configuratie: zie docs/configuration.md
// - geheimen (apparaattoken, API-sleutel, hash van beheercode) in de Keychain via een KeychainStore
// - overige verbindingsinstellingen in UserDefaults via een AppConfiguration-type
// - managed config (MDM) heeft voorrang en is read-only

@Model final class TaskDefinition {  // instelbare takenlijst
    @Attribute(.unique) var key: String
    var label: String
    var symbolName: String
    var colorName: String
    var sortOrder: Int
    var asksForAircraft: Bool
    var isArchived: Bool
}

@Model final class AppSettings {  // singleton
    var clubName: String?          // uit GET /club.json; nil → "Winter" tonen
    var clubFetchedAt: Date?
    var closingHour: Int = 21
    var closingMinute: Int = 0
    var activePeriodId: Int?
    var lastSuccessfulUploadAt: Date?
    var lastRefreshAt: Date?
    var lastAttemptAt: Date?
}
```

## Afgeleide regels (pure functies, unit-testen)
- `duration(start:stop:) -> Minutes`
- `decimalHours(minutes:) -> Double` (2 decimalen)
- `flags(for:) -> [Flag]` → kort (< 5 min), lang (> 10 u), automatisch gestopt, gestopt door iemand anders
- `autoStopDate(for start: Date, closing: DateComponents) -> Date`: het sluitingsuur op de startdag; start ná het sluitingsuur → het sluitingsuur van de volgende dag
- `canCloseDay(runningCount:) -> Bool`
- `description(for session:, aircraft:) -> String`
- Bewaartermijn: geüploade sessies 90 dagen lokaal, daarna opruimen.
