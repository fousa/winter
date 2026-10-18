# 0008 — Open source, configured on the device

- **Status**: accepted (UI language superseded by [0010](0010-three-languages-en-nl-fr.md), CI secret scanning by [0011](0011-no-continuous-integration.md))
- **Date**: 2026-10-18

## Context
The app has to be usable by any club on zweef.app, not just by the author's club.

## Decision
The code is open source (MIT). Nothing club-specific or secret lives in the repository. On first launch a setup assistant configures the connection, the club and an admin code; afterwards everything can be changed in the app behind that admin code. Secrets live in the Keychain. Clubs with an MDM can supply the configuration as Managed App Configuration.

## Consequences
- The app is called Winter and is generic: the club name, members, aircraft and period come from zweef.app; the task list, the closing time and the zweef.app values are configurable.
- Being generic now also covers language: the app ships in English, Dutch and French ([ADR 0010](0010-three-languages-en-nl-fr.md)).
- Secrets are kept out of commits by review, not by a pipeline: the project runs no CI ([ADR 0011](0011-no-continuous-integration.md)).
- Test data and fixtures are anonymised.

## Alternatives considered
- A closed app per club: more work for the author, fewer contributions.
