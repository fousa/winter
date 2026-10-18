# Fixtures

Real zweef.app JSON, with every trace of the club removed.

The *structure* here is taken from live responses of a real club in October
2026 — every key, its type and its nullability — because the published API
documentation has no response examples at all
([zweef-api.md](../../docs/zweef-api.md)). The *content* is entirely made up:
the fictional members from `SampleData`, invented ids, `example.com` addresses,
and no club schema anywhere. No real member data, no key, no club name belongs
in this repository (see [SECURITY.md](../../SECURITY.md)).

| File | Endpoint | What it exercises |
|---|---|---|
| `accounts.json` | `GET /accounts.json` | Active members, with the untouched `data`, `extra` and `groups` sub-objects, so the decoder is proven to ignore the 60-odd keys it does not want |
| `accounts-inactive.json` | `GET /accounts.json?inactive=1` | Returns *only* inactive members, not all of them |
| `material.json` | `GET /material.json` | Gliders, rolling stock and other; one item without `kist_configuration` and with a null `kist_id`, both of which occur |
| `maintenance-hours.json` | `GET /maintenance-hours/current/hours.json` | A stored registration, including one already accepted by the board, and the `period_id` the app reads the active period from |

If you refresh these from a live club, keep them anonymised and keep the shape:
a decoder that only works on tidy data is not worth testing.
