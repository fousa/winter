# 0001 — Offline-first, with local storage as the source of truth

- **Status**: accepted, amended by [0015](0015-manual-upload.md)
- **Date**: 2026-10-18

## Context
Internet at the club is unreliable and sometimes absent. Members have to be able to log hours at all times, and an hour that has been recorded on the iPad must never be lost.

## Decision
The app stores every action in SwiftData on the iPad immediately. Starting, stopping and closing the day work fully offline. Syncing to zweef.app is a background process that retries automatically as soon as there is a connection. A sync screen shows the status.

## Consequences
- No user action ever waits on the network.
- We need a sync engine with retries, dedup and a visible status.
- Hours can sit on the iPad for days when there is no internet; the sync screen makes that visible.

## Alternatives considered
- An online-only app: unusable with bad internet.
- Uploading right after every stop: the same complexity, but less control per day.
