# 0020 — What the work was on comes from zweef.app

- **Status**: accepted
- **Date**: 2026-10-23
- **Amends**: [0008](0008-open-source-configuration.md) (the task list is no longer configured)

## Context
The stop sheet offered six tasks invented for the mockups — Glider, Winch,
Hangar and workshop, Grounds, Clubhouse, Something else — editable per club,
with the aircraft as a separate pick under Glider. The chosen task's label went
to zweef.app as `project`.

zweef.app's own maintenance form works differently. Its "Materiaal" field
("Selecteer project") has three tabs — Vliegend, Rollend, Overig — and lists
the club's `material.json` in them: the aircraft, the rolling stock (golf
carts, jeeps, the winch), and the club's projects ("Club", "Overige
projecten"). The tabs are `material.json`'s `category`: `kist`, `rollend`,
`overig`. The API has no other list of projects; the official collection was
checked endpoint by endpoint.

So Winter's task list matched nothing the board books on, and a club had to
keep two lists in step by hand.

## Decision
The stop sheet asks "What did you work on?" and offers zweef.app's material
list, in zweef.app's three tabs (Flying, Rolling, Other), in a searchable
picker of glass tiles. Picking one sends its id as `material_id` and its name
as `project`; picking nothing is still allowed. Among the aircraft only the
club's own (`kist_category` "club") are offered; hidden items are left out.
The list is refreshed with the members, and an item zweef.app no longer lists
disappears from the device.

`TaskDefinition`, the default task list and its section in Settings are gone.
`WorkSession.taskKey` is dropped and `aircraftId` becomes `materialId` (stored
under its old name). `Aircraft` is replaced by `Material`, which keeps every
visible item with its kind.

## Consequences
- What a member picks is exactly what the board would pick in zweef.app, and a
  material added there appears in the app at the next refresh.
- The club no longer chooses its own words, icons or colours for tasks; the
  picker shows zweef.app's names, with an icon per tab.
- That `project` is the material's name is an assumption: it is what zweef.app's
  form most likely writes, but no registration made through that form has
  been checked yet. If it differs, it is a one-line change in the draft.
- Sessions stopped with a task before this change upload without a project.

## Alternatives considered
- **Learn the project names from existing registrations**: works only for
  values already used, and says nothing about `material_id`.
- **Always send "Club" and put the task in the description**: matches what one
  club types today, but ignores the material zweef.app already offers.
