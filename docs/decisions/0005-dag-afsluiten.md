# 0005 — Iedereen sluit de dag af, alleen zonder lopende timers

- **Status**: aanvaard
- **Datum**: 2026-10-18

## Context
Er is niet elke werkdag een verantwoordelijke aanwezig, en niet iedereen denkt aan afsluiten.

## Beslissing
Iedereen kan de dag afsluiten, maar de knop is pas actief als er geen timers meer lopen. Iedereen mag een vergeten timer van een ander stoppen (gemarkeerd). Op het instelbare sluitingsuur stopt de app lopende timers automatisch (gemarkeerd). Wordt de dag niet afgesloten, dan blijven sessies bewaard en gaan ze mee bij de volgende afsluiting; als vangnet worden afgeronde sessies ouder dan 24 uur ook geüpload.

## Gevolgen
- Geen afhankelijkheid van één persoon.
- Markeringen gaan mee naar zweef.app zodat het bestuur automatisch gestopte tijden kan corrigeren.

## Overwogen alternatieven
- Alleen een verantwoordelijke met pincode: werkt niet als die er niet is.
- Geen afsluiten, alles meteen uploaden: minder overzicht per dag.
