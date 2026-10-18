# Functionele specificatie

## Doel
Leden registreren hun onderhoudsuren op een gedeelde iPad in de hangar/werkplaats, zonder login, met zo weinig mogelijk tikken. De uren komen in zweef.app terecht als maintenance-hours-registraties, waar het bestuur ze goedkeurt.

## Rollen
| Rol | Wat | Waar |
|---|---|---|
| Lid | Start/stopt eigen sessie, kiest optioneel taak en toestel, sluit de dag af als laatste | iPad |
| Bestuur / onderhoudsverantwoordelijke | Keurt registraties goed, corrigeert | zweef.app |

## Omgeving
- Eén iPad, liggend, vast aan de muur of op een standaard, in Begeleide toegang (Guided Access).
- Scherm blijft aan tijdens gebruik (`isIdleTimerDisabled = true` zolang er een timer loopt of de app recent gebruikt is); dimmen mag na 2 minuten inactiviteit.
- Internet is onstabiel of afwezig. De app moet volledig offline werken.

## Schermen (zie docs/design.md voor details)
0. **Setup-assistent** (eerste start) en **Instellingen** (verborgen, achter beheercode) — zie docs/configuration.md.
1. **Startscherm** — ledenlijst (vaak hier + alle leden, zoeken, letterindex), statusknop sync, knop "Dag afsluiten", zwevende balk "Nu aan het werk".
2. **Starten** (sheet) — foto + naam, "Start", "Dat ben ik niet".
3. **Bevestiging start** — glazen kaart, "Ongedaan maken" (10 s), sluit vanzelf na 3 s.
4. **Stoppen** (sheet) — persoon + lopende timer links, taaklijst + toestelkeuze rechts, "Stop en bewaar".
5. **Bevestiging stop** — duur, taak/toestel, "Ongedaan maken", sluit vanzelf na 3 s.
6. **Dag afsluiten** — overzicht van de dag, gemarkeerde sessies, "Dag afsluiten".
7. **Synchronisatie** — verbinding, wachtende/geweigerde/geüploade sessies, "Nu opnieuw proberen".

## Flows

### Starten
1. Lid tikt op zijn tegel (startscherm).
2. Sheet "Starten" → tik "Start".
3. Sessie wordt meteen opgeslagen (`status = .running`, `start = now`).
4. Bevestiging met "Ongedaan maken" gedurende 10 s (verwijdert de sessie volledig).
- Lid heeft al een lopende sessie → sheet toont in plaats daarvan "Je bent al bezig sinds 09:12" met knop "Stoppen" (leidt naar Stoppen).

### Stoppen
1. Iemand tikt op een kaart in "Nu aan het werk" (eigen of andermans timer).
2. Sheet "Stoppen" toont persoon, starttijd, lopende duur.
3. Optioneel: taak kiezen uit de takenlijst van de club (standaard: Zweefvliegtuig, Lier, Hangar en werkplaats, Terrein, Clubhuis, Iets anders; instelbaar). Bij taken met `asksForAircraft` verschijnt de toestelkeuze (uit `material.json`, + "Ander").
4. "Stop en bewaar" → `stop = now`, `status = .completed`, `syncState = .pending`.
5. Bevestiging met "Ongedaan maken" (10 s, zet sessie terug op running).
- Stoppen van andermans timer: toegestaan. De sessie krijgt `stoppedByOther = true` en de markering "gestopt door iemand anders" (in scherm 6 en in `description`, zie zweef-api.md).

### Dag afsluiten
- Knop altijd zichtbaar rechtsboven op het startscherm.
- Lopen er timers → knop disabled (glas, grijs, slotje).
- Geen lopende timers → knop actief, opent scherm 6.
- Scherm 6 toont per sessie: lid, tijden, taak/toestel, duur, markeringen. Ook sessies van eerdere niet-afgesloten dagen ("Ook mee").
- "Dag afsluiten" zet alle afgeronde sessies van die dag(en) op `readyForUpload` en triggert een sync. Werkt offline.
- **Als niemand afsluit**: sessies blijven bewaard. Bij de volgende afsluiting gaan alle openstaande dagen mee. Op het startscherm verschijnt een herinnering "3 dagen niet afgesloten" (badge op de statusknop).

> Keuze voor de implementatie: synchroniseer alleen sessies die `readyForUpload` zijn (na afsluiten), plus — als vangnet — afgeronde sessies ouder dan 24 u die nooit afgesloten werden. Dit houdt de upload "per dag" zoals gevraagd, zonder dat uren blijven hangen.

### Automatisch stoppen
- Instelbaar sluitingsuur (standaard 21:00, lokale tijd).
- Lopende timers worden gestopt met `stop = sluitingsuur` (niet `now`), `autoStopped = true`.
- Wordt uitgevoerd: bij app actief, bij BG-refresh, en via een timer als de app voorgrond is. Ook bij app-start voor timers van vorige dagen.

### Validatie en markeringen
| Regel | Gevolg |
|---|---|
| Duur < 5 min | Bevestigingsvraag bij stoppen ("Klopt 4 minuten?"); markering "korte sessie" |
| Duur > 10 u | Markering "lange sessie" |
| Automatisch gestopt | Markering "automatisch gestopt" |
| Overlappende sessies zelfde lid | Kan niet: een lid kan maar één lopende sessie hebben |

Markeringen gaan mee in `description` naar zweef.app en worden oranje getoond in scherm 6.

### Clubgegevens
- De clubnaam komt uit zweef.app (`GET /club.json`): opgehaald bij "Verbinding testen" in de setup en bij elke refresh. Lokaal gecachet zodat hij offline zichtbaar blijft.
- De app is generiek: geen clubnaam, leden, toestellen of taken in de code.

### Ledenlijst en foto's
- Bij elke succesvolle sync: `GET /accounts.json` → leden upserten (actief/inactief), foto's downloaden en lokaal cachen (bestand op schijf, pad in model).
- Geen foto → initialen in gekleurde cirkel (kleur deterministisch op basis van id).
- "Vaak hier": top 5 leden op aantal sessies in de laatste 30 dagen, anders laatst gezien.
- Zoeken op voornaam en familienaam, diacritics-insensitive.

## Configuratie (open source)
- Bij de eerste start: setup-assistent (verbinding, club, beheercode). Zonder volledige configuratie is de rest van de app niet bereikbaar.
- Achteraf aanpasbaar in de app: lang drukken op de titel → beheercode → Instellingen. Daar kan je proxy-URL, apparaattoken, verbindingsmodus, sluitingsuur, taken en de beheercode wijzigen, de verbinding testen en leden verversen.
- Een gewijzigde verbinding wordt eerst getest; bij een fout blijven de oude waarden actief tot je bevestigt.
- Wachtende sessies blijven bewaard bij een wijziging van verbinding; ze gaan naar de nieuwe verbinding.
- Details: docs/configuration.md.

## Niet in scope
Login of pincode voor leden, uren beheren op de iPad, vrije tekst, inspreken, CSV-export, uren achteraf invoeren of wijzigen op de iPad, iPhone-versie.

## Open vragen
- Foto-URL in accounts-respons?
- Toegelaten waarden `category` / `project` / `status`, en POST-respons.
- Sluitingsuur.
- Vaste wifi of eigen 4G/5G-iPad mogelijk?
