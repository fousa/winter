# Winter — iPad-app voor onderhoudsuren

**Winter** is generiek: bruikbaar door elke club die zweef.app gebruikt. Een gedeelde iPad in de werkplaats van de club waarop leden zonder login hun onderhoudsuren registreren met start/stop. Alles wordt lokaal bewaard en zodra er internet is gesynchroniseerd naar zweef.app (GlidingApp) als *maintenance hours*.

## Lees eerst
Volledige index: `docs/README.md`.
- `docs/architecture.md` — modules, verantwoordelijkheden, concurrency, foutafhandeling, testen
- `docs/decisions/` — ADR's: waarom de keuzes zo gemaakt zijn (wijzigen = nieuwe ADR)
- `docs/glossary.md` — Nederlandse UI-termen ↔ Engelse code-namen
- `docs/configuration.md` — open source: setup-assistent, instellingen in de app, tokens, MDM
- `docs/spec.md` — functionele specificatie en alle beslissingen
- `docs/design.md` — schermen, componenten, Liquid Glass, kleuren, teksten
- `docs/data-model.md` — SwiftData-modellen
- `docs/sync.md` — sync-engine (offline-first, retries, dedup)
- `docs/zweef-api.md` — zweef.app endpoints en veldmapping
- `PLAN.md` — stappenplan; werk het van boven naar onder af en vink af
- `mockups/*.dc.html` — bronbestanden van de mockups (referentie voor layout, maten en kleuren; ze draaien niet los, ze hebben de runtime van het design-canvas nodig)

## Vaste beslissingen (niet zonder overleg wijzigen)
- **Platform**: native iPadOS 26, SwiftUI, Swift 6 strict concurrency, SwiftData. Alleen liggende stand, iPad 11" als referentie (1194×834 pt). Geen iPhone-target.
- **Look & feel**: iOS 26 HIG. Liquid Glass alleen op de navigatie-/controllaag (toolbar, zwevende balk onderaan, sheets, knoppen). Content (ledentegels, lijsten, kaarten) blijft opaak. Systeemfont, systeemkleuren, inset grouped lijsten.
- **Geen login** voor leden. Leden kiezen hun naam; geen pincode voor gewoon gebruik. Enkel het instellingenscherm zit achter een beheercode. Controle en correcties gebeuren door het bestuur in zweef.app (registraties komen binnen met status `in_aanvraag`).
- **Volledig offline bruikbaar**. Starten, stoppen en de dag afsluiten werken zonder netwerk. Internet op de club is onstabiel; sync gebeurt automatisch wanneer er verbinding is.
- **Twee tikken** om te starten (naam → Start) en twee om te stoppen (kaart → Stop en bewaar). Taak en toestel kiezen is optioneel.
- **Geen** inspreken/dicteren, **geen** vrij tekstveld, **geen** CSV-export.
- **Dag afsluiten** kan iedereen, maar alleen als er geen lopende timers zijn. Iedereen mag een vergeten timer van een ander stoppen. Op het sluitingsuur (instelbaar, voorstel 21:00) stopt de app lopende timers automatisch en markeert ze "automatisch gestopt".
- **API-sleutel**: standaard via een proxy (`proxy/`) die elke club zelf deployt; de iPad heeft een eigen, intrekbaar apparaattoken. Een directe modus (API-sleutel in de Keychain, met waarschuwing) bestaat voor clubs zonder proxy.
- **Open source** (MIT). Niets club-specifieks of geheims in code of repo. Proxy-URL, apparaattoken (of clubschema + API-sleutel in directe modus), sluitingsuur en taken worden ingesteld in een setup-assistent bij de eerste start, en zijn later aan te passen in een instellingenscherm in de app achter een beheercode. De clubnaam, leden en toestellen komen uit zweef.app (`GET /club.json`, `accounts.json`, `material.json`). Geheimen alleen in de Keychain. Optioneel via MDM (Managed App Configuration).
- **Taal** van de UI: Nederlands (Vlaams). Code, identifiers en commits in het Engels.

## Architectuur in het kort
```
SwiftUI views ──▶ ViewModels (@Observable, @MainActor)
                    │
                    ▼
            SessionStore (SwiftData)  ◀── AutoStopService (sluitingsuur)
                    │
                    ▼
            SyncEngine (actor) ──▶ ZweefAPI ──▶ ProxyTransport ──▶ eigen proxy van de club ──▶ admin.gliding.app/club/{club}/api
                                     └▶ DirectTransport (X-API-KEY uit Keychain) ──▶ admin.gliding.app/club/{club}/api
                    ▲
            NWPathMonitor + BGAppRefreshTask + timer bij app actief
```

## Conventies
- Mappen: `App/`, `Features/<Scherm>/`, `Domain/` (modellen, regels), `Data/` (SwiftData, ZweefClient, SyncEngine), `DesignSystem/` (glass-componenten, kleuren, Avatar), `Configuration/` (setup, instellingen, Keychain, managed config).
- Domeinregels (sluitingsuur, korte sessie, duur → decimale uren) als pure functies met unit tests (Swift Testing).
- Netwerkcode testbaar via een `ZweefAPI`-protocol met een fake.
- Geen third-party dependencies tenzij echt nodig.
- Previews voor elk scherm met fake data (zelfde voorbeeldleden als de mockups).
- Documentatie: publieke types en niet-triviale functies krijgen DocC-commentaar (`///`) dat het *waarom* uitlegt. Werk `docs/` bij in dezelfde wijziging als het gedrag verandert, en voeg een regel toe aan `CHANGELOG.md`.
- Commits: Conventional Commits in het Engels (zie `CONTRIBUTING.md`).

## Open vragen (zie ook docs/spec.md)
- Geeft `GET /accounts.json` een foto-URL per lid? Niet gedocumenteerd → testen met API-sleutel.
- Welke waarden accepteert zweef.app voor `category`, `project`, `status`; wat geeft de POST terug (id?).
- Exact sluitingsuur; kan de iPad vaste wifi of een eigen 4G/5G-verbinding krijgen?

## Links
(De analyse en mockups zijn privélinks van de maker; niet nodig om bij te dragen.)
- Analyse (Claude Docs): https://claude.ai/code/artifact/25729b6f-a068-4ab4-8073-5bc762c6b3c2
- Mockups (design-canvas): https://claude.ai/artifact/XMfZ6e3Hj5xbwkNHAXixna
- zweef.app API: https://documenter.getpostman.com/view/25434528/2s8ZDX5PRi
