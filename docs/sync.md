# Sync engine (offline-first)

Internet at the club is unreliable. The app always works locally; syncing is a background process that keeps trying on its own.

## Triggers
- `NWPathMonitor`: the path becomes `.satisfied` → sync.
- The app becomes active (`scenePhase == .active`) → sync.
- "Close day" → sync.
- "Try again now" on the sync screen → sync (ignoring backoff).
- `BGAppRefreshTask` (best effort; the system decides when).
- While the app is in the foreground and something is waiting: retry with exponential backoff (30 s, 1 m, 2 m, 5 m, max 15 m) plus jitter.

## The order of one sync run (`SyncEngine` is an `actor`, one run at a time)
1. **Apply auto-stop** (running timers past the closing time).
2. **Refresh** (at most once every 6 h, or when the cache is empty): club → update the club name; accounts → upsert members; photos → download (only changed or missing ones); material → aircraft; periods → the active period.
3. **Upload** every session with `syncState == .ready` (and completed `.local` ones older than 24 h):
   - Set `.uploading`, POST, and on success `.uploaded` + `remoteId` + `uploadedAt`.
   - Network error/timeout/5xx → back to `.ready`, `attempts += 1`, `lastError`.
   - Unclear whether the POST arrived (a timeout after sending) → on the next run, do a dedup check first (see zweef-api.md).
   - 4xx (validation, member inactive, period closed) → `.rejected` with the reason; no automatic retry. Visible under "Needs attention" with a "Retry" button.
4. Update `SyncLog` and `AppSettings.last*`.

## What the sync screen shows
- The connection status (online / no connection) and the time of the last attempt.
- The number of pending sessions and the total pending hours.
- The last successful upload, the last refresh of club, members and photos, and the active period.
- **Needs attention**: `.rejected` sessions with their reason.
- **Waiting to upload**: per day (`.local`/`.ready`), with the number of sessions, the total, and whether the day is closed.
- **Recently uploaded**: the most recent days with `.uploaded`.
- A "Try again now" button.

The status button on the home screen shows the number of pending sessions (orange when there is no connection, a green checkmark when everything is uploaded).

## Testing
- A `ZweefAPI` protocol plus a `FakeZweefAPI` that can simulate errors, timeouts and 4xx.
- Tests for: retry/backoff, dedup after a timeout, the rejected flow, auto-stop before upload, and no double upload on parallel triggers.
