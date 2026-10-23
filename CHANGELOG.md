# Changelog

All notable changes are recorded in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]
### Added
- The project name **Winter**; the app is generic and works for any club on zweef.app.
- The club name is fetched from zweef.app (`GET /club.json`) when connecting and on every refresh.
- Functional specification, architecture, data model, sync and API documentation.
- Design decisions as ADRs (0001–0010).
- The app ships in English, Dutch and French, following the device's language (ADR 0010). English is the source language; text sent to zweef.app uses the club's reporting language.
- Support for iPhone as well as iPad: one universal app, all orientations, layouts driven by size classes (ADR 0009). Running timers stay on the device they were started on.
- Installation guide for clubs and configuration documentation.
- Mockups of eight screens.

- Xcode project generated with XcodeGen from `project.yml`; universal iPhone and iPad app target, a Swift Testing target, and a String Catalog with `en`, `nl` and `fr`.
- Domain rules as pure functions with tests: session duration and flags, decimal hours, duration text per language, the closing time (including both daylight-saving nights), and the zweef.app registration description with its dedup tag.
- SwiftData models and `SessionStore`: start, stop (also someone else's timer), undo, close the day including earlier unclosed days, and automatic stop at the closing time.
- Sample club data for previews and tests.
- The screens, in both size classes: home (member grid, search, letter index, "Often here", the "Working now" bar), the start and stop sheets, the confirmations with undo, closing the day, and the sync overview. Design system components (`MemberAvatar`, glass bar and card, stat card, flag badge) and `LayoutMetrics`, which resolves the mockups' sizes from the size classes.
- Member list rules in `Domain` with tests: diacritics-insensitive search, letter sections, and the "often here" ranking.
- Every UI string in the String Catalog, translated into Dutch and French, with a test suite that fails on a missing translation, a stale string, an empty key or an incomplete plural.
- Accessibility pass: VoiceOver grouping and selection traits, `.scaledFont` so the sizes taken from the mockups still respond to Dynamic Type, and custom colours darkened until each measures 4.5:1 against the surface it sits on.
- Creating a registration is verified against a real club: zweef.app returns the whole stored record, which the app keeps rather than just the id.
- Configuration: the setup assistant (connection, club name, closing time, reporting language, admin code), the settings screen behind that code, secrets in the Keychain, MDM values that take precedence and are read-only, and "erase everything on this device". The connection is read on every sync run, so a changed token takes effect at once.
- Sync engine: an actor that stops forgotten timers, refreshes members and aircraft every six hours, and uploads closed days — with per-session backoff plus jitter, a dedup check that recognises an upload which already arrived, rejections that wait for a human, and one run at a time however many triggers arrive. Triggered by connectivity returning, the app becoming active, closing the day, "try again now" and a background refresh.
- The club name can be typed in the setup, because `GET /club.json` answers 500 for a real club (ADR 0012). A typed name is never overwritten by a later refresh.
- zweef.app client: `ZweefAPI` with `ZweefClient` (URLSession, async/await) and `FakeZweefAPI`, typed errors that say whether to retry, and the `WorkSession` → registration mapping. Anonymised fixtures captured from a real club.
- App icon and launch screen. The icon is an Icon Composer bundle (`Design/AppIcon/AppIcon.icon`) with Liquid Glass layers; the launch screen is a flat version of it, from a colour and a vector mark in the new asset catalog, named by `UILaunchScreen` in `App/Info.plist`.
- A running timer can be deleted from the stop sheet instead of saved: a trash menu in the toolbar that asks "Delete Jan's timer?" and says the time is removed from the device and never sent to zweef.app. Only running timers; finished sessions are corrected in zweef.app.

### Changed
- The floating "Working now" bar is gone. Running timers are the first section of the member list, in the same tiles as everyone else, with the time written as "46m" or "1h23m" in the normal text colour; the phone's "which timer?" sheet went with the bar.
- "Often here" is now called "Recents" (nl "Recent", fr "Récents"); the ranking is unchanged.
- Search results have a "Members" heading, so they no longer read as part of "Working now" above them.
- A member with a running timer appears only in "Working now", not also in "Recents" and the letter sections, and search covers "Working now" too. Starting or stopping animates the tile between the sections.
- Member tiles are interactive Liquid Glass (ADR 0014). The running ones are wider, with the name on top and the time underneath, so a long name no longer collapses to an ellipsis.
- The home subtitle is larger: a `.largeSubtitle` toolbar item in title 3 instead of the caption-sized `navigationSubtitle`, wrapping on a phone.
- The start sheet has one button. "That isn't me" is gone; the close button does the same.
- The stop sheet no longer asks "I'm stopping this for someone else"; the app no longer records who stopped a timer.
- Three settings Xcode 27 recommends are set in `project.yml`: the analyzer's "Missing Localizability" check, String Catalog symbol generation and asset symbol extensions on `Color` and `Image`.
- Debug builds take a `-sampleClub <n>` launch argument that opens the fictional club with `n` timers running, so a screen can be looked at on a simulator without a zweef.app key (CONTRIBUTING.md).
- No proxy: the app talks to zweef.app directly with the club's API key in the Keychain (ADR 0013). `proxy/`, the device token and the connection-mode choice are gone. SECURITY.md records what that costs — a lost device now means rotating the club's key.
- All repository documentation is written in English.
- Verified the zweef.app API against a real club: `accounts.json` has no member photo (avatars are always initials, and the photo cache is dropped), `category` is sent empty rather than `"Maintenance"`, the active period is read from `current/hours.json` because `periods.json` answers 404, and `club.json` answers 500 so the club name may be unavailable.
- No CI: tests and the secrets check are run locally before merging (ADR 0011).
- `Config/Shared.xcconfig` defaults `BUNDLE_ID_PREFIX` to `com.example`, so a fresh clone builds without a `Local.xcconfig`.
- Starting no longer shows a confirmation card: the tile moving into "Working now" and a haptic say it worked, and the "Undo" chip stays for 10 seconds.
- The stop confirmation has no Done button and no longer closes by itself after 3 seconds. It stays until someone taps outside it, and its "Undo" (which sets the timer running again) works for as long as it is up.
- Hours are uploaded by hand (ADR 0015). Nothing uploads by itself any more — not on reconnecting, not in the background, not after closing the day — and the 24-hour safety net is gone. The sync screen's "Try again now" became a prominent "Upload 2 sessions" button that sends every finished session still waiting, closed day or not, and leaves running timers alone. Automatic runs still stop forgotten timers and refresh the members. The retry backoff went with it, and `RetryPolicy` is now `RefreshPolicy`.
- The sync screen shows its sessions as a two-column grid of tiles like the home screen's (the status card moves on top in portrait, and the grey background now fills the screen), each saying who worked, when, how long, and on what task and aircraft, with the flags and, for a rejected session, the reason.
- On the stop sheet, choosing Glider opens a searchable picker of aircraft as glass tiles, the registration large with its type ("Schleicher ASK 21") underneath, instead of a row of capsules; the choice then shows under Glider and reopens the picker. The type comes from `material.json` and is stored as `Aircraft.typeName`; aircraft stored before that are refreshed on the next run rather than after six hours.
- "Stop and save" asks first, in a menu on the button ("Stop Jan's timer?"). For a short session the menu asks whether the time is right instead, replacing the separate dialog.
- Debug builds also take `-sampleScreen sync` or `-sampleScreen closeDay`, which opens that screen with finished sample sessions.
- Xcode Cloud can build the app (ADR 0016, amending 0011): `ci_scripts/ci_post_clone.sh` installs XcodeGen and generates the project, and writes `Config/Local.xcconfig` from the workflow's `WINTER_BUNDLE_ID_PREFIX` and `WINTER_DEVELOPMENT_TEAM`.
- Buttons are the system's standard size everywhere ("Start", "Stop and save", "Upload", "Next", "Test connection"), no longer full-width 56–64 pt slabs. `LayoutMetrics.primaryButtonHeight` is gone.
- The stop sheet is a smaller form sheet in one column, and puts "Stop and save" right under the time, and writes the time as everywhere else ("46m", "1h05m") in the primary colour instead of a green clock with an "hours : minutes" caption. The tasks are a grid of glass tiles instead of a table, with the chosen aircraft in a glass row under it.
- Debug builds take `-sampleScreen stop` too, which opens the stop sheet of the first running timer.
- The aircraft picker offers only the club's own aircraft (`kist_category` "club"), not members' private gliders, and opens as a form sheet the size of the stop sheet.
- The club's logo can be picked from Photos in the setup assistant's club step and in Settings ("Choose", "Change", "Remove"). It is stored as a PNG of at most 512 px and shown round at the top left of the home screen.
- Dark mode: cards and tiles use the secondary grouped background instead of `.background`, which was the same black as the page and made the sync, close-day and setup cards vanish; `.flag` and `.runningTimer` are only darkened in light mode, so badges and status icons stay readable on black.
- Builds need the iOS 27.1 SDK (Xcode 27.1) to fill the iPhone Duo's screen; with 27.0 the app ran in a compatibility window.
- No reporting-language setting any more (ADR 0017, amending 0010): the words the app writes into zweef.app, such as the flags, are in the language of the device that uploads them. The setup assistant and Settings no longer ask, and `AppSettings.reportingLanguageCode` is gone.
- The club logo is shown whole, never cropped, inside the same glass circle as the sync button opposite it.
- No closing the day (ADR 0018, superseding that part of 0005). The "Close day" button, the close-day screen, `SessionStore.closeDay` and `WorkSession.dayClosedAt` are gone: since uploading became manual, closing only marked sessions and the sync screen already lists them. The closing time still stops forgotten timers, and anyone may still stop anyone's timer. Debug builds no longer take `-sampleScreen closeDay`.
- The home screen has a header with the club's logo beside a much larger club name (44 pt on iPad, 28 on iPhone, wrapping rather than truncating), replacing the large title and the small logo in the toolbar. The name moves into the navigation bar once the header scrolls away.
- The logo has a page of its own in the setup assistant, between the club and the admin code, so nobody misses it.
- The description sent to zweef.app is the times and the member's comment, nothing else (ADR 0019, amending 0007 and superseding 0017): no task or aircraft (already in `project` and `material_id`), no flags such as "short session", and no `[ou:…]` tag. A timed-out upload is recognised by member, day, hours, aircraft and description instead. `ReportingLanguage` is gone.
- The stop sheet has a comment field under the tasks, and a club can require a comment ("A comment is required when stopping", in the setup's club step and in Settings). The task tiles are one row each, so the form sheet fits it without growing.

### Fixed
- After deleting and reinstalling the app, setup jumped to the home screen as soon as the connection step was saved, and the home screen stayed empty. iOS keeps Keychain items when an app is deleted, so the old API key and admin code made the device look set up. Setup now completes only on its last step (a flag in UserDefaults, which is deleted with the app), the members are fetched right after it, and an empty member list says where the members come from with a "Fetch members" button instead of "No results".
- A member's avatar colour changed every time the app started: it came from `id.hashValue`, which Swift seeds afresh per launch. It now comes from the id itself.
- The sync screen said "This device has no zweef.app connection configured yet" on a connected device, a placeholder from before the setup assistant existed. It now says why hours are waiting. The two counters line up at the top.
- Starting or stopping a timer no longer glitches: the sheet used to be swapped for its confirmation in one step, so SwiftUI dismissed and presented at the same time. The confirmation now waits for the sheet to finish closing.
- Build warnings: the setup summary's plural ("3 registrations in period 7") is written with a substitution so the compiler knows which number drives it; the unused accent-colour setting is gone (the app uses the system tint); and the XcodeGen project records Xcode 27 as its last upgrade check.
- The first upload crashed with `_dispatch_assert_queue_fail`: the flag-label closure handed to the sync engine assumed it was on the main actor to read the reporting language, but the engine calls it from its own executor. The engine now reads the language from its own context and passes it to the closure.
