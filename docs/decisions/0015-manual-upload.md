# 0015 — Hours are uploaded by hand

- **Status**: accepted
- **Date**: 2026-10-23
- **Amends**: [0001](0001-offline-first.md), [0005](0005-closing-the-day.md)

## Context
[ADR 0001](0001-offline-first.md) made syncing a background process that
retries on its own whenever there is a connection, and [ADR 0005](0005-closing-the-day.md)
made closing the day the moment hours go up, with completed sessions older than
24 hours uploaded anyway as a safety net.

In use, that left the club unable to tell when hours would reach zweef.app. The
sync screen showed sessions "waiting" with a "Try again now" button that did
nothing while the day was open, and hours went up whenever a trigger happened
to fire. The project owner wants a person to decide when hours are sent.

## Decision
Nothing uploads by itself. Hours leave the device only when someone taps
"Upload" on the sync screen, a prominent button that sends every finished
session still waiting (`.local` or `.ready`), whether or not its day was closed.
Running timers stay on the device, because they are not finished yet. Sessions
zweef.app rejected are not sent again.

The automatic triggers (the app becoming active, the network returning, the
background task) still run, but only to stop forgotten timers at the closing
time and to refresh the members, aircraft and club name. Closing the day still
exists and still needs every timer stopped; it marks the day's sessions ready
but does not send them.

Everything else in ADR 0001 stands: every action is stored locally first and
works offline. Everything else in ADR 0005 stands except the upload on closing
and the 24-hour safety net.

## Consequences
- Hours can sit on a device until somebody uploads them. The badge on the home
  screen's sync button counts them, so they stay visible, but nothing forces
  the upload; the club has to make it a habit.
- There is no retry and no backoff: an upload only runs because someone is
  standing at the device, so a failure is shown and the next tap tries again.
  `RetryPolicy` became `RefreshPolicy`, which only times the member refresh.
- "Last attempt" on the sync screen means the last upload someone asked for.

## Alternatives considered
- Keep the automatic sync and let the button upload unclosed sessions early:
  keeps hours moving without anyone thinking about it, but does not give the
  club control over when they arrive.
- Upload once when the day is closed, and otherwise by hand: one fewer tap, but
  two ways for hours to leave the device instead of one.
