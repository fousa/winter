# Design — iOS 26, Liquid Glass, iPhone and iPad

Reference: the mockups in `mockups/*.dc.html` (1194×834 pt, landscape) and the canvas https://claude.ai/artifact/XMfZ6e3Hj5xbwkNHAXixna. The HTML approximates glass with a blur; in the app you use the real SwiftUI APIs.

The mockups show the iPad in landscape, which stays the reference design. Everything below describes that layout first and then how it adapts to a compact size class. The sizes in pt from the mockups are the regular-width values; they are not fixed screen coordinates ([ADR 0009](decisions/0009-universal-app-iphone-and-ipad.md)).

## Principles
- Liquid Glass for the layer that floats above the content — toolbar items, sheets, buttons — and for the member tiles, which are the home screen's buttons ([ADR 0014](decisions/0014-glass-member-tiles.md)). Other content (lists, stat cards) is opaque white on `systemGroupedBackground`.
- SwiftUI: `.glassEffect()` / `GlassEffectContainer` for custom glass shapes, `.buttonStyle(.glass)` for secondary buttons and `.buttonStyle(.glassProminent)` for primary ones. Let standard toolbars and sheets use their system glass instead of rebuilding it.
- Big targets: at least 44 pt, primary buttons 56–64 pt tall, capsule-shaped. Concentric corner radii (tiles 24, cards 24–28, sheets system).
- System font (SF Pro), support Dynamic Type. Times with `.monospacedDigit()`.
- **A size from the mockups still has to scale.** `.font(.system(size:))` is fixed, so a member with Larger Text would get the same 28 pt timer as everyone else — exactly backwards, since the timer is what they came to read. Use `.scaledFont(size:relativeTo:…)`, which scales against a text style and stops at a maximum before the number pushes the name off the card. Plain `.font(.title)` tokens elsewhere.
- VoiceOver: a row is one stop, not four. Cards, stat cards and list rows use `.accessibilityElement(children: .combine)`; a selected task carries `.isSelected` rather than only a checkmark; decorative glyphs and avatars are `.accessibilityHidden(true)` because the name is already in the row's label.
- Colours: system colours. Primary `.tint` (blue).
- **Contrast is measured, not judged.** Apple's `systemGreen` and `systemOrange` are 2.2:1 on white — fine as a fill behind white text, unreadable as text on an opaque card. So each custom colour is darkened until it passes 4.5:1 against the surface it actually sits on, and the ratio is recorded next to it in `DesignSystem/Palette.swift`:

| Colour | Used for | Ratio |
|---|---|---|
| `.runningTimer` (green, 35% black) | running timers, "connected", the working dot | 4.9:1 on white |
| `.flag` (orange, 35% black) | flag badges, "needs attention" | 4.9:1 on white, 4.3:1 on the badge's own tint |
| `.stopAction` (red, 15% black) | the stop button's fill | white on it is 4.7:1 |
| `.avatarBackground` (8 hues, 20% black) | initials | carries white initials |
- Confirmations: haptics (`.sensoryFeedback(.success, …)`).

## Adaptive layout
The app is one universal app with no orientation locks. Layout decisions follow the size classes, never the device model, the idiom or a screen size.

- Read `@Environment(\.horizontalSizeClass)` and `\.verticalSizeClass`. Never `UIDevice.current.userInterfaceIdiom`, never `UIScreen.main.bounds`, and no `GeometryReader` where a layout container or `ViewThatFits` will do.
- Grids use `LazyVGrid` with `.adaptive(minimum:)` so the number of columns follows the available width instead of a hardcoded count.
- Spacing and padding come from a small scale that has a compact and a regular value; the mockup numbers are the regular ones.
- Dynamic Type at accessibility sizes effectively makes any layout compact: test the largest size in both size classes, and let two-column layouts fall back to one column when the text no longer fits (`ViewThatFits`).
- Safe areas are respected on every edge (the home indicator, Dynamic Island, and the iPad's rounded corners). The undo chip sits in a bottom safe-area bar, so the content scrolls clear of it.

### Per size class
| Element | Regular width (iPad, iPhone landscape on the largest models) | Compact width (iPhone) |
|---|---|---|
| Home grid | 5-column grid, member tiles with first and last name | `.adaptive(minimum: 150)`, roughly 2 columns in portrait; the letter index stays on the trailing edge |
| Search | A search field in the toolbar | `.searchable` on the navigation stack, so it collapses into the title area |
| Toolbar | Sync status, search and "Close day" side by side | Sync status stays visible; "Close day" moves into the bottom bar, where the primary action belongs on a phone |
| "Working now" | A section at the top of the grid, the same tiles with the running time | The same section, one tile per row like the rest of the grid |
| Start sheet | Form sheet, ~540×560 | A full-height sheet; the avatar shrinks and the button goes to the bottom |
| Stop sheet | Two columns: person and timer left, task list right | One scrolling column: person, timer, then the task list; "Stop and save" pinned at the bottom in a glass bar |
| Confirmations | A centred glass card above the dimmed screen | The same card as a sheet with `.presentationDetents([.medium])` |
| Sync screen | The status card beside two columns of tiles when the width allows (an iPad in landscape); in portrait the card on top and the two tile columns full width below | One scrolling column, with the status card first and one tile per row |
| Settings | `NavigationSplitView` | `NavigationStack` with a single `Form`, sections in the same order |
| Setup assistant | Centred content, one step per page | The same steps full width; the progress capsule stays at the top and the primary button at the bottom |

### Compact height (iPhone landscape)
- Centred confirmation cards become sheets, so the content keeps scrolling behind them.
- Large display text (the 76 pt timer on the Stop screen) scales down with the vertical size class instead of being clipped.
- Nothing is placed in a fixed-height container that assumes portrait.

### Shared device vs. personal device
The shared workshop device (usually the iPad) runs in Guided Access with the screen kept on. A personal iPhone does neither: no Guided Access, no `isIdleTimerDisabled` beyond a running timer, and no reminder to mount it on a wall. The screens are otherwise identical — the same member list, the same two taps.

Running timers belong to the device they were started on. The "Working now" section therefore only lists this device's timers, and simply is not there when none run here.

## Screens

### 1. Home (`Main.dc.html`, `Druk.dc.html`)
- A navigation bar with the large title = the club name from zweef.app (falling back to "Winter" while it is unknown), subtitle "Maintenance hours · Thursday 1 October · tap your name to start". The subtitle is a `.largeSubtitle` toolbar item in title 3 (subheadline on a phone, wrapping to two lines) rather than `navigationSubtitle`, whose caption size was too small to read from a step back. The mockups still show "Onderhoudsuren" as the title.
- Toolbar on the right (glass): the sync status button ("8 waiting", an orange cloud when there is no connection) → screen 7; a search field; "Close day" (prominent when allowed, otherwise disabled with a lock).
- Content: a "Working now" section, a "Recents" section (5 tiles) and the members under letter headings (a 5-column grid). While searching, the letters give way to one "Members" heading over the results, under "Working now" when a working member matches too. A tile: interactive Liquid Glass, radius 24, height 84, avatar 52 pt round (initials — zweef.app has no member photos, see [zweef-api.md](zweef-api.md)), first name 17 semibold, last name 15 secondary. Glass because the tiles are the screen's buttons and should lift under a finger like one ([ADR 0014](decisions/0014-glass-member-tiles.md)).
- A letter index on the right (as in Contacts).
- "Working now", the first section while anything runs on this device: the same tiles as the rest of the grid, oldest timer first, in a wider column (280 pt minimum, 220 compact) and two rows: avatar and name on top with the full width to themselves, the running time underneath at 28 pt (22 compact), in the primary text colour, written "46m" under an hour and "1h23m" after. No colour on the tile or the time: the section title and the time itself say what is going on. Tapping one opens the stop sheet. It replaces the floating bar of earlier versions, so there is one way to see who is working and it scrolls with everything else. A working member is *only* here: their tile leaves "Often here" and the letter sections while the timer runs, so each person has one tile. Search filters this section like the others, so typing a name finds a member whether or not they are working.
- Starting or stopping moves the tile: it flies from its letter section into "Working now" and back with a smooth spring, while the sheet slides away. A tile with nowhere visible to fly from — scrolled out of view, or a timer that was deleted — scales and fades instead.

### 2. Start (`Start.dc.html`)
A form sheet (~540×560). Close button on the left (glass, xmark), title "Start". Avatar 120, name 34 bold, "Ready to get going?". One button: "Start" (glassProminent, play.fill, 64 tall). A wrong name is dismissed with the close button, like any sheet; the mockup's "That's not me" button is gone. Footnote: "You pick what you worked on when you stop."

### 3. Start confirmation (`Gestart.dc.html`) — dropped
The mockup's card ("Enjoy the work, Ellen") is not built. Starting already shows itself: the sheet closes, the tile moves into "Working now" with its clock running, and a haptic fires. A card on top of that only stood between the member and the workshop. A start under the wrong name is taken back with the "Undo" chip at the bottom of the home screen ("Ellen started · Undo"), which disappears by itself after 10 s.

### 4. Stop (`Stop.dc.html`)
A wide sheet (~920×680) in two columns:
- Left: avatar 96, name, "Working since 09:12", a 76 pt light timer, "hours : minutes", and a "Stop and save" button (red, stop.fill). The button opens a menu that confirms: headed "Stop Jan's timer?" — or, under five minutes, "Is 3 minutes right?" with the short-session note as the subtitle — with "Stop and save" and "Keep working". A menu, like the trash button, so the confirmation sits under the finger that tapped.
- Right: "What were you working on?" + "Optional"; an inset grouped list with 6 tasks (a coloured icon in a rounded square, a checkmark on selection); choosing Glider opens the aircraft picker straight away: a page sheet titled "Aircraft" with a search field ("Registration or type") and a grid of interactive glass tiles, the registration large and the type underneath, gliders first; tapping one selects it and closes the sheet, and "No aircraft" takes the choice back. Under Glider in the list, one row then shows the chosen aircraft (or "Choose the aircraft") and reopens the picker. Glass, because the tiles are buttons (ADR 0014); footnote "Saved on this device, with or without internet."
- Toolbar: close (xmark) on the left and a trash menu on the right, which is not in the mockup. The menu is headed "Delete Jan's timer?" and offers "Delete" (destructive, with the consequence as its subtitle) and "Keep working"; "Delete" removes the session without saving it. A menu rather than a confirmation dialog, because the dialog's popover anchored away from the button on the wide sheet. It is a toolbar icon rather than a second big button so that "Stop and save" stays the one obvious action on a shared device.

#### Two things the mockups left open
- **How long can a stop be undone?** For as long as its confirmation card is up. The card no longer closes by itself after 3 s — that took the undo away before anyone had read the summary — and it has no Done button: tapping outside it closes it, as with any popover. Undoing a stop sets the session running again, without its task and aircraft.
- **Who stopped the timer?** On a device with no login the app cannot tell whether Jan stopped his own timer or Koen stopped it for him. An earlier version asked with a switch on the stop sheet; it was removed because nobody used it and it cluttered the one screen that must stay simple. The app no longer sets `stoppedByOther`, so the "stopped by someone else" flag only appears on sessions recorded before the change.

### 5. Stop confirmation (`Gestopt.dc.html`)
A centred glass card (~480 wide, radius 48) above the dimmed home screen in regular width; a medium-detent sheet in compact. A green circle with a checkmark, "Thanks, Jan", the summary ("2 h 18 min · Glider · ASK 21"), one "Undo" button (glass), and the footnote "Tap outside to close". No Done button and no auto-dismiss: a tap on the dimmed screen (or above the sheet, or VoiceOver's escape gesture) closes it.

### 6. Close day (`Dagoverzicht.dc.html`)
A pushed screen. Toolbar: back (glass), the title "Close day" + the date as a subtitle, a status capsule "No running timers". Three stat cards (sessions today, the total, and what is also included from earlier days). An inset grouped list per session (avatar, name, times, task, an orange flag capsule, duration). A floating glass bar at the bottom: "8 sessions ready", "Closing does not send them: upload them from the sync screen", and a "Close day" button (prominent). The mockup's "They go to zweef.app by themselves" no longer holds (ADR 0015).

### 7. Synchronisation (`Sync.dc.html`)
A pushed screen in two columns. Left: a status card (icon, a status line that says why hours are waiting — "Nothing is sent by itself. Upload when the hours are complete." — two counters, and "Upload 2 sessions": glassProminent, full width, as tall as "Start" and "Stop and save", disabled when nothing waits) and a list with the last upload / members refreshed / the period. Right: the sections "Needs attention", "Waiting to upload" and "Recently uploaded", each a two-column grid of tiles (one column in compact width): per session a tile in two fixed rows, so every tile is the same height: the avatar, the name and "23 Oct · 09:00–11:18" with the duration on the right as on the home screen ("2h18m"); underneath, the task and aircraft ("Glider · OO-ZXA", or "No task chosen" in secondary text) with the flags at the end. A rejected session adds its reason. The tiles are opaque, not glass: they are read, not tapped (ADR 0014).

### 8. Setup assistant (no mockup yet)
Fullscreen, one step per page with the progress at the top (a glass capsule with the steps), large fields in inset grouped lists, and a primary "Next" button at the bottom (glassProminent). The steps: Welcome → Connection (club schema and API key, the warning about what that key opens, "Test connection" with a result row "Connected to <club name>" or the period it found) → Club (the club name, typed or prefilled; the closing time; the language hours are written in) → Admin code (a six-digit entry, twice) → Done.

### 9. Settings (no mockup yet)
Reachable by long-pressing (3 s) on the title (the club name) → the admin code sheet. The standard settings pattern: a `NavigationSplitView` in regular width, a `NavigationStack` with one `Form` in compact width, with the sections Connection, Club, Tasks, Admin code and Data. Fields holding secrets show "••••••• (set)" with a "Change" button. Direct mode shows an orange warning row. Values from MDM are greyed out with "Managed by your organisation". The destructive action "Erase everything on this device" sits in red at the bottom.

## App icon and launch screen
The icon is a glass glider above glass snow hills, with a winter sun in a clear sky: winter is a gliding club's maintenance season. It is built in Icon Composer as `Design/AppIcon/AppIcon.icon`, four white layers on a gradient, so iOS 26 renders real Liquid Glass and derives the Default, Dark, Clear and Tinted appearances itself. The `.icon` bundle is a resource of the target and `ASSETCATALOG_COMPILER_APPICON_NAME` points at it; the layer sources, flat PNG fallbacks and the generator script sit next to it (`Design/AppIcon/README.md`).

The launch screen is a flat version of the icon, so starting the app feels like opening it: the `LaunchBackground` colour (the middle of the icon's sky, with a dark variant) and the `LaunchMark` vector image (light and dark) live in `Resources/Assets.xcassets`, and `UILaunchScreen` in `App/Info.plist` names them. No text, no glass. The sources are in `Design/LaunchScreen`. iOS caches launch screens: delete and reinstall the app to see a change.

## Copy and localisation
The app ships in English, Dutch and French ([ADR 0010](decisions/0010-three-languages-en-nl-fr.md)). The strings quoted above are the **English source text**: that is what goes in the code and in the base of the String Catalog (`Localizable.xcstrings`), with `nl` and `fr` as translations. The mockups hold the original Dutch copy and stay the reference for tone; the [glossary](glossary.md) lists the terms in all three languages.

- Every visible string goes through the catalog. No string is built by concatenation, because word order differs per language; use one string with placeholders per sentence.
- Durations, times, dates and decimal hours are formatted with `Date.FormatStyle`, `Duration.UnitsFormatStyle` and `NumberFormatter`, never by hand — "2 h 18 min" is "2 u 18 min" in Dutch, "2 h 18 min" in French, and the decimal separator is a comma in both.
- Counts use the catalog's plural variants ("8 waiting", "1 waiting"), including Dutch and French plural rules.
- Weekdays and month names come from the locale, so the home subtitle is not a hand-built string.
- Member names, the club name, aircraft and club-edited task labels are data, not copy: they are shown as they come from zweef.app or as the club typed them, never translated.
- French labels run roughly 20–30% longer than English, and some short ones far more. The `String catalog` test suite prints the ones that more than double, which is the list to check on a device. Today that is "Close day" → "Clôturer la journée", "Sync" → "Synchronisation", "Admin code" → "Code d'administration". Two of those sit in toolbars, so the sync button is icon-only and "Close day" shrinks slightly rather than wrapping.
- VoiceOver labels are translated too, including the ones that differ from the visible text (the sync status button, the timer).

## Sample data for previews
Members: Jan Verhoeven, Koen Maes, Ellen Peeters, Sofie Claes, Bart Wouters, Lotte Janssens, Pieter De Smet, … Aircraft: OO-ZXA (Schleicher ASK 21), OO-ZXB (Rolladen-Schneider LS4), OO-ZXC (Schempp-Hirth Discus b) — named by registration, as clubs do in zweef.app.

Every screen gets at least two previews: an iPad in landscape (the reference) and an iPhone in portrait. Add an iPhone landscape preview for the screens with a compact-height variant (the Stop sheet, the confirmations), one preview at the largest accessibility text size, and one in French (`.environment(\.locale, Locale(identifier: "fr"))`) as the longest language.
