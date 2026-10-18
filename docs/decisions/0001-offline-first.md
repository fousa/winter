# 0001 — Offline-first met lokale opslag als bron van waarheid

- **Status**: aanvaard
- **Datum**: 2026-10-18

## Context
Het internet op de club is onstabiel of soms afwezig. Leden moeten altijd uren kunnen registreren, en een uur dat op de iPad geregistreerd is mag nooit verloren gaan.

## Beslissing
De app bewaart elke actie meteen in SwiftData op de iPad. Starten, stoppen en de dag afsluiten werken volledig offline. Synchronisatie naar zweef.app is een achtergrondproces dat het automatisch opnieuw probeert zodra er verbinding is. Een syncscherm toont de status.

## Gevolgen
- Geen enkele gebruikersactie wacht op het netwerk.
- Er is een sync-engine nodig met retries, dedup en een zichtbare status.
- Uren kunnen dagen op de iPad blijven staan als er geen internet is; het syncscherm maakt dat zichtbaar.

## Overwogen alternatieven
- Online-only app: onbruikbaar bij slecht internet.
- Direct uploaden na elke stop: zelfde complexiteit, maar minder controle per dag.
