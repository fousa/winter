# Stappenplan

Werk per fase; laat na elke fase de app bouwen en de tests draaien.

## Fase 0 — Project
- [ ] Xcode-project "Winter" (iPadOS 26, SwiftUI, Swift 6, alleen iPad, alleen liggend). Bij voorkeur gegenereerd met XcodeGen (`project.yml`) zodat Claude Code het kan beheren.
- [ ] Mappenstructuur volgens CLAUDE.md; String Catalog met `nl-BE`.
- [ ] Testtarget met Swift Testing.

## Fase 0b — Open source
- [ ] Git-repo met README, LICENSE, .gitignore, `Config/*.xcconfig` (geen secrets).
- [ ] Controle in CI of pre-commit dat er geen tokens/sleutels in commits zitten (bv. gitleaks).

## Fase 1 — Domein en opslag
- [ ] SwiftData-modellen uit `docs/data-model.md`.
- [ ] Domeinregels als pure functies + tests (duur, decimale uren, markeringen, sluitingsuur, canCloseDay, description).
- [ ] `SessionStore`: start, stop (ook andermans timer), undo binnen 10 s, dag afsluiten, auto-stop.
- [ ] Seed met voorbeeldleden voor previews en eerste testen.

## Fase 2 — UI met fake data
- [ ] DesignSystem: `Avatar` (foto of initialen), glass-balk, statkaart, markering-capsule.
- [ ] Startscherm incl. zoeken, letterindex, "Vaak hier", balk "Nu aan het werk" (1–3 groot, 4+ compact).
- [ ] Sheets Starten en Stoppen, bevestigingen met auto-dismiss en undo, haptiek.
- [ ] Dag afsluiten.
- [ ] Synchronisatie-scherm.
- [ ] Scherm-aan-logica (`isIdleTimerDisabled`) en Guided Access-vriendelijk (geen links naar buiten de app).

## Fase 3 — zweef.app
- [ ] `ZweefAPI` protocol + `ZweefClient` (URLSession, async/await, Codable) + `FakeZweefAPI`.
- [ ] Echte JSON van accounts, material, periods en een POST-respons vastleggen als fixtures (met test-API-sleutel).
- [ ] Mapping WorkSession → POST-body (`docs/zweef-api.md`).

## Fase 4 — Sync
- [ ] `SyncEngine` actor volgens `docs/sync.md` (triggers, backoff, dedup, rejected).
- [ ] Foto-cache (download, opslaan in Application Support, opruimen).
- [ ] BGAppRefreshTask registreren.
- [ ] Tests met FakeZweefAPI (timeouts, 4xx, dubbele triggers).

## Fase 4b — Configuratie
- [ ] `KeychainStore`, `AppConfiguration` (UserDefaults), managed-config-lezer.
- [ ] Setup-assistent (docs/configuration.md), met "Verbinding testen".
- [ ] Instellingenscherm achter beheercode (lang drukken op titel), alle waarden aanpasbaar, verbinding testen vóór opslaan.
- [ ] `ProxyTransport` en `DirectTransport` achter `ZweefAPI`.
- [ ] Instelbare takenlijst (TaskDefinition) met standaardwaarden.

## Fase 5 — Proxy
- [ ] Cloudflare Worker uit `proxy/` deployen; secrets `ZWEEF_API_KEY`, `CLUB`, `DEVICE_TOKENS`.
- [ ] Documentatie voor clubs: proxy deployen en tokens aanmaken (proxy/README.md).

## Fase 6 — Afwerking
- [ ] VoiceOver-labels, Dynamic Type, contrast.
- [ ] TestFlight / Apple Business Manager-uitrol.
- [ ] Test op de club: 3 leden van verschillende leeftijden, een dag zonder internet.
