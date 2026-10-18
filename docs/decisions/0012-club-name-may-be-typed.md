# 0012 — The club name may be entered by hand

- **Status**: accepted
- **Date**: 2026-10-18
- **Supersedes**: the "club name is never typed in" part of [0008](0008-open-source-configuration.md)

## Context
[ADR 0008](0008-open-source-configuration.md) made a point of the app being
generic: nothing club-specific is typed into it, the club's identity comes from
zweef.app. The club name was the clearest example — fetched from
`GET /club.json` at setup and on every refresh, cached so it survives offline,
and deliberately *not* editable.

Checking that against a real club on 18 October 2026 found that
`GET /club.json` answers `500 Server Error`
([zweef-api.md](../zweef-api.md)). Every other endpoint the app needs works.
So the one value that was supposed to come from zweef.app is the one value
zweef.app will not give.

The consequence was visible: a club that configures the app correctly sees
"Winter" as the title of its own workshop screen, with no way to fix it. For a
device mounted on a clubhouse wall, that reads as broken.

## Decision
The setup assistant asks for the club name, and the settings screen lets it be
changed. It is prefilled from `GET /club.json` when that endpoint answers, and
left empty when it does not.

The precedence rule, because both sources can now have an opinion:

- A name the club **typed** wins, and is kept. A later successful
  `club.json` does not silently overwrite it: nobody's screen should rename
  their club behind their back.
- A name that was **fetched** is refreshed freely from zweef.app, which stays
  the source of truth when it works.
- Neither → the app shows "Winter".

That needs one stored bit next to the name (`clubNameIsManual`), and the
settings screen offers "use the name from zweef.app" to hand control back.

## Consequences
- One club-specific value is now typed into the app. The app stays generic in
  every other respect: members, aircraft, the period and the task list are
  still fetched or configured, and the name is a label, not behaviour.
- A club that mistypes its name lives with it until someone fixes it in
  settings — strictly better than living with "Winter".
- If zweef.app fixes `club.json`, nothing has to change: clubs that never typed
  a name simply start seeing the real one.
- The policy is a pure function with tests, rather than a rule spread across the
  setup assistant and the sync engine.

## Alternatives considered
- **Wait for zweef.app to fix `club.json`**: the honest option, and it leaves
  every club in the meantime looking at the wrong name on the wall with no
  recourse. Rejected because the fix is not ours to schedule.
- **Derive the name from the club schema**: no typing, but a schema name is a
  short internal identifier, not something to put in a navigation title above a
  clubhouse.
- **Always let the fetched name win**: simpler, one rule fewer, but it would
  throw away what someone deliberately typed the moment the endpoint recovers.
