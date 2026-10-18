# zweef.app (GlidingApp) API

Source: https://documenter.getpostman.com/view/25434528/2s8ZDX5PRi (consulted 18 October 2026). The published documentation lists the endpoints but contains **no response examples at all**, so every shape below was read off live responses from a real club on 18 October 2026 and captured — anonymised — as fixtures in [`Tests/Fixtures`](../Tests/Fixtures/README.md).

- **Base URL**: `https://admin.gliding.app/club/{club}/api` (`{club}` = the schema name from the club settings). There is no endpoint that works without it.
- **Auth**: the header `X-API-KEY: <token>` (created in the admin pages). The documentation says so explicitly: do not use it client-side → only in the proxy.

## Endpoints we use
The app is generic: everything club-specific (name, members, aircraft, period) comes from these endpoints.

| Method | Path | Verified | Purpose in the app |
|---|---|---|---|
| GET | `/club.json` | **500** | Should give the club name. Answers `500 Server Error` for a real club, so the app cannot rely on it (see below). |
| GET | `/accounts.json` | 200 | Active members. A bare JSON array. |
| GET | `/accounts.json?inactive=1` | 200 | **Only** the inactive members, not all of them — getting everybody means two calls. |
| GET | `/material.json` | 200 | Aircraft and equipment for the aircraft picker. A bare array. |
| GET | `/maintenance-hours/periods.json` | **404** | Should give the active period. Answers `404` for a real club (also with `?id=`), so the app derives the period another way (see below). |
| GET | `/maintenance-hours/current/hours.json` | 200 | The registrations in the current period. A bare array. |
| GET | `/maintenance-hours/{periodId}/hours.json` | 200 | The registrations in one period. |
| POST | `/maintenance-hours.json` | 200 | Create a registration. Returns the whole stored record (see below). `GET` on this path answers `405`, which confirms it is write-only. |
| PUT / DELETE | `/maintenance-hours.json` | not tried | Update or delete, `id` required in the body. Not used: corrections happen in zweef.app (ADR 0004). |

## What the responses actually contain

### `GET /accounts.json`
A bare array. Each member carries about twenty top-level keys plus nested `data` (26 keys), `extra` (club-specific custom fields) and `association` objects — including address, date of birth, national registry number and medical validity dates.

The app decodes exactly four: `id`, `first_name`, `last_name`, `is_active`. What it never decodes it can never store, log or leak.

> **There is no photo.** Across every member of a real club there is no `photo`, `image`, `avatar` or `picture` key anywhere in the response, nested objects included. The member tiles therefore always show initials in a colour derived from the member's id. This answers an open question that had been in the spec from the start, and it is why there is no photo cache.

Verified non-null for every member: `id`, `first_name`, `last_name`, `name`, `is_active`, `email`, `groups`, `uuid`.

### `GET /material.json`
A bare array of aircraft *and* ground equipment.

| Field | Values seen | Use |
|---|---|---|
| `id` | int | This is what `material_id` on a registration refers to |
| `kist_id` | int or null | Links to the flights table; null for anything that does not fly. **Not** the id to upload |
| `name` | string | What the aircraft picker shows |
| `category` | `kist`, `rollend`, `overig` | `kist` = aircraft, the rest is winches, cars, buildings |
| `kist_configuration` | `Glider`, `TMG`, `Sustainer`, `Self-launching`, `""`, or the key is absent | Gliders are offered first |
| `status` | `in bedrijf`, `niet inzetbaar` | |

`kist_configuration` is genuinely missing on non-aircraft and empty on at least one aircraft, so it decodes as optional.

### `GET /maintenance-hours/current/hours.json`
A bare array of stored registrations: `id`, `date_created`, `period_id`, `user_id`, `user_name`, `date`, `hours`, `material_id`, `workorder_id`, `is_private`, `category`, `sub_category`, `project`, `description`, `status`, `date_reviewed`, `reviewer_id`, `reviewer_name`.

The values a real club has, which is what the app matches rather than the documentation's example:

| Field | Reality | The documentation's example |
|---|---|---|
| `category` | `""` on every registration | `"Maintenance"` |
| `sub_category` | `""` | `""` |
| `project` | a short free-text label (`"Club"`) | `"Workshop"` |
| `status` | `"in_aanvraag"`, and `"geaccepteerd"` once the board approves | `"in_aanvraag"` |
| `hours` | float, one or two decimals (`1.5`, `5.3`) | `2.5` |
| `date` | `"YYYY-MM-DD"` | same |
| `description` | free text, Dutch | same |

So the app sends an **empty** `category`, not `"Maintenance"`: matching what the club already has keeps the board's own filters working.

## POST /maintenance-hours.json — the body we send
```json
{
  "period_id": 1,
  "user_id": 101,
  "user_name": "Jan Verhoeven",
  "date": "2026-10-15",
  "hours": 2.3,
  "material_id": 1,
  "workorder_id": null,
  "is_private": false,
  "category": "",
  "sub_category": "",
  "project": "Zweefvliegtuig",
  "description": "Zweefvliegtuig · ASK 21 · 09:12–11:30 [ou:a1b2c3d4]",
  "status": "in_aanvraag"
}
```

## What the POST returns
The whole stored registration, flat, exactly as `hours.json` returns one — `id` at the top level, the fields we sent echoed back, and the review fields empty. Verified against a real club on 18 October 2026 by creating one registration and deleting it again:

```json
{
  "id": 12,
  "date_created": "2026-10-18T15:57:45.390792+02:00",
  "period_id": 1,
  "user_id": 5,
  "user_name": "Winter test",
  "date": "2026-10-18",
  "hours": 0.1,
  "material_id": null,
  "workorder_id": null,
  "is_private": false,
  "category": "",
  "sub_category": "",
  "project": "",
  "description": "Winter app test - please delete [ou:test0001]",
  "status": "in_aanvraag",
  "date_reviewed": null,
  "reviewer_id": null,
  "reviewer_name": ""
}
```

The app keeps the whole record, not just the id: it is the server's own account of what it stored, which is the only trustworthy answer to "did the hours arrive as we meant them".

Two things that test also settled:

- **`hours` accepts fractions below a tenth**: `0.1` was stored as sent, so the two-decimal values the app sends are safe.
- **`user_name` is free text and is not checked against `user_id`.** The test row was accepted with a `user_name` that belongs to nobody, while `user_id` pointed at a real member. So the name is purely what the board reads, and the app must send the member's real full name — the id alone does not populate it.

## Mapping from a WorkSession
| Field | Value |
|---|---|
| `period_id` | The active period (see "Finding the period") |
| `user_id`, `user_name` | The member (`zweefId`, full name) |
| `date` | `yyyy-MM-dd` of `start` in the device's own time zone, which is what defines the club's day |
| `hours` | The duration in hours, two decimals (2h15 → 2.25). Rounding: the exact minutes |
| `material_id` | The chosen aircraft's material `id`, or `null` |
| `workorder_id` | `null` |
| `is_private` | `false` |
| `category` | `""` (see above) |
| `sub_category` | `""` |
| `project` | The task label as the club stores it, or `""` |
| `description` | Composed: task · aircraft · times · flags, then the dedup tag. Flags are in the club's reporting language (ADR 0010) |
| `status` | `"in_aanvraag"` |

## Finding the period
`periods.json` is the documented way and answers 404 for a real club, so the app reads `period_id` off the registrations in `current/hours.json` instead.

That leaves one hole: a brand-new period with no registrations yet has no `period_id` to read. The app then has nothing to upload against and keeps the sessions local — they are not lost, but they do not move either. Worth asking zweef.app about, together with why `periods.json` 404s.

## The club name
`GET /club.json` answers `500` for a real club, so the app cannot count on learning the club's name. The setup assistant therefore asks for it, prefilled from this endpoint when it answers ([ADR 0012](decisions/0012-club-name-may-be-typed.md)). A typed name is kept even once `club.json` recovers; a fetched one is refreshed freely.

## Dedup / idempotency
The POST has no client-side key. The strategy:
1. After a successful POST: store the `remoteId` from the response, if there is one.
2. If the response is unclear (a timeout after sending): before trying again, `GET /maintenance-hours/current/hours.json` and look for a registration with the tag `[ou:xxxxxxxx]` in `description` (fallback: the same `user_id` + `date` + `hours`). Found → mark it as uploaded with that `id`.
3. Corrections after upload happen in zweef.app, not in the app (PUT/DELETE are only there for future use).

The decoder reads the full record zweef.app returns, and keeps a fallback for a bare id, `{"id": …}`, `{"data": {"id": …}}` or `{"maintenance_hour": {"id": …}}` — not as speculation but because PUT is undocumented too, and an id we can still read beats an upload we cannot confirm. A missing id is not a failure: dedup works off the tag, not off the id.

## Proxy
The app talks to the proxy (`proxy/`), never directly to admin.gliding.app. The proxy only forwards the paths above and replaces the device token with the `X-API-KEY`.

## Still open
- Why `periods.json` 404s, and how to find the period of a brand-new maintenance period that has no registrations to read one from.
- Why `club.json` answers 500 (worked around by [ADR 0012](decisions/0012-club-name-may-be-typed.md)).
