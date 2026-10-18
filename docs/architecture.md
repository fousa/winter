# Architecture

This document describes how the app is put together technically: which modules exist, who is responsible for what, how data flows, how concurrency and errors are handled, and how it is all tested. For the *what* and *why*, see [spec.md](spec.md) and the [ADRs](decisions/README.md).

## Goals that drive the architecture
1. **Never lose hours.** Every action is stored locally straight away. The network is never a precondition for recording something.
2. **Offline-first.** The local database is the source of truth for the device. zweef.app is the destination, not the source.
3. **Generic and secret-free.** No club-specific values or secrets in the code; the club name, members and aircraft come from zweef.app. Everything else comes from the configuration on the device.
4. **Testable without a network and without zweef.app.** Every external dependency sits behind a protocol.
5. **Simplicity.** One app target, no third-party dependencies, no backend of our own beyond the thin proxy.

## Overview
```
┌──────────────────────────── Winter app ────────────────────────────┐
│                                                                    │
│  Features (SwiftUI views + @Observable view models, @MainActor)    │
│    Home · StartSheet · StopSheet · Confirmation · CloseDay · Sync  │
│    Setup · Settings                                                │
│                │                                                   │
│                ▼                                                   │
│  Domain (pure Swift, no UI, no I/O)                                │
│    SessionRules · ClosingTime · Flags · HoursFormatter             │
│                │                                                   │
│                ▼                                                   │
│  Data                                                              │
│    SessionStore ──── SwiftData (Member, WorkSession, ...)          │
│    PhotoCache   ──── Application Support/Photos                    │
│    SyncEngine (actor) ── ZweefAPI ── Transport ──────────────┐     │
│    AutoStopService · ConnectivityMonitor · BackgroundTasks   │     │
│                                                              │     │
│  Configuration                                               │     │
│    AppConfiguration (UserDefaults) · KeychainStore           │     │
│    ManagedConfiguration (MDM) · AdminCodeVerifier            │     │
└──────────────────────────────────────────────────────────────┼─────┘
                                                               │ HTTPS
                     ┌─────────────────────────────────────────┴───┐
                     │ ProxyTransport            DirectTransport   │
                     ▼                                     │       │
          The club's proxy (Cloudflare Worker)             │       │
                     │  X-API-KEY                          │       │
                     ▼                                     ▼       │
          admin.gliding.app/club/{club}/api  ◀─────────────┘       │
```

## Modules and responsibilities

### `App/`
- `WinterApp`: the entry point. Builds the `ModelContainer` and the services, and injects them through the SwiftUI environment.
- Decides which root screen is shown: **Setup** while the configuration is incomplete, otherwise **Home**.
- Registers the `BGAppRefreshTask` and wires `scenePhase` changes to sync and auto-stop.

### `Features/`
One folder per screen, containing the view, the view model and the previews.

| Feature | Responsibility |
|---|---|
| `Home` | Member list, search, letter index, the "Working now" bar, the sync status button, the "Close day" button, the hidden entrance to Settings |
| `StartSheet` | Confirming that the right member is starting; already working → redirect to stopping |
| `StopSheet` | Showing the running time, picking a task/aircraft, stopping |
| `Confirmation` | Confirmation after start/stop, with "Undo" and auto-dismiss |
| `CloseDay` | Overview of the day and closing it |
| `Sync` | Sync status, pending/rejected/uploaded sessions, retrying |
| `Setup` | The setup assistant on first launch |
| `Settings` | Settings behind the admin code |

Rules for features:
- Views contain no logic beyond presentation. Decisions ("may the day be closed?") come from `Domain`.
- View models are `@Observable` and `@MainActor`, and talk to `SessionStore` and `SyncEngine`, never to the network directly.
- Every screen has previews with sample data (see [design.md](design.md)).

### `Domain/`
Pure functions and value types, without SwiftData, SwiftUI or networking. That makes them fully unit-testable.
- `SessionRules`: `canCloseDay`, `isShortSession`, `isLongSession`, `flags(for:)`.
- `ClosingTime`: computes the automatic stop time for a session.
- `HoursFormatter`: duration ↔ "2 h 18 min" ↔ decimal hours (2.3).
- `RegistrationDescription`: builds the `description` field for zweef.app, including the dedup tag.

### `Data/`
- `SessionStore` (`@MainActor`): the only place that creates or modifies a `WorkSession`. Methods: `start(member:)`, `stop(session:task:aircraft:by:)`, `undo(_:)`, `closeDay(_:)`, `applyAutoStop(now:)`. Saves immediately after every mutation.
- `SyncEngine` (`actor`): see [sync.md](sync.md). Uses its own (background) `ModelContext` through a `ModelActor`.
- `ZweefAPI` (protocol) with `ZweefClient` (the real one) and `FakeZweefAPI` (tests, previews).
- `Transport` (protocol) with `ProxyTransport` and `DirectTransport`: sets the right base URL and headers. `ZweefClient` does not know which mode is active.
- `PhotoCache`: downloads and stores profile photos, and returns local URLs.
- `AutoStopService`: calls `SessionStore.applyAutoStop` at app launch, when the app becomes active, every minute in the foreground, and in the background task.
- `ConnectivityMonitor`: a wrapper around `NWPathMonitor` that exposes an `AsyncStream<Bool>`.

### `Configuration/`
- `AppConfiguration`: typed access to the non-secret settings (UserDefaults).
- `KeychainStore`: reading/writing secrets (device token, API key, the hash of the admin code).
- `ManagedConfiguration`: reads MDM values; those take precedence and are read-only.
- `AdminCodeVerifier`: checks the admin code (hash + salt, with a delay after failed attempts).
- See [configuration.md](configuration.md) for every key.

### `DesignSystem/`
Reusable components in the Liquid Glass style: `MemberAvatar`, `GlassBar`, `StatCard`, `FlagBadge`, `PrimaryActionButton`. See [design.md](design.md).

## Key flows

### Start
```
Home (tap a member) → StartSheet → SessionStore.start(member)
   → WorkSession(status: .running) saved
   → Confirmation (Undo, 10 s) → Home
```

### Stop
```
Home (tap a card in the bar) → StopSheet → SessionStore.stop(session, task, aircraft, by: .self/.other)
   → status .completed, syncState .local
   → Confirmation (Undo, 10 s) → Home
```

### Closing the day and syncing
```
Home → CloseDay (only if SessionRules.canCloseDay) → SessionStore.closeDay
   → syncState .ready for every completed session of that day (or days)
   → SyncEngine.requestSync(reason: .dayClosed)
   → (online) POST per session → .uploaded   |   (offline) stays .ready, retried later
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
| 401/403 from the proxy or zweef.app | Syncing stops, the sync screen shows "Connection refused: check the token in Settings" |
| 4xx on a registration | The session becomes `.rejected` with the reason, with no automatic retry |
| 5xx or a timeout | Retry with backoff |
| Incomplete configuration | The app shows the setup assistant |

Errors are logged with `os.Logger` (subsystem = the bundle id, categories `sync`, `store`, `config`). Never log tokens, keys or personal data; use `privacy: .private` for names.

## Testing
| Layer | How |
|---|---|
| Domain | Swift Testing, pure functions, parametrised tests for edge cases (midnight, the closing time, daylight saving) |
| SessionStore | An in-memory `ModelContainer` |
| SyncEngine | A `FakeZweefAPI` that simulates success, timeouts, 4xx and 5xx; a controlled clock |
| ZweefClient | A `URLProtocol` stub with JSON fixtures (anonymised) |
| UI | Previews for every screen; a few UI tests for start → stop → close |

Time is always injectable (`Clock`/`now: () -> Date`), so that the closing time and the undo windows are testable.

## Deliberately not used
- No backend or database of our own beyond the proxy.
- No CloudKit sync between devices. Every device keeps its own sessions and uploads them itself; running timers are not shared ([ADR 0009](decisions/0009-universal-app-iphone-and-ipad.md)).
- No third-party networking or DI libraries.
