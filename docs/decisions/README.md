# Architectuurbeslissingen (ADR's)

Elke belangrijke keuze staat in een kort document: context, beslissing, gevolgen en overwogen alternatieven. Wil je een beslissing wijzigen, voeg dan een nieuwe ADR toe die de oude vervangt, in plaats van de oude te herschrijven.

| Nr | Beslissing | Status |
|---|---|---|
| 0001 | [Offline-first met lokale opslag als bron van waarheid](0001-offline-first.md) | aanvaard |
| 0002 | [Geen login voor leden; beheercode alleen voor instellingen](0002-geen-login.md) | aanvaard |
| 0003 | [API-sleutel via een proxy, directe modus als uitzondering](0003-proxy-voor-api-sleutel.md) | aanvaard |
| 0004 | [Uren als maintenance hours in zweef.app, goedkeuring daar](0004-maintenance-hours-endpoint.md) | aanvaard |
| 0005 | [Iedereen sluit de dag af, alleen zonder lopende timers](0005-dag-afsluiten.md) | aanvaard |
| 0006 | [Native SwiftUI-app voor iPadOS 26 met Liquid Glass](0006-native-ipados-26.md) | aanvaard |
| 0007 | [Geen inspreken, vrij tekstveld of CSV-export](0007-geen-vrije-invoer.md) | aanvaard |
| 0008 | [Open source, configuratie op het toestel](0008-open-source-configuratie.md) | aanvaard |

## Sjabloon
```markdown
# NNNN — Titel

- **Status**: voorgesteld | aanvaard | vervangen door NNNN
- **Datum**: JJJJ-MM-DD

## Context
## Beslissing
## Gevolgen
## Overwogen alternatieven
```
