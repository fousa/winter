# Sync-engine (offline-first)

Internet op de club is onstabiel. De app werkt altijd lokaal; synchronisatie is een achtergrondproces dat het vanzelf blijft proberen.

## Triggers
- `NWPathMonitor`: pad wordt `.satisfied` → sync.
- App wordt actief (`scenePhase == .active`) → sync.
- "Dag afsluiten" → sync.
- "Nu opnieuw proberen" op het syncscherm → sync (negeert backoff).
- `BGAppRefreshTask` (best effort; iPadOS beslist zelf wanneer).
- Zolang de app voorgrond is en er iets wacht: retry met exponentiële backoff (30 s, 1 m, 2 m, 5 m, max 15 m) + jitter.

## Volgorde van één sync-run (`SyncEngine` is een `actor`, één run tegelijk)
1. **Auto-stop** toepassen (lopende timers voorbij sluitingsuur).
2. **Refresh** (max. 1× per 6 u of bij lege cache): club → clubnaam bijwerken; accounts → leden upserten; foto's downloaden (alleen gewijzigd/ontbrekend); material → toestellen; periods → actieve periode.
3. **Upload** alle sessies met `syncState == .ready` (en afgeronde `.local` ouder dan 24 u):
   - Zet `.uploading`, POST, bij succes `.uploaded` + `remoteId` + `uploadedAt`.
   - Netwerkfout/timeout/5xx → terug naar `.ready`, `attempts += 1`, `lastError`.
   - Onduidelijk of de POST aankwam (timeout na verzenden) → bij volgende run eerst dedup-check (zie zweef-api.md).
   - 4xx (validatie, lid inactief, periode gesloten) → `.rejected` met reden; geen automatische retry. Zichtbaar in "Aandacht nodig" met knop "Opnieuw".
4. `SyncLog` en `AppSettings.last*` bijwerken.

## Wat het syncscherm toont
- Verbindingsstatus (online / geen verbinding) en tijdstip laatste poging.
- Aantal wachtende sessies en totale wachtende uren.
- Laatste geslaagde upload, laatste refresh van club, leden en foto's, actieve periode.
- **Aandacht nodig**: `.rejected` sessies met reden.
- **Wacht op upload**: per dag (`.local`/`.ready`), met aantal sessies, totaal en of de dag afgesloten is.
- **Recent geüpload**: laatste dagen met `.uploaded`.
- Knop "Nu opnieuw proberen".

De statusknop op het startscherm toont het aantal wachtende sessies (oranje zonder verbinding, groen vinkje als alles geüpload is).

## Testen
- `ZweefAPI` protocol + `FakeZweefAPI` die fouten, timeouts en 4xx kan simuleren.
- Tests voor: retry/backoff, dedup na timeout, rejected-flow, auto-stop vóór upload, geen dubbele upload bij parallelle triggers.
