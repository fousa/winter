# Mockups

Source files from the design canvas (https://claude.ai/artifact/XMfZ6e3Hj5xbwkNHAXixna). They use that canvas's runtime (`support.js`, `<x-dc>`, `{{holes}}`), so they do not open standalone in a browser. Use them as the reference for layout, sizes (pt = px), colours and copy.

The file names come from the canvas and are kept as they are there.

The mockups show the iPad in landscape, which is the reference design. The app itself is universal and adapts to iPhone and to every orientation; `docs/design.md` describes how each screen below behaves in a compact size class.

| File | Screen |
|---|---|
| `Main.dc.html` | 1 · Home (tweak `aanHetWerk` 0–10) |
| `Start.dc.html` | 2 · Start (sheet) |
| `Gestart.dc.html` | 3 · Start confirmation |
| `Stop.dc.html` | 4 · Stop (sheet) |
| `Gestopt.dc.html` | 5 · Stop confirmation |
| `Dagoverzicht.dc.html` | 6 · Close day (not built any more, ADR 0018) |
| `Sync.dc.html` | 7 · Synchronisation |
| `Druk.dc.html` | 8 · Home with 8 members working |

## Pause (`pause/`) — built ([ADR 0022](../docs/decisions/0022-pause-within-one-day.md))

Source files from a second canvas (https://claude.ai/artifact/Ux2hsFR5KS1UghiDsYkwdZ), which also holds the options that were not chosen. These are newer than the files above: English copy, initials for avatars, and the home screen as the app has it today. They import `pause/Main.dc.html`, not the `Main.dc.html` in this folder.

A member pauses from the timer sheet and resumes the same way; a pause never outlives the day.

| File | Screen |
|---|---|
| `pause/Main.dc.html` | Home, shared by the boards below (tweak `variant`: `today`, `paused`, `forgot`, …) |
| `pause/A1-Pause-sheet.dc.html` | The timer sheet (today's Stop sheet) with "Pause" beside "Stop and save" |
| `pause/A2-Paused-home.dc.html` | Home: the paused tile stays in "Working now", "On a break since 12:30" |
| `pause/A3-Resume-sheet.dc.html` | The timer sheet while paused: "Resume" or "Stop and save" |
| `pause/F1-Forgot-home.dc.html` | Home: a break of over an hour stands out |
| `pause/F2-Forgot-sheet.dc.html` | The timer sheet after a long break: pick how long it really was |
| `pause/F3-Sync-ended-on-break.dc.html` | Sync: a session the closing time ended on a break, and one with a break |
| `pause/P1-Phone-home.dc.html` … `P4-Phone-forgot-sheet.dc.html` | The same four moments on an iPhone in portrait |

The avatars in the mockups are drawn placeholders. The app shows initials in a colour derived from the member id: zweef.app returns no member photos at all (see [zweef-api.md](../docs/zweef-api.md)).

The copy in the mockups is Dutch. The app ships in English, Dutch and French with English as the source language, so the mockup text is the Dutch translation and `docs/design.md` holds the English source strings ([ADR 0010](../docs/decisions/0010-three-languages-en-nl-fr.md)).
