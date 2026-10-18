# 0002 — Geen login voor leden; beheercode alleen voor instellingen

- **Status**: aanvaard
- **Datum**: 2026-10-18

## Context
De iPad hangt in een werkplaats. Leden komen met vuile handen even registreren. Elke extra stap (login, pincode) verlaagt het gebruik. Misbruik (iemand anders inklokken) is een klein risico in een clubcontext.

## Beslissing
Leden kiezen hun naam uit de lijst (met foto). Er is geen login en geen persoonlijke pincode. Controle gebeurt sociaal (wie aan het werk is staat groot op het scherm) en achteraf door het bestuur in zweef.app. Alleen het instellingenscherm zit achter een beheercode, zodat leden geen tokens of instellingen kunnen wijzigen.

## Gevolgen
- Starten en stoppen kosten elk twee tikken.
- Registraties komen in zweef.app binnen als `in_aanvraag` en worden daar goedgekeurd.
- Een persoonlijke pincode kan later optioneel toegevoegd worden als misbruik een probleem blijkt.

## Overwogen alternatieven
- Persoonlijke pincode: veiliger, maar verdubbelt de drempel.
- NFC-badges of QR-codes: extra materiaal en kosten voor de club.
