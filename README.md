# Winter

**Winter** is een open-source iPad-app voor elke zweefvliegclub die [zweef.app / GlidingApp](https://zweef.app) gebruiken. Leden registreren hun onderhoudsuren op een gedeelde iPad in de werkplaats met start/stop, zonder login. De app werkt volledig offline en synchroniseert de uren naar zweef.app (maintenance hours) zodra er internet is.

## Functies
- Start en stop in twee tikken, met foto's van de leden
- Volledig offline; automatische sync bij verbinding, met een syncstatus-scherm
- Iedereen kan de dag afsluiten zodra er geen timers meer lopen; vergeten timers stoppen automatisch op het sluitingsuur
- Registraties komen in zweef.app binnen als "in aanvraag", zodat het bestuur ze goedkeurt
- iPadOS 26-design met Liquid Glass

## Vereisten
- iPad met iPadOS 26 of later
- Een zweef.app-account met beheerrechten om een API-sleutel aan te maken
- Aanbevolen: een Cloudflare-account (gratis) voor de proxy

## Installatie voor je club
De volledige stap-voor-stapgids staat in [docs/installatiegids.md](docs/installatiegids.md). In het kort:

1. **Proxy opzetten** (aanbevolen): zie [`proxy/README.md`](proxy/README.md). Je krijgt een proxy-URL en maakt een apparaattoken per iPad.
2. **App installeren** op de iPad (TestFlight, Apple Business Manager of zelf bouwen, zie hieronder).
3. **Eerste start**: de setup-assistent vraagt de proxy-URL en het apparaattoken (of, zonder proxy, het clubschema en de API-sleutel), het sluitingsuur en een beheercode. De naam van je club haalt de app zelf op uit zweef.app.
4. **Begeleide toegang** aanzetten op de iPad (Instellingen › Toegankelijkheid › Begeleide toegang).

Alle instellingen staan in [`docs/configuration.md`](docs/configuration.md), inclusief MDM-configuratie.

## Zelf bouwen
1. Kopieer `Config/Local.xcconfig.example` naar `Config/Local.xcconfig` en vul je `DEVELOPMENT_TEAM` en `BUNDLE_ID_PREFIX` in.
2. Open het project in Xcode 26 en bouw voor je iPad.

## Documentatie
Alles staat in [`docs/`](docs/README.md): installatiegids voor clubs, configuratie, functionele specificatie, architectuur, datamodel, synchronisatie, zweef.app API, design en de [ontwerpbeslissingen](docs/decisions/README.md).

## Bijdragen
Issues en pull requests zijn welkom. Lees eerst [CONTRIBUTING.md](CONTRIBUTING.md). Beveiligingsproblemen meld je volgens [SECURITY.md](SECURITY.md). Zet nooit sleutels, tokens of echte ledendata in de repo.

## Status
In ontwerp: documentatie, mockups en proxy zijn klaar; de app zelf wordt gebouwd volgens [PLAN.md](PLAN.md).

## English summary
**Winter** is an open-source iPad app (iPadOS 26, SwiftUI) for any gliding club using zweef.app/GlidingApp. Nothing in it is specific to one club: the club's name and members come from zweef.app. Members log maintenance hours on a shared workshop iPad with start/stop, no login. Works fully offline and syncs to zweef.app's maintenance-hours API when a connection is available. The club's API key stays in a small self-hosted Cloudflare Worker proxy; everything club-specific is configured on the device. Documentation is in Dutch; code and commits are in English.

## Licentie
[MIT](LICENSE)
