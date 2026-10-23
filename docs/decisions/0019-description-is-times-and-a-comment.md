# 0019 — The description is the times and a comment

- **Status**: accepted
- **Date**: 2026-10-23
- **Amends**: [0007](0007-no-free-form-input.md); supersedes [0017](0017-reporting-language-follows-the-device.md)

## Context
Each registration's `description` in zweef.app read like "Glider · OO-YBY ·
17:06–17:08 · short session [ou:af83c7b5]". The board saw the task twice (it
is also in `project`), the aircraft twice (also in `material_id`), a flag for
every quick fix, and a machine code that meant nothing to them. What they did
not see was what had actually been done, because [ADR 0007](0007-no-free-form-input.md)
ruled out a text field.

## Decision
The description is the start and stop time and, when the member wrote one,
their comment: "17:06–17:08 · Replaced the canopy seal".

- No task, no aircraft and no flags in the text. The task stays in `project`,
  the aircraft in `material_id`, and the flags (short, long, stopped
  automatically) stay on the device, on the sync screen's tiles.
- No `[ou:…]` tag. An upload that timed out is recognised by its contents
  instead: the same member, day, hours, aircraft and description. The times
  to the minute make that one member's one session.
- The stop sheet has a comment field, under the tasks. It is optional unless
  the club turns on "A comment is required when stopping" — in the setup's
  club step or in Settings — in which case "Stop and save" stays disabled
  until something is typed.

With nothing language-dependent written into zweef.app any more, ADR 0017's
question of which language the flags are in no longer arises, and
`ReportingLanguage` is gone.

## Consequences
- The board reads what was done, in the member's words, and nothing twice.
- "Stopped automatically" no longer reaches the board as text. The times
  still show it — a session ending at the closing time on the dot.
- A registration edited in zweef.app between a timed-out upload and the next
  tap would no longer be recognised, and would be posted again. That window
  is minutes and needs the board to act in it; the tag closed it, at the cost
  of the code in every row.
- ADR 0007's other refusals stand: no voice notes or dictation, no CSV export.

## Alternatives considered
- **Keep the tag at the end, hidden from nobody**: the safest dedup, but the
  owner asked for it to go.
- **Flags as words in the comment**: the board found "short session" noise.
