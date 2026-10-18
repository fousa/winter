# Configuratie en installatie (open source)

De app is open source en moet door elke club met zweef.app gebruikt kunnen worden. Daarom staat er **niets club-specifieks of geheims in de code of de repo**. Alles wordt ingesteld bij de eerste start van de app (of via MDM) en bewaard op het toestel.

## Wat moet ingesteld worden
| Instelling | Waar bewaard | Verplicht | Opmerking |
|---|---|---|---|
| Verbindingsmodus | UserDefaults | ja | `proxy` (aanbevolen) of `direct` |
| Proxy-URL | UserDefaults | bij proxy | bv. `https://winter-proxy.<account>.workers.dev` |
| Apparaattoken | **Keychain** | bij proxy | lange random string, uniek per iPad |
| Clubschema (`{club}`) | UserDefaults | bij direct | uit de zweef.app-clubinstellingen |
| zweef.app API-sleutel | **Keychain** | bij direct | `X-API-KEY` |
| Clubnaam | UserDefaults (cache) | automatisch | opgehaald uit zweef.app (`GET /club.json`) bij "Verbinding testen" en bij elke refresh; niet handmatig in te vullen |
| Sluitingsuur | SwiftData `AppSettings` | ja | standaard 21:00 |
| Taken | SwiftData | ja | standaardlijst (Zweefvliegtuig, Lier, Hangar en werkplaats, Terrein, Clubhuis, Iets anders), aanpasbaar |
| `category` / `status` voor zweef.app | UserDefaults | ja | standaard `Maintenance` / `in_aanvraag` |
| Beheercode | **Keychain** (hash) | ja | 6 cijfers; beschermt alleen het instellingenscherm, niet het gebruik |

Keychain-items met `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, zodat ze niet in back-ups of naar andere toestellen gaan.

## Verbindingsmodi
- **Proxy (aanbevolen)**: de club zet de Worker uit `proxy/` op met haar eigen API-sleutel. De iPad kent alleen de proxy-URL en een apparaattoken, dat de club kan intrekken. Volgt het advies van zweef.app om de sleutel niet client-side te bewaren.
- **Direct**: voor clubs zonder technische mensen. Clubschema en API-sleutel worden in de Keychain van de iPad bewaard. Het instellingenscherm toont een duidelijke waarschuwing: de sleutel geeft toegang tot alle ledengegevens en financiële data, en een iPad in de hangar is fysiek bereikbaar.

Beide modi gebruiken dezelfde `ZweefAPI`-interface; alleen de transportlaag verschilt (`ProxyTransport` vs `DirectTransport`).

## Eerste start: setup-assistent
Verschijnt zolang de configuratie onvolledig is. Stappen:
1. **Welkom** — wat de app doet, wat je nodig hebt (proxy-URL + token, of clubschema + API-sleutel).
2. **Verbinding** — modus kiezen, velden invullen (sleutelvelden als `SecureField`, plakken toegestaan), knop "Verbinding testen" → `GET /maintenance-hours/periods.json`. Haalt bij succes de clubnaam op (`GET /club.json`) en toont "Verbonden met <clubnaam>" plus de actieve periode, duidelijke fout bij mislukking (401, verkeerde URL, geen internet). Offline overslaan mag: de app werkt, sync volgt later.
3. **Club** — toont de opgehaalde clubnaam ter bevestiging ("Is dit je club?"); daarna sluitingsuur en takenlijst (standaard ingevuld). Zonder internet bij de setup: de clubnaam verschijnt na de eerste geslaagde verbinding; tot dan toont de app "Winter".
4. **Beheercode** — 6 cijfers, twee keer invoeren.
5. **Klaar** — leden worden opgehaald (als er internet is); tip om Begeleide toegang aan te zetten.

## Instellingen achteraf
- Verborgen ingang: lang drukken (3 s) op de titel (de clubnaam) → beheercode → instellingenscherm.
- Zelfde velden als de setup, plus: "Leden nu verversen", "Token wijzigen", "Alles wissen op deze iPad" (met bevestiging; waarschuwt als er nog niet-geüploade sessies zijn).
- Beheercode vergeten → app verwijderen en opnieuw installeren (lokale data en Keychain gaan mee weg; waarschuw hiervoor in de README).

## MDM / Managed App Configuration (optioneel)
Clubs met Apple Business Manager of een MDM kunnen de setup overslaan. De app leest `UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed")`:

| Sleutel | Type |
|---|---|
| `connectionMode` | String (`proxy`/`direct`) |
| `proxyURL` | String |
| `deviceToken` | String |
| `clubSchema` | String |
| `closingTime` | String (`HH:mm`) |

Bij aanwezigheid: waarden overnemen (geheimen meteen naar de Keychain), setup-stap 2 overslaan. Managed waarden zijn read-only in het instellingenscherm.

## Generiek voor elke club
Winter bevat niets dat aan één club gebonden is:
- **Clubnaam** en **leden** (met foto's) komen uit zweef.app.
- **Toestellen** komen uit `material.json`, de **onderhoudsperiode** uit `maintenance-hours/periods.json`.
- **Takenlijst**, **sluitingsuur** en de zweef.app-waarden voor `category`/`status` zijn instelbaar, met verstandige standaardwaarden.
- Teksten en voorbeelden in de code en previews gebruiken fictieve clubs en leden.

## Repo-hygiëne
- Geen sleutels, tokens, clubschema's of echte ledendata in de repo, ook niet in previews of tests (fixtures geanonimiseerd).
- Build-instellingen via `Config/Shared.xcconfig`; persoonlijke waarden (`DEVELOPMENT_TEAM`, `BUNDLE_ID_PREFIX`) in `Config/Local.xcconfig`, dat in `.gitignore` staat. Voorbeeld: `Config/Local.xcconfig.example`.
- Proxy-secrets enkel via `wrangler secret put`.
- Elke club deployt haar eigen proxy; er is geen gedeelde centrale server.
