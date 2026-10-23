# Configuration and installation (open source)

The app is open source and has to be usable by any club on zweef.app. That is why **nothing club-specific or secret lives in the code or the repository**. Everything is configured on first launch (or through MDM) and stored on the device.

## What has to be configured
| Setting | Stored in | Required | Note |
|---|---|---|---|
| Club schema (`{club}`) | UserDefaults | yes | from the zweef.app club settings; part of the API's URL |
| zweef.app API key | **Keychain** | yes | `X-API-KEY`. Opens the club's whole account — see [SECURITY.md](../SECURITY.md) |
| Club logo | SwiftData `AppSettings` (external storage) | no | Optional, picked from Photos in the setup or in Settings, stored as a PNG of at most 512 px. zweef.app has no logo to give. Shown round at the top left of the home screen; nothing is shown without one |
| Club name | SwiftData `AppSettings` | no | Typed in the setup, prefilled from zweef.app (`GET /club.json`) when that endpoint answers — which for a real club it does not, so typing it is the normal case ([ADR 0012](decisions/0012-club-name-may-be-typed.md)). Empty → the app shows "Winter" |
| Closing time | SwiftData `AppSettings` | yes | 21:00 by default |
| Tasks | SwiftData | yes | a default list (Glider, Winch, Hangar and workshop, Grounds, Clubhouse, Something else), seeded in the setup language and editable; edited labels are club data and are not translated |
| `category` / `status` for zweef.app | UserDefaults | yes | `""` / `in_aanvraag` by default — an empty category is what real registrations carry, the documentation's `Maintenance` is not ([zweef-api.md](zweef-api.md)) |
| Admin code | **Keychain** (hashed) | yes | six digits; protects only the settings screen, not everyday use |

Keychain items use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: *after first unlock* because a wall-mounted device reboots and has to sync before anyone touches it, and *this device only* so the key cannot travel in a backup. The two keys are `apiKey` and `adminCode`, namespaced per bundle id so a debug and a release build on one device do not fight over them.

The admin code itself is never stored — a random 16-byte salt and a SHA-256 hash are. Three wrong attempts are free (room for a typo), after which the wait doubles from 30 s to a ceiling of five minutes. The count is persisted, so force-quitting the app is not a way to reset it. The code protects the *settings*, not use of the app: six digits keep a curious member out of the tokens and the erase button, and nothing more is claimed for them.

## How the device connects
Straight to `https://admin.gliding.app/club/{club}/api`, with the club's API key in the Keychain. There is one connection path and nothing to choose ([ADR 0013](decisions/0013-no-proxy.md)).

The setup and the settings screen both warn about what that key opens, and [SECURITY.md](../SECURITY.md) spells out the consequence: a lost device means rotating the club's key, because there is no per-device token to revoke.

## First launch: the setup assistant
It appears for as long as the configuration is incomplete. The steps:
1. **Welcome** — what the app does, and what you need: the club's schema name and an API key.
2. **Connection** — the club schema and the API key (a `SecureField`, pasting allowed), with the warning about what the key opens. Tap "Test connection" → `GET /maintenance-hours/current/hours.json` (not `periods.json`, which 404s). On success it shows the active period, and tries `GET /club.json` for the club name — which currently answers 500, so a successful connection without a name is normal; on failure a clear error (401, wrong URL, no internet). Skipping it while offline is allowed: the app works, syncing follows later.
3. **Club** — the club name, and optionally the club's logo from Photos ("Choose", then "Change" or "Remove"): prefilled and shown for confirmation ("Is this your club?") when `club.json` answered, and an empty field to type it in when it did not. Then the closing time and the task list (pre-filled in the language the setup is running in). Without internet during setup the club name appears after the first successful connection; until then the app shows "Winter".
4. **Admin code** — six digits, entered twice.
5. **Done** — the members are fetched (if there is internet); a tip to turn on Guided Access, and where to find the settings again.

Testing the connection is encouraged but not required: a club setting the app up in a hangar with no signal must still be able to finish. Secrets are written to the Keychain as the step is left, and the fields are cleared so the values do not sit in a view model for the rest of the session.

## Changing settings later
- The hidden entrance: long-press (3 s) on the title (the club name) → admin code → the settings screen.
- The same fields as the setup, including the club name and the logo, plus "use the name from zweef.app" to hand control of it back. And: "Refresh members now", "Change" for the key, "Erase everything on this device" (with a confirmation; it warns if there are still sessions that have not been uploaded).
- Admin code forgotten → delete the app and reinstall it (local data and the Keychain go with it; warn about this in the README).

## MDM / Managed App Configuration (optional)
Clubs with Apple Business Manager or an MDM can skip the setup. The app reads `UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed")`:

| Key | Type |
|---|---|
| `clubSchema` | String |
| `closingTime` | String (`HH:mm`) |

The API key is deliberately **not** an MDM key: a managed configuration is readable on the device, and a key that opens the club's whole account does not belong in one. It is typed once, into the Keychain.

When present: the values are prefilled, so there is less to type on a device mounted on a wall. Managed values are read-only in the setup and in the settings screen, marked with a building icon and "Managed by your organisation" — letting someone edit a value the MDM will overwrite tonight is worse than not offering it. A malformed `closingTime` is ignored rather than guessed at.

## Generic for every club
Winter contains nothing tied to a single club:
- The **members** come from zweef.app. There are no member photos: `accounts.json` has no photo field, so the app shows initials ([zweef-api.md](zweef-api.md)).
- The **club name** comes from zweef.app when `club.json` works, and is typed otherwise. A typed name is never overwritten by a later refresh ([ADR 0012](decisions/0012-club-name-may-be-typed.md)).
- The **aircraft** come from `material.json`, the **maintenance period** from the registrations in `maintenance-hours/current/hours.json`.
- The **task list**, the **closing time** and the zweef.app values for `category`/`status` are configurable, with sensible defaults.
- The **UI language** follows the device: English, Dutch or French, with English as the fallback. Not a setting in the app.
- Copy and examples in the code and the previews use fictional clubs and members.

## Repository hygiene
- No keys, tokens, club schemas or real member data in the repository, not even in previews or tests (fixtures are anonymised).
- Build settings through `Config/Shared.xcconfig`; personal values (`DEVELOPMENT_TEAM`, `BUNDLE_ID_PREFIX`) in `Config/Local.xcconfig`, which is in `.gitignore`. Example: `Config/Local.xcconfig.example`.
- The API key is typed into the app, never committed, never in an MDM payload, never logged.
