# Functional specification

## Purpose
Members log their maintenance hours on a shared device in the hangar/workshop, without logging in, with as few taps as possible. The hours end up in zweef.app as maintenance-hours registrations, where the board approves them.

## Roles
| Role | What | Where |
|---|---|---|
| Member | Starts/stops their own session, optionally picks a task and an aircraft | iPhone or iPad |
| Board / maintenance officer | Approves registrations, corrects them | zweef.app |

## Environment
The app is one universal app for iPhone and iPad, in any orientation ([ADR 0009](decisions/0009-universal-app-iphone-and-ipad.md)).

- **The shared workshop device** is the main setup: usually an iPad in landscape, mounted on a wall or a stand, in Guided Access. The screen stays on while the app is in use (`isIdleTimerDisabled = true` as long as a timer is running or the app was used recently); it may dim after two minutes of inactivity.
- **A personal iPhone or iPad** is the same app with the same flows, for a club without a shared iPad or for a member who logs their own hours. No Guided Access and no screen-on behaviour beyond a running timer.
- Internet is unreliable or absent. The app must work fully offline.

### Several devices
Each device has its own local database and uploads its own sessions.

- A running timer is only visible — and can only be stopped — on the device it was started on. zweef.app has no concept of a running timer, so there is nothing to sync it through.
- Uploading sends the sessions on *that* device. Another device uploads its own.
- "Working now" and the pending-upload counts are therefore always about the current device. The copy says so explicitly.
- Once uploaded, every device's hours end up in the same place in zweef.app, where the board sees the full picture.

## Screens (see docs/design.md for the layouts per size class)
0. **Setup assistant** (first launch) and **Settings** (hidden, behind the admin code) — see docs/configuration.md.
1. **Home** — member list ("Working now" with the running times, recents, all members; search, letter index), sync status button.
2. **Start** (sheet) — avatar + name, "Start". A wrong name is closed with the sheet's close button.
3. **Start** has no confirmation of its own: the tile moves into "Working now", a haptic fires, and an "Undo" chip stays for 10 s.
4. **Stop** (sheet) — the person and the running timer, the task list and the aircraft picker, "Stop and save"; a trash menu to delete the timer instead, with the confirmation inside the menu.
5. **Stop confirmation** — duration, task/aircraft, "Undo"; stays until someone taps outside it.
6. **Close day** — removed ([ADR 0018](decisions/0018-no-closing-the-day.md)); the sync screen lists the waiting sessions.
7. **Synchronisation** — connection, pending/rejected/uploaded sessions, and the prominent "Upload" button: the only way hours leave the device (ADR 0015).

## Flows

### Starting
1. The member taps their tile (home screen).
2. The "Start" sheet appears → tap "Start".
3. The session is saved immediately (`status = .running`, `start = now`).
4. No confirmation card: the sheet closes and the tile moves into "Working now" with its clock running. An "Undo" chip at the bottom of the screen stays for 10 s (undo deletes the session entirely).
- The member already has a running session → instead the sheet shows "You have been working since 09:12" with a "Stop" button (which leads to Stopping).

### Stopping
1. Someone taps the member's tile in "Working now" at the top of the list (their own timer or someone else's). While a timer runs, that is the member's only tile; search finds it there too.
2. The "Stop" sheet shows the person, the start time and the running duration.
3. Optional: pick a task from the club's task list (default: Glider, Winch, Hangar and workshop, Grounds, Clubhouse, Something else; configurable). For tasks with `asksForAircraft` a searchable picker of the club's own aircraft opens (from `material.json`, each with its registration and type; private gliders are left out).
4. Optional: a comment for the board, which goes into the registration after the times; required when the club turned that on (ADR 0019).
5. "Stop and save" opens a confirmation menu ("Stop Jan's timer?", or "Is 3 minutes right?" for a short session); confirming sets `stop = now`, `status = .completed`, `syncState = .local`.
6. A confirmation card with the summary and "Undo" (which puts the session back to running). No Done button and no timer: it stays until someone taps outside it, and undo is possible for as long as it is up.
- Stopping someone else's timer is allowed, and is not recorded: the app cannot tell who tapped. `stoppedByOther` and its flag remain only for sessions recorded before the stop sheet's switch was removed.

### Deleting instead of stopping
1. On the "Stop" sheet, tap the trash button in the toolbar.
2. A menu opens on the button, headed "Delete Jan's timer?", with "Delete" (destructive, subtitled "Removed from this device, never sent to zweef.app") and "Keep working".
3. "Delete" removes the session entirely; the sheet closes. There is no confirmation card and no undo — the menu was the confirmation.
- For the timer that was started by mistake, or under the wrong name, once the ten-second undo after starting has passed. Like stopping, it is open to everyone.
- Only a running timer can be deleted. A finished session is on its way to the board; corrections to those happen in zweef.app.

### Uploading
- There is no closing the day ([ADR 0018](decisions/0018-no-closing-the-day.md)). A finished session waits on the device until someone uploads it.

> Uploading is by hand ([ADR 0015](decisions/0015-manual-upload.md)): "Upload" on the sync screen sends every finished session still waiting and leaves running timers alone. Nothing uploads by itself, so there is no 24-hour safety net any more.

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

Flags are shown in orange on the sync screen's tiles. They do not travel to zweef.app: the description there is the times and the member's comment (ADR 0019).

### Language
- The app ships in English, Dutch and French, and nothing else ([ADR 0010](decisions/0010-three-languages-en-nl-fr.md)).
- It follows the system language. There is no language picker in the app; iOS's per-app language setting is the override.
- On a device set to any other language, the app falls back to English.
- Dates, times, durations and decimal hours follow the device locale.
- What the club typed itself (task labels) and what comes from zweef.app (club name, member names, aircraft) is shown as-is and never translated.
- Nothing language-dependent goes *to* zweef.app: the task label in `project` is the club's own name, and the description is the times and the member's comment (ADR 0019).

### Club data
- The club name comes from zweef.app (`GET /club.json`) when that endpoint answers, fetched during "Test connection" and on every refresh, and cached locally so it stays visible offline.
- **It answers 500 for a real club**, so the setup assistant asks for the name as well ([ADR 0012](decisions/0012-club-name-may-be-typed.md)). A typed name wins and is never overwritten by a later refresh; a fetched one is refreshed freely; neither → the app shows "Winter".
- The app is generic: no club name, members, aircraft or tasks in the code — the name is configured on the device like everything else.

### Member list and avatars
- On an automatic refresh (at most every 6 h, or with an empty cache): `GET /accounts.json` → upsert members. `?inactive=1` returns *only* the inactive members, so keeping old names for history takes a second call.
- **Members always show initials** in a colour derived from their id: `accounts.json` carries no photo, avatar or image field for any member (verified against a real club, see [zweef-api.md](zweef-api.md)). There is nothing to download and no photo cache.
- "Recents" (nl "Recent", fr "Récents"): the top 5 members by number of sessions in the last 30 days, otherwise by last seen.
- Search on first and last name, diacritics-insensitive.

## Configuration (open source)
- On first launch: the setup assistant (connection, club, logo, admin code). Without a complete configuration the rest of the app is unreachable.
- Changeable afterwards in the app: long-press the title → admin code → Settings. There you can change the club schema, the API key, the club name, the closing time, the logo, the tasks and the admin code, test the connection and refresh the members.
- A changed connection is tested first; on failure the old values stay active until you confirm.
- Pending sessions are kept when the connection changes; they go to the new connection.
- Details: docs/configuration.md.

## Out of scope
A login or PIN for members, managing hours on the device, free text, voice notes, CSV export, entering or editing hours after the fact on the device, syncing running timers between devices (see [ADR 0009](decisions/0009-universal-app-iphone-and-ipad.md)).

## Open questions
- Why `GET /club.json` answers 500 and `GET /maintenance-hours/periods.json` answers 404, and how to find the period of a brand-new maintenance period.
- The closing time.
- Is wired wifi or a device with its own 4G/5G possible for the workshop?

Answered against a real club on 18 October 2026: there is no photo in the accounts response, `category` is empty rather than `"Maintenance"`, and creating a registration returns the whole stored record (see [zweef-api.md](zweef-api.md)).
