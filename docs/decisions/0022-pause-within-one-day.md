# 0022 — A timer can be paused, within one day

- **Status**: accepted
- **Date**: 2026-11-18
- **Amends**: [0018](0018-no-closing-the-day.md) (what the closing time does to a paused timer) and [0019](0019-description-is-times-and-a-comment.md) (the times in the description)

## Context
A member who went for lunch had two choices: leave the timer running and log
an hour they did not work, or stop and start again, which gives the board two
registrations to approve for one day's work. The project owner asked for a way
to pause.

Four designs were drawn (`mockups/pause/`, and the canvas it names): a Pause
button on the stop sheet, a Pause button on the tile itself, an "On a break"
section with a button that pauses everyone, and no pause at all but a break
length picked when stopping.

## Decision
The sheet that opens from a "Working now" tile gets a "Pause" button beside
"Stop and save", and is titled "Timer" now that it does both. A paused timer
shows "Resume" in its place. Two taps to pause, two to resume — the same path
as stopping.

- **A paused timer is still a running session.** It keeps its tile in "Working
  now", with the time standing still and "On a break since 12:30" under it.
  An upload leaves it alone, like any timer that is not finished.
- **A break is not counted.** The hours sent to zweef.app are the time worked.
  The description lists the stretches that were worked instead of one start
  and stop: "09:12–12:30 · 13:15–16:05 · Replaced the canopy seal". Times
  only, so the rule from ADR 0019 stands: nothing language-dependent goes to
  zweef.app.
- **A pause never outlives the day.** At the closing time a timer that is
  still paused ends where its break began, and is flagged "Ended on a break"
  on the sync screen. The next day the member starts again.
- **Stopping while on a break** ends the session where the break began too:
  someone who went home at lunch taps "Stop and save" from wherever they are
  in the evening, or lets the closing time do it.
- **A forgotten resume can be repaired on the spot.** After an hour the tile
  says "Break of 1h05m · forgot to resume?", and the sheet asks how long the
  break really was: 30 minutes, 45 minutes, an hour, or "Still on a break".
  Picking a length ends the break that long after it began, so the afternoon
  is not lost. If nobody does, no hours are invented.

A session stores `pausedAt` (the break it is on, if any) and its finished
breaks. Both are optional, so a database from before this version opens
unchanged.

## Consequences
- One registration per day's work, with the lunch taken out, instead of two —
  or one that is an hour too long.
- The board reads a break as a gap between two time ranges. It no longer finds
  exactly one start and one stop in every description.
- A member who forgets to resume and never comes back to the device loses the
  afternoon: the session ends at the start of the break. That is the price of
  never inventing hours; the tile and the sheet are there to catch it the same
  day.
- The hour's threshold and the three lengths are fixed in the code. A club
  whose lunches run longer sees the question a little early and answers
  "Still on a break".
- ADR 0018's rule is otherwise unchanged: a timer that is running at the
  closing time still stops at the closing time.

## Alternatives considered
- **Pause and Resume on the tile**: one tap each, but a button inside a tile
  that is itself a button, on a shared device where the wrong name gets
  tapped; it needed an undo bar to be safe.
- **An "On a break" section with "Pause everyone"**: right for a club that
  lunches together, wrong for the member still under a wing when someone
  taps it. It can be added on top of this later.
- **No pause, a break length picked when stopping**: nothing to forget, and
  the smallest change. But the length is a guess, and it is not what was
  asked for. Its chips came back as the repair for a forgotten resume.
- **A pause that lasts for days**: zweef.app has one date per registration,
  the first day's hours would sit on the device until the member came back —
  perhaps to another device, perhaps never — and "Working now" would list
  people who went home on Saturday.
- **"30 min break" as words in the description**: easier to read than a gap,
  but text in one device's language in a database every device writes to,
  which is what ADR 0019 ended.
