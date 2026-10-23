# 0017 — Each device writes in its own language

- **Status**: superseded by [0019](0019-description-is-times-and-a-comment.md): nothing language-dependent is written into zweef.app any more
- **Date**: 2026-10-23
- **Amends**: [0010](0010-three-languages-en-nl-fr.md)

## Context
[ADR 0010](0010-three-languages-en-nl-fr.md) made the text the app writes into
zweef.app — the flags in a registration's description, such as "short
session" — follow one reporting language per club, set in the setup assistant
and in Settings. The aim was one consistent list for the board, whatever
language each member's device is in.

In use the setting raised more questions than it answered: the setup asked
"Hours are written to zweef.app in" next to the club name, and the project
owner asked what it was and why the app did not just use the device's
language.

## Decision
There is no reporting-language setting. The generated words in a registration
are written in the language the app runs in on the device that uploads them:
English, Dutch or French, resolved the same way as the app's own text, so a
per-app language set in iOS Settings counts too. The setup assistant and
Settings no longer ask, and `AppSettings.reportingLanguageCode` is gone.

The rest of ADR 0010 stands: three languages, English as the source, the app
follows the system language. Task labels are still the club's own names and
are never translated.

## Consequences
- A club whose devices are in different languages sees flags in different
  languages in zweef.app, one per device. The flags are a word or two next to
  the hours; the hours, dates, task and aircraft read the same either way.
- For the common case — the workshop iPad in the club's language — nothing
  changes, and there is one question fewer during setup.
- A device that changes language writes the new language from its next upload.

## Alternatives considered
- **Keep the setting, but only in Settings**: one consistent list for mixed
  clubs, at the cost of a setting most clubs would never need.
- **Flags in English only**: consistent, but English on a Dutch or French
  club's list.
