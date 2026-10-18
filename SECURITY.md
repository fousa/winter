# Beveiliging en privacy

## Wat er beschermd moet worden
- **zweef.app API-sleutel**: geeft toegang tot alle ledengegevens en financiële data van een club.
- **Apparaattokens**: geven een iPad toegang tot de proxy van de club.
- **Ledendata**: namen, foto's en gewerkte uren van clubleden.

## Hoe de app dat doet
- Geen geheimen in de code of repo. Alles wordt op het toestel ingesteld ([docs/configuration.md](docs/configuration.md)).
- Geheimen staan in de Keychain met `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (niet in back-ups, niet overdraagbaar).
- Aanbevolen opzet met een proxy: de API-sleutel komt nooit op de iPad ([ADR 0003](docs/decisions/0003-proxy-voor-api-sleutel.md)). De proxy laat alleen de nodige endpoints door.
- Het instellingenscherm zit achter een beheercode (gehasht met salt, vertraging na foute pogingen).
- Logs bevatten nooit tokens, sleutels of persoonsgegevens.
- Ledendata blijft op de iPad en in zweef.app; er is geen andere server.

## Als er iets gelekt is
| Wat | Doe meteen |
|---|---|
| API-sleutel | Trek hem in via de zweef.app-beheerpagina's, maak een nieuwe, zet die in de proxy (`wrangler secret put ZWEEF_API_KEY`) of in de app-instellingen |
| Apparaattoken | Verwijder het uit `DEVICE_TOKENS`, deploy de proxy opnieuw, zet een nieuw token in de app |
| Geheim in een commit | Intrekken zoals hierboven. Het uit de geschiedenis verwijderen is niet genoeg: beschouw het als gelekt. |

## Een kwetsbaarheid melden
Meld beveiligingsproblemen **niet** in een publiek issue. Gebruik GitHub *Private vulnerability reporting* (tab "Security" van de repository). Je krijgt binnen een week een reactie.
