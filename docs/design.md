# Design — iPadOS 26, Liquid Glass

Referentie: de mockups in `mockups/*.dc.html` (1194×834 pt, liggend) en het canvas https://claude.ai/artifact/XMfZ6e3Hj5xbwkNHAXixna. De HTML benadert glass met blur; in de app gebruik je de echte SwiftUI-API's.

## Principes
- Liquid Glass enkel voor de laag die boven de content zweeft: toolbar-items, de zwevende balk "Nu aan het werk", sheets, knoppen. Content (ledentegels, lijsten, statkaarten) is opaak wit op `systemGroupedBackground`.
- SwiftUI: `.glassEffect()` / `GlassEffectContainer` voor eigen glazen vormen, `.buttonStyle(.glass)` voor secundaire en `.buttonStyle(.glassProminent)` voor primaire knoppen. Laat standaard toolbars en sheets hun systeemglas gebruiken in plaats van het na te bouwen.
- Grote doelen: minimaal 44 pt, primaire knoppen 56–64 pt hoog, capsulevorm. Concentrische hoekstralen (tegels 24, kaarten 24–28, sheets systeem).
- Systeemfont (SF Pro), Dynamic Type ondersteunen. Tijden met `.monospacedDigit()`.
- Kleuren: systeemkleuren. Primair `.tint` (blue). Timers in donkergroen (toegankelijke variant van `.green`), markeringen oranje, stop rood (zoals Klok-app).
- Bevestigingen: haptiek (`.sensoryFeedback(.success, …)`).

## Schermen

### 1. Startscherm (`Main.dc.html`, `Druk.dc.html`)
- Navigatiebalk met large title = de clubnaam uit zweef.app (fallback "Winter" zolang die onbekend is), subtitel "Onderhoudsuren · Donderdag 1 oktober · tik op je naam om te starten". In de mockups staat nog "Onderhoudsuren" als titel.
- Toolbar rechts (glas): statusknop sync ("8 wachten", oranje wolk zonder verbinding) → scherm 7; zoekveld; "Dag afsluiten" (prominent als toegestaan, anders disabled met slotje).
- Content: sectie "Vaak hier" (5 tegels), sectie "Alle leden" (grid 5 kolommen). Tegel: wit, radius 24, hoogte 84, foto 52 pt rond, voornaam 17 semibold, familienaam 15 secondary.
- Letterindex rechts (zoals Contacten).
- Zwevende glazen balk onderaan "Nu aan het werk" (boven de content, content scrolt eronder, extra bottom inset):
  - links: groene stip + "Nu aan het werk", "2 leden", "Tik om te stoppen"
  - 1–3 lopend: grote kaarten (foto 52, volledige naam, "sinds 09:12", timer 28 pt groen)
  - 4+ lopend: compacte kaarten in een grid van 4 kolommen (foto 48, "Jan V.", timer 22 pt); balk groeit in hoogte
  - 0 lopend: grijze stip, "Niemand", tekst "Als laatste weg? Sluit de dag af rechtsboven."

### 2. Starten (`Start.dc.html`)
Form sheet (~540×560). Sluitknop links (glas, xmark), titel "Starten". Foto 120, naam 34 bold, "Klaar om te beginnen?". Knoppen: "Start" (glassProminent, play.fill, 64 hoog), "Dat ben ik niet" (glass). Voetnoot: "Waaraan je werkte, kies je bij het stoppen."

### 3. Bevestiging start (`Gestart.dc.html`)
Gecentreerde glazen kaart (~480×480, radius 48) boven gedimd startscherm. Blauwe cirkel met checkmark, "Veel werkplezier, Ellen", "Gestart om 14:05". Knoppen "Ongedaan maken" (glass) en "Klaar" (prominent). "Sluit vanzelf na 3 seconden".

### 4. Stoppen (`Stop.dc.html`)
Brede sheet (~920×680), twee kolommen:
- Links: foto 96, naam, "Bezig sinds 09:12", timer 76 pt light, "uur : minuten", knop "Stop en bewaar" (rood, stop.fill).
- Rechts: "Waaraan werkte je?" + "Optioneel"; inset grouped lijst met 6 taken (gekleurd icoon in afgeronde vierkant, checkmark bij selectie); bij Zweefvliegtuig een rij toestel-capsules; voetnoot "Wordt op deze iPad bewaard, ook zonder internet."

### 5. Bevestiging stop (`Gestopt.dc.html`)
Zoals 3, groene cirkel. "Bedankt, Jan", "2 u 18 min", "09:12 – 11:30 · Zweefvliegtuig · ASK 21", "Bewaard op deze iPad, gaat naar zweef.app zodra er internet is".

### 6. Dag afsluiten (`Dagoverzicht.dc.html`)
Push-scherm. Toolbar: terug (glas), titel "Dag afsluiten" + subtitel datum, status-capsule "Geen lopende timers". Drie statkaarten (sessies vandaag, totaal, ook mee van eerdere dagen). Inset grouped lijst per sessie (foto, naam, tijden, taak, markering-capsule oranje, duur). Zwevende glazen balk onderaan: wifi.slash-icoon, "Geen internet · 8 sessies klaar", "Gaan vanzelf naar zweef.app zodra de iPad verbinding heeft", knop "Dag afsluiten" (prominent).

### 7. Synchronisatie (`Sync.dc.html`)
Push-scherm, twee kolommen. Links: statuskaart (icoon, "Geen verbinding", laatste poging, 2 tellers, "Nu opnieuw proberen"), lijst met laatste upload / leden en foto's ververst / periode. Rechts: secties "Aandacht nodig", "Wacht op upload" (per dag), "Recent geüpload".

### 8. Setup-assistent (nog geen mockup)
Fullscreen, één stap per pagina met voortgang bovenaan (glazen capsule met stappen), grote velden in inset grouped lijsten, primaire knop "Volgende" onderaan (glassProminent). Stappen: Welkom → Verbinding (segmented control Proxy/Direct, velden, "Verbinding testen" met resultaat-rij "Verbonden met <clubnaam>") → Club (opgehaalde clubnaam ter bevestiging, niet bewerkbaar; sluitingsuur met wheel-picker, takenlijst met herschikken) → Beheercode (6-cijferige invoer) → Klaar.

### 9. Instellingen (nog geen mockup)
Bereikbaar via lang drukken (3 s) op de titel (clubnaam) → beheercode-sheet. Standaard iPad-instellingenpatroon: `NavigationSplitView` met secties Verbinding, Club, Taken, Beheercode, Gegevens. Velden met geheimen tonen "••••••• (ingesteld)" met knop "Wijzigen". Directe modus toont een oranje waarschuwingsrij. Waarden uit MDM zijn grijs met "Beheerd door je organisatie". Gevaarlijke actie "Alles wissen op deze iPad" in rood onderaan.

## Teksten (NL)
Gebruik de teksten uit de mockups als bron. Centraliseer in een String Catalog (`Localizable.xcstrings`), basistaal `nl-BE`.

## Voorbeelddata voor previews
Leden: Jan Verhoeven, Koen Maes, Ellen Peeters, Sofie Claes, Bart Wouters, Lotte Janssens, Pieter De Smet, … Toestellen: ASK 21, LS4, Discus.
