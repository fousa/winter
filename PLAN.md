# Build plan

Work phase by phase; after each phase, make sure the app builds and the tests pass.

## Phase 0 — Project
- [ ] Xcode project "Winter" (iOS/iPadOS 26, SwiftUI, Swift 6, universal iPhone + iPad, all orientations). Preferably generated with XcodeGen (`project.yml`) so Claude Code can manage it.
- [ ] Folder structure as described in CLAUDE.md; String Catalog with `en` as the source language plus `nl` and `fr`.
- [ ] Test target with Swift Testing.

## Phase 0b — Open source
- [ ] Git repository with README, LICENSE, .gitignore, `Config/*.xcconfig` (no secrets).
- [ ] A check in CI or pre-commit that no tokens or keys end up in commits (e.g. gitleaks).

## Phase 1 — Domain and storage
- [ ] SwiftData models from `docs/data-model.md`.
- [ ] Domain rules as pure functions + tests (duration, decimal hours, flags, closing time, canCloseDay, description).
- [ ] `SessionStore`: start, stop (including someone else's timer), undo within 10 s, close the day, auto-stop.
- [ ] Seed with sample members for previews and first tests.

## Phase 2 — UI with fake data
- [ ] DesignSystem: `Avatar` (photo or initials), glass bar, stat card, flag badge, plus the spacing scale with a compact and a regular value.
- [ ] Home screen including search, letter index, "Often here", and the "Working now" bar (1–3 large, 4+ compact).
- [ ] Start and Stop sheets, confirmations with auto-dismiss and undo, haptics.
- [ ] Close day.
- [ ] Sync screen.
- [ ] Compact variants per `docs/design.md`: the adaptive home grid, the single-column Stop sheet, confirmations as sheets, the collapsed floating bar, Settings as one `Form`. No `userInterfaceIdiom` or `UIScreen.main` anywhere.
- [ ] Previews per screen for iPad landscape, iPhone portrait, iPhone landscape (compact height) and the largest accessibility text size.
- [ ] Screen-stays-on logic (`isIdleTimerDisabled`) and Guided Access friendliness (no links that leave the app), only for the shared device.

## Phase 3 — zweef.app
- [ ] `ZweefAPI` protocol + `ZweefClient` (URLSession, async/await, Codable) + `FakeZweefAPI`.
- [ ] Capture real JSON from accounts, material, periods and a POST response as fixtures (using a test API key).
- [ ] Mapping WorkSession → POST body (`docs/zweef-api.md`).

## Phase 4 — Sync
- [ ] `SyncEngine` actor as described in `docs/sync.md` (triggers, backoff, dedup, rejected).
- [ ] Photo cache (download, store in Application Support, clean up).
- [ ] Register the BGAppRefreshTask.
- [ ] Tests with FakeZweefAPI (timeouts, 4xx, duplicate triggers).

## Phase 4b — Configuration
- [ ] `KeychainStore`, `AppConfiguration` (UserDefaults), managed-configuration reader.
- [ ] Setup assistant (docs/configuration.md), including "Test connection".
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
