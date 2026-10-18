# Glossary

The UI is in Dutch and the code is in English. Use these names consistently.

| Dutch (UI) | English (code/docs) | Meaning |
|---|---|---|
| Winter | `Winter` (app, bundle `<prefix>.winter`) | The name of the app |
| Club | `club` | The gliding club; its name comes from zweef.app |
| Lid | `Member` | A club member from zweef.app |
| Sessie | `WorkSession` | One period of work between start and stop |
| Lopende sessie / timer | `status == .running` | A session without a stop time |
| Taak | `TaskDefinition` | What was worked on (configurable per club) |
| Toestel | `Aircraft` | An aircraft or piece of equipment from zweef.app `material.json` |
| Dag afsluiten | `closeDay` | Mark all completed sessions of the day as ready to upload |
| Sluitingsuur | `closingTime` | The time at which running timers stop automatically |
| Automatisch gestopt | `autoStopped` | A session stopped by the closing time |
| Gestopt door iemand anders | `stoppedByOther` | Someone stopped another member's timer |
| Markering | `Flag` | A notable property of a session (short, long, stopped automatically, …) |
| Synchronisatie / sync | `SyncEngine` | Uploading to and fetching from zweef.app |
| Wacht op upload | `syncState == .ready` | Closed, not yet in zweef.app |
| Geweigerd | `syncState == .rejected` | zweef.app refused the registration |
| Registratie | maintenance-hours record | A maintenance-hours row in zweef.app |
| Onderhoudsperiode | `period` | The period in zweef.app that registrations belong to |
| Proxy | proxy | The club's Cloudflare Worker that holds the API key |
| Apparaattoken | `deviceToken` | The secret a device uses to authenticate with the proxy; one per device |
| Beheercode | `adminCode` | The code that protects the settings screen |
| Setup-assistent | `Setup` | Configuration on first launch |
| Begeleide toegang | Guided Access | The iOS/iPadOS feature that keeps the shared device in one app |
| Bestuur | the board | Approves registrations in zweef.app; has no role in the app |
