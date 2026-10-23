# 0018 — No closing the day

- **Status**: accepted
- **Date**: 2026-10-23
- **Supersedes**: the closing part of [0005](0005-closing-the-day.md); amends [0015](0015-manual-upload.md)

## Context
[ADR 0005](0005-closing-the-day.md) made "Close day" the end of a work day:
anyone could tap it once every timer was stopped, review the day's hours and
send them to zweef.app. [ADR 0015](0015-manual-upload.md) then made uploading
a separate, manual step on the sync screen that sends every finished session,
closed day or not.

After that, closing did nothing anyone needed. It marked sessions "ready" and
stamped when the day was closed, but the upload treated closed and unclosed
sessions alike, and the sync screen already lists every waiting session with
the button that sends them. The project owner asked why it was still there.

## Decision
There is no "Close day": no button on the home screen, no close-day screen,
no `SessionStore.closeDay` and no `dayClosedAt`. A finished session waits on
the device until someone taps "Upload" on the sync screen.

What stays from ADR 0005: anyone may stop anyone's forgotten timer, and at the
club's closing time (configurable, 21:00 by default) the app stops whatever is
still running and flags it "stopped automatically".

`SyncState.ready` stays, now meaning "an upload was tried and did not get
through". Sessions that an older version marked ready by closing the day are
simply waiting, like any other, so no migration is needed.

## Consequences
- One fewer button on the home screen, and on a phone no grey lock in the
  bottom bar while timers run.
- There is no end-of-day review screen any more. The sync screen shows every
  waiting session, as tiles, before anyone uploads.
- Nothing asks the last person out to do anything; the closing time still
  stops forgotten timers.

## Alternatives considered
- **Keep "Close day" as a review step**: a second screen listing the same
  sessions as the sync screen.
- **Make "Close day" upload**: two ways to send hours, which ADR 0015 chose
  against.
