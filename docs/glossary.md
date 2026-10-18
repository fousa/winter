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
| Task | `TaskDefinition` | Taak | Tâche | What was worked on (configurable per club) |
| Aircraft | `Aircraft` | Toestel | Appareil | An aircraft or piece of equipment from zweef.app `material.json` |
| Close the day | `closeDay` | Dag afsluiten | Clôturer la journée | Mark all completed sessions of the day as ready to upload |
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

## Default task list
Seeded during setup in the language the setup ran in, and editable by the club afterwards. Once edited, a label is club data and is shown as typed, in whatever language the club used ([ADR 0010](decisions/0010-three-languages-en-nl-fr.md)).

| Key | English | Dutch | French | Asks for an aircraft |
|---|---|---|---|---|
| `glider` | Glider | Zweefvliegtuig | Planeur | yes |
| `winch` | Winch | Lier | Treuil | no |
| `workshop` | Hangar and workshop | Hangar en werkplaats | Hangar et atelier | no |
| `grounds` | Grounds | Terrein | Terrain | no |
| `clubhouse` | Clubhouse | Clubhuis | Club-house | no |
| `other` | Something else | Iets anders | Autre chose | no |
