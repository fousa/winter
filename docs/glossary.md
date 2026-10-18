# Woordenlijst

De UI en documentatie zijn Nederlands, de code is Engels. Gebruik deze namen consequent.

| Nederlands (UI/docs) | Engels (code) | Betekenis |
|---|---|---|
| Winter | `Winter` (app, bundle `<prefix>.winter`) | Naam van de app |
| Club | `club` | De zweefvliegclub; naam komt uit zweef.app |
| Lid | `Member` | Clublid uit zweef.app |
| Sessie | `WorkSession` | Eén periode van werken tussen start en stop |
| Lopende sessie / timer | `status == .running` | Sessie zonder stoptijd |
| Taak | `TaskDefinition` | Waaraan gewerkt werd (instelbaar per club) |
| Toestel | `Aircraft` | Vliegtuig of materiaal uit zweef.app `material.json` |
| Dag afsluiten | `closeDay` | Alle afgeronde sessies van de dag klaarzetten voor upload |
| Sluitingsuur | `closingTime` | Tijdstip waarop lopende timers automatisch stoppen |
| Automatisch gestopt | `autoStopped` | Sessie gestopt door het sluitingsuur |
| Gestopt door iemand anders | `stoppedByOther` | Iemand stopte de timer van een ander lid |
| Markering | `Flag` | Opvallend kenmerk van een sessie (kort, lang, automatisch gestopt, …) |
| Synchronisatie / sync | `SyncEngine` | Uploaden naar en ophalen uit zweef.app |
| Wacht op upload | `syncState == .ready` | Afgesloten, nog niet in zweef.app |
| Geweigerd | `syncState == .rejected` | zweef.app weigerde de registratie |
| Registratie | maintenance-hours record | Een onderhoudsuren-regel in zweef.app |
| Onderhoudsperiode | `period` | Periode in zweef.app waaronder registraties vallen |
| Proxy | proxy | Cloudflare Worker van de club die de API-sleutel bewaart |
| Apparaattoken | `deviceToken` | Geheim waarmee de iPad zich bij de proxy aanmeldt |
| Beheercode | `adminCode` | Code die het instellingenscherm beschermt |
| Setup-assistent | `Setup` | Configuratie bij de eerste start |
| Begeleide toegang | Guided Access | iPadOS-functie die de iPad in één app houdt |
| Bestuur | — | Keurt registraties goed in zweef.app; geen rol in de app |
