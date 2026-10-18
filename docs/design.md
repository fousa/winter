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
| "Working now" bar | Floating glass bar, 1–3 large cards or a 4-column grid of compact cards | A single floating glass row ("2 members · tap to stop"). One timer running → straight to the stop sheet; more than one → a sheet asking which, because guessing the first would stop the wrong member's hours |
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
- A navigation bar with the large title = the club name from zweef.app (falling back to "Winter" while it is unknown), subtitle "Maintenance hours · Thursday 1 October · tap your name to start". The mockups still show "Onderhoudsuren" as the title.
- Toolbar on the right (glass): the sync status button ("8 waiting", an orange cloud when there is no connection) → screen 7; a search field; "Close day" (prominent when allowed, otherwise disabled with a lock).
- Content: an "Often here" section (5 tiles) and an "All members" section (a 5-column grid). A tile: white, radius 24, height 84, photo 52 pt round, first name 17 semibold, last name 15 secondary.
- A letter index on the right (as in Contacts).
- A floating glass "Working now" bar at the bottom (above the content, the content scrolls underneath it, with extra bottom inset):
  - left: a green dot + "Working now", "2 members", "Tap to stop"
  - 1–3 running: large cards (photo 52, full name, "since 09:12", timer 28 pt green)
  - 4+ running: compact cards in a 4-column grid (photo 48, "Jan V.", timer 22 pt); the bar grows taller
  - 0 running: a grey dot, "Nobody on this device", and the text "Last one out? Close the day, top right."

### 2. Start (`Start.dc.html`)
A form sheet (~540×560). Close button on the left (glass, xmark), title "Start". Photo 120, name 34 bold, "Ready to get going?". Buttons: "Start" (glassProminent, play.fill, 64 tall) and "That's not me" (glass). Footnote: "You pick what you worked on when you stop."

### 3. Start confirmation (`Gestart.dc.html`)
A centred glass card (~480×480, radius 48) above the dimmed home screen. A blue circle with a checkmark, "Enjoy the work, Ellen", "Started at 14:05". Buttons "Undo" (glass) and "Done" (prominent). "Closes by itself after 3 seconds".

### 4. Stop (`Stop.dc.html`)
A wide sheet (~920×680) in two columns:
- Left: photo 96, name, "Working since 09:12", a 76 pt light timer, "hours : minutes", and a "Stop and save" button (red, stop.fill).
- Right: "What were you working on?" + "Optional"; an inset grouped list with 6 tasks (a coloured icon in a rounded square, a checkmark on selection); for Glider a row of aircraft capsules; footnote "Saved on this device, with or without internet."

#### Two things the mockups left open
- **The card closes after 3 seconds, but undo is promised for 10** (`spec.md`). Both are kept: the card auto-dismisses after 3 s, and the rest of the window lives on as a small "Undo" chip above the floating bar on the home screen, which disappears by itself. Undoing a start deletes the session; undoing a stop sets it running again.
- **Who stopped the timer?** On a device with no login the app cannot tell whether Jan stopped his own timer or Koen stopped it for him, and `stoppedByOther` has to come from somewhere. The stop sheet therefore has one switch, off by default — "I'm stopping this for someone else" — so the normal path is still two taps and the flag is only set when someone says so.

### 5. Stop confirmation (`Gestopt.dc.html`)
Like 3, with a green circle. "Thanks, Jan", "2 h 18 min", "09:12 – 11:30 · Glider · ASK 21", "Saved on this device, and sent to zweef.app as soon as there is internet".

### 6. Close day (`Dagoverzicht.dc.html`)
A pushed screen. Toolbar: back (glass), the title "Close day" + the date as a subtitle, a status capsule "No running timers". Three stat cards (sessions today, the total, and what is also included from earlier days). An inset grouped list per session (photo, name, times, task, an orange flag capsule, duration). A floating glass bar at the bottom: a wifi.slash icon, "No internet · 8 sessions ready", "They go to zweef.app by themselves once this device has a connection", and a "Close day" button (prominent).

### 7. Synchronisation (`Sync.dc.html`)
A pushed screen in two columns. Left: a status card (icon, "No connection", the last attempt, two counters, "Try again now") and a list with the last upload / members and photos refreshed / the period. Right: the sections "Needs attention", "Waiting to upload" (per day) and "Recently uploaded".

### 8. Setup assistant (no mockup yet)
Fullscreen, one step per page with the progress at the top (a glass capsule with the steps), large fields in inset grouped lists, and a primary "Next" button at the bottom (glassProminent). The steps: Welcome → Connection (a segmented control Proxy/Direct, the fields, "Test connection" with a result row "Connected to <club name>") → Club (the fetched club name for confirmation, not editable; the closing time with a wheel picker, the task list with reordering) → Admin code (a six-digit entry) → Done.

### 9. Settings (no mockup yet)
Reachable by long-pressing (3 s) on the title (the club name) → the admin code sheet. The standard settings pattern: a `NavigationSplitView` in regular width, a `NavigationStack` with one `Form` in compact width, with the sections Connection, Club, Tasks, Admin code and Data. Fields holding secrets show "••••••• (set)" with a "Change" button. Direct mode shows an orange warning row. Values from MDM are greyed out with "Managed by your organisation". The destructive action "Erase everything on this device" sits in red at the bottom.

## Copy and localisation
The app ships in English, Dutch and French ([ADR 0010](decisions/0010-three-languages-en-nl-fr.md)). The strings quoted above are the **English source text**: that is what goes in the code and in the base of the String Catalog (`Localizable.xcstrings`), with `nl` and `fr` as translations. The mockups hold the original Dutch copy and stay the reference for tone; the [glossary](glossary.md) lists the terms in all three languages.

- Every visible string goes through the catalog. No string is built by concatenation, because word order differs per language; use one string with placeholders per sentence.
- Durations, times, dates and decimal hours are formatted with `Date.FormatStyle`, `Duration.UnitsFormatStyle` and `NumberFormatter`, never by hand — "2 h 18 min" is "2 u 18 min" in Dutch, "2 h 18 min" in French, and the decimal separator is a comma in both.
- Counts use the catalog's plural variants ("8 waiting", "1 waiting"), including Dutch and French plural rules.
- Weekdays and month names come from the locale, so the home subtitle is not a hand-built string.
- Member names, the club name, aircraft and club-edited task labels are data, not copy: they are shown as they come from zweef.app or as the club typed them, never translated.
- French labels run roughly 20–30% longer than English. Buttons, capsules and the floating bar grow with their label; nothing truncates a primary action. Check the longest language together with the largest Dynamic Type size.
- VoiceOver labels are translated too, including the ones that differ from the visible text (the sync status button, the timer).

## Sample data for previews
Members: Jan Verhoeven, Koen Maes, Ellen Peeters, Sofie Claes, Bart Wouters, Lotte Janssens, Pieter De Smet, … Aircraft: ASK 21, LS4, Discus.

Every screen gets at least two previews: an iPad in landscape (the reference) and an iPhone in portrait. Add an iPhone landscape preview for the screens with a compact-height variant (the floating bar, the Stop sheet, the confirmations), one preview at the largest accessibility text size, and one in French (`.environment(\.locale, Locale(identifier: "fr"))`) as the longest language.
