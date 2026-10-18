# zweef.app (GlidingApp) API

Bron: https://documenter.getpostman.com/view/25434528/2s8ZDX5PRi (geraadpleegd 18 oktober 2026). Respons-voorbeelden staan niet in de documentatie: verifieer alles met een echte API-sleutel en leg de echte JSON vast als fixtures in de tests.

- **Base URL**: `https://admin.gliding.app/club/{club}/api` (`{club}` = schema-naam uit de clubinstellingen)
- **Auth**: header `X-API-KEY: <token>` (aan te maken in de admin-pagina's). De documentatie zegt expliciet: niet client-side gebruiken → enkel in de proxy.

## Gebruikte endpoints
De app is generiek: alles wat club-specifiek is (naam, leden, toestellen, periode) komt uit deze endpoints.

| Methode | Pad | Doel in de app |
|---|---|---|
| GET | `/club.json` | Clubgegevens; de app gebruikt de **clubnaam** (titel op het startscherm, bevestiging in de setup). Ook de eerste call bij "Verbinding testen". Exacte veldnaam te verifiëren. |
| GET | `/accounts.json` | Actieve leden (`?inactive=1` voor inactieve) |
| GET | `/material.json` | Toestellen/materiaal voor de toestelkeuze (`material_id`) |
| GET | `/maintenance-hours/periods.json` | Actieve onderhoudsperiode; `?id=123` voor een specifieke |
| GET | `/maintenance-hours/{periodId}/hours.json` | Registraties van een periode; `/maintenance-hours/current/hours.json` voor de huidige |
| POST | `/maintenance-hours.json` | Registratie aanmaken |
| PUT | `/maintenance-hours.json` | Registratie aanpassen (`id` verplicht in body) |
| DELETE | `/maintenance-hours.json` | Registratie verwijderen (`id` verplicht in body) |

## POST /maintenance-hours.json — voorbeeld uit de documentatie
```json
{
  "period_id": 123,
  "user_id": 5,
  "user_name": "Example",
  "date": "2002-02-02",
  "hours": 2.5,
  "material_id": null,
  "workorder_id": null,
  "is_private": false,
  "category": "Maintenance",
  "sub_category": "",
  "project": "Workshop",
  "description": "Routine inspection",
  "status": "in_aanvraag"
}
```

## Mapping vanuit een WorkSession
| Veld | Waarde |
|---|---|
| `period_id` | actieve periode op moment van upload (gecachet; bij twijfel opnieuw ophalen) |
| `user_id`, `user_name` | lid (`zweefId`, volledige naam) |
| `date` | `yyyy-MM-dd` van `start` in Europe/Brussels |
| `hours` | duur in uren, 2 decimalen (2u15 → 2.25). Afronding: exacte minuten, tenzij de club anders beslist |
| `material_id` | gekozen toestel of `null` |
| `workorder_id` | `null` |
| `is_private` | `false` |
| `category` | `"Maintenance"` (te bevestigen) |
| `sub_category` | `""` |
| `project` | taaklabel (bv. "Hangar en werkplaats"), of `""` |
| `description` | samengesteld, bv. `"Zweefvliegtuig · ASK 21 · 09:12–11:30 · automatisch gestopt"`; markeringen achteraan; altijd een app-tag `[ou:<uuid-prefix8>]` voor dedup |
| `status` | `"in_aanvraag"` |

## Dedup / idempotentie
De POST heeft geen client-side sleutel. Strategie:
1. Na een geslaagde POST: `remoteId` uit de respons bewaren (vorm te verifiëren).
2. Als de respons onduidelijk is (timeout na versturen): vóór een nieuwe poging `GET /maintenance-hours/current/hours.json` en zoeken naar een registratie met de tag `[ou:xxxxxxxx]` in `description` (fallback: zelfde `user_id` + `date` + `hours`). Gevonden → markeer als geüpload met die `id`.
3. Correcties na upload gebeuren in zweef.app, niet op de iPad (PUT/DELETE enkel voor toekomstig gebruik).

## Proxy
De iPad praat met de proxy (`proxy/`), nooit rechtstreeks met admin.gliding.app. De proxy laat alleen de bovenstaande paden door en vervangt het apparaattoken door de `X-API-KEY`.
