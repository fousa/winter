# Glossary

The app ships in English, Dutch and French ([ADR 0010](decisions/0010-three-languages-en-nl-fr.md)). English is the source language: it is what the code and this documentation use, and what goes in the String Catalog's base. Use these names consistently, in all three languages and in the code.

## Concepts
| English (source, UI/docs) | Code | Dutch (`nl`) | French (`fr`) | Meaning |
|---|---|---|---|---|
| Winter | `Winter` (app, bundle `<prefix>.winter`) | Winter | Winter | The name of the app; not translated |
| Club | `club` | Club | Club | The gliding club; its name comes from zweef.app |
| Member | `Member` | Lid | Membre | A club member from zweef.app |
| Session | `WorkSession` | Sessie | Session | One period of work between start and stop |
| Running session / timer | `status == .running` | Lopende sessie / timer | Session en cours | A session without a stop time |
| Material | `Material` | Materiaal | Matériel | What the work was on: an item of zweef.app `material.json` — an aircraft, rolling stock, or a club project (ADR 0020) |
| Flying / Rolling / Other | `MaterialKind` | Vliegend / Rollend / Overig | Volant / Roulant / Autre | zweef.app's three tabs: `material.json` `category` `kist`, `rollend`, `overig` |
| Closing time | `closingTime` | Sluitingsuur | Heure de fermeture | The time at which running timers stop automatically |
| Stopped automatically | `autoStopped` | Automatisch gestopt | Arrêtée automatiquement | A session stopped by the closing time |
| Stopped by someone else | `stoppedByOther` | Gestopt door iemand anders | Arrêtée par quelqu'un d'autre | Someone stopped another member's timer |
| Flag | `Flag` | Markering | Signalement | A notable property of a session (short, long, stopped automatically, …) |
| Sync | `SyncEngine` | Synchronisatie / sync | Synchronisation | Uploading to and fetching from zweef.app |
| Waiting to upload | `syncState == .ready` | Wacht op upload | En attente d'envoi | Closed, not yet in zweef.app |
| Rejected | `syncState == .rejected` | Geweigerd | Refusée | zweef.app refused the registration |
| Registration | maintenance-hours record | Registratie | Enregistrement | A maintenance-hours row in zweef.app |
| Maintenance period | `period` | Onderhoudsperiode | Période d'entretien | The period in zweef.app that registrations belong to |
| API key | `apiKey` | API-sleutel | Clé API | The club's zweef.app key, in the Keychain; opens the whole account |
| Admin code | `adminCode` | Beheercode | Code d'administration | The code that protects the settings screen |
| Setup assistant | `Setup` | Setup-assistent | Assistant de configuration | Configuration on first launch |
| Guided Access | Guided Access | Begeleide toegang | Accès guidé | The iOS/iPadOS feature that keeps the shared device in one app; use Apple's own translation |
| The board | — | Bestuur | Comité | Approves registrations in zweef.app; has no role in the app |
