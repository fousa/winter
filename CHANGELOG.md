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
- Proxy (Cloudflare Worker) for the zweef.app API key.

- Xcode project generated with XcodeGen from `project.yml`; universal iPhone and iPad app target, a Swift Testing target, and a String Catalog with `en`, `nl` and `fr`.
- Domain rules as pure functions with tests: session duration and flags, decimal hours, duration text per language, the closing time (including both daylight-saving nights), and the zweef.app registration description with its dedup tag.
- SwiftData models and `SessionStore`: start, stop (also someone else's timer), undo, close the day including earlier unclosed days, and automatic stop at the closing time.
- Sample club data for previews and tests.
- The screens, in both size classes: home (member grid, search, letter index, "Often here", the "Working now" bar), the start and stop sheets, the confirmations with undo, closing the day, and the sync overview. Design system components (`MemberAvatar`, glass bar and card, stat card, flag badge) and `LayoutMetrics`, which resolves the mockups' sizes from the size classes.
- Member list rules in `Domain` with tests: diacritics-insensitive search, letter sections, and the "often here" ranking.
- All 84 UI strings in the String Catalog, translated into Dutch and French.
- Sync engine: an actor that stops forgotten timers, refreshes members and aircraft every six hours, and uploads closed days — with per-session backoff plus jitter, a dedup check that recognises an upload which already arrived, rejections that wait for a human, and one run at a time however many triggers arrive. Triggered by connectivity returning, the app becoming active, closing the day, "try again now" and a background refresh.
- The club name can be typed in the setup, because `GET /club.json` answers 500 for a real club (ADR 0012). A typed name is never overwritten by a later refresh.
- zweef.app client: `ZweefAPI` with `ZweefClient` (URLSession, async/await) and `FakeZweefAPI`, `ProxyTransport` and `DirectTransport`, typed errors that say whether to retry, and the `WorkSession` → registration mapping. Anonymised fixtures captured from a real club.

### Changed
- All repository documentation is written in English.
- Verified the zweef.app API against a real club: `accounts.json` has no member photo (avatars are always initials, and the photo cache is dropped), `category` is sent empty rather than `"Maintenance"`, the active period is read from `current/hours.json` because `periods.json` answers 404, and `club.json` answers 500 so the club name may be unavailable.
- No CI: tests and the secrets check are run locally before merging (ADR 0011).
- `Config/Shared.xcconfig` defaults `BUNDLE_ID_PREFIX` to `com.example`, so a fresh clone builds without a `Local.xcconfig`.
