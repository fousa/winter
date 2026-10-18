# 0002 — No login for members; an admin code for the settings only

- **Status**: accepted
- **Date**: 2026-10-18

## Context
The iPad hangs in a workshop. Members stop by with dirty hands to log something quickly. Every extra step (a login, a PIN) reduces use. Abuse (clocking in as someone else) is a small risk in a club setting.

## Decision
Members pick their name from the list (with a photo). There is no login and no personal PIN. Oversight is social (whoever is working is shown large on the screen) and after the fact by the board in zweef.app. Only the settings screen sits behind an admin code, so that members cannot change tokens or settings.

## Consequences
- Starting and stopping each take two taps.
- Registrations arrive in zweef.app as `in_aanvraag` and are approved there.
- A personal PIN can be added later as an option if abuse turns out to be a problem.

## Alternatives considered
- A personal PIN: safer, but it doubles the barrier.
- NFC badges or QR codes: extra hardware and cost for the club.
