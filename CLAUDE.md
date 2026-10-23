# Winter — iPhone and iPad app for maintenance hours

**Winter** is generic: usable by any club that uses zweef.app. Members log their maintenance hours with start/stop, without logging in — usually on a shared iPad in the club's workshop, and just as well on a phone. Everything is stored locally and, as soon as there is a connection, synced to zweef.app (GlidingApp) as *maintenance hours*.

## Read first
Full index: `docs/README.md`.
- `docs/architecture.md` — modules, responsibilities, concurrency, error handling, testing
- `docs/decisions/` — ADRs: why the choices were made the way they were (changing one = a new ADR)
- `docs/glossary.md` — terms in English, Dutch and French ↔ the code names
- `docs/configuration.md` — open source: setup assistant, in-app settings, tokens, MDM
- `docs/spec.md` — functional specification and every decision
- `docs/design.md` — screens, components, Liquid Glass, colours, copy
- `docs/data-model.md` — SwiftData models
- `docs/sync.md` — sync engine (offline-first, retries, dedup)
- `docs/zweef-api.md` — zweef.app endpoints and field mapping
- `PLAN.md` — build plan; work through it top to bottom and tick items off
- `mockups/*.dc.html` — the mockup source files (reference for layout, sizes and colours; they do not run standalone, they need the design-canvas runtime)

## Settled decisions (do not change without discussion)
- **Platform**: native iOS/iPadOS 26, SwiftUI, Swift 6 strict concurrency, SwiftData. One universal app for iPhone and iPad, all orientations, no orientation locks. Layout follows the size classes, never the device model or a screen size. The iPad 11" in landscape (1194×834 pt) is the reference design; compact layouts are derived from it.
- **One device, one set of sessions**: running timers and the day overview are about the device they live on. No syncing of running timers between devices.
- **Look & feel**: iOS 26 HIG. Liquid Glass on the navigation/control layer (toolbar, sheets, buttons) and on the member tiles, which are the home screen's buttons (ADR 0014). Other content (lists, cards) stays opaque. System font, system colours, inset grouped lists.
- **No login** for members. Members pick their name; no PIN for everyday use. Only the settings screen sits behind an admin code. Checking and corrections happen in zweef.app by the board (registrations arrive with status `in_aanvraag`).
- **Fully usable offline**. Starting, stopping and closing the day work without a network. Internet at the club is unreliable; syncing happens automatically whenever there is a connection.
- **Two taps** to start (name → Start) and two to stop (card → Stop and save). Picking a task and an aircraft is optional.
- **No** voice notes/dictation, **no** free-text field, **no** CSV export.
- **Closing the day** is open to everyone, but only when no timers are running. Anyone may stop someone else's forgotten timer. At the closing time (configurable, 21:00 suggested) the app stops running timers automatically and flags them "stopped automatically".
- **API key**: the app talks to zweef.app directly, with the club's API key in the Keychain (ADR 0013). There is no proxy and no device token. The key opens the club's whole account, so the setup and settings warn about it and a lost device means rotating the key — see `SECURITY.md`.
- **Open source** (MIT). Nothing club-specific or secret in the code or the repository. The club schema, the API key, the club name, the closing time and the tasks are configured in a setup assistant on first launch, and can be changed later in an in-app settings screen behind an admin code. The members and aircraft come from zweef.app (`accounts.json`, `material.json`); the club name too when `GET /club.json` works, and typed in the setup when it does not (ADR 0012). Secrets only in the Keychain. Optionally through MDM (Managed App Configuration).
- **Languages**: the app ships in English, Dutch and French only. `en` is the String Catalog's source language (literals in the code are English), `nl` and `fr` are translations. The app follows the system language; no language picker. Text sent to zweef.app uses the club's reporting language, not the member's. Code, identifiers, commits and all documentation in English.

## Architecture in brief
```
SwiftUI views ──▶ ViewModels (@Observable, @MainActor)
                    │
                    ▼
            SessionStore (SwiftData)  ◀── AutoStopService (closing time)
                    │
                    ▼
            SyncEngine (actor) ──▶ ZweefAPI ──▶ ZweefTransport (X-API-KEY from the Keychain) ──▶ admin.gliding.app/club/{club}/api
                    ▲
            NWPathMonitor + BGAppRefreshTask + a timer while the app is active
```

## Conventions
- Folders: `App/`, `Features/<Screen>/`, `Domain/` (models, rules), `Data/` (SwiftData, ZweefClient, SyncEngine), `DesignSystem/` (glass components, colours, Avatar), `Configuration/` (setup, settings, Keychain, managed config).
- Domain rules (closing time, short session, duration → decimal hours) as pure functions with unit tests (Swift Testing).
- Network code testable through a `ZweefAPI` protocol with a fake.
- No third-party dependencies unless genuinely necessary.
- Previews for every screen with fake data (the same sample members as the mockups), on an iPad in landscape and an iPhone in portrait.
- Documentation: public types and non-trivial functions get a DocC comment (`///`) that explains the *why*. Update `docs/` in the same change as the behaviour, and add a line to `CHANGELOG.md`.
- Commits: Conventional Commits in English (see `CONTRIBUTING.md`).

## Open questions (see also docs/spec.md)
- Why does `GET /club.json` answer 500 and `GET /maintenance-hours/periods.json` answer 404? And how is the period found for a brand-new maintenance period?
- The exact closing time; can the workshop device get wired wifi or its own 4G/5G connection?

Answered on 18 October 2026 by checking a real club (`docs/zweef-api.md`): `accounts.json` has **no** photo field, so avatars are always initials; `category` is `""`, not `"Maintenance"`; `status` goes `in_aanvraag` → `geaccepteerd`; the POST returns the whole stored record, and `user_name` is free text that zweef.app does not check against `user_id`.

## Links
(The analysis and mockups are the author's private links; they are not needed in order to contribute.)
- Analysis (Claude Docs): https://claude.ai/code/artifact/25729b6f-a068-4ab4-8073-5bc762c6b3c2
- Mockups (design canvas): https://claude.ai/artifact/XMfZ6e3Hj5xbwkNHAXixna
- zweef.app API: https://documenter.getpostman.com/view/25434528/2s8ZDX5PRi
