# 0005 — Anyone closes the day, only when no timers are running

- **Status**: accepted, amended by [0015](0015-manual-upload.md)
- **Date**: 2026-10-18

## Context
There is not a responsible officer present on every work day, and not everyone remembers to close up.

## Decision
Anyone can close the day, but the button only becomes active once no timers are running. Anyone may stop someone else's forgotten timer (which is flagged). At the configurable closing time the app stops running timers automatically (also flagged). If the day is not closed, sessions are kept and are included at the next closing; as a safety net, completed sessions older than 24 hours are uploaded too.

## Consequences
- No dependency on one person.
- Flags travel along to zweef.app, so the board can correct times that were stopped automatically.

## Alternatives considered
- Only an officer with a PIN: does not work when they are not there.
- No closing at all, uploading everything immediately: less overview per day.
