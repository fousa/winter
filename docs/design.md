# Design — iOS 26, Liquid Glass, iPhone and iPad

Reference: the mockups in `mockups/*.dc.html` (1194×834 pt, landscape) and the canvas https://claude.ai/artifact/XMfZ6e3Hj5xbwkNHAXixna. The HTML approximates glass with a blur; in the app you use the real SwiftUI APIs.

The mockups show the iPad in landscape, which stays the reference design. Everything below describes that layout first and then how it adapts to a compact size class. The sizes in pt from the mockups are the regular-width values; they are not fixed screen coordinates ([ADR 0009](decisions/0009-universal-app-iphone-and-ipad.md)).

## Principles
- Liquid Glass only for the layer that floats above the content: toolbar items, the floating "Working now" bar, sheets, buttons. Content (member tiles, lists, stat cards) is opaque white on `systemGroupedBackground`.
- SwiftUI: `.glassEffect()` / `GlassEffectContainer` for custom glass shapes, `.buttonStyle(.glass)` for secondary buttons and `.buttonStyle(.glassProminent)` for primary ones. Let standard toolbars and sheets use their system glass instead of rebuilding it.
- Big targets: at least 44 pt, primary buttons 56–64 pt tall, capsule-shaped. Concentric corner radii (tiles 24, cards 24–28, sheets system).
- System font (SF Pro), support Dynamic Type. Times with `.monospacedDigit()`.
- Colours: system colours. Primary `.tint` (blue). Timers in dark green (an accessible variant of `.green`), flags orange, stop red (like the Clock app).
- Confirmations: haptics (`.sensoryFeedback(.success, …)`).

## Adaptive layout
The app is one universal app with no orientation locks. Layout decisions follow the size classes, never the device model, the idiom or a screen size.

- Read `@Environment(\.horizontalSizeClass)` and `\.verticalSizeClass`. Never `UIDevice.current.userInterfaceIdiom`, never `UIScreen.main.bounds`, and no `GeometryReader` where a layout container or `ViewThatFits` will do.
- Grids use `LazyVGrid` with `.adaptive(minimum:)` so the number of columns follows the available width instead of a hardcoded count.
- Spacing and padding come from a small scale that has a compact and a regular value; the mockup numbers are the regular ones.
- Dynamic Type at accessibility sizes effectively makes any layout compact: test the largest size in both size classes, and let two-column layouts fall back to one column when the text no longer fits (`ViewThatFits`).
- Safe areas are respected on every edge (the home indicator, Dynamic Island, and the iPad's rounded corners). The floating bar sits above the bottom safe area and adds its height as a bottom content inset so nothing is permanently hidden underneath it.

### Per size class
| Element | Regular width (iPad, iPhone landscape on the largest models) | Compact width (iPhone) |
|---|---|---|
| Home grid | 5-column grid, member tiles with first and last name | `.adaptive(minimum: 150)`, roughly 2 columns in portrait; the letter index stays on the trailing edge |
| Search | A search field in the toolbar | `.searchable` on the navigation stack, so it collapses into the title area |
| Toolbar | Sync status, search and "Close day" side by side | Sync status stays visible; "Close day" moves into the bottom bar, where the primary action belongs on a phone |
| "Working now" bar | Floating glass bar, 1–3 large cards or a 4-column grid of compact cards | A single floating glass row ("2 members working · tap to stop") that opens a sheet with the list; it never covers more than a third of the height |
| Start sheet | Form sheet, ~540×560 | A full-height sheet; the photo shrinks and the buttons go to the bottom |
| Stop sheet | Two columns: person and timer left, task list right | One scrolling column: person, timer, then the task list; "Stop and save" pinned at the bottom in a glass bar |
| Confirmations | A centred glass card above the dimmed screen | The same card as a sheet with `.presentationDetents([.medium])` |
| Sync screen | Two columns | One scrolling column, with the status card first |
| Settings | `NavigationSplitView` | `NavigationStack` with a single `Form`, sections in the same order |
| Setup assistant | Centred content, one step per page | The same steps full width; the progress capsule stays at the top and the primary button at the bottom |

### Compact height (iPhone landscape)
- Centred confirmation cards become sheets, so the content keeps scrolling behind them.
- The floating bar collapses to one line; the timer stays readable (`.monospacedDigit()`), the rest is secondary.
- Large display text (the 76 pt timer on the Stop screen) scales down with the vertical size class instead of being clipped.
- Nothing is placed in a fixed-height container that assumes portrait.

### Shared device vs. personal device
The shared workshop device (usually the iPad) runs in Guided Access with the screen kept on. A personal iPhone does neither: no Guided Access, no `isIdleTimerDisabled` beyond a running timer, and no reminder to mount it on a wall. The screens are otherwise identical — the same member list, the same two taps.

Running timers belong to the device they were started on. The "Working now" bar is therefore phrased as being about this device, and the empty state on a phone does not claim nobody is working at the club.

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
  - 0 running: a grey dot, "Niemand op dit toestel", and the text "Als laatste weg? Sluit de dag af rechtsboven."

### 2. Start (`Start.dc.html`)
A form sheet (~540×560). Close button on the left (glass, xmark), title "Starten". Photo 120, name 34 bold, "Klaar om te beginnen?". Buttons: "Start" (glassProminent, play.fill, 64 tall) and "Dat ben ik niet" (glass). Footnote: "Waaraan je werkte, kies je bij het stoppen."

### 3. Start confirmation (`Gestart.dc.html`)
A centred glass card (~480×480, radius 48) above the dimmed home screen. A blue circle with a checkmark, "Veel werkplezier, Ellen", "Gestart om 14:05". Buttons "Ongedaan maken" (glass) and "Klaar" (prominent). "Sluit vanzelf na 3 seconden".

### 4. Stop (`Stop.dc.html`)
A wide sheet (~920×680) in two columns:
- Left: photo 96, name, "Bezig sinds 09:12", a 76 pt light timer, "uur : minuten", and a "Stop en bewaar" button (red, stop.fill).
- Right: "Waaraan werkte je?" + "Optioneel"; an inset grouped list with 6 tasks (a coloured icon in a rounded square, a checkmark on selection); for Zweefvliegtuig a row of aircraft capsules; footnote "Wordt op dit toestel bewaard, ook zonder internet."

### 5. Stop confirmation (`Gestopt.dc.html`)
Like 3, with a green circle. "Bedankt, Jan", "2 u 18 min", "09:12 – 11:30 · Zweefvliegtuig · ASK 21", "Bewaard op dit toestel, gaat naar zweef.app zodra er internet is".

### 6. Close day (`Dagoverzicht.dc.html`)
A pushed screen. Toolbar: back (glass), the title "Dag afsluiten" + the date as a subtitle, a status capsule "Geen lopende timers". Three stat cards (sessions today, the total, and what is also included from earlier days). An inset grouped list per session (photo, name, times, task, an orange flag capsule, duration). A floating glass bar at the bottom: a wifi.slash icon, "Geen internet · 8 sessies klaar", "Gaan vanzelf naar zweef.app zodra dit toestel verbinding heeft", and a "Dag afsluiten" button (prominent).

### 7. Synchronisation (`Sync.dc.html`)
A pushed screen in two columns. Left: a status card (icon, "Geen verbinding", the last attempt, two counters, "Nu opnieuw proberen") and a list with the last upload / members and photos refreshed / the period. Right: the sections "Aandacht nodig", "Wacht op upload" (per day) and "Recent geüpload".

### 8. Setup assistant (no mockup yet)
Fullscreen, one step per page with the progress at the top (a glass capsule with the steps), large fields in inset grouped lists, and a primary "Volgende" button at the bottom (glassProminent). The steps: Welkom → Verbinding (a segmented control Proxy/Direct, the fields, "Verbinding testen" with a result row "Verbonden met <clubnaam>") → Club (the fetched club name for confirmation, not editable; the closing time with a wheel picker, the task list with reordering) → Beheercode (a six-digit entry) → Klaar.

### 9. Settings (no mockup yet)
Reachable by long-pressing (3 s) on the title (the club name) → the admin code sheet. The standard settings pattern: a `NavigationSplitView` in regular width, a `NavigationStack` with one `Form` in compact width, with the sections Verbinding, Club, Taken, Beheercode and Gegevens. Fields holding secrets show "••••••• (ingesteld)" with a "Wijzigen" button. Direct mode shows an orange warning row. Values from MDM are greyed out with "Beheerd door je organisatie". The destructive action "Alles wissen op dit toestel" sits in red at the bottom.

## Copy (NL)
Use the copy from the mockups as the source. Centralise it in a String Catalog (`Localizable.xcstrings`) with `nl-BE` as the base language.

## Sample data for previews
Members: Jan Verhoeven, Koen Maes, Ellen Peeters, Sofie Claes, Bart Wouters, Lotte Janssens, Pieter De Smet, … Aircraft: ASK 21, LS4, Discus.

Every screen gets at least two previews: an iPad in landscape (the reference) and an iPhone in portrait. Add an iPhone landscape preview for the screens with a compact-height variant (the floating bar, the Stop sheet, the confirmations), and one preview at the largest accessibility text size.
