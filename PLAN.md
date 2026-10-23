# Build plan

Work phase by phase; after each phase, make sure the app builds and the tests pass.

`Winter.xcodeproj` is generated: run `xcodegen generate` after cloning or after adding files.

## Phase 0 — Project
- [x] Xcode project "Winter" (iOS/iPadOS 26, SwiftUI, Swift 6, universal iPhone + iPad, all orientations). Preferably generated with XcodeGen (`project.yml`) so Claude Code can manage it.
- [x] Folder structure as described in CLAUDE.md; String Catalog with `en` as the source language plus `nl` and `fr`.
- [x] Test target with Swift Testing.

## Phase 0b — Open source
- [x] Git repository with README, LICENSE, .gitignore, `Config/*.xcconfig` (no secrets).
- [x] No CI ([ADR 0011](docs/decisions/0011-no-continuous-integration.md)): tests and the secrets check are run locally before merging.

## Phase 1 — Domain and storage
- [x] SwiftData models from `docs/data-model.md`.
- [x] Domain rules as pure functions + tests (duration, decimal hours, flags, closing time, description).
- [x] `SessionStore`: start, stop (including someone else's timer), undo, auto-stop. (Closing the day was built here and removed later, ADR 0018.) The 10-second undo *window* is a UI concern and lands with `Confirmation` in phase 2.
- [x] Seed with sample members for previews and first tests.

## Phase 2 — UI with fake data
- [x] DesignSystem: `Avatar` (photo or initials), glass bar, stat card, flag badge, plus the spacing scale with a compact and a regular value.
- [x] Home screen including search, letter index, "Recents", and "Working now" (now a section at the top of the list, with the running times).
- [x] Start and Stop sheets, the stop confirmation and the start's undo chip, haptics.
- [x] Close day. Removed later (ADR 0018).
- [x] Sync screen (shows the stored sync state; the engine behind it lands in phase 4).
- [x] Compact variants per `docs/design.md`: the adaptive home grid, the single-column Stop sheet, confirmations as sheets. No `userInterfaceIdiom` or `UIScreen.main` anywhere. (Settings as one `Form` comes with the screen itself in phase 4b.)
- [x] Previews per screen for iPad landscape, iPhone portrait, iPhone landscape (compact height) and the largest accessibility text size.
- [x] Screen-stays-on logic (`isIdleTimerDisabled`) while a timer runs, and Guided Access friendliness (no links that leave the app). Limiting it to the shared device needs the configuration from phase 4b.

## Phase 3 — zweef.app
- [x] `ZweefAPI` protocol + `ZweefClient` (URLSession, async/await, Codable) + `FakeZweefAPI`.
- [x] Capture real JSON from accounts, material and hours as anonymised fixtures. Still open: the POST response, which needs a registration in a live club. `periods.json` 404s and `club.json` 500s — see `docs/zweef-api.md`.
- [x] Mapping WorkSession → POST body (`docs/zweef-api.md`).

## Phase 4 — Sync
- [x] `SyncEngine` actor as described in `docs/sync.md` (triggers, dedup, rejected). Uploading became manual later (ADR 0015).
- [x] ~~Photo cache~~ — dropped: `accounts.json` carries no photo for any member, so there is nothing to cache and avatars are always initials.
- [x] Register the BGAppRefreshTask, with the `UIBackgroundModes` and `BGTaskSchedulerPermittedIdentifiers` keys it needs in `App/Info.plist`.
- [x] Tests with FakeZweefAPI (timeouts, 4xx, duplicate triggers).

## Phase 4b — Configuration
- [x] `KeychainStore`, `AppConfiguration` (UserDefaults), managed-configuration reader.
- [x] Setup assistant (docs/configuration.md), including "Test connection" and the club-name field (ADR 0012).
- [x] Settings screen behind the admin code (long-press the title), all values editable, connection tested before saving.
- [x] `ZweefTransport` behind `ZweefAPI` (one connection path; the proxy was dropped by ADR 0013).
- [x] Configurable task list (TaskDefinition), seeded from the catalog in the setup language. Replaced later by zweef.app's material list (ADR 0020).
- [x] Reporting language in `AppSettings` and in the setup, used by `RegistrationDescription`. Removed later (ADR 0017, ADR 0019).

## Phase 6 — Finishing touches

Done in code:
- [x] VoiceOver labels and grouping, Dynamic Type through `.scaledFont`, and contrast measured rather than judged — every custom colour now passes 4.5:1 on the surface it sits on (`docs/design.md`).
- [x] Translations: `nl` and `fr` complete, and a `String catalog` test suite that fails on a missing translation, a stale string, an empty key or an incomplete plural. It also prints the short labels that grow most in French.
- [x] Distribution documented: build-it-yourself, TestFlight and MDM (`docs/installation-guide.md`).

Needs a device or a simulator, which the development machine does not have:
- [ ] Look at it. Nobody has yet seen this app run: not a preview, not a screenshot. The home screen has now been seen on the iPad and iPhone simulators (Debug launch argument `-sampleClub`); the stop sheet, the confirmations and real hardware have not.
- [ ] Rotation pass on both devices: no clipping, no layout jumps, nothing hidden behind the undo chip or a safe area.
- [ ] French at the largest accessibility text size, on the four labels the catalog test flags.
- [ ] VoiceOver pass with the screen curtain on: start, stop, upload.

Needs people:
- [ ] A native Dutch and a native French speaker read their language. The translations are mine and have not been reviewed.
- [ ] TestFlight rollout (needs the club's Apple Developer Program account).
- [ ] Test at the club: three members of different ages, one day without internet, on the workshop iPad and on a phone.
