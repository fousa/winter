# Architecture

This document describes how the app is put together technically: which modules exist, who is responsible for what, how data flows, how concurrency and errors are handled, and how it is all tested. For the *what* and *why*, see [spec.md](spec.md) and the [ADRs](decisions/README.md).

## Goals that drive the architecture
1. **Never lose hours.** Every action is stored locally straight away. The network is never a precondition for recording something.
2. **Offline-first.** The local database is the source of truth for the device. zweef.app is the destination, not the source.
3. **Generic and secret-free.** No club-specific values or secrets in the code; the club name, members and aircraft come from zweef.app. Everything else comes from the configuration on the device.
4. **Testable without a network and without zweef.app.** Every external dependency sits behind a protocol.
5. **Simplicity.** One app target, no third-party dependencies, no backend of our own at all (ADR 0013).

## Overview
```
┌──────────────────────────── Winter app ────────────────────────────┐
│                                                                    │
│  Features (SwiftUI views + @Observable view models, @MainActor)    │
│    Home · StartSheet · StopSheet · Confirmation · Sync             │
│    Setup · Settings                                                │
│                │                                                   │
│                ▼                                                   │
│  Domain (pure Swift, no UI, no I/O)                                │
│    SessionRules · ClosingTime · Flags · HoursFormatter             │
│                │                                                   │
│                ▼                                                   │
│  Data                                                              │
│    SessionStore ──── SwiftData (Member, WorkSession, ...)          │
│    SyncEngine (actor) ── ZweefAPI ── ZweefTransport ──────────┐    │
│    AutoStopService · ConnectivityMonitor · BackgroundTasks    │    │
│                                                               │    │
│  Configuration                                                │    │
│    AppConfiguration (UserDefaults) · SecretStore (Keychain)   │    │
│    ManagedConfiguration (MDM) · AdminCodeVerifier             │    │
└──────────────────────────────────┼─────────────────────────────────┘
                                   │ HTTPS, X-API-KEY from the Keychain
                                   ▼
                    admin.gliding.app/club/{club}/api
```

## Modules and responsibilities

The Xcode project is generated from `project.yml` with XcodeGen and is not in
git, so adding a file means adding a file — not resolving a conflict in a
project file. One app target, one test target.

### `App/`
- `WinterApp`: the entry point. Builds the `ModelContainer` and the services, and injects them through the SwiftUI environment.
- Decides which root screen is shown: **Setup** while the configuration is incomplete, otherwise **Home**.
- Registers the `BGAppRefreshTask` and wires `scenePhase` changes to sync and auto-stop.

### `Features/`
One folder per screen, containing the view, the view model and the previews.

| Feature | Responsibility |
|---|---|
| `Home` | Member list with the "Working now" section, search, letter index, the sync status button, the hidden entrance to Settings |
| `StartSheet` | Confirming that the right member is starting; already working → redirect to stopping |
| `StopSheet` | Showing the running time, picking what the work was on (zweef.app's material), a comment, stopping |
| `Confirmation` | Confirmation after a stop, with "Undo"; closed by tapping outside it |
| `Sync` | Sync status, pending/rejected/uploaded sessions, and the "Upload" button |
| `Setup` | The setup assistant on first launch |
| `Settings` | Settings behind the admin code |

Rules for features:
- Views contain no logic beyond presentation. Decisions ("may the day be closed?", "who is often here?") come from `Domain`.
- View models are `@Observable` and `@MainActor`, and talk to `SessionStore` and `SyncEngine`, never to the network directly.
- Every screen has previews with sample data (see [design.md](design.md)).

How that splits in practice, now that the screens exist:

| Concern | Where | Why |
|---|---|---|
| Reading stored data | `@Query` in the view | SwiftData already pushes a started or stopped session into the view; a view model holding a copy would only add a way to be stale |
| Deriving lists (search, letter sections, "often here") | `Domain` (`MemberDirectory`) | Pure functions on a `MemberListItem` protocol, so the ranking is unit-tested instead of eyeballed, and `Domain` still does not import SwiftData |
| Screen state (search text, which sheet, the undo offer) | `@Observable` model (`HomeModel`) | The part `@Query` cannot hold |
| Writing | `SessionStore` | One audited door in front of the sessions (ADR 0001) |

`SessionStore` holds no state beyond its dependencies, so a view makes one from
its `modelContext` where it needs to write. That keeps the model types free of
"which context am I on" questions and out of initialisation order.

### `Domain/`
Pure functions and value types, without SwiftData, SwiftUI or networking. That makes them fully unit-testable.
- `SessionRules`: `isShortSession`, `isLongSession`, `flags(for:)`.
- `MemberDirectory`: search (diacritics-insensitive), letter sections, and the "often here" ranking.
- `ClosingTime`: computes the automatic stop time for a session.
- `HoursFormatter`: duration ↔ "2 h 18 min" ↔ decimal hours (2.3).
- `RegistrationDescription`: builds the `description` field for zweef.app: the times and the member's comment (ADR 0019).

### `Data/`
- `SessionStore` (`@MainActor`): the only place that creates or modifies a `WorkSession`. Methods: `start(member:)`, `stop(session:material:comment:by:)`, `undo(_:)`, `applyAutoStop(now:)`. Saves immediately after every mutation.
- `SyncEngine` (`actor`): see [sync.md](sync.md). Creates its own `ModelContext` per run, on its own executor, so nothing is shared with the UI and nothing stale survives between runs. Runs one at a time: actors are reentrant, so a flag guards it and extra triggers merge into a single follow-up.
- `SyncCoordinator` (`@MainActor`, `@Observable`): the only thing the screens talk to about syncing. Owns the triggers — connectivity returning, the app becoming active and the background task (which only refresh and auto-stop), and "Upload" (the only one that sends hours, ADR 0015) — and publishes `isSyncing`, `isConnected` and the last outcome.
- `ZweefAPI` (protocol) with `ZweefClient` (the real one) and `FakeZweefAPI` (tests, previews). Six calls, only one of which writes. There is no photo cache: zweef.app returns no member photos, so avatars are initials ([zweef-api.md](zweef-api.md)).
- `ZweefTransport`: builds the requests, with the club schema in the URL and the API key in the header. One concrete type, because there is one way to connect (ADR 0013).
- `AutoStopService`: calls `SessionStore.applyAutoStop` when the app becomes active and every minute in the foreground. Separate from the sync engine because it must work with no network at all.
- `ConnectivityMonitor`: a wrapper around `NWPathMonitor` exposing an `AsyncStream<Bool>`, behind a `ConnectivityReporting` protocol so a preview can be offline on purpose. A sync fires when the path *becomes* satisfied, not on every update.

### `Configuration/`
- `AppConfiguration` (`@MainActor`, `@Observable`): typed access to the non-secret settings (UserDefaults), and whether the device is configured at all.
- `SecretStore`: a protocol with `KeychainSecretStore` (the real one) and `InMemorySecretStore` (tests, previews). Two secrets: the API key and the admin code's salted hash. The Keychain needs a signed app with an entitlement, and these rules deserve tests that run anywhere.
- `ManagedConfiguration`: MDM values, parsed once into typed fields so it is a plain `Sendable` value. Takes precedence and is read-only.
- `AdminCodeVerifier`: salt + SHA-256 in the Keychain, with a lockout that grows after wrong attempts. Throws rather than returning a result, so a caller cannot forget to look at the answer.
- `ConnectionSettings` / `ConnectionProvider`: a `Sendable` snapshot of the connection, and the holder the sync engine reads on every run. The connection changes while the app runs — setup creates it, settings edit it — so an engine that captured an API at launch would keep using a key the club has rotated.
- `ConnectionTester`: tries a connection without saving it, using `current/hours.json` rather than the `periods.json` that answers 404.
- See [configuration.md](configuration.md) for every key.

### `DesignSystem/`
Reusable components in the Liquid Glass style: `MemberAvatar`, `GlassBar`, `GlassCard`, `StatCard`, `FlagBadge`. Plus `LayoutMetrics`, the sizes resolved from the size classes and put in the environment — the one place that knows the numbers from the mockups, so no view reaches for `UIScreen` or the device idiom. See [design.md](design.md).

### Localisation
The app ships in English, Dutch and French ([ADR 0010](decisions/0010-three-languages-en-nl-fr.md)).

- One String Catalog (`Localizable.xcstrings`) with `en` as the source language and `nl` and `fr` as translations. Literals in the code are English.
- Views use `LocalizedStringResource`/`Text` with placeholders; `Domain` never returns a user-facing sentence, only values (minutes, flags as an enum) that the view formats.
- `HoursFormatter` and anything date-related take a `Locale`, so the formatting is testable per language instead of depending on the simulator's region.
- `RegistrationDescription` is the one place that formats text for zweef.app; it is the times and a comment, with nothing to translate (ADR 0019).
- Search stays diacritics- and case-insensitive through `String.compare` with the right options, not by stripping characters by hand.

## Key flows

### Start
```
Home (tap a member) → StartSheet → SessionStore.start(member)
   → WorkSession(status: .running) saved
   → Home, with an Undo chip (10 s)
```

### Stop
```
Home (tap a tile in "Working now") → StopSheet → SessionStore.stop(session, material, comment)
   → status .completed, syncState .local
   → Confirmation (Undo, until tapped away) → Home
```

### Uploading
```
Sync screen → "Upload" → SyncEngine.requestSync(.upload)
   → POST every completed .local/.ready session → .uploaded
   → (offline or failed) stays waiting until the next tap
```

## Concurrency
- Swift 6 strict concurrency is on; no `@unchecked Sendable` without a comment explaining why.
- The UI and `SessionStore` run on the `MainActor`. Mutations are small and fast.
- `SyncEngine` is an `actor` with its own `ModelContext`; it loads sessions by id and never passes model objects across actor boundaries.
- One sync run at a time: new triggers during a run are merged into a single follow-up run.
- Timers (the running duration in the UI) use `TimelineView(.periodic(from:by: 1))`, not a `Timer` of their own.

## Error handling
| Kind of error | Behaviour |
|---|---|
| Saving to SwiftData fails | An assertion in debug; in release a clear message and the action is not shown as succeeded. Should not happen in practice. |
| No network | No message; the status is visible through the status button and the sync screen |
| 401/403 from zweef.app | Syncing stops, the sync screen shows "Connection refused: check the API key in Settings" |
| 4xx on a registration | The session becomes `.rejected` with the reason, with no automatic retry |
| 5xx or a timeout | The session stays waiting; the next tap on "Upload" tries again |
| Incomplete configuration | The app shows the setup assistant |

Errors are logged with `os.Logger` (subsystem = the bundle id, categories `sync`, `store`, `config`). Never log tokens, keys or personal data; use `privacy: .private` for names.

## Testing
| Layer | How |
|---|---|
| Domain | Swift Testing, pure functions, parametrised tests for edge cases (midnight, the closing time, daylight saving) |
| SessionStore | An in-memory `ModelContainer` |
| SyncEngine | A `FakeZweefAPI` that simulates success, timeouts, 4xx and 5xx; a controlled clock |
| ZweefClient | A `URLProtocol` stub with JSON fixtures (anonymised) |
| UI | Previews for every screen, in both size classes and in French; a few UI tests for start → stop → close |
| Localisation | Every language has the same set of keys (a test that fails on a missing or stale translation); formatting tests per locale for durations, dates and decimal hours |

Time is always injectable (`Clock`/`now: () -> Date`), so that the closing time and the undo windows are testable.

## Deliberately not used
- No backend or database of our own (ADR 0013).
- No CloudKit sync between devices. Every device keeps its own sessions and uploads them itself; running timers are not shared ([ADR 0009](decisions/0009-universal-app-iphone-and-ipad.md)).
- No third-party networking or DI libraries.
