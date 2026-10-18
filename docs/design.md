# Design — iPadOS 26, Liquid Glass

Reference: the mockups in `mockups/*.dc.html` (1194×834 pt, landscape) and the canvas https://claude.ai/artifact/XMfZ6e3Hj5xbwkNHAXixna. The HTML approximates glass with a blur; in the app you use the real SwiftUI APIs.

## Principles
- Liquid Glass only for the layer that floats above the content: toolbar items, the floating "Working now" bar, sheets, buttons. Content (member tiles, lists, stat cards) is opaque white on `systemGroupedBackground`.
- SwiftUI: `.glassEffect()` / `GlassEffectContainer` for custom glass shapes, `.buttonStyle(.glass)` for secondary buttons and `.buttonStyle(.glassProminent)` for primary ones. Let standard toolbars and sheets use their system glass instead of rebuilding it.
- Big targets: at least 44 pt, primary buttons 56–64 pt tall, capsule-shaped. Concentric corner radii (tiles 24, cards 24–28, sheets system).
- System font (SF Pro), support Dynamic Type. Times with `.monospacedDigit()`.
- Colours: system colours. Primary `.tint` (blue). Timers in dark green (an accessible variant of `.green`), flags orange, stop red (like the Clock app).
- Confirmations: haptics (`.sensoryFeedback(.success, …)`).

## Screens

### 1. Home (`Main.dc.html`, `Druk.dc.html`)
- A navigation bar with the large title = the club name from zweef.app (falling back to "Winter" while it is unknown), subtitle "Onderhoudsuren · Donderdag 1 oktober · tik op je naam om te starten". The mockups still show "Onderhoudsuren" as the title.
- Toolbar on the right (glass): the sync status button ("8 wachten", an orange cloud when there is no connection) → screen 7; a search field; "Dag afsluiten" (prominent when allowed, otherwise disabled with a lock).
- Content: a "Vaak hier" section (5 tiles) and an "Alle leden" section (a 5-column grid). A tile: white, radius 24, height 84, photo 52 pt round, first name 17 semibold, last name 15 secondary.
- A letter index on the right (as in Contacts).
- A floating glass "Nu aan het werk" bar at the bottom (above the content, the content scrolls underneath it, with extra bottom inset):
  - left: a green dot + "Nu aan het werk", "2 leden", "Tik om te stoppen"
  - 1–3 running: large cards (photo 52, full name, "sinds 09:12", timer 28 pt green)
  - 4+ running: compact cards in a 4-column grid (photo 48, "Jan V.", timer 22 pt); the bar grows taller
  - 0 running: a grey dot, "Niemand", and the text "Als laatste weg? Sluit de dag af rechtsboven."

### 2. Start (`Start.dc.html`)
A form sheet (~540×560). Close button on the left (glass, xmark), title "Starten". Photo 120, name 34 bold, "Klaar om te beginnen?". Buttons: "Start" (glassProminent, play.fill, 64 tall) and "Dat ben ik niet" (glass). Footnote: "Waaraan je werkte, kies je bij het stoppen."

### 3. Start confirmation (`Gestart.dc.html`)
A centred glass card (~480×480, radius 48) above the dimmed home screen. A blue circle with a checkmark, "Veel werkplezier, Ellen", "Gestart om 14:05". Buttons "Ongedaan maken" (glass) and "Klaar" (prominent). "Sluit vanzelf na 3 seconden".

### 4. Stop (`Stop.dc.html`)
A wide sheet (~920×680) in two columns:
- Left: photo 96, name, "Bezig sinds 09:12", a 76 pt light timer, "uur : minuten", and a "Stop en bewaar" button (red, stop.fill).
- Right: "Waaraan werkte je?" + "Optioneel"; an inset grouped list with 6 tasks (a coloured icon in a rounded square, a checkmark on selection); for Zweefvliegtuig a row of aircraft capsules; footnote "Wordt op deze iPad bewaard, ook zonder internet."

### 5. Stop confirmation (`Gestopt.dc.html`)
Like 3, with a green circle. "Bedankt, Jan", "2 u 18 min", "09:12 – 11:30 · Zweefvliegtuig · ASK 21", "Bewaard op deze iPad, gaat naar zweef.app zodra er internet is".

### 6. Close day (`Dagoverzicht.dc.html`)
A pushed screen. Toolbar: back (glass), the title "Dag afsluiten" + the date as a subtitle, a status capsule "Geen lopende timers". Three stat cards (sessions today, the total, and what is also included from earlier days). An inset grouped list per session (photo, name, times, task, an orange flag capsule, duration). A floating glass bar at the bottom: a wifi.slash icon, "Geen internet · 8 sessies klaar", "Gaan vanzelf naar zweef.app zodra de iPad verbinding heeft", and a "Dag afsluiten" button (prominent).

### 7. Synchronisation (`Sync.dc.html`)
A pushed screen in two columns. Left: a status card (icon, "Geen verbinding", the last attempt, two counters, "Nu opnieuw proberen") and a list with the last upload / members and photos refreshed / the period. Right: the sections "Aandacht nodig", "Wacht op upload" (per day) and "Recent geüpload".

### 8. Setup assistant (no mockup yet)
Fullscreen, one step per page with the progress at the top (a glass capsule with the steps), large fields in inset grouped lists, and a primary "Volgende" button at the bottom (glassProminent). The steps: Welkom → Verbinding (a segmented control Proxy/Direct, the fields, "Verbinding testen" with a result row "Verbonden met <clubnaam>") → Club (the fetched club name for confirmation, not editable; the closing time with a wheel picker, the task list with reordering) → Beheercode (a six-digit entry) → Klaar.

### 9. Settings (no mockup yet)
Reachable by long-pressing (3 s) on the title (the club name) → the admin code sheet. The standard iPad settings pattern: a `NavigationSplitView` with the sections Verbinding, Club, Taken, Beheercode and Gegevens. Fields holding secrets show "••••••• (ingesteld)" with a "Wijzigen" button. Direct mode shows an orange warning row. Values from MDM are greyed out with "Beheerd door je organisatie". The destructive action "Alles wissen op deze iPad" sits in red at the bottom.

## Copy (NL)
Use the copy from the mockups as the source. Centralise it in a String Catalog (`Localizable.xcstrings`) with `nl-BE` as the base language.

## Sample data for previews
Members: Jan Verhoeven, Koen Maes, Ellen Peeters, Sofie Claes, Bart Wouters, Lotte Janssens, Pieter De Smet, … Aircraft: ASK 21, LS4, Discus.
