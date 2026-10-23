# Architecture decisions (ADRs)

Every significant choice is recorded in a short document: context, decision, consequences and the alternatives considered. If you want to change a decision, add a new ADR that supersedes the old one instead of rewriting the old one.

| No | Decision | Status |
|---|---|---|
| 0001 | [Offline-first, with local storage as the source of truth](0001-offline-first.md) | accepted |
| 0002 | [No login for members; an admin code for the settings only](0002-no-member-login.md) | accepted |
| 0003 | [The API key through a proxy, direct mode as the exception](0003-proxy-for-the-api-key.md) | superseded by 0013 |
| 0004 | [Hours as maintenance hours in zweef.app, approved there](0004-maintenance-hours-endpoint.md) | accepted |
| 0005 | [Anyone closes the day, only when no timers are running](0005-closing-the-day.md) | accepted |
| 0006 | [A native SwiftUI app for iPadOS 26 with Liquid Glass](0006-native-ipados-26.md) | accepted (device and orientation superseded by 0009) |
| 0007 | [No voice notes, free-text field or CSV export](0007-no-free-form-input.md) | accepted |
| 0008 | [Open source, configured on the device](0008-open-source-configuration.md) | accepted (UI language superseded by 0010, CI by 0011, club name by 0012) |
| 0009 | [One universal app for iPhone and iPad, fully adaptive](0009-universal-app-iphone-and-ipad.md) | accepted |
| 0010 | [The app ships in English, Dutch and French only](0010-three-languages-en-nl-fr.md) | accepted |
| 0011 | [No continuous integration](0011-no-continuous-integration.md) | accepted |
| 0012 | [The club name may be entered by hand](0012-club-name-may-be-typed.md) | accepted |
| 0013 | [No proxy: the app talks to zweef.app directly](0013-no-proxy.md) | accepted |
| 0014 | [Member tiles are Liquid Glass](0014-glass-member-tiles.md) | accepted |
| 0015 | [Hours are uploaded by hand](0015-manual-upload.md) | accepted |

## Template
```markdown
# NNNN — Title

- **Status**: proposed | accepted | superseded by NNNN
- **Date**: YYYY-MM-DD

## Context
## Decision
## Consequences
## Alternatives considered
```
