# Functional specification

## Purpose
Members log their maintenance hours on a shared device in the hangar/workshop, without logging in, with as few taps as possible. The hours end up in zweef.app as maintenance-hours registrations, where the board approves them.

## Roles
| Role | What | Where |
|---|---|---|
| Member | Starts/stops their own session, optionally picks a task and an aircraft, closes the day if they are the last to leave | iPhone or iPad |
| Board / maintenance officer | Approves registrations, corrects them | zweef.app |

## Environment
The app is one universal app for iPhone and iPad, in any orientation ([ADR 0009](decisions/0009-universal-app-iphone-and-ipad.md)).

- **The shared workshop device** is the main setup: usually an iPad in landscape, mounted on a wall or a stand, in Guided Access. The screen stays on while the app is in use (`isIdleTimerDisabled = true` as long as a timer is running or the app was used recently); it may dim after two minutes of inactivity.
- **A personal iPhone or iPad** is the same app with the same flows, for a club without a shared iPad or for a member who logs their own hours. No Guided Access and no screen-on behaviour beyond a running timer.
- Internet is unreliable or absent. The app must work fully offline.

### Several devices
Each device has its own local database and its own device token, and uploads its own sessions.

- A running timer is only visible — and can only be stopped — on the device it was started on. zweef.app has no concept of a running timer, so there is nothing to sync it through.
- Closing the day closes the sessions on *that* device. Another device can still have open sessions of its own; it closes them itself.
- "Working now", the day overview and the pending-upload counts are therefore always about the current device. The copy says so explicitly.
- Once uploaded, every device's hours end up in the same place in zweef.app, where the board sees the full picture.

## Screens (see docs/design.md for the layouts per size class)
0. **Setup assistant** (first launch) and **Settings** (hidden, behind the admin code) — see docs/configuration.md.
1. **Home** — member list (often here + all members, search, letter index), sync status button, "Close day" button, floating "Working now" bar.
2. **Start** (sheet) — photo + name, "Start", "That's not me".
3. **Start confirmation** — glass card, "Undo" (10 s), dismisses itself after 3 s.
4. **Stop** (sheet) — the person and the running timer, the task list and the aircraft picker, "Stop and save".
5. **Stop confirmation** — duration, task/aircraft, "Undo", dismisses itself after 3 s.
6. **Close day** — overview of the day, flagged sessions, "Close day".
7. **Synchronisation** — connection, pending/rejected/uploaded sessions, "Try again now".

## Flows

### Starting
1. The member taps their tile (home screen).
2. The "Start" sheet appears → tap "Start".
3. The session is saved immediately (`status = .running`, `start = now`).
4. A confirmation with "Undo" for 10 s (which deletes the session entirely).
- The member already has a running session → instead the sheet shows "You have been working since 09:12" with a "Stop" button (which leads to Stopping).

### Stopping
1. Someone taps a card in "Working now" (their own timer or someone else's).
2. The "Stop" sheet shows the person, the start time and the running duration.
3. Optional: pick a task from the club's task list (default: Glider, Winch, Hangar and workshop, Grounds, Clubhouse, Something else; configurable). For tasks with `asksForAircraft` the aircraft picker appears (from `material.json`, plus "Other").
4. "Stop and save" → `stop = now`, `status = .completed`, `syncState = .local`.
5. A confirmation with "Undo" (10 s, which puts the session back to running).
- Stopping someone else's timer is allowed. The session gets `stoppedByOther = true` and the flag "stopped by someone else" (in screen 6 and in `description`, see zweef-api.md).

### Closing the day
- The button is always visible in the top right of the home screen.
- Timers running → the button is disabled (glass, grey, with a lock).
- No running timers → the button is active and opens screen 6.
- Screen 6 shows, per session on this device: member, times, task/aircraft, duration, flags. Including sessions from earlier days that were never closed ("Also included").
- "Close day" sets every completed session of that day (or days) to `readyForUpload` and triggers a sync. Works offline.
- **If nobody closes the day**: sessions are kept. At the next closing, every open day is included. The home screen shows a reminder "3 days not closed" (a badge on the status button).

> Implementation choice: only sync sessions that are `readyForUpload` (after closing), plus — as a safety net — completed sessions older than 24 h that were never closed. This keeps uploads "per day" as requested, without hours getting stuck.

### Stopping automatically
- A configurable closing time (21:00 by default, local time).
- Running timers are stopped with `stop = the closing time` (not `now`) and `autoStopped = true`.
- Runs: when the app becomes active, on background refresh, and from a timer while the app is in the foreground. Also at app launch, for timers from previous days.

### Validation and flags
| Rule | Result |
|---|---|
| Duration < 5 min | A confirmation prompt when stopping ("Is 4 minutes right?"); flag "short session" |
| Duration > 10 h | Flag "long session" |
| Stopped automatically | Flag "stopped automatically" |
| Overlapping sessions for the same member | Impossible: a member can only have one running session |

Flags travel along in `description` to zweef.app and are shown in orange on screen 6.

### Language
- The app ships in English, Dutch and French, and nothing else ([ADR 0010](decisions/0010-three-languages-en-nl-fr.md)).
- It follows the system language. There is no language picker in the app; iOS's per-app language setting is the override.
- On a device set to any other language, the app falls back to English.
- Dates, times, durations and decimal hours follow the device locale.
- What the club typed itself (task labels) and what comes from zweef.app (club name, member names, aircraft) is shown as-is and never translated.
- Text that goes *to* zweef.app (the task label in `project`, the flags in `description`) uses the club's reporting language, not the language of the member who stopped the timer, so the board reads one consistent list.

### Club data
- The club name comes from zweef.app (`GET /club.json`): fetched during "Test connection" in the setup and on every refresh. Cached locally so it stays visible offline.
- The app is generic: no club name, members, aircraft or tasks in the code.

### Member list and photos
- On every successful sync: `GET /accounts.json` → upsert members (active/inactive), download photos and cache them locally (a file on disk, the path in the model).
- No photo → initials in a coloured circle (the colour derived deterministically from the id).
- "Often here": the top 5 members by number of sessions in the last 30 days, otherwise by last seen.
- Search on first and last name, diacritics-insensitive.

## Configuration (open source)
- On first launch: the setup assistant (connection, club, admin code). Without a complete configuration the rest of the app is unreachable.
- Changeable afterwards in the app: long-press the title → admin code → Settings. There you can change the proxy URL, the device token, the connection mode, the closing time, the tasks and the admin code, test the connection and refresh the members.
- A changed connection is tested first; on failure the old values stay active until you confirm.
- Pending sessions are kept when the connection changes; they go to the new connection.
- Details: docs/configuration.md.

## Out of scope
A login or PIN for members, managing hours on the device, free text, voice notes, CSV export, entering or editing hours after the fact on the device, syncing running timers between devices (see [ADR 0009](decisions/0009-universal-app-iphone-and-ipad.md)).

## Open questions
- Is there a photo URL in the accounts response?
- Allowed values for `category` / `project` / `status`, and the POST response.
- The closing time.
- Is wired wifi or a device with its own 4G/5G possible for the workshop?
