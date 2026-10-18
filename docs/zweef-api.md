# zweef.app (GlidingApp) API

Source: https://documenter.getpostman.com/view/25434528/2s8ZDX5PRi (consulted 18 October 2026). The documentation contains no response examples: verify everything with a real API key and capture the real JSON as fixtures in the tests.

- **Base URL**: `https://admin.gliding.app/club/{club}/api` (`{club}` = the schema name from the club settings)
- **Auth**: the header `X-API-KEY: <token>` (created in the admin pages). The documentation says so explicitly: do not use it client-side → only in the proxy.

## Endpoints we use
The app is generic: everything club-specific (name, members, aircraft, period) comes from these endpoints.

| Method | Path | Purpose in the app |
|---|---|---|
| GET | `/club.json` | Club details; the app uses the **club name** (the title on the home screen, the confirmation in the setup). Also the first call during "Test connection". The exact field name still needs verifying. |
| GET | `/accounts.json` | Active members (`?inactive=1` for inactive ones) |
| GET | `/material.json` | Aircraft/equipment for the aircraft picker (`material_id`) |
| GET | `/maintenance-hours/periods.json` | The active maintenance period; `?id=123` for a specific one |
| GET | `/maintenance-hours/{periodId}/hours.json` | The registrations in a period; `/maintenance-hours/current/hours.json` for the current one |
| POST | `/maintenance-hours.json` | Create a registration |
| PUT | `/maintenance-hours.json` | Update a registration (`id` required in the body) |
| DELETE | `/maintenance-hours.json` | Delete a registration (`id` required in the body) |

## POST /maintenance-hours.json — the example from the documentation
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

## Mapping from a WorkSession
| Field | Value |
|---|---|
| `period_id` | The active period at the moment of upload (cached; fetched again when in doubt) |
| `user_id`, `user_name` | The member (`zweefId`, full name) |
| `date` | `yyyy-MM-dd` of `start` in Europe/Brussels |
| `hours` | The duration in hours, two decimals (2h15 → 2.25). Rounding: the exact minutes, unless the club decides otherwise |
| `material_id` | The chosen aircraft, or `null` |
| `workorder_id` | `null` |
| `is_private` | `false` |
| `category` | `"Maintenance"` (to be confirmed) |
| `sub_category` | `""` |
| `project` | The task label (e.g. "Hangar en werkplaats"), or `""` |
| `description` | Composed, e.g. `"Zweefvliegtuig · ASK 21 · 09:12–11:30 · automatisch gestopt"`; flags at the end; always an app tag `[ou:<uuid-prefix8>]` for dedup |
| `status` | `"in_aanvraag"` |

## Dedup / idempotency
The POST has no client-side key. The strategy:
1. After a successful POST: store the `remoteId` from the response (its shape still needs verifying).
2. If the response is unclear (a timeout after sending): before trying again, `GET /maintenance-hours/current/hours.json` and look for a registration with the tag `[ou:xxxxxxxx]` in `description` (fallback: the same `user_id` + `date` + `hours`). Found → mark it as uploaded with that `id`.
3. Corrections after upload happen in zweef.app, not in the app (PUT/DELETE are only there for future use).

## Proxy
The app talks to the proxy (`proxy/`), never directly to admin.gliding.app. The proxy only forwards the paths above and replaces the device token with the `X-API-KEY`.
