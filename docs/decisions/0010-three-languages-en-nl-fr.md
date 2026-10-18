# 0010 — The app ships in English, Dutch and French only

- **Status**: accepted
- **Date**: 2026-10-18
- **Supersedes**: the UI language part of [0008](0008-open-source-configuration.md) and the Dutch-only assumption throughout the docs

## Context
The app was written for Flemish clubs, so the UI was Dutch and the String Catalog had `nl-BE` as its base language. Two things pull against that. Belgium has French-speaking gliding clubs, and a club that is reachable in Dutch but not in French is not usable by half the country. And the repository is open source: contributors who do not read Dutch were expected to add Dutch literals to the code.

Translating into *every* language is a separate, much larger promise — one nobody can keep without native speakers reviewing each release. Three is what this project can actually maintain.

## Decision
The app ships in exactly three languages: **English, Dutch and French**. No other language is offered, and no machine-translated language is added without a native speaker reviewing it.

- **English (`en`) is the source language.** Literals in the code are English, and `en` is the String Catalog's base language. Code, identifiers, commits and documentation are already English ([CONTRIBUTING.md](../../CONTRIBUTING.md)), so there is no longer a language seam in the middle of the project.
- **Dutch ships as `nl`, not `nl-BE`.** The wording is Flemish, which is the main audience, but the catalog is registered under the bare language code so that a device set to Dutch (Netherlands) matches it instead of falling back to English. A `nl-NL` variant can be added later if the wording turns out to matter.
- **French ships as `fr`.** Same reasoning: a Belgian French club and a French club both match. `fr-BE` can be added later if needed.
- **The app follows the system language.** There is no language picker in the app. iOS's own per-app language setting (Settings › Winter › Language) is the override, which is where users expect it under the HIG.
- **Text sent to zweef.app uses one reporting language per club**, not the language of whoever happened to tap Stop. It is a club setting (`reportingLanguage`, default: the device language during setup). Otherwise the board would read a maintenance-hours list in which the flags are Dutch on one row and French on the next.

## Consequences
- The copy in `docs/design.md` is the English source text. The mockups stay the layout reference, but their Dutch copy is now one translation of three.
- Every string goes through the String Catalog; no string concatenation to build sentences, because word order differs per language. Flags, durations and dates are formatted with `Date.FormatStyle` and friends, never assembled by hand.
- French runs roughly 20–30% longer than English. Buttons and capsules have to grow with their label instead of truncating, which is tested the same way as the largest Dynamic Type size.
- Club-configured task labels are *not* translated. They are entered by the club in its own language and shown as typed; only the default list that is seeded during setup comes from the catalog, in the language the setup ran in.
- The dedup tag `[ou:<uuid-prefix8>]` in `description` stays untranslated and unformatted — it is a machine key ([zweef-api.md](../zweef-api.md)).
- A fourth language is a new ADR, not a pull request with a new catalog.
- The glossary keeps a term table per language so the three stay consistent with each other and with the code names.

## Alternatives considered
- **Dutch-only** (the original position): simplest, but unusable for French-speaking clubs and hostile to outside contributors.
- **Dutch as the source language, English as a translation**: keeps the mockup copy as the literal source, but leaves Dutch strings in an otherwise English codebase and makes every contributor write Dutch.
- **As many languages as people contribute**: tempting for an open-source project, but an unreviewed translation in a safety-adjacent club tool is worse than no translation, and nobody here can review Polish.
- **A language picker in the app**: duplicates a system feature, and on a shared workshop device it would be one more setting for members to flip by accident.
