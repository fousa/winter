# Documentation

An overview of all documentation in this repository. If you are new, start at the top.

## For clubs (installing and using)
| Document | Contents |
|---|---|
| [Installation guide for clubs](installation-guide.md) | Step by step: API key, app, first launch, Guided Access, troubleshooting |
| [Configuration](configuration.md) | Every setting, where it is stored, MDM keys |

## For developers
| Document | Contents |
|---|---|
| [CLAUDE.md](../CLAUDE.md) | A short summary of every settled decision; also the instructions for Claude Code |
| [PLAN.md](../PLAN.md) | Build plan in phases |
| [Functional specification](spec.md) | Flows, rules, edge cases |
| [Architecture](architecture.md) | Modules, responsibilities, concurrency, error handling, testing |
| [Data model](data-model.md) | SwiftData models and derived rules |
| [Synchronisation](sync.md) | The offline-first sync engine |
| [zweef.app API](zweef-api.md) | Endpoints, field mapping, dedup |
| [Design](design.md) | Screens, adaptive layout per size class, Liquid Glass, colours, copy |
| [Glossary](glossary.md) | Terms in English, Dutch and French ↔ the code names |
| [Decisions (ADRs)](decisions/README.md) | Why the main choices were made the way they were |
| [Mockups](../mockups/README.md) | Source files of the screen designs |

## For contributors
| Document | Contents |
|---|---|
| [CONTRIBUTING.md](../CONTRIBUTING.md) | How to contribute: branches, commits, tests, review |
| [SECURITY.md](../SECURITY.md) | Secrets, member data privacy, reporting vulnerabilities |
| [CHANGELOG.md](../CHANGELOG.md) | Changes per version |

## Language
The app ships in **English, Dutch and French**, and nothing else ([ADR 0010](decisions/0010-three-languages-en-nl-fr.md)). English is the source language: the code, identifiers, commits, comments, this documentation and the String Catalog's base are all English, with `nl` and `fr` as translations. See the [glossary](glossary.md) for the terms in all three languages.
