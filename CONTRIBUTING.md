# Bijdragen

Bedankt dat je wil helpen! Deze app wordt gebouwd door en voor zweefvliegclubs. Bijdragen zijn welkom: bugs melden, documentatie verbeteren, vertalingen, code.

## Voor je begint
1. Lees de [documentatie-index](docs/README.md), vooral [CLAUDE.md](CLAUDE.md) (vaste beslissingen) en de [ADR's](docs/decisions/README.md).
2. Wil je iets groters veranderen? Open eerst een issue om het te bespreken. Een wijziging die tegen een ADR ingaat, begint met een nieuwe ADR.

## Ontwikkelomgeving
- macOS met Xcode 26 of later.
- Kopieer `Config/Local.xcconfig.example` naar `Config/Local.xcconfig` en vul `DEVELOPMENT_TEAM` en `BUNDLE_ID_PREFIX` in.
- Je hebt geen zweef.app-sleutel nodig om te ontwikkelen: previews en tests gebruiken `FakeZweefAPI`.
- Voor de proxy: Node.js en `wrangler` (zie [proxy/README.md](proxy/README.md)).

## Werkwijze
- Branch vanaf `main`: `feature/<korte-naam>`, `fix/<korte-naam>` of `docs/<korte-naam>`.
- Commits volgens [Conventional Commits](https://www.conventionalcommits.org/) in het Engels, bv. `feat(sync): retry uploads with backoff`.
- Eén logische wijziging per pull request; vul het PR-sjabloon in.
- Werk de documentatie bij in dezelfde PR als het gedrag verandert (spec, design, datamodel, sync of API).
- Voeg een regel toe aan [CHANGELOG.md](CHANGELOG.md) onder "Unreleased".

## Code
- Swift 6 met strict concurrency; volg de structuur in [docs/architecture.md](docs/architecture.md).
- Geen third-party dependencies zonder voorafgaand overleg in een issue.
- Publieke types en niet-triviale functies krijgen een DocC-commentaar (`///`) dat uitlegt *waarom*, niet alleen *wat*.
- UI-teksten in de String Catalog (`nl-BE`), nooit hardgecodeerd in views.
- Domeinregels als pure functies met tests.

## Testen
- Alle tests moeten slagen voor een PR gemerged wordt.
- Nieuwe logica in `Domain/` of `Data/` heeft tests nodig; tijd altijd injecteren.
- Fixtures met zweef.app-JSON altijd anonimiseren.

## Geheimen en privacy
- Zet **nooit** API-sleutels, tokens, clubschema's of echte ledendata in de repo, in issues of in screenshots.
- CI draait een geheimen-scan; een PR met een gevonden geheim wordt niet gemerged. Is er toch iets gelekt, lees dan [SECURITY.md](SECURITY.md).

## Vragen
Open een issue met het label `question`.
