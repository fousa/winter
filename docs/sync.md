# Sync engine (offline-first)

Internet at the club is unreliable. The app always works locally. Hours leave the device only when someone taps "Upload" on the sync screen ([ADR 0015](decisions/0015-manual-upload.md)); everything else the engine does in the background is about bringing the members in, not sending hours out.

## Triggers
- "Upload" on the sync screen → a run that **uploads**. The only one.
- `NWPathMonitor`: the path becomes `.satisfied` → a run without uploading.
- The app becomes active (`scenePhase == .active`) → a run without uploading.
- `BGAppRefreshTask` (best effort; the system decides when) → a run without uploading.

There is no retry and no backoff. An upload runs because a person is standing at the device; if it fails, the screen says so and the next tap tries again.

## The order of one sync run (`SyncEngine` is an `actor`, one run at a time)
1. **Apply auto-stop** (running timers past the closing time).
2. **Refresh** (at most once every 6 h, or when the cache is empty; `RefreshPolicy`): club → update the club name if `club.json` answers at all; accounts → upsert members (twice: active, then `?inactive=1`); material → aircraft; the active period → read off `current/hours.json`, because `periods.json` 404s. No photos: there are none to fetch ([zweef-api.md](zweef-api.md)).
3. **Upload** — only for "Upload" — every completed session with `syncState` `.local` or `.ready`. Running sessions are not finished and stay. `.rejected` ones are not sent again.
   - Set `.uploading`, POST, and on success `.uploaded` + `remoteId` + `uploadedAt`.
   - Network error/timeout/5xx → back to `.ready`, `attempts += 1`, `lastError`.
   - Unclear whether the POST arrived (a timeout after sending) → on the next upload, first look for a registration with the same member, day, hours, aircraft and description (see zweef-api.md).
   - 401/403 → the run stops; the other sessions are not touched.
   - 4xx (validation, member inactive, period closed) → `.rejected` with the reason. Visible under "Needs attention".
4. Update `SyncLog` and `AppSettings.last*` ("last attempt" only on an upload).

## What the sync screen shows
- The connection status (online / no connection), a line saying why hours are waiting, and the time of the last upload attempt.
- The number of pending sessions and the total pending hours.
- The last successful upload, the last refresh of club and members, and the active period.
- **Needs attention**: `.rejected` sessions with their reason.
- **Waiting to upload**: every finished session not yet in zweef.app (`.local`/`.ready`), as tiles.
- **Recently uploaded**: the sessions with `.uploaded`.
- A prominent "Upload" button ("Upload 2 sessions"), disabled while nothing waits.

The status button on the home screen shows the number of pending sessions (orange when there is no connection, a green checkmark when everything is uploaded).

## Testing
- A `ZweefAPI` protocol plus a `FakeZweefAPI` that can simulate errors, timeouts and 4xx.
- Tests for: automatic runs never uploading, finished sessions going up with "Upload" while running ones stay, dedup after a timeout, the rejected flow, auto-stop before upload, and no double upload on parallel triggers.
