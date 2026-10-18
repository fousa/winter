# Build plan

Work phase by phase; after each phase, make sure the app builds and the tests pass.

## Phase 0 — Project
- [ ] Xcode project "Winter" (iPadOS 26, SwiftUI, Swift 6, iPad only, landscape only). Preferably generated with XcodeGen (`project.yml`) so Claude Code can manage it.
- [ ] Folder structure as described in CLAUDE.md; String Catalog with `nl-BE`.
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
- [ ] DesignSystem: `Avatar` (photo or initials), glass bar, stat card, flag badge.
- [ ] Home screen including search, letter index, "Often here", and the "Working now" bar (1–3 large, 4+ compact).
- [ ] Start and Stop sheets, confirmations with auto-dismiss and undo, haptics.
- [ ] Close day.
- [ ] Sync screen.
- [ ] Screen-stays-on logic (`isIdleTimerDisabled`) and Guided Access friendliness (no links that leave the app).

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
- [ ] Configurable task list (TaskDefinition) with sensible defaults.

## Phase 5 — Proxy
- [ ] Deploy the Cloudflare Worker from `proxy/`; secrets `ZWEEF_API_KEY`, `CLUB`, `DEVICE_TOKENS`.
- [ ] Documentation for clubs: deploying the proxy and creating tokens (proxy/README.md).

## Phase 6 — Finishing touches
- [ ] VoiceOver labels, Dynamic Type, contrast.
- [ ] TestFlight / Apple Business Manager rollout.
- [ ] Test at the club: three members of different ages, one day without internet.
