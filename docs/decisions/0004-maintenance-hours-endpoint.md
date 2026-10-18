# 0004 — Uren als maintenance hours in zweef.app, goedkeuring daar

- **Status**: aanvaard
- **Datum**: 2026-10-18

## Context
Bij de start van het project had de publieke API geen endpoint voor werkuren. In oktober 2026 kwamen er `maintenance-hours`-endpoints bij, met een `status`-veld (voorbeeld: `in_aanvraag`).

## Beslissing
Elke sessie wordt één registratie via `POST /maintenance-hours.json`, met status `in_aanvraag`. Goedkeuren en corrigeren gebeurt door het bestuur in zweef.app. De iPad laat geen correcties toe na upload.

## Gevolgen
- De iPad hoeft geen beheerfuncties te hebben.
- Dedup is nodig omdat de POST geen client-sleutel kent (tag in `description`, zie zweef-api.md).
- Toegelaten waarden voor `category`, `project` en `status` moeten nog bevestigd worden.

## Overwogen alternatieven
- Notities of grootboekregels gebruiken (de vroegere omweg): niet optelbaar of verschijnt op facturen.
