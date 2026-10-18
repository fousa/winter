# Architectuur

Dit document beschrijft hoe de app technisch in elkaar zit: welke modules er zijn, wie waarvoor verantwoordelijk is, hoe data stroomt, hoe concurrency en fouten worden behandeld en hoe alles getest wordt. Voor het *wat* en *waarom* zie [spec.md](spec.md) en de [ADR's](decisions/README.md).

## Doelen die de architectuur sturen
1. **Nooit uren verliezen.** Elke actie wordt meteen lokaal bewaard. Netwerk is nooit een voorwaarde om iets te registreren.
2. **Offline-first.** De lokale database is de bron van waarheid voor de iPad. zweef.app is de bestemming, niet de bron.
3. **Generiek en zonder geheimen.** Geen club-specifieke waarden of geheimen in de code; clubnaam, leden en toestellen komen uit zweef.app. Alles komt uit de configuratie op het toestel.
4. **Testbaar zonder netwerk en zonder zweef.app.** Alle externe afhankelijkheden zitten achter protocollen.
5. **Eenvoud.** Eén app-target, geen third-party dependencies, geen eigen backend behalve de dunne proxy.

## Overzicht
```
┌───────────────────────────── iPad-app ─────────────────────────────┐
│                                                                    │
│  Features (SwiftUI views + @Observable view models, @MainActor)    │
│    Home · StartSheet · StopSheet · Confirmation · CloseDay · Sync  │
│    Setup · Settings                                                │
│                │                                                   │
│                ▼                                                   │
│  Domain (pure Swift, geen UI, geen I/O)                            │
│    SessionRules · ClosingTime · Flags · HoursFormatter             │
│                │                                                   │
│                ▼                                                   │
│  Data                                                              │
│    SessionStore ──── SwiftData (Member, WorkSession, ...)          │
│    PhotoCache   ──── Application Support/Photos                    │
│    SyncEngine (actor) ── ZweefAPI ── Transport ──────────────┐     │
│    AutoStopService · ConnectivityMonitor · BackgroundTasks   │     │
│                                                              │     │
│  Configuration                                               │     │
│    AppConfiguration (UserDefaults) · KeychainStore           │     │
│    ManagedConfiguration (MDM) · AdminCodeVerifier            │     │
└──────────────────────────────────────────────────────────────┼─────┘
                                                               │ HTTPS
                     ┌─────────────────────────────────────────┴───┐
                     │ ProxyTransport            DirectTransport   │
                     ▼                                     │       │
          Proxy van de club (Cloudflare Worker)            │       │
                     │  X-API-KEY                          │       │
                     ▼                                     ▼       │
          admin.gliding.app/club/{club}/api  ◀─────────────┘       │
```

## Modules en verantwoordelijkheden

### `App/`
- `WinterApp`: entrypoint. Bouwt de `ModelContainer`, de services en injecteert ze via de SwiftUI-environment.
- Beslist welk root-scherm getoond wordt: **Setup** zolang de configuratie onvolledig is, anders **Home**.
- Registreert de `BGAppRefreshTask` en koppelt `scenePhase`-wijzigingen aan sync en auto-stop.

### `Features/`
Eén map per scherm, met daarin de view, het view model en previews.

| Feature | Verantwoordelijkheid |
|---|---|
| `Home` | Ledenlijst, zoeken, letterindex, balk "Nu aan het werk", statusknop sync, knop "Dag afsluiten", verborgen ingang naar Instellingen |
| `StartSheet` | Bevestigen dat het juiste lid start; al bezig → doorverwijzen naar stoppen |
| `StopSheet` | Lopende tijd tonen, taak/toestel kiezen, stoppen |
| `Confirmation` | Bevestiging na start/stop met "Ongedaan maken" en auto-dismiss |
| `CloseDay` | Overzicht van de dag en afsluiten |
| `Sync` | Syncstatus, wachtende/geweigerde/geüploade sessies, opnieuw proberen |
| `Setup` | Setup-assistent bij de eerste start |
| `Settings` | Instellingen achter de beheercode |

Regels voor features:
- Views bevatten geen logica buiten presentatie. Beslissingen ("mag de dag afgesloten worden?") komen uit `Domain`.
- View models zijn `@Observable` en `@MainActor`, en praten met `SessionStore` en `SyncEngine`, nooit rechtstreeks met het netwerk.
- Elk scherm heeft previews met voorbeelddata (zie [design.md](design.md)).

### `Domain/`
Pure functies en waardetypes, zonder SwiftData, SwiftUI of netwerk. Daardoor volledig unit-testbaar.
- `SessionRules`: `canCloseDay`, `isShortSession`, `isLongSession`, `flags(for:)`.
- `ClosingTime`: berekent het automatische stoptijdstip voor een sessie.
- `HoursFormatter`: duur ↔ "2 u 18 min" ↔ decimale uren (2.3).
- `RegistrationDescription`: bouwt het `description`-veld voor zweef.app, inclusief de dedup-tag.

### `Data/`
- `SessionStore` (`@MainActor`): enige plek die `WorkSession` aanmaakt of wijzigt. Methodes: `start(member:)`, `stop(session:task:aircraft:by:)`, `undo(_:)`, `closeDay(_:)`, `applyAutoStop(now:)`. Slaat na elke mutatie meteen op.
- `SyncEngine` (`actor`): zie [sync.md](sync.md). Gebruikt een eigen `ModelContext` (achtergrond) via een `ModelActor`.
- `ZweefAPI` (protocol) met `ZweefClient` (echt) en `FakeZweefAPI` (tests, previews).
- `Transport` (protocol) met `ProxyTransport` en `DirectTransport`: zet de juiste base-URL en headers. `ZweefClient` weet niet welke modus actief is.
- `PhotoCache`: downloadt en bewaart profielfoto's, geeft lokale URL's terug.
- `AutoStopService`: roept `SessionStore.applyAutoStop` aan bij app-start, bij actief worden, elke minuut in de voorgrond en in de achtergrondtaak.
- `ConnectivityMonitor`: wrapper rond `NWPathMonitor` die een `AsyncStream<Bool>` aanbiedt.

### `Configuration/`
- `AppConfiguration`: getypeerde toegang tot niet-geheime instellingen (UserDefaults).
- `KeychainStore`: lezen/schrijven van geheimen (apparaattoken, API-sleutel, hash van de beheercode).
- `ManagedConfiguration`: leest MDM-waarden; die hebben voorrang en zijn read-only.
- `AdminCodeVerifier`: controleert de beheercode (hash + salt, vertraging na foute pogingen).
- Zie [configuration.md](configuration.md) voor alle sleutels.

### `DesignSystem/`
Herbruikbare componenten met de Liquid Glass-stijl: `MemberAvatar`, `GlassBar`, `StatCard`, `FlagBadge`, `PrimaryActionButton`. Zie [design.md](design.md).

## Belangrijke flows

### Start
```
Home (tik op lid) → StartSheet → SessionStore.start(member)
   → WorkSession(status: .running) opgeslagen
   → Confirmation (Ongedaan maken 10 s) → Home
```

### Stop
```
Home (tik op kaart in balk) → StopSheet → SessionStore.stop(session, task, aircraft, by: .self/.other)
   → status .completed, syncState .local
   → Confirmation (Ongedaan maken 10 s) → Home
```

### Dag afsluiten en sync
```
Home → CloseDay (enkel als SessionRules.canCloseDay) → SessionStore.closeDay
   → syncState .ready voor alle afgeronde sessies van die dag(en)
   → SyncEngine.requestSync(reason: .dayClosed)
   → (online) POST per sessie → .uploaded   |   (offline) blijft .ready, retry later
```

## Concurrency
- Swift 6 strict concurrency staat aan; geen `@unchecked Sendable` zonder commentaar waarom.
- UI en `SessionStore` draaien op de `MainActor`. Mutaties zijn klein en snel.
- `SyncEngine` is een `actor` met een eigen `ModelContext`; hij laadt sessies op id, nooit modelobjecten over actor-grenzen heen.
- Eén sync-run tegelijk: nieuwe triggers tijdens een run worden samengevoegd tot één vervolg-run.
- Timers (lopende duur in de UI) gebruiken `TimelineView(.periodic(from:by: 1))`, niet een eigen `Timer`.

## Foutafhandeling
| Soort fout | Gedrag |
|---|---|
| Opslaan in SwiftData mislukt | Assertie in debug; in release een duidelijke melding en de actie niet als gelukt tonen. Mag in de praktijk niet voorkomen. |
| Geen netwerk | Geen melding; status zichtbaar via de statusknop en het syncscherm |
| 401/403 van proxy of zweef.app | Sync stopt, syncscherm toont "Verbinding geweigerd: controleer het token in Instellingen" |
| 4xx op een registratie | Sessie wordt `.rejected` met de reden, geen automatische retry |
| 5xx of timeout | Retry met backoff |
| Configuratie onvolledig | App toont de setup-assistent |

Fouten worden gelogd met `os.Logger` (subsystem = bundle id, categorieën `sync`, `store`, `config`). Nooit tokens, sleutels of persoonsgegevens loggen; gebruik `privacy: .private` voor namen.

## Testen
| Laag | Hoe |
|---|---|
| Domain | Swift Testing, pure functies, parametrized tests voor randgevallen (middernacht, sluitingsuur, zomertijd) |
| SessionStore | In-memory `ModelContainer` |
| SyncEngine | `FakeZweefAPI` die succes, timeouts, 4xx en 5xx simuleert; gecontroleerde klok |
| ZweefClient | `URLProtocol`-stub met JSON-fixtures (geanonimiseerd) |
| UI | Previews voor elk scherm; enkele UI-tests voor start → stop → afsluiten |

Tijd is altijd injecteerbaar (`Clock`/`now: () -> Date`), zodat sluitingsuur en undo-vensters testbaar zijn.

## Wat bewust niet gebruikt wordt
- Geen eigen backend of database buiten de proxy.
- Geen CloudKit-sync tussen iPads (één iPad per club is het uitgangspunt).
- Geen third-party networking- of DI-libraries.
