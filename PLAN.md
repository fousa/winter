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
- [x] Domain rules as pure functions + tests (duration, decimal hours, flags, closing time, canCloseDay, description).
- [x] `SessionStore`: start, stop (including someone else's timer), undo, close the day, auto-stop. The 10-second undo *window* is a UI concern and lands with `Confirmation` in phase 2.
- [x] Seed with sample members for previews and first tests.

## Phase 2 — UI with fake data
- [x] DesignSystem: `Avatar` (photo or initials), glass bar, stat card, flag badge, plus the spacing scale with a compact and a regular value.
- [x] Home screen including search, letter index, "Often here", and the "Working now" bar (1–3 large, 4+ compact).
- [x] Start and Stop sheets, confirmations with auto-dismiss and undo, haptics.
- [x] Close day.
- [x] Sync screen (shows the stored sync state; the engine behind it lands in phase 4).
- [x] Compact variants per `docs/design.md`: the adaptive home grid, the single-column Stop sheet, confirmations as sheets, the collapsed floating bar. No `userInterfaceIdiom` or `UIScreen.main` anywhere. (Settings as one `Form` comes with the screen itself in phase 4b.)
- [x] Previews per screen for iPad landscape, iPhone portrait, iPhone landscape (compact height) and the largest accessibility text size.
- [x] Screen-stays-on logic (`isIdleTimerDisabled`) while a timer runs, and Guided Access friendliness (no links that leave the app). Limiting it to the shared device needs the configuration from phase 4b.

## Phase 3 — zweef.app
- [x] `ZweefAPI` protocol + `ZweefClient` (URLSession, async/await, Codable) + `FakeZweefAPI`.
- [x] Capture real JSON from accounts, material and hours as anonymised fixtures. Still open: the POST response, which needs a registration in a live club. `periods.json` 404s and `club.json` 500s — see `docs/zweef-api.md`.
- [x] Mapping WorkSession → POST body (`docs/zweef-api.md`).

## Phase 4 — Sync
- [ ] `SyncEngine` actor as described in `docs/sync.md` (triggers, backoff, dedup, rejected).
- [x] ~~Photo cache~~ — dropped: `accounts.json` carries no photo for any member, so there is nothing to cache and avatars are always initials.
- [ ] Register the BGAppRefreshTask.
- [ ] Tests with FakeZweefAPI (timeouts, 4xx, duplicate triggers).

## Phase 4b — Configuration
- [ ] `KeychainStore`, `AppConfiguration` (UserDefaults), managed-configuration reader.
- [ ] Setup assistant (docs/configuration.md), including "Test connection" and the club-name field (ADR 0012; the policy and storage are done, the screen is not).
- [ ] Settings screen behind the admin code (long-press the title), all values editable, connection tested before saving.
- [ ] `ProxyTransport` and `DirectTransport` behind `ZweefAPI`.
- [ ] Configurable task list (TaskDefinition), seeded from the catalog in the setup language.
- [ ] Reporting language in `AppSettings` and in the setup, used by `RegistrationDescription`.

## Phase 5 — Proxy
- [ ] Deploy the Cloudflare Worker from `proxy/`; secrets `ZWEEF_API_KEY`, `CLUB`, `DEVICE_TOKENS`.
- [ ] Documentation for clubs: deploying the proxy and creating tokens (proxy/README.md).

## Phase 6 — Finishing touches
- [ ] VoiceOver labels, Dynamic Type, contrast.
- [ ] Translations: fill `nl` and `fr` in the catalog, have a native speaker read each, and check that no key is missing or stale.
- [ ] Localisation pass in French (the longest language) at the largest text size: no truncated buttons, no clipped capsules.
- [ ] Rotation pass on both devices: no clipping, no layout jumps, nothing hidden behind the floating bar or a safe area.
- [ ] TestFlight / Apple Business Manager rollout.
- [ ] Test at the club: three members of different ages, one day without internet, on the workshop iPad and on a phone.
